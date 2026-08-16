import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'camera_source.dart';
import 'design_tokens.dart';
import 'models.dart';
import 'pipeline.dart';
import 'processors.dart';
import 'rtmp_streamer.dart';
import 'sinks.dart';

/// Central application state. All modules read/write through this notifier.
class StudioState extends ChangeNotifier {
  AppModule _module = AppModule.faceSwap;
  UserMode _mode = UserMode.professional;
  StreamStatus _streamStatus = StreamStatus.idle;
  FaceSwapMode _faceMode = FaceSwapMode.realTime;
  FaceTarget? _sourceFace;
  FaceTarget? _targetFace;

  // Toggles
  bool meshOverlay = true;
  bool depthMap = false;
  bool hdr = true;
  bool chromaKey = false;
  bool noiseSuppression = true;
  bool backgroundBlur = false;
  bool virtualBackground = false;
  bool faceBeautify = true;
  bool autoLight = true;

  // Sliders
  double blendStrength = 0.85;
  double smoothing = 0.70;
  double faceScale = 1.0;
  double outputBitrate = 6000;
  double audioGain = 1.0;

  // Stream
  String streamKey = '';
  String rtmpUrl = 'rtmp://live.twitch.tv/app/';
  int viewerCount = 0;
  int streamDuration = 0;
  Timer? _streamTimer;

  // Video edit
  double playhead = 0.32;
  double zoom = 100.0;
  double brightness = 0.0;
  double contrast = 0.0;
  double saturation = 0.0;
  double sharpness = 0.0;
  double vignette = 0.0;
  double filmGrain = 0.0;
  String selectedTransition = 'Cut';
  String selectedColorGrade = 'Natural';
  List<String> timelineClips = ['Clip A', 'Clip B', 'Clip C', 'Clip D'];

  // AI Chat
  List<ChatMessage> chatHistory = [];
  bool aiTyping = false;
  Timer? _typingTimer;

  // API connections
  final List<ApiConnection> apiConnections = [
    ApiConnection(id: 'twitch', name: 'Twitch', icon: '🟣', category: 'Streaming'),
    ApiConnection(id: 'youtube', name: 'YouTube Live', icon: '🔴', category: 'Streaming'),
    ApiConnection(id: 'facebook', name: 'Facebook Live', icon: '🔵', category: 'Streaming'),
    ApiConnection(id: 'tiktok', name: 'TikTok Live', icon: '⚫', category: 'Streaming'),
    ApiConnection(id: 'zoom', name: 'Zoom', icon: '🔷', category: 'Video Call'),
    ApiConnection(id: 'teams', name: 'MS Teams', icon: '🟦', category: 'Video Call'),
    ApiConnection(id: 'meet', name: 'Google Meet', icon: '🟢', category: 'Video Call'),
    ApiConnection(id: 'discord', name: 'Discord', icon: '🟤', category: 'Social'),
    ApiConnection(id: 'instagram', name: 'Instagram Live', icon: '🌸', category: 'Social'),
    ApiConnection(id: 'snap', name: 'Snapchat', icon: '🟡', category: 'Social'),
    ApiConnection(id: 'obs', name: 'OBS Studio', icon: '⚙️', category: 'Pro Tool'),
    ApiConnection(id: 'vmix', name: 'vMix', icon: '🎬', category: 'Pro Tool'),
    ApiConnection(id: 'nvidia', name: 'NVIDIA Broadcast', icon: '💚', category: 'Pro Tool'),
    ApiConnection(id: 'ndi', name: 'NDI Protocol', icon: '📡', category: 'Pro Tool'),
    ApiConnection(id: 'srt', name: 'SRT Stream', icon: '📶', category: 'Pro Tool'),
    ApiConnection(id: 'webhook', name: 'Custom Webhook', icon: '🔗', category: 'Developer'),
    ApiConnection(id: 'rest', name: 'REST API', icon: '🌐', category: 'Developer'),
    ApiConnection(id: 'rtmp', name: 'Custom RTMP', icon: '📺', category: 'Developer'),
  ];

  // Face library — category added so FacePicker compiles & shows useful labels
  final List<FaceTarget> faceLibrary = const [
    FaceTarget(id: 'synth01', name: 'Synth Avatar 01', emoji: '🤖', accent: C.purple, category: 'Synthetic'),
    FaceTarget(id: 'anime01', name: 'Anime Vector', emoji: '🌸', accent: C.pink, category: 'Stylized'),
    FaceTarget(id: 'ghost01', name: 'Ghost Protocol', emoji: '👻', accent: C.teal, category: 'Effect'),
    FaceTarget(id: 'cyber01', name: 'Cyber Phantom', emoji: '😈', accent: C.cyan, category: 'Synthetic'),
    FaceTarget(id: 'hero01', name: 'Hero Mask', emoji: '🦸', accent: C.gold, category: 'Character'),
    FaceTarget(id: 'alien01', name: 'Astra Entity', emoji: '👽', accent: C.green, category: 'Sci-Fi'),
    FaceTarget(id: 'cat01', name: 'Nekko Overlay', emoji: '🐱', accent: C.amber, category: 'Fun'),
    FaceTarget(id: 'custom1', name: 'Custom Face 1', emoji: '📁', accent: C.blue, isCustom: true, category: 'Custom'),
  ];

