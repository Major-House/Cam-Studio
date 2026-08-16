/// Frame sinks — where the endless feed goes.
///
/// For a true system-wide virtual camera on desktop you need one of:
///   • OBS Studio + Virtual Camera (easiest)
///   • NDI (NewTek) → any NDI receiver
///   • Custom virtual webcam driver (advanced)
///
/// This file provides:
///   - PreviewSink (in-app UI)
///   - HttpPushSink (send frames to a local OBS / Python relay)
///   - WebSocketSink (low-latency binary frames to a local bridge)

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'pipeline.dart';

/// In-app preview — always available.
class PreviewSink implements FrameSink {
  @override
  final String id = 'preview';
  @override
  final String name = 'In-App Preview';

  final StreamController<StudioFrame> _frames = StreamController.broadcast();
  bool _active = false;

  Stream<StudioFrame> get previewFrames => _frames.stream;

  @override
  bool get isActive => _active;

  @override
  Future<void> start() async => _active = true;

  @override
  Future<void> stop() async => _active = false;

  @override
  Future<void> push(StudioFrame frame) async {
    if (_active && _frames.hasListener) {
      _frames.add(frame);
    }
  }

  void dispose() {
    _frames.close();
  }
}

/// Pushes JPEG frames to a local bridge that feeds OBS Virtual Cam / NDI.
/// Example bridge: a small Python script that receives POST /frame and
/// writes into pyvirtualcam or obs-websocket.
class HttpPushSink implements FrameSink {
  @override
  final String id = 'http_push';
  @override
  final String name = 'HTTP → Virtual Cam Bridge';

  String endpoint = 'http://127.0.0.1:8766/frame';
  bool _active = false;

  @override
  bool get isActive => _active;

  @override
  Future<void> start() async => _active = true;

  @override
  Future<void> stop() async => _active = false;

  @override
  Future<void> push(StudioFrame frame) async {
    if (!_active) return;
    try {
      await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/octet-stream',
          'X-Frame-Width': '${frame.width}',
          'X-Frame-Height': '${frame.height}',
          'X-Frame-Format': frame.format.name,
        },
        body: frame.bytes,
      ).timeout(const Duration(milliseconds: 80));
    } catch (e) {
      // Drop frame on bridge timeout — keep pipeline real-time.
      if (kDebugMode) debugPrint('HttpPushSink: $e');
    }
  }
}

/// Binary WebSocket sink for lower latency to a local virtual-cam bridge.
class WebSocketSink implements FrameSink {
  @override
  final String id = 'ws_push';
  @override
  final String name = 'WebSocket → Virtual Cam Bridge';

  String url = 'ws://127.0.0.1:8767/frames';
  WebSocketChannel? _channel;
  bool _active = false;

  @override
  bool get isActive => _active;

  @override
  Future<void> start() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _active = true;
    } catch (e) {
      debugPrint('WebSocketSink connect failed: $e');
      _active = false;
    }
  }

  @override
  Future<void> stop() async {
    await _channel?.sink.close();
    _channel = null;
    _active = false;
  }

  @override
  Future<void> push(StudioFrame frame) async {
    if (!_active || _channel == null) return;
    try {
      // Header as JSON + binary, or pure binary depending on bridge protocol.
      final header = jsonEncode({
        'w': frame.width,
        'h': frame.height,
        'fmt': frame.format.name,
        'ts': frame.timestamp.millisecondsSinceEpoch,
      });
      _channel!.sink.add(header);
      _channel!.sink.add(frame.bytes);
    } catch (e) {
      if (kDebugMode) debugPrint('WebSocketSink: $e');
    }
  }
}
