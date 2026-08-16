/// RTMP live streaming service for Hollywood Studio Pro.
///
/// Desktop path (recommended for studio):
///   Frames → HttpPushSink / pipe → local bridge → FFmpeg → RTMP server
///
/// Mobile path (optional):
///   Use a native plugin (rtmp_streaming / apivideo_live_stream) via [MobileRtmpAdapter].
///
/// Full RTMP URL = rtmpUrl + streamKey  (e.g. rtmp://live.twitch.tv/app/live_xxx)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'pipeline.dart';

enum RtmpConnectionState {
  idle,
  connecting,
  live,
  reconnecting,
  error,
  stopped,
}

class RtmpStats {
  final int bitrateKbps;
  final double fps;
  final int droppedFrames;
  final Duration uptime;
  final String? lastError;

  const RtmpStats({
    this.bitrateKbps = 0,
    this.fps = 0,
    this.droppedFrames = 0,
    this.uptime = Duration.zero,
    this.lastError,
  });
}

/// Configuration for an RTMP publish session.
class RtmpConfig {
  /// Base ingest URL without key, e.g. `rtmp://live.twitch.tv/app/`
  final String rtmpUrl;

  /// Stream key / path segment.
  final String streamKey;

  final int width;
  final int height;
  final int fps;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
  final String videoCodec; // libx264 | h264_nvenc | h264_qsv ...
  final String preset; // veryfast, fast, medium...
  final bool enableAudio;

  /// Local bridge that runs FFmpeg (default matches virtual_cam_bridge port scheme).
  final String bridgeBaseUrl;

  const RtmpConfig({
    required this.rtmpUrl,
    required this.streamKey,
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
    this.videoBitrateKbps = 6000,
    this.audioBitrateKbps = 160,
    this.videoCodec = 'libx264',
    this.preset = 'veryfast',
    this.enableAudio = true,
    this.bridgeBaseUrl = 'http://127.0.0.1:8766',
  });

  /// Combined publish URL: trims duplicate slashes between base and key.
  String get publishUrl {
    final base = rtmpUrl.endsWith('/') ? rtmpUrl : '$rtmpUrl/';
    final key = streamKey.startsWith('/') ? streamKey.substring(1) : streamKey;
    return '$base$key';
  }

  Map<String, dynamic> toJson() => {
        'rtmpUrl': rtmpUrl,
        'streamKey': streamKey,
        'publishUrl': publishUrl,
        'width': width,
        'height': height,
        'fps': fps,
        'videoBitrateKbps': videoBitrateKbps,
        'audioBitrateKbps': audioBitrateKbps,
        'videoCodec': videoCodec,
        'preset': preset,
        'enableAudio': enableAudio,
      };
}

/// High-level RTMP controller used by StudioState and the OBS Stream module.
class RtmpStreamer extends ChangeNotifier {
  RtmpConfig? _config;
  RtmpConnectionState _state = RtmpConnectionState.idle;
  RtmpStats _stats = const RtmpStats();
  String? _error;
  DateTime? _liveSince;
  Timer? _statsTimer;
  int _dropped = 0;

  RtmpConnectionState get state => _state;
  RtmpStats get stats => _stats;
  String? get error => _error;
  bool get isLive => _state == RtmpConnectionState.live;
  RtmpConfig? get config => _config;

  /// Start publishing. Requires the Python bridge running with RTMP support.
  Future<void> start(RtmpConfig config) async {
    if (_state == RtmpConnectionState.live ||
        _state == RtmpConnectionState.connecting) {
      return;
    }
    if (config.streamKey.trim().isEmpty) {
      _setError('Stream key is required');
      return;
    }
    if (config.rtmpUrl.trim().isEmpty) {
      _setError('RTMP URL is required');
      return;
    }

    _config = config;
    _error = null;
    _dropped = 0;
    _setState(RtmpConnectionState.connecting);

    try {
      final res = await http
          .post(
            Uri.parse('${config.bridgeBaseUrl}/rtmp/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(config.toJson()),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _liveSince = DateTime.now();
        _setState(RtmpConnectionState.live);
        _startStatsPolling();
      } else {
        _setError('Bridge error ${res.statusCode}: ${res.body}');
      }
    } on SocketException catch (e) {
      _setError(
        'Cannot reach RTMP bridge at ${config.bridgeBaseUrl}. '
        'Start bridge/virtual_cam_bridge.py first. ($e)',
      );
    } on TimeoutException {
      _setError('Bridge timed out while starting RTMP');
    } catch (e) {
      _setError('Failed to start RTMP: $e');
    }
  }

  /// Stop publishing.
  Future<void> stop() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    final base = _config?.bridgeBaseUrl ?? 'http://127.0.0.1:8766';
    try {
      await http
          .post(Uri.parse('$base/rtmp/stop'))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('RTMP stop request failed: $e');
    }
    _liveSince = null;
    _setState(RtmpConnectionState.stopped);
    _stats = const RtmpStats();
    notifyListeners();
  }

  /// Push a processed frame to the bridge while live.
  /// The bridge muxes into the FFmpeg RTMP process.
  Future<void> pushFrame(StudioFrame frame) async {
    if (!isLive || _config == null) return;
    final base = _config!.bridgeBaseUrl;
    try {
      final res = await http
          .post(
            Uri.parse('$base/rtmp/frame'),
            headers: {
              'Content-Type': 'application/octet-stream',
              'X-Frame-Width': '${frame.width}',
              'X-Frame-Height': '${frame.height}',
              'X-Frame-Format': frame.format.name,
            },
            body: frame.bytes,
          )
          .timeout(const Duration(milliseconds: 80));  // drop frame if bridge busy
      if (res.statusCode >= 400) {
        _dropped++;
      }
    } catch (_) {
      _dropped++;
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_config == null) return;
      try {
        final res = await http
            .get(Uri.parse('${_config!.bridgeBaseUrl}/rtmp/stats'))
            .timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body) as Map<String, dynamic>;
          final uptime = _liveSince != null
              ? DateTime.now().difference(_liveSince!)
              : Duration.zero;
          _stats = RtmpStats(
            bitrateKbps: (j['bitrateKbps'] as num?)?.toInt() ??
                _config!.videoBitrateKbps,
            fps: (j['fps'] as num?)?.toDouble() ?? 0,
            droppedFrames: (j['dropped'] as num?)?.toInt() ?? _dropped,
            uptime: uptime,
            lastError: j['error'] as String?,
          );
          if (j['state'] == 'error') {
            _setError(j['error']?.toString() ?? 'RTMP error');
          }
          notifyListeners();
        }
      } catch (_) {
        // Bridge briefly unreachable — keep last stats
      }
    });
  }

  void _setState(RtmpConnectionState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    _state = RtmpConnectionState.error;
    debugPrint('RtmpStreamer: $msg');
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }
}

/// Pipeline sink that forwards frames to [RtmpStreamer] while live.
class RtmpFrameSink implements FrameSink {
  final RtmpStreamer streamer;

  RtmpFrameSink(this.streamer);

  @override
  String get id => 'rtmp';

  @override
  String get name => 'RTMP Stream';

  @override
  bool get isActive => streamer.isLive;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> push(StudioFrame frame) => streamer.pushFrame(frame);
}