  // Engine stats (simulated)
  int fps = 0;
  double latency = 0;
  double cpu = 0;
  double gpu = 0;
  double vram = 0;
  Timer? _statsTimer;
  final _rng = Random();

  AppModule get module => _module;
  UserMode get userMode => _mode;
  StreamStatus get streamStatus => _streamStatus;
  FaceSwapMode get faceSwapMode => _faceMode;
  FaceTarget? get sourceFace => _sourceFace;
  FaceTarget? get targetFace => _targetFace;
  bool get isLive => _streamStatus == StreamStatus.live;

  void setModule(AppModule m) {
    _module = m;
    notifyListeners();
  }

  void setUserMode(UserMode m) {
    _mode = m;
    notifyListeners();
  }

  void setFaceSwapMode(FaceSwapMode m) {
    _faceMode = m;
    notifyListeners();
  }

  void setSourceFace(FaceTarget? f) {
    _sourceFace = f;
    notifyListeners();
  }

  void setTargetFace(FaceTarget? f) {
    _targetFace = f;
    notifyListeners();
  }

  void toggleStream() {
    if (_streamStatus == StreamStatus.live) {
      _streamStatus = StreamStatus.idle;
      _streamTimer?.cancel();
      _stopStats();
      streamDuration = 0;
      viewerCount = 0;
    } else {
      _streamStatus = StreamStatus.live;
      _startStats();
      _streamTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        streamDuration++;
        viewerCount += _rng.nextInt(5) - 1;
        if (viewerCount < 0) viewerCount = 0;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void toggleApi(String id) {
    final api = apiConnections.firstWhere((a) => a.id == id);
    api.connected = !api.connected;
    notifyListeners();
  }

  void _startStats() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      fps = 55 + _rng.nextInt(10);
      latency = 10 + _rng.nextDouble() * 12;
      cpu = 20 + _rng.nextDouble() * 18;
      gpu = 35 + _rng.nextDouble() * 22;
      vram = 2.4 + _rng.nextDouble() * 0.8;
      notifyListeners();
    });
  }

  void _stopStats() {
    _statsTimer?.cancel();
    fps = 0;
    latency = 0;
    cpu = 0;
    gpu = 0;
    vram = 0;
  }

  void sendChat(String text) {
    chatHistory.add(ChatMessage(text: text, isUser: true, time: DateTime.now()));
    aiTyping = true;
    notifyListeners();
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(milliseconds: 800 + _rng.nextInt(1200)), () {
      chatHistory.add(ChatMessage(
        text: _generateAiReply(text),
        isUser: false,
        time: DateTime.now(),
      ));
      aiTyping = false;
      notifyListeners();
    });
  }

  String _generateAiReply(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('face swap') || lower.contains('face switch')) {
      return 'To enable real-time face swap: go to Face Swap → select a Target Face → tap Real-Time. For streaming, make sure your Virtual Camera is active and set as source in Zoom/OBS.';
    }
    if (lower.contains('stream') || lower.contains('twitch') || lower.contains('youtube')) {
      return 'For streaming: open OBS Stream tab → paste your RTMP URL and Stream Key → tap Go Live. Connect your platform in API Hub first for auto-key import.';
    }
    if (lower.contains('filter') || lower.contains('effect')) {
      return 'Open FX Lab for post-processing: color grading, LUTs, film grain, vignette, chroma key. Pro filters include Rec.709, S-Log2, and custom LUT upload.';
    }
    if (lower.contains('obs')) {
      return "Hollywood Studio Pro works as a virtual camera source. In OBS: Add Source → Video Capture Device → select 'HollywoodStudio Virtual Cam'. Enable in API Hub → OBS Studio.";
    }
    if (lower.contains('photo') || lower.contains('image')) {
      return 'Photo Edit tab has Canva-style tools: crop, resize, retouch, AI background remove, color adjust, text overlay, stickers, and one-tap export to Instagram/TikTok size.';
    }
    if (lower.contains('api') || lower.contains('webhook') || lower.contains('rtmp')) {
      return 'API Hub supports RTMP, SRT, NDI, REST webhooks, and platform OAuth. For custom RTMP: enter your ingest URL + stream key. For REST: configure endpoint + auth token.';
    }
    if (lower.contains('help') || lower.contains('how')) {
      return "I'm your AI studio assistant! I can guide you through: face swap setup, streaming configuration, video editing, API connections, and effect settings. What do you need?";
    }
    return "Got it! Here's what I suggest for your workflow: start with Face Swap → connect your platform in API Hub → go live from OBS Stream. Need help with any specific step?";
  }

  String get streamDurationFormatted {
    final h = streamDuration ~/ 3600;
    final m = (streamDuration % 3600) ~/ 60;
    final s = streamDuration % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  @override
  void dispose() {
    _streamTimer?.cancel();
    _statsTimer?.cancel();
    _typingTimer?.cancel();
    rtmp.dispose();
    pipeline?.dispose();
    previewSink?.dispose();
    super.dispose();
  }

  // ── Real pipeline integration ──────────────────────────────────────────
  StudioPipeline? pipeline;
  PreviewSink? previewSink;
  HttpPushSink? virtualCamSink;
  bool realPipelineActive = false;

  void initPipeline() {
    if (pipeline != null) return;
    pipeline = StudioPipeline();
    previewSink = PreviewSink();
    virtualCamSink = HttpPushSink()
      ..endpoint = 'http://127.0.0.1:8766/frame';

    pipeline!
      ..addProcessor(BeautifyProcessor()..enabled = faceBeautify)
      ..addProcessor(BackgroundProcessor()
        ..enabled = backgroundBlur || virtualBackground
        ..blur = backgroundBlur)
      ..addProcessor(ColorGradeProcessor()
        ..enabled = true
        ..lutName = selectedColorGrade)
      ..addProcessor(ExternalFaceSwapProcessor()
        ..enabled = targetFace != null
        ..targetFaceId = targetFace?.id ?? '')
      ..addSink(previewSink!)
      ..addSink(virtualCamSink!);

    pipeline!.addListener(() {
      if (realPipelineActive) {
        fps = pipeline!.fps;
        latency = pipeline!.latencyMs;
        notifyListeners();
      }
    });
  }

  Future<void> startRealPipeline() async {
    initPipeline();
    final source = CameraFrameSource();
    try {
      await source.listCameras();
      pipeline!.setSource(source);
      for (final p in pipeline!.processors) {
        if (p is BeautifyProcessor) p.enabled = faceBeautify;
        if (p is BackgroundProcessor) {
          p.enabled = backgroundBlur || virtualBackground;
          p.blur = backgroundBlur;
        }
        if (p is ExternalFaceSwapProcessor) {
          p.enabled = targetFace != null;
          p.targetFaceId = targetFace?.id ?? '';
        }
      }
      await pipeline!.start();
      realPipelineActive = true;
      if (_streamStatus != StreamStatus.live) {
        toggleStream();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('startRealPipeline failed: $e');
      rethrow;
    }
  }

  Future<void> stopRealPipeline() async {
    await stopRtmpStream();
    await pipeline?.stop();
    realPipelineActive = false;
    if (_streamStatus == StreamStatus.live) {
      toggleStream();
    }
    notifyListeners();
  }

  // ── RTMP streaming ─────────────────────────────────────────────────────
  final RtmpStreamer rtmp = RtmpStreamer();
  bool rtmpEnabled = false;

  Future<void> startRtmpStream({
    String? url,
    String? key,
    int? bitrateKbps,
    int width = 1920,
    int height = 1080,
    int fps = 30,
  }) async {
    final config = RtmpConfig(
      rtmpUrl: url ?? rtmpUrl,
      streamKey: key ?? streamKey,
      width: width,
      height: height,
      fps: fps,
      videoBitrateKbps: (bitrateKbps ?? outputBitrate).round(),
      enableAudio: true,
    );

    // Ensure pipeline is running so frames reach the RTMP sink
    if (!realPipelineActive) {
      try {
        await startRealPipeline();
      } catch (e) {
        debugPrint('Pipeline start for RTMP: $e');
        // Still try RTMP — bridge can use last frame / test pattern later
      }
    }

    initPipeline();
    // Attach RTMP sink once
    final hasRtmpSink = pipeline!.sinks.any((s) => s.id == 'rtmp');
    if (!hasRtmpSink) {
      pipeline!.addSink(RtmpFrameSink(rtmp));
    }

    await rtmp.start(config);
    rtmpEnabled = rtmp.isLive;
    if (rtmp.isLive && _streamStatus != StreamStatus.live) {
      toggleStream();
    }
    rtmp.addListener(_onRtmpUpdate);
    notifyListeners();
  }

  void _onRtmpUpdate() {
    rtmpEnabled = rtmp.isLive;
    if (rtmp.state == RtmpConnectionState.error) {
      debugPrint('RTMP error: ${rtmp.error}');
    }
    notifyListeners();
  }

  Future<void> stopRtmpStream() async {
    await rtmp.stop();
    rtmpEnabled = false;
    notifyListeners();
  }
}
