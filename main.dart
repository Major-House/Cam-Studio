// ============================================================
// ENDLESS CAM / STUDIO — Full Professional Edition
// Flutter Single-File Implementation
// Modules: Face Swap · OBS Stream · Video Edit · Photo Edit
//          API Hub · AI Chat · Capture · Timeline · FX
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const EndlessCamApp());
}

// ─────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────
enum StudioTheme { broadcast, midnight, oled }

/// Dark-mode design tokens (all themes are dark — optimized for studio work).
class C {
  static Color bg       = const Color(0xFF070710);
  static Color panel    = const Color(0xFF0D0D1E);
  static Color elevated = const Color(0xFF131326);
  static Color card     = const Color(0xFF181830);
  static Color border   = const Color(0xFF1E1E3C);
  static Color divider  = const Color(0xFF151530);

  static Color gold     = const Color(0xFFFFBF00);
  static Color goldDim  = const Color(0xFF8A6800);
  static Color cyan     = const Color(0xFF00E5FF);
  static Color purple   = const Color(0xFFBB86FC);
  static Color pink     = const Color(0xFFFF4081);
  static Color green    = const Color(0xFF00E676);
  static Color red      = const Color(0xFFFF1744);
  static Color amber    = const Color(0xFFFFAB00);
  static Color blue     = const Color(0xFF448AFF);
  static Color teal     = const Color(0xFF1DE9B6);

  static Color tx1      = const Color(0xFFF0F0FF);
  static Color tx2      = const Color(0xFF8888AA);
  static Color tx3      = const Color(0xFF44445A);

  static LinearGradient goldGrad = const LinearGradient(
    colors: [Color(0xFFFFBF00), Color(0xFFFF6F00)],
  );
  static LinearGradient cyanGrad = const LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
  );
  static LinearGradient purpleGrad = const LinearGradient(
    colors: [Color(0xFFBB86FC), Color(0xFF7C4DFF)],
  );

  static void apply(StudioTheme theme) {
    switch (theme) {
      case StudioTheme.broadcast:
        bg = const Color(0xFF070710);
        panel = const Color(0xFF0D0D1E);
        elevated = const Color(0xFF131326);
        card = const Color(0xFF181830);
        border = const Color(0xFF1E1E3C);
        divider = const Color(0xFF151530);
        gold = const Color(0xFFFFBF00);
        cyan = const Color(0xFF00E5FF);
        tx1 = const Color(0xFFF0F0FF);
        tx2 = const Color(0xFF8888AA);
        tx3 = const Color(0xFF44445A);
        break;
      case StudioTheme.midnight:
        bg = const Color(0xFF0A0E17);
        panel = const Color(0xFF111827);
        elevated = const Color(0xFF1A2332);
        card = const Color(0xFF1F2A3D);
        border = const Color(0xFF2A3A52);
        divider = const Color(0xFF162032);
        gold = const Color(0xFFFFC933);
        cyan = const Color(0xFF38BDF8);
        tx1 = const Color(0xFFE8EEF8);
        tx2 = const Color(0xFF94A3B8);
        tx3 = const Color(0xFF64748B);
        break;
      case StudioTheme.oled:
        bg = const Color(0xFF000000);
        panel = const Color(0xFF050505);
        elevated = const Color(0xFF0C0C0C);
        card = const Color(0xFF121212);
        border = const Color(0xFF222222);
        divider = const Color(0xFF141414);
        gold = const Color(0xFFFFB800);
        cyan = const Color(0xFF00F0FF);
        tx1 = const Color(0xFFFFFFFF);
        tx2 = const Color(0xFFAAAAAA);
        tx3 = const Color(0xFF555555);
        break;
    }
  }

  static String label(StudioTheme t) {
    switch (t) {
      case StudioTheme.broadcast: return 'Broadcast';
      case StudioTheme.midnight: return 'Midnight';
      case StudioTheme.oled: return 'OLED';
    }
  }
}

// ─────────────────────────────────────────
// MODELS & STATE
// ─────────────────────────────────────────
enum AppModule {
  faceSwap, obsStream, videoEdit, photoEdit,
  apiHub, aiChat, voiceClone, capture, timeline, fxLab,
}

enum StreamStatus { idle, live, paused, error }
enum FaceSwapMode { realTime, staticPhoto, videoFile }
enum UserMode { amateur, professional }

class FaceTarget {
  final String id, name, emoji;
  final Color accent;
  final bool isCustom;
  final String category;
  const FaceTarget({
    required this.id, required this.name,
    required this.emoji, required this.accent,
    this.isCustom = false,
    this.category = 'Avatar',
  });
}

class ApiConnection {
  final String id, name, icon, category;
  bool connected;
  ApiConnection({
    required this.id, required this.name,
    required this.icon, required this.category,
    this.connected = false,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, required this.time});
}

class StudioState extends ChangeNotifier {
  AppModule _module = AppModule.faceSwap;
  UserMode _mode = UserMode.amateur;
  StudioTheme _theme = StudioTheme.broadcast;
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
  bool backgroundBlur = true;       // on by default for studio look
  bool virtualBackground = false;
  bool faceBeautify = true;
  bool autoLight = true;
  bool endlessCamEnabled = true;    // virtual cam path always armed
  bool allStudioFeatures = true;    // face + grade + obs hooks active

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
  List<ApiConnection> apiConnections = [
    ApiConnection(id: 'twitch',   name: 'Twitch',         icon: '🟣', category: 'Streaming'),
    ApiConnection(id: 'youtube',  name: 'YouTube Live',   icon: '🔴', category: 'Streaming'),
    ApiConnection(id: 'facebook', name: 'Facebook Live',  icon: '🔵', category: 'Streaming'),
    ApiConnection(id: 'tiktok',   name: 'TikTok Live',    icon: '⚫', category: 'Streaming'),
    ApiConnection(id: 'zoom',     name: 'Zoom',           icon: '🔷', category: 'Video Call'),
    ApiConnection(id: 'teams',    name: 'MS Teams',       icon: '🟦', category: 'Video Call'),
    ApiConnection(id: 'meet',     name: 'Google Meet',    icon: '🟢', category: 'Video Call'),
    ApiConnection(id: 'discord',  name: 'Discord',        icon: '🟤', category: 'Social'),
    ApiConnection(id: 'instagram',name: 'Instagram Live', icon: '🌸', category: 'Social'),
    ApiConnection(id: 'snap',     name: 'Snapchat',       icon: '🟡', category: 'Social'),
    ApiConnection(id: 'obs',      name: 'OBS Studio',     icon: '⚙️', category: 'Pro Tool'),
    ApiConnection(id: 'vmix',     name: 'vMix',           icon: '🎬', category: 'Pro Tool'),
    ApiConnection(id: 'nvidia',   name: 'NVIDIA Broadcast',icon: '💚', category: 'Pro Tool'),
    ApiConnection(id: 'ndi',      name: 'NDI Protocol',   icon: '📡', category: 'Pro Tool'),
    ApiConnection(id: 'srt',      name: 'SRT Stream',     icon: '📶', category: 'Pro Tool'),
    ApiConnection(id: 'webhook',  name: 'Custom Webhook', icon: '🔗', category: 'Developer'),
    ApiConnection(id: 'rest',     name: 'REST API',       icon: '🌐', category: 'Developer'),
    ApiConnection(id: 'rtmp',     name: 'Custom RTMP',    icon: '📺', category: 'Developer'),
  ];

  // Face library
  final List<FaceTarget> faceLibrary = [
    FaceTarget(id: 'synth01', name: 'Synth Avatar 01', emoji: '🤖', accent: C.purple, category: 'Synthetic'),
    FaceTarget(id: 'anime01', name: 'Anime Vector',    emoji: '🌸', accent: C.pink, category: 'Stylized'),
    FaceTarget(id: 'ghost01', name: 'Ghost Protocol',  emoji: '👻', accent: C.teal, category: 'Effect'),
    FaceTarget(id: 'cyber01', name: 'Cyber Phantom',   emoji: '😈', accent: C.cyan, category: 'Synthetic'),
    FaceTarget(id: 'hero01',  name: 'Hero Mask',       emoji: '🦸', accent: C.gold, category: 'Character'),
    FaceTarget(id: 'alien01', name: 'Astra Entity',    emoji: '👽', accent: C.green, category: 'Sci-Fi'),
    FaceTarget(id: 'cat01',   name: 'Nekko Overlay',   emoji: '🐱', accent: C.amber, category: 'Fun'),
    FaceTarget(id: 'custom1', name: 'Custom Face 1',   emoji: '📁', accent: C.blue, isCustom: true, category: 'Custom'),
  ];

  // Engine stats
  int fps = 0;
  double latency = 0;
  double cpu = 0;
  double gpu = 0;
  double vram = 0;
  Timer? _statsTimer;
  final _rng = Random();

  AppModule  get module      => _module;
  UserMode   get userMode    => _mode;
  StudioTheme get studioTheme => _theme;
  StreamStatus get streamStatus => _streamStatus;
  FaceSwapMode get faceSwapMode => _faceMode;
  FaceTarget? get sourceFace => _sourceFace;
  FaceTarget? get targetFace => _targetFace;
  bool get isLive => _streamStatus == StreamStatus.live;

  void setModule(AppModule m)       { _module = m; notifyListeners(); }
  void setUserMode(UserMode m)      { _mode = m; notifyListeners(); }
  void setStudioTheme(StudioTheme th) {
    _theme = th;
    C.apply(th);
    notifyListeners();
  }
  void cycleStudioTheme() {
    const order = StudioTheme.values;
    final i = (order.indexOf(_theme) + 1) % order.length;
    setStudioTheme(order[i]);
  }
  void setFaceSwapMode(FaceSwapMode m) { _faceMode = m; notifyListeners(); }
  void setSourceFace(FaceTarget? f) { _sourceFace = f; notifyListeners(); }
  void setTargetFace(FaceTarget? f) { _targetFace = f; notifyListeners(); }


  // RTMP live via local FFmpeg bridge (bridge/virtual_cam_bridge.py)
  String? rtmpError;
  bool rtmpConnecting = false;

  Future<void> goLiveRtmp({
    required String url,
    required String key,
  }) async {
    rtmpUrl = url.trim();
    streamKey = key.trim();
    rtmpError = null;

    if (streamKey.isEmpty) {
      rtmpError = 'Stream key is required';
      notifyListeners();
      return;
    }
    if (rtmpUrl.isEmpty) {
      rtmpError = 'RTMP URL is required';
      notifyListeners();
      return;
    }

    if (isLive) {
      // Stop RTMP + UI live state
      try {
        await http.post(Uri.parse('http://127.0.0.1:8766/rtmp/stop'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      toggleStream();
      notifyListeners();
      return;
    }

    rtmpConnecting = true;
    notifyListeners();

    final base = rtmpUrl.endsWith('/') ? rtmpUrl : '$rtmpUrl/';
    final sk = streamKey.startsWith('/') ? streamKey.substring(1) : streamKey;
    final publishUrl = '$base$sk';

    final body = jsonEncode({
      'rtmpUrl': rtmpUrl,
      'streamKey': streamKey,
      'publishUrl': publishUrl,
      'width': 1920,
      'height': 1080,
      'fps': 30,
      'videoBitrateKbps': outputBitrate.round(),
      'audioBitrateKbps': 160,
      'videoCodec': 'auto',  // h264_nvenc when available, else libx264
      'preset': 'veryfast',
      'enableAudio': true,
    });

    try {
      final res = await http
          .post(
            Uri.parse('http://127.0.0.1:8766/rtmp/start'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        toggleStream(); // UI live badge + stats
        rtmpError = null;
      } else {
        rtmpError = 'RTMP start failed (${res.statusCode}): ${res.body}';
      }
    } catch (e) {
      rtmpError =
          'Cannot reach RTMP bridge at 127.0.0.1:8766. '
          'Run: python bridge/virtual_cam_bridge.py (and install ffmpeg). ($e)';
    } finally {
      rtmpConnecting = false;
      notifyListeners();
    }
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
    fps = 0; latency = 0; cpu = 0; gpu = 0; vram = 0;
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
    if (lower.contains('face swap') || lower.contains('face switch'))
      return "To enable real-time face swap: go to Face Swap → select a Target Face → tap Real-Time. For streaming, make sure your Virtual Camera is active and set as source in Zoom/OBS.";
    if (lower.contains('stream') || lower.contains('twitch') || lower.contains('youtube'))
      return "For streaming: open OBS Stream tab → paste your RTMP URL and Stream Key → tap Go Live. Connect your platform in API Hub first for auto-key import.";
    if (lower.contains('filter') || lower.contains('effect'))
      return "Open FX Lab for post-processing: color grading, LUTs, film grain, vignette, chroma key. Pro filters include Rec.709, S-Log2, and custom LUT upload.";
    if (lower.contains('obs'))
      return "Endless Cam / Studio works as a virtual camera source. In OBS: Add Source → Video Capture Device → select 'EndlessCam Virtual Cam'. Enable in API Hub → OBS Studio.";
    if (lower.contains('photo') || lower.contains('image'))
      return "Photo Edit tab has Canva-style tools: crop, resize, retouch, AI background remove, color adjust, text overlay, stickers, and one-tap export to Instagram/TikTok size.";
    if (lower.contains('api') || lower.contains('webhook') || lower.contains('rtmp'))
      return "API Hub supports RTMP, SRT, NDI, REST webhooks, and platform OAuth. For custom RTMP: enter your ingest URL + stream key. For REST: configure endpoint + auth token.";
    if (lower.contains('virtual cam') || lower.contains('zoom') || lower.contains('teams') || lower.contains('discord') || lower.contains('endless cam'))
      return "Option 1 — VIRTUAL CAM (best for calls): Start the Python bridge, enable virtual camera, then in Zoom/Teams/Discord/Meet choose camera = StudioCam / OBS Virtual Camera. Lowest latency for native apps.";
    if (lower.contains('webrtc') || lower.contains('browser') || lower.contains('web preview'))
      return "Option 2 — WEBRTC (best for browser): Run python bridge/webrtc_server.py then open http://127.0.0.1:8787 and tap Connect. Ultra-low latency for web viewers and control-room preview.";
    if (lower.contains('nvenc') || lower.contains('nvidia') || lower.contains('hardware encode'))
      return "Option 3 — RTMP + NVIDIA NVENC: In OBS Stream set codec to auto/h264_nvenc (needs NVIDIA + FFmpeg with NVENC). Go Live to Twitch/YouTube/TikTok. Hardware encode = lower CPU and lower stream lag.";
    if (lower.contains('delivery') || lower.contains('output path') || lower.contains('3 options') || lower.contains('remember'))
      return "Remember the 3 delivery paths:\n1) VIRTUAL CAM → Zoom/Teams/Discord (local endless cam)\n2) WEBRTC → browser at :8787 (lowest web latency)\n3) RTMP + NVENC → Twitch/YouTube/TikTok live\nPick one path in OBS Stream → Delivery, or say the option name here.";
    if (lower.contains('whip') || lower.contains('webrtc ingest'))
      return "WHIP (RFC 9725): Run python bridge/whip_server.py · URL http://127.0.0.1:8788/whip/endpoint · Bearer token from WHIP_TOKEN. OBS Custom WHIP or any WHIP encoder. Pro delivery path 4.";
    if (lower.contains('help') || lower.contains('how'))
      return "Easy checklist: (1) Virtual Cam for calls (2) WebRTC for browser preview (3) RTMP+NVENC for public live. Also: Face Swap, Voice, Video Edit shorts/film. What should we do first?";
    return "Remember: Virtual Cam = calls · WebRTC = browser · RTMP+NVENC = public live. Start Face Swap if you want a look, then pick a delivery path in OBS Stream. Ask me any of those three by name!";
  }

  String get streamDurationFormatted {
    final h = streamDuration ~/ 3600;
    final m = (streamDuration % 3600) ~/ 60;
    final s = streamDuration % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _statsTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────
class EndlessCamApp extends StatelessWidget {
  const EndlessCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme is applied live inside StudioRoot via StudioState.studioTheme
    return const StudioRoot();
  }
}

ThemeData _buildDarkTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.panel,
    cardColor: C.card,
    dividerColor: C.border,
    colorScheme: ColorScheme.dark(
      primary: C.gold,
      secondary: C.cyan,
      surface: C.panel,
      error: C.red,
      onPrimary: Colors.black,
      onSurface: C.tx1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: C.panel,
      foregroundColor: C.tx1,
      elevation: 0,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: C.elevated,
      titleTextStyle: TextStyle(color: C.tx1, fontWeight: FontWeight.bold),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.elevated,
      contentTextStyle: TextStyle(color: C.tx1),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: C.gold,
      inactiveTrackColor: C.border,
      thumbColor: C.gold,
      overlayColor: C.gold.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.gold : C.tx3,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? C.gold.withValues(alpha: 0.4)
            : C.border,
      ),
    ),
  );
}

// ─────────────────────────────────────────
// STUDIO ROOT
// ─────────────────────────────────────────
class StudioRoot extends StatefulWidget {
  const StudioRoot({super.key});
  @override
  State<StudioRoot> createState() => _StudioRootState();
}

class _StudioRootState extends State<StudioRoot> with TickerProviderStateMixin {
  final StudioState _state = StudioState();
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    C.apply(_state.studioTheme);
    _state.addListener(() => setState(() {}));
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Endless Cam / Studio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _buildDarkTheme(),
      darkTheme: _buildDarkTheme(),
      home: Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        _TopBar(state: _state),
        Expanded(child: Row(children: [
          _SideNav(state: _state),
          Expanded(child: _buildModule()),
          _RightPanel(state: _state, pulseCtrl: _pulseCtrl, scanCtrl: _scanCtrl),
        ])),
        _StatusBar(state: _state),
      ]),
    ),
    );
  }

  Widget _buildModule() {
    switch (_state.module) {
      case AppModule.faceSwap:   return FaceSwapModule(state: _state);
      case AppModule.obsStream:  return OBSStreamModule(state: _state);
      case AppModule.videoEdit:  return VideoEditModule(state: _state);
      case AppModule.photoEdit:  return PhotoEditModule(state: _state);
      case AppModule.apiHub:     return ApiHubModule(state: _state);
      case AppModule.aiChat:     return AiChatModule(state: _state);
      case AppModule.voiceClone: return VoiceCloneModule(state: _state);
      case AppModule.capture:    return CaptureModule(state: _state);
      case AppModule.timeline:   return TimelineModule(state: _state);
      case AppModule.fxLab:      return FxLabModule(state: _state);
    }
  }
}

// ─────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final StudioState state;
  const _TopBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        // Brand logo
        Image.asset(
          'assets/branding/endless_cam_studio_logo.jpg',
          height: 36,
          width: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.movie_creation, color: C.gold, size: 22),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (b) => C.goldGrad.createShader(b),
          child: const Text('ENDLESS CAM / STUDIO',
            style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2.0)),
        ),
        const SizedBox(width: 12),
        _Pill(label: 'v3.0 ELITE', color: C.gold),
        const Spacer(),
        // Dark theme pack
        _ThemeToggle(state: state),
        const SizedBox(width: 10),
        // Mode toggle
        _ModeToggle(state: state),
        const SizedBox(width: 16),
        // Live badge
        if (state.isLive) ...[
          _LiveBadge(state: state),
          const SizedBox(width: 12),
        ],
        // Virtual cam
        _TopBtn(
          icon: Icons.videocam,
          label: 'Virtual Cam',
          active: state.isLive,
          color: C.cyan,
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _TopBtn(
          icon: Icons.record_voice_over,
          label: 'Voice FX',
          active: state.noiseSuppression,
          color: C.purple,
          onTap: () { state.noiseSuppression = !state.noiseSuppression; },
        ),
        const SizedBox(width: 8),
        _TopBtn(
          icon: Icons.settings_suggest,
          label: 'AI Assist',
          active: true,
          color: C.gold,
          onTap: () => state.setModule(AppModule.aiChat),
        ),
      ]),
    );
  }
}


class _ThemeToggle extends StatelessWidget {
  final StudioState state;
  const _ThemeToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state.cycleStudioTheme,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: C.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dark_mode, size: 14, color: C.cyan),
            const SizedBox(width: 6),
            Text(
              C.label(state.studioTheme),
              style: TextStyle(
                color: C.tx1,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final StudioState state;
  const _ModeToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: C.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _ModeBtn(label: 'PRO', active: state.userMode == UserMode.professional,
          onTap: () => state.setUserMode(UserMode.professional)),
        _ModeBtn(label: 'EASY', active: state.userMode == UserMode.amateur,
          color: C.cyan, onTap: () => state.setUserMode(UserMode.amateur)),
      ]),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.active,
    this.color = C.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: TextStyle(
          color: active ? color : C.tx3,
          fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2,
        )),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final StudioState state;
  const _LiveBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: C.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: C.red.withOpacity(0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
          decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('LIVE  ${state.streamDurationFormatted}',
          style: const TextStyle(color: C.red, fontSize: 10,
            fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(width: 8),
        Text('👁 ${state.viewerCount}',
          style: const TextStyle(color: C.tx2, fontSize: 10)),
      ]),
    );
  }
}

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.label,
    required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : C.elevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color.withOpacity(0.5) : C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? color : C.tx2),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: active ? color : C.tx2,
            fontSize: 10, fontWeight: FontWeight.w600,
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// SIDE NAV
// ─────────────────────────────────────────
class _SideNav extends StatelessWidget {
  final StudioState state;
  const _SideNav({required this.state});

  static const _items = [
    (AppModule.faceSwap,  '🎭', 'Face Swap'),
    (AppModule.obsStream, '📡', 'OBS Stream'),
    (AppModule.videoEdit, '🎬', 'Video Edit'),
    (AppModule.photoEdit, '🖼️', 'Photo Edit'),
    (AppModule.apiHub,    '🔗', 'API Hub'),
    (AppModule.aiChat,    '🤖', 'AI Chat'),
    (AppModule.voiceClone,'🎙️', 'Voice'),
    (AppModule.capture,   '📷', 'Capture'),
    (AppModule.timeline,  '🎞️', 'Timeline'),
    (AppModule.fxLab,     '✨', 'FX Lab'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(right: BorderSide(color: C.border)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/branding/endless_cam_studio_logo.jpg',
              height: 44,
              width: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 44, width: 44,
                decoration: BoxDecoration(
                  color: C.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.videocam, color: C.gold, size: 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._items.map((item) => _NavIcon(
          module: item.$1,
          emoji: item.$2,
          label: item.$3,
          selected: state.module == item.$1,
          onTap: () => state.setModule(item.$1),
        )),
      ]),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final AppModule module;
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _NavIcon({required this.module, required this.emoji,
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? C.gold.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? C.gold.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 3),
          Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? C.gold : C.tx3,
              fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// RIGHT PANEL — Live Preview + Engine
// ─────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  final StudioState state;
  final AnimationController pulseCtrl, scanCtrl;
  const _RightPanel({required this.state, required this.pulseCtrl, required this.scanCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(left: BorderSide(color: C.border)),
      ),
      child: Column(children: [
        // Preview window
        _PreviewWindow(state: state, pulseCtrl: pulseCtrl, scanCtrl: scanCtrl),
        const Divider(height: 1, color: C.border),
        // Engine stats
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _PanelLabel('ENGINE STATS'),
            const SizedBox(height: 8),
            _StatRow('FPS', state.isLive ? '${state.fps}' : '--',
              color: state.fps >= 55 ? C.green : C.amber),
            _StatRow('LATENCY', state.isLive ? '${state.latency.toStringAsFixed(1)}ms' : '--', color: C.cyan),
            _StatRow('CPU', state.isLive ? '${state.cpu.toStringAsFixed(1)}%' : '--', color: C.amber),
            _StatRow('GPU', state.isLive ? '${state.gpu.toStringAsFixed(1)}%' : '--', color: C.purple),
            _StatRow('VRAM', state.isLive ? '${state.vram.toStringAsFixed(1)} GB' : '--', color: C.gold),
            const SizedBox(height: 16),
            _PanelLabel('QUICK TOGGLES'),
            const SizedBox(height: 8),
            _MiniToggle('Face Beautify',    state.faceBeautify, (v) { state.faceBeautify = v; }),
            _MiniToggle('Auto Light',       state.autoLight,    (v) { state.autoLight = v; }),
            _MiniToggle('Background Blur',  state.backgroundBlur,(v) { state.backgroundBlur = v; }),
            _MiniToggle('Chroma Key',       state.chromaKey,    (v) { state.chromaKey = v; }),
            _MiniToggle('Noise Suppress',   state.noiseSuppression,(v) { state.noiseSuppression = v; }),
            _MiniToggle('Virtual BG',       state.virtualBackground,(v) { state.virtualBackground = v; }),
            const SizedBox(height: 16),
            _PanelLabel('OUTPUT'),
            const SizedBox(height: 8),
            _StatRow('BITRATE', '${state.outputBitrate.toStringAsFixed(0)} kbps', color: C.green),
            _StatRow('FORMAT', '1080p 60fps', color: C.tx2),
            _StatRow('CODEC', 'H.264', color: C.tx2),
            _StatRow('AUDIO', '320kbps AAC', color: C.tx2),
          ]),
        )),
      ]),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniToggle(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: C.tx2, fontSize: 11))),
        Transform.scale(scale: 0.75,
          child: Switch(value: value, onChanged: onChanged)),
      ]),
    );
  }
}

class _PreviewWindow extends StatelessWidget {
  final StudioState state;
  final AnimationController pulseCtrl, scanCtrl;
  const _PreviewWindow({required this.state, required this.pulseCtrl, required this.scanCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: state.isLive ? C.red.withOpacity(0.6) : C.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(children: [
          // Grid
          CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
          // Scan line
          if (state.isLive) AnimatedBuilder(
            animation: scanCtrl,
            builder: (_, __) => Align(
              alignment: Alignment(0, (scanCtrl.value * 2) - 1),
              child: Container(height: 1,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  Colors.transparent, C.red.withOpacity(0.5), Colors.transparent,
                ])),
              ),
            ),
          ),
          // Avatar
          Center(child: AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final glow = state.isLive ? pulseCtrl.value * 0.3 : 0.0;
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.elevated,
                    border: Border.all(
                      color: (state.targetFace?.accent ?? C.gold)
                          .withOpacity(state.isLive ? 0.5 + glow : 0.25),
                      width: 2,
                    ),
                    boxShadow: state.isLive ? [BoxShadow(
                      color: (state.targetFace?.accent ?? C.gold).withOpacity(0.15 + glow * 0.2),
                      blurRadius: 20, spreadRadius: 4,
                    )] : null,
                  ),
                  child: Center(child: Text(
                    state.targetFace?.emoji ?? '📷',
                    style: const TextStyle(fontSize: 24),
                  )),
                ),
                const SizedBox(height: 6),
                Text(state.targetFace?.name ?? 'No face selected',
                  style: const TextStyle(color: C.tx2, fontSize: 9)),
                Text(state.isLive ? '● LIVE' : '◎ PREVIEW',
                  style: TextStyle(
                    color: state.isLive ? C.red : C.tx3,
                    fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2,
                  )),
              ]);
            },
          )),
          // Corner brackets
          ..._corners(state.isLive ? C.gold : C.border),
          // REC badge
          if (state.isLive) Positioned(top: 6, right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(3)),
              child: const Text('REC', style: TextStyle(color: Colors.white,
                fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            )),
        ]),
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const s = 12.0;
    Widget c(double? t, double? b, double? l, double? r, bool fH, bool fV) =>
      Positioned(top: t, bottom: b, left: l, right: r,
        child: Transform(alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(fH ? -1 : 1, fV ? -1 : 1, 1),
          child: CustomPaint(size: const Size(s, s),
            painter: _BracketPainter(color: color))));
    return [c(6,null,6,null,false,false), c(6,null,null,6,true,false),
            c(null,6,6,null,false,true),  c(null,6,null,6,true,true)];
  }
}

// ─────────────────────────────────────────
// MODULE: FACE SWAP
// ─────────────────────────────────────────
class FaceSwapModule extends StatelessWidget {
  final StudioState state;
  const FaceSwapModule({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(title: 'Face Swap Studio', subtitle: 'Real-time · Static · Video',
        icon: '🎭', actions: [
          _HeaderChip(label: state.faceSwapMode == FaceSwapMode.realTime ? '● REAL-TIME' : '◎ STATIC',
            color: state.faceSwapMode == FaceSwapMode.realTime ? C.red : C.tx2),
        ]),
      // Mode selector
      _ModeSelector(state: state),
      Expanded(child: Row(children: [
        // Source face
        Expanded(child: _FaceSlot(
          label: 'SOURCE FACE',
          sublabel: 'Your camera / input',
          icon: '📸',
          face: state.sourceFace,
          color: C.cyan,
          onTap: () => _showFacePicker(context, state, isSource: true),
        )),
        // Arrow
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.swap_horiz, color: C.gold, size: 32),
            SizedBox(height: 4),
            Text('SWAP', style: TextStyle(color: C.gold, fontSize: 9,
              fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ]),
        ),
        // Target face
        Expanded(child: _FaceSlot(
          label: 'TARGET FACE',
          sublabel: 'Avatar / overlay',
          icon: '🎭',
          face: state.targetFace,
          color: C.purple,
          onTap: () => _showFacePicker(context, state, isSource: false),
        )),
      ])),
      // Controls
      _FaceSwapControls(state: state),
    ]);
  }

  void _showFacePicker(BuildContext context, StudioState state, {required bool isSource}) {
    showDialog(context: context, builder: (_) => _FacePickerDialog(
      state: state, isSource: isSource));
  }
}

class _ModeSelector extends StatelessWidget {
  final StudioState state;
  const _ModeSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Row(children: FaceSwapMode.values.map((mode) {
        final labels = {
          FaceSwapMode.realTime:   ('⚡', 'Real-Time', 'Live camera feed'),
          FaceSwapMode.staticPhoto:('🖼️', 'Static Photo', 'Single image'),
          FaceSwapMode.videoFile:  ('🎬', 'Video File', 'Offline render'),
        };
        final (emoji, name, sub) = labels[mode]!;
        final sel = state.faceSwapMode == mode;
        return Expanded(child: GestureDetector(
          onTap: () => state.setFaceSwapMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? C.gold.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? C.gold.withOpacity(0.5) : Colors.transparent),
            ),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 3),
              Text(name, style: TextStyle(
                color: sel ? C.gold : C.tx2,
                fontSize: 11, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: C.tx3, fontSize: 9)),
            ]),
          ),
        ));
      }).toList()),
    );
  }
}

class _FaceSlot extends StatelessWidget {
  final String label, sublabel, icon;
  final FaceTarget? face;
  final Color color;
  final VoidCallback onTap;
  const _FaceSlot({required this.label, required this.sublabel,
    required this.icon, required this.face,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
        decoration: BoxDecoration(
          color: C.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: face != null ? color.withOpacity(0.5) : C.border,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _SectionTag(label: label, color: color),
          const SizedBox(height: 20),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.card,
              border: Border.all(color: face != null ? color.withOpacity(0.6) : C.border, width: 2),
            ),
            child: Center(child: Text(
              face?.emoji ?? icon,
              style: const TextStyle(fontSize: 44),
            )),
          ),
          const SizedBox(height: 12),
          Text(face?.name ?? 'Tap to select',
            style: TextStyle(color: face != null ? C.tx1 : C.tx3,
              fontSize: 13, fontWeight: FontWeight.w600)),
          Text(sublabel, style: const TextStyle(color: C.tx3, fontSize: 10)),
          const SizedBox(height: 16),
          _OutlineBtn(label: face != null ? 'Change' : 'Select', color: color, onTap: onTap),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _FacePickerDialog extends StatelessWidget {
  final StudioState state;
  final bool isSource;
  const _FacePickerDialog({required this.state, required this.isSource});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.border)),
      child: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text(isSource ? 'Select Source Face' : 'Select Target Face',
                style: const TextStyle(color: C.tx1, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: C.tx2),
                onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: C.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 10, runSpacing: 10,
              children: state.faceLibrary.map((face) {
                final sel = isSource
                    ? state.sourceFace?.id == face.id
                    : state.targetFace?.id == face.id;
                return GestureDetector(
                  onTap: () {
                    if (isSource) state.setSourceFace(face);
                    else state.setTargetFace(face);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 110,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel ? face.accent.withOpacity(0.15) : C.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? face.accent.withOpacity(0.7) : C.border,
                      ),
                    ),
                    child: Column(children: [
                      Text(face.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 6),
                      Text(face.name, textAlign: TextAlign.center,
                        style: TextStyle(color: sel ? face.accent : C.tx2,
                          fontSize: 10, fontWeight: FontWeight.w600)),
                      Text(face.category, style: const TextStyle(color: C.tx3, fontSize: 9)),
                    ]),
                  ),
                );
              }).toList()),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _FaceSwapControls extends StatelessWidget {
  final StudioState state;
  const _FaceSwapControls({required this.state});

  @override
  Widget build(BuildContext context) {
    final isRt = state.faceSwapMode == FaceSwapMode.realTime;
    final isStill = state.faceSwapMode == FaceSwapMode.staticPhoto;
    final isVideo = state.faceSwapMode == FaceSwapMode.videoFile;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Column(children: [
        // Mode-specific tip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.border),
          ),
          child: Text(
            isRt
                ? '⚡ Real-time: live camera → swap → virtual cam / RTMP. Best for streams & calls.'
                : isStill
                    ? '🖼️ Still: pick a photo, apply swap, export PNG/JPG. Great for avatars & posts.'
                    : '🎬 Video file: offline render with face swap on every frame. Export MP4.',
            style: const TextStyle(color: C.tx2, fontSize: 11, height: 1.35),
          ),
        ),
        Row(children: [
          Expanded(child: _SliderField(
            label: 'Blend Strength',
            value: state.blendStrength,
            onChanged: (v) { state.blendStrength = v; },
            color: C.purple,
          )),
          const SizedBox(width: 16),
          Expanded(child: _SliderField(
            label: 'Smoothing',
            value: state.smoothing,
            onChanged: (v) { state.smoothing = v; },
            color: C.cyan,
          )),
          const SizedBox(width: 16),
          Expanded(child: _SliderField(
            label: 'Face Scale',
            value: state.faceScale.clamp(0.5, 1.5) / 1.5,
            onChanged: (v) { state.faceScale = 0.5 + v; },
            color: C.gold,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _GoldBtn(
            label: state.isLive
                ? '⏹  STOP'
                : (isRt
                    ? '▶  START REAL-TIME SWAP'
                    : isStill
                        ? '✨  APPLY TO PHOTO'
                        : '🎬  RENDER VIDEO SWAP'),
            onTap: () {
              if (isRt) {
                state.toggleStream();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isStill
                      ? 'Still face swap applied — export from Photo Edit or snapshot.'
                      : 'Offline video face-swap render queued (connect model service for real output).'),
                ));
              }
            },
            filled: true,
            color: state.isLive ? C.red : C.gold,
          )),
          const SizedBox(width: 10),
          Expanded(child: _GoldBtn(
            label: isStill ? '📥  Import Photo' : '📸  Snapshot Frame',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Frame / photo captured to gallery buffer.'),
              ));
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: _GoldBtn(
            label: '📡  Send to OBS / Live',
            onTap: () => state.setModule(AppModule.obsStream),
          )),
        ]),
      ]),
    );
  }
}


// ─────────────────────────────────────────
// MODULE: OBS STREAM
// ─────────────────────────────────────────
class OBSStreamModule extends StatefulWidget {
  final StudioState state;
  const OBSStreamModule({required this.state});
  @override
  State<OBSStreamModule> createState() => _OBSStreamModuleState();
}

class _OBSStreamModuleState extends State<OBSStreamModule> {
  late TextEditingController _rtmpCtrl;
  late TextEditingController _keyCtrl;
  String _platform = 'Twitch';
  String? _bridgeStatus; // null = checking, 'ok', 'down'
  bool _checkingBridge = false;

  static const _presets = <String, String>{
    'Twitch': 'rtmp://live.twitch.tv/app/',
    'YouTube': 'rtmp://a.rtmp.youtube.com/live2/',
    'Facebook': 'rtmps://live-api-s.facebook.com:443/rtmp/',
    'TikTok': 'rtmp://push.tiktok.com/live/',
    'Custom': '',
  };

  @override
  void initState() {
    super.initState();
    _rtmpCtrl = TextEditingController(text: widget.state.rtmpUrl);
    _keyCtrl = TextEditingController(text: widget.state.streamKey);
    _checkBridge();
  }

  @override
  void dispose() {
    _rtmpCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBridge() async {
    setState(() {
      _checkingBridge = true;
      _bridgeStatus = null;
    });
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:8766/health'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        setState(() => _bridgeStatus = 'ok');
      } else {
        setState(() => _bridgeStatus = 'down');
      }
    } catch (_) {
      setState(() => _bridgeStatus = 'down');
    } finally {
      setState(() => _checkingBridge = false);
    }
  }

  void _applyPreset(String name) {
    setState(() {
      _platform = name;
      final url = _presets[name] ?? '';
      if (url.isNotEmpty) {
        _rtmpCtrl.text = url;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(children: [
      _ModuleHeader(
        title: 'OBS Stream Engine',
        subtitle: 'One-tap live · RTMP · Virtual Cam',
        icon: '📡',
        actions: [
          _HeaderChip(
            label: s.isLive ? '● LIVE' : '◎ READY',
            color: s.isLive ? C.red : C.tx2,
          ),
        ],
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bridge status banner
              _BridgeBanner(
                status: _bridgeStatus,
                checking: _checkingBridge,
                onRetry: _checkBridge,
              ),
              const SizedBox(height: 14),

              // OBS Scenes
              _ObsScenesCard(),
              const SizedBox(height: 12),


              // DELIVERY PATHS — 3 world options
              _SectionCard(title: '0 · Delivery path (remember these 3)', children: [
                Text(
                  'Pick how the world sees your endless cam',
                  style: TextStyle(color: C.tx2, fontSize: 11),
                ),
                const SizedBox(height: 10),
                _DeliveryPathTile(
                  n: '1',
                  title: 'Virtual Cam',
                  subtitle: 'Zoom · Teams · Meet · Discord — local endless camera',
                  color: C.cyan,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Start bridge → select StudioCam / OBS Virtual Camera in your call app',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _DeliveryPathTile(
                  n: '2',
                  title: 'WebRTC',
                  subtitle: 'Browser preview · http://127.0.0.1:8787 — ultra-low latency web',
                  color: C.purple,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Run: python bridge/webrtc_server.py → open :8787 → Connect',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _DeliveryPathTile(
                  n: '3',
                  title: 'RTMP + NVENC',
                  subtitle: 'Twitch · YouTube · TikTok · Facebook — hardware encode live',
                  color: C.gold,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Paste stream key below → Go Live (codec auto uses NVIDIA NVENC when available)',
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                _DeliveryPathTile(
                  n: '4',
                  title: 'WHIP (WebRTC ingest)',
                  subtitle: 'RFC 9725 · http://127.0.0.1:8788/whip/endpoint · low-latency live',
                  color: C.teal,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Run: python bridge/whip_server.py · OBS Custom WHIP URL + Bearer token',
                        ),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 12),

              // STEP 1 — Platform presets
              _SectionCard(title: '1 · Choose platform (fills RTMP URL)', children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.keys.map((name) {
                    final sel = _platform == name;
                    return GestureDetector(
                      onTap: () => _applyPreset(name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? C.gold.withValues(alpha: 0.18) : C.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? C.gold.withValues(alpha: 0.6) : C.border,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: sel ? C.gold : C.tx2,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ]),
              const SizedBox(height: 12),

              // STEP 2 — Key + URL
              _SectionCard(title: '2 · Stream key & URL', children: [
                _FieldRow(
                  label: 'Stream Key (from your platform dashboard)',
                  ctrl: _keyCtrl,
                  hint: 'Paste stream key here',
                  icon: Icons.vpn_key,
                  obscure: true,
                ),
                const SizedBox(height: 10),
                _FieldRow(
                  label: 'RTMP Ingest URL',
                  ctrl: _rtmpCtrl,
                  hint: 'rtmp://…',
                  icon: Icons.link,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: pick a platform above — URL fills automatically. Only paste your secret key.',
                  style: const TextStyle(color: C.tx3, fontSize: 10),
                ),
              ]),
              const SizedBox(height: 12),

              // STEP 3 — Quality
              _SectionCard(title: '3 · Quality (optional)', children: [
                _SliderField(
                  label: 'Bitrate: ${s.outputBitrate.toStringAsFixed(0)} kbps',
                  value: s.outputBitrate / 12000,
                  onChanged: (v) {
                    s.outputBitrate = v * 12000;
                    setState(() {});
                  },
                  color: C.green,
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: _EnumDropdown(
                      label: 'Resolution',
                      value: '1920×1080',
                      options: ['1920×1080', '1280×720', '854×480'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EnumDropdown(
                      label: 'FPS',
                      value: '30 fps',
                      options: ['60 fps', '30 fps', '24 fps'],
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),

              // Sources (compact OBS-style)
              _SectionCard(title: 'Sources (OBS-style)', children: [
                _SourceRow(icon: '🎥', name: 'Camera / Virtual Cam', type: 'Video', active: true),
                _SourceRow(icon: '🎭', name: 'Face Swap Layer', type: 'Filter', active: s.targetFace != null),
                _SourceRow(icon: '🎤', name: 'Microphone', type: 'Audio', active: true),
                _SourceRow(icon: '🖼️', name: 'Virtual Background', type: 'Scene', active: s.virtualBackground),
              ]),
              const SizedBox(height: 16),

              if (s.rtmpError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: C.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.red.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    s.rtmpError!,
                    style: const TextStyle(color: C.red, fontSize: 12, height: 1.35),
                  ),
                ),
              ],

              // Big Go Live
              _GoldBtn(
                label: s.rtmpConnecting
                    ? '⏳  CONNECTING…'
                    : (s.isLive ? '⏹  STOP BROADCAST' : '📡  GO LIVE NOW'),
                onTap: s.rtmpConnecting
                    ? () {}
                    : () {
                        s.goLiveRtmp(url: _rtmpCtrl.text, key: _keyCtrl.text);
                      },
                filled: true,
                color: s.isLive ? C.red : C.green,
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  s.isLive
                      ? 'Streaming to $_platform · bridge keeps last frame alive'
                      : 'Requires bridge running: python bridge/virtual_cam_bridge.py',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.tx3, fontSize: 10),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ]);
  }
}


class _ObsScenesCard extends StatefulWidget {
  @override
  State<_ObsScenesCard> createState() => _ObsScenesCardState();
}

class _ObsScenesCardState extends State<_ObsScenesCard> {
  List<Map<String, dynamic>> _scenes = [];
  bool _connected = false;
  bool _loading = true;
  String? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:8766/obs/scenes'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        _connected = j['connected'] == true;
        _scenes = List<Map<String, dynamic>>.from(
            (j['scenes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _current = j['current'] as String?;
      }
    } catch (_) {
      _connected = false;
      _scenes = [
        {'name': 'Main Camera', 'current': true},
        {'name': 'Face Swap Close-up', 'current': false},
        {'name': 'Screen Share', 'current': false},
        {'name': 'BRB', 'current': false},
        {'name': 'Starting Soon', 'current': false},
        {'name': 'Ending', 'current': false},
      ];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setScene(String name) async {
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:8766/obs/scene'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
    setState(() {
      _current = name;
      for (final s in _scenes) {
        s['current'] = s['name'] == name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: _connected
          ? 'OBS Scenes (live)'
          : 'OBS Scenes (demo — connect WebSocket for live control)',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Loading scenes…', style: TextStyle(color: C.tx3, fontSize: 11)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _scenes.map((s) {
              final name = s['name']?.toString() ?? '';
              final cur = s['current'] == true || name == _current;
              return GestureDetector(
                onTap: () => _setScene(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cur ? C.cyan.withValues(alpha: 0.18) : C.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cur ? C.cyan.withValues(alpha: 0.6) : C.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers,
                          size: 14, color: cur ? C.cyan : C.tx3),
                      const SizedBox(width: 6),
                      Text(name,
                          style: TextStyle(
                              color: cur ? C.cyan : C.tx2,
                              fontSize: 11,
                              fontWeight:
                                  cur ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: _load,
            child: Text('Refresh scenes',
                style: TextStyle(color: C.gold.withValues(alpha: 0.9), fontSize: 10)),
          ),
          const Spacer(),
          Text(
            _connected ? 'WebSocket :4455' : 'Start OBS + enable WebSocket',
            style: const TextStyle(color: C.tx3, fontSize: 9),
          ),
        ]),
      ],
    );
  }
}

class _BridgeBanner extends StatelessWidget {
  final String? status;
  final bool checking;
  final VoidCallback onRetry;
  const _BridgeBanner({
    required this.status,
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String title;
    String sub;
    if (checking || status == null) {
      color = C.amber;
      title = 'Checking OBS bridge…';
      sub = 'http://127.0.0.1:8766';
    } else if (status == 'ok') {
      color = C.green;
      title = 'Bridge online · virtual cam + RTMP ready';
      sub = 'FFmpeg + pyvirtualcam connected';
    } else {
      color = C.red;
      title = 'Bridge offline — start it to go live';
      sub = 'Run: python bridge/virtual_cam_bridge.py';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: C.tx3, fontSize: 10)),
            ],
          ),
        ),
        if (status == 'down')
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text('Retry',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }
}

class _SimulcastRow extends StatelessWidget {
  final String emoji, name, url;
  final bool enabled;
  final VoidCallback onToggle;
  const _SimulcastRow({required this.emoji, required this.name,
    required this.url, required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? C.green.withOpacity(0.08) : C.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: enabled ? C.green.withOpacity(0.4) : C.border),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: C.tx1, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(url, style: const TextStyle(color: C.tx3, fontSize: 10)),
        ])),
        Switch(value: enabled, onChanged: (_) => onToggle()),
      ]),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String icon, name, type;
  final bool active;
  const _SourceRow({required this.icon, required this.name, required this.type, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.border),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: C.tx1, fontSize: 12)),
          Text(type, style: const TextStyle(color: C.tx3, fontSize: 10)),
        ])),
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
            color: active ? C.green : C.tx3,
            shape: BoxShape.circle,
          )),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// MODULE: VIDEO EDIT
// ─────────────────────────────────────────
class VideoEditModule extends StatelessWidget {
  final StudioState state;
  const VideoEditModule({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(
        title: 'Cinema & Shorts Editor',
        subtitle: 'Movies · Reels · TikTok · YouTube Shorts · AI Cut',
        icon: '🎬',
        actions: [
          _HeaderChip(label: '4K · 60FPS', color: C.gold),
          const SizedBox(width: 8),
          _HeaderChip(label: 'SHORTS READY', color: C.pink),
        ],
      ),
      // Format presets strip
      _ShortsFormatBar(state: state),
      // Toolbar
      _VideoToolbar(),
      Expanded(child: Row(children: [
        Expanded(child: Column(children: [
          Expanded(flex: 3, child: _VideoPreview(state: state)),
          _ColorGradeStrip(state: state),
          _TransitionStrip(state: state),
        ])),
        Container(
          width: 240,
          decoration: const BoxDecoration(
            color: C.panel,
            border: Border(left: BorderSide(color: C.border)),
          ),
          child: _VideoAdjustPanel(state: state),
        ),
      ])),
      _TimelineStrip(state: state),
    ]);
  }
}

class _ShortsFormatBar extends StatelessWidget {
  final StudioState state;
  const _ShortsFormatBar({required this.state});

  static const _formats = [
    ('📱', 'TikTok', '9:16 · 1080×1920 · 15s–10m'),
    ('📸', 'Instagram Reel', '9:16 · 1080×1920 · 15–90s'),
    ('👻', 'Snapchat', '9:16 · 1080×1920 · 10–60s'),
    ('💬', 'WhatsApp Status', '9:16 · 720×1280 · ≤30s'),
    ('✈️', 'Telegram', '9:16 / 16:9 · flexible'),
    ('📘', 'Facebook Reel', '9:16 · 1080×1920 · ≤90s'),
    ('⬜', 'IG / FB Feed', '1:1 · 1080×1080'),
    ('📄', 'IG Portrait', '4:5 · 1080×1350'),
    ('🖥️', 'YouTube / Film', '16:9 · 1920×1080 · up to 2h'),
    ('📺', 'Cinema Scope', '21:9 · up to 2h+'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const Center(
            child: Text('FORMAT  ',
                style: TextStyle(color: C.tx3, fontSize: 10, letterSpacing: 1)),
          ),
          ..._formats.map((f) {
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Canvas set to ${f.$2} (${f.$3})')),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: C.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.border),
                ),
                child: Row(children: [
                  Text(f.$1, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(f.$2,
                          style: const TextStyle(
                              color: C.tx1, fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(f.$3, style: const TextStyle(color: C.tx3, fontSize: 9)),
                    ],
                  ),
                ]),
              ),
            );
          }),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Auto-Cut: detecting beats & scenes…')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: C.purpleGrad,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('AI Auto-Cut',
                    style: TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransitionStrip extends StatelessWidget {
  final StudioState state;
  const _TransitionStrip({required this.state});

  static const _fx = [
    'Cut', 'Dissolve', 'Whip Pan', 'Zoom Punch', 'Glitch', 'Film Burn', 'Light Leak', 'Match Cut'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(top: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        const Text('TRANS  ',
            style: TextStyle(color: C.tx3, fontSize: 10, letterSpacing: 1)),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _fx.map((t) {
              final sel = state.selectedTransition == t;
              return GestureDetector(
                onTap: () { state.selectedTransition = t; },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? C.pink.withValues(alpha: 0.2) : C.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: sel ? C.pink.withValues(alpha: 0.6) : C.border),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          color: sel ? C.pink : C.tx2,
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class _VideoToolbar extends StatelessWidget {
  const _VideoToolbar();

  @override
  Widget build(BuildContext context) {
    final tools = [
      (Icons.content_cut, 'Split'),
      (Icons.content_copy, 'Duplicate'),
      (Icons.delete_outline, 'Delete'),
      (Icons.undo, 'Undo'),
      (Icons.redo, 'Redo'),
      (Icons.zoom_in, 'Zoom'),
      (Icons.crop, 'Crop'),
      (Icons.text_fields, 'Titles'),
      (Icons.music_note, 'Music'),
      (Icons.speed, 'Speed'),
      (Icons.filter, 'LUT'),
      (Icons.auto_awesome, 'AI Cut'),
      (Icons.closed_caption, 'Captions'),
      (Icons.movie_filter, 'VFX'),
    ];
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: tools
            .map((t) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Tooltip(
                    message: t.$2,
                    child: IconButton(
                      icon: Icon(t.$1, size: 16, color: C.tx2),
                      onPressed: () {},
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  final StudioState state;
  const _VideoPreview({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.border),
      ),
      child: Stack(children: [
        CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
        const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_circle_outline, size: 64, color: C.gold),
            SizedBox(height: 8),
            Text('Preview · Drop clips or record',
                style: TextStyle(color: C.tx2, fontSize: 14)),
            Text('Shorts · Film · Multi-cam ready',
                style: TextStyle(color: C.tx3, fontSize: 11)),
          ]),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.skip_previous, color: C.tx2, size: 20),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.play_arrow, color: C.gold, size: 28),
                onPressed: () {}),
            IconButton(
                icon: const Icon(Icons.skip_next, color: C.tx2, size: 20),
                onPressed: () {}),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('00:00:12 / 00:00:45',
                  style: TextStyle(
                      color: C.tx2, fontSize: 11, fontFamily: 'monospace')),
            ),
            const SizedBox(width: 8),
            IconButton(
                icon: const Icon(Icons.fullscreen, color: C.tx2, size: 18),
                onPressed: () {}),
          ]),
        ),
        // Safe-area guides for shorts
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: C.pink.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: C.pink.withValues(alpha: 0.4)),
            ),
            child: const Text('SAFE ZONE',
                style: TextStyle(
                    color: C.pink, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _ColorGradeStrip extends StatelessWidget {
  final StudioState state;
  const _ColorGradeStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final grades = [
      'Natural', 'Cinematic', 'Rec.709', 'S-Log2', 'Orange-Teal',
      'B&W', 'Warm', 'Cool', 'Neon Night', 'Film Stock'
    ];
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(top: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Text('GRADE  ',
            style: TextStyle(color: C.tx3, fontSize: 10, letterSpacing: 1)),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: grades.map((g) {
              final sel = state.selectedColorGrade == g;
              return GestureDetector(
                onTap: () { state.selectedColorGrade = g; },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? C.gold.withValues(alpha: 0.2) : C.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: sel ? C.gold.withValues(alpha: 0.6) : C.border),
                  ),
                  child: Text(g,
                      style: TextStyle(
                          color: sel ? C.gold : C.tx2,
                          fontSize: 11,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

class _VideoAdjustPanel extends StatelessWidget {
  final StudioState state;
  const _VideoAdjustPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _PanelLabel('COLOR'),
        const SizedBox(height: 8),
        _SliderField(
            label: 'Brightness',
            value: (state.brightness + 1) / 2,
            onChanged: (v) { state.brightness = v * 2 - 1; },
            color: C.gold),
        const SizedBox(height: 6),
        _SliderField(
            label: 'Contrast',
            value: (state.contrast + 1) / 2,
            onChanged: (v) { state.contrast = v * 2 - 1; },
            color: C.cyan),
        const SizedBox(height: 6),
        _SliderField(
            label: 'Saturation',
            value: (state.saturation + 1) / 2,
            onChanged: (v) { state.saturation = v * 2 - 1; },
            color: C.pink),
        const SizedBox(height: 6),
        _SliderField(
            label: 'Sharpness',
            value: state.sharpness,
            onChanged: (v) { state.sharpness = v; },
            color: C.green),
        const SizedBox(height: 14),
        const _PanelLabel('CINEMATIC'),
        const SizedBox(height: 8),
        _SliderField(
            label: 'Vignette',
            value: state.vignette,
            onChanged: (v) { state.vignette = v; },
            color: C.purple),
        const SizedBox(height: 6),
        _SliderField(
            label: 'Film Grain',
            value: state.filmGrain,
            onChanged: (v) { state.filmGrain = v; },
            color: C.amber),
        const SizedBox(height: 14),
        const _PanelLabel('EXPORT · SHORTS'),
        const SizedBox(height: 8),
        _GoldBtn(
          label: '📱 TikTok / IG / Snap (9:16)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exporting vertical short for TikTok, Instagram, Snapchat…')),
            );
          },
          filled: true,
          color: C.pink,
        ),
        const SizedBox(height: 6),
        _GoldBtn(
          label: '💬 WhatsApp / Telegram Status',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exporting ≤30s status clip (compressed)…')),
            );
          },
          filled: true,
          color: C.green,
        ),
        const SizedBox(height: 6),
        _GoldBtn(
          label: '📘 Facebook Reel / Feed',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exporting Facebook Reel / feed ratio…')),
            );
          },
          filled: true,
          color: C.blue,
        ),
        const SizedBox(height: 14),
        const _PanelLabel('EXPORT · FILM (UP TO ~2 HOURS)'),
        const SizedBox(height: 8),
        _GoldBtn(
          label: '🎬 Feature 16:9 · Balanced (~2h)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Long-form encode: libx264 medium CRF20 film-tune · faststart · up to ~2h. '
                  'POST /export/movie mode=balanced',
                ),
              ),
            );
          },
          filled: true,
        ),
        const SizedBox(height: 6),
        _GoldBtn(
          label: '🎥 Feature · Quality (slow CRF18)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quality master encode queued (mode=quality). Best for final delivery.'),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _GoldBtn(
          label: '⚡ Draft 2h · Fast preset',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fast draft encode (mode=fast veryfast CRF23).')),
            );
          },
        ),
        const SizedBox(height: 6),
        _GoldBtn(
          label: '📺 Cinema 21:9 Master',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Widescreen cinema master (21:9) via /export/movie…')),
            );
          },
        ),
        const SizedBox(height: 6),
        _GoldBtn(
          label: '📤 Send to Endless Cam / OBS',
          onTap: () => state.setModule(AppModule.obsStream),
        ),
      ]),
    );
  }
}

class _TimelineStrip extends StatelessWidget {
  final StudioState state;
  const _TimelineStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(top: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('TIMELINE',
              style: TextStyle(
                  color: C.tx3,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const Spacer(),
          Text('${state.timelineClips.length} clips',
              style: const TextStyle(color: C.tx3, fontSize: 9)),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _TrackLabel('V1'),
              _TrackLabel('V2'),
              _TrackLabel('A1'),
            ]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(children: [
                _TrackRow(clips: state.timelineClips, color: C.gold),
                _TrackRow(
                    clips: ['FX', 'Titles', 'Trans'], color: C.purple, h: 14),
                _TrackRow(
                    clips: ['VO', 'Music', 'SFX'], color: C.cyan, h: 14),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TrackLabel extends StatelessWidget {
  final String label;
  const _TrackLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(label,
            style: const TextStyle(
                color: C.tx3, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final List<String> clips;
  final Color color;
  final double h;
  const _TrackRow({required this.clips, required this.color, this.h = 18});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: clips.asMap().entries.map((e) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(e.value,
                      style: TextStyle(color: color, fontSize: 8),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}


class PhotoEditModule extends StatelessWidget {
  final StudioState state;
  const PhotoEditModule({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(title: 'Photo Studio', subtitle: 'Canva-style · AI Retouch · Export',
        icon: '🖼️', actions: [_HeaderChip(label: 'AI ENHANCED', color: C.purple)]),
      Expanded(child: Row(children: [
        // Tools sidebar
        _PhotoToolsSidebar(),
        // Canvas
        Expanded(child: _PhotoCanvas()),
        // Properties
        _PhotoPropertiesPanel(state: state),
      ])),
    ]);
  }
}

class _PhotoToolsSidebar extends StatelessWidget {
  const _PhotoToolsSidebar();

  @override
  Widget build(BuildContext context) {
    final tools = [
      (Icons.pan_tool, 'Select'),
      (Icons.crop, 'Crop'),
      (Icons.brush, 'Brush'),
      (Icons.healing, 'Heal'),
      (Icons.text_fields, 'Text'),
      (Icons.face_retouching_natural, 'Retouch'),
      (Icons.auto_awesome, 'AI Magic'),
      (Icons.remove_red_eye, 'Red-Eye'),
      (Icons.blur_on, 'Blur'),
      (Icons.brightness_6, 'Exposure'),
      (Icons.gradient, 'Gradient'),
      (Icons.format_shapes, 'Shape'),
      (Icons.sticky_note_2, 'Sticker'),
    ];
    return Container(
      width: 56,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(right: BorderSide(color: C.border)),
      ),
      child: Column(children: tools.map((t) => Tooltip(
        message: t.$2,
        child: IconButton(
          icon: Icon(t.$1, size: 18, color: C.tx2),
          onPressed: () {},
        ),
      )).toList()),
    );
  }
}

class _PhotoCanvas extends StatelessWidget {
  const _PhotoCanvas();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Stack(children: [
        // Checkerboard hint
        Center(child: Container(
          width: 400, height: 300,
          decoration: BoxDecoration(
            color: C.elevated,
            border: Border.all(color: C.border),
          ),
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_photo_alternate_outlined, size: 48, color: C.tx3),
            SizedBox(height: 8),
            Text('Drop image or click to open', style: TextStyle(color: C.tx2, fontSize: 13)),
            SizedBox(height: 4),
            Text('PNG · JPG · WebP · HEIC · RAW', style: TextStyle(color: C.tx3, fontSize: 10)),
          ])),
        )),
        // Format presets
        Positioned(bottom: 16, left: 0, right: 0, child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _FormatChip('📱 Story 9:16'),
            _FormatChip('⬜ Square 1:1'),
            _FormatChip('🖼️ Post 4:5'),
            _FormatChip('🖥️ Banner 16:9'),
            _FormatChip('📄 A4 Print'),
          ]),
        )),
      ]),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  const _FormatChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: C.elevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: C.border),
      ),
      child: Text(label, style: const TextStyle(color: C.tx2, fontSize: 10)),
    );
  }
}

class _PhotoPropertiesPanel extends StatelessWidget {
  final StudioState state;
  const _PhotoPropertiesPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(left: BorderSide(color: C.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _PanelLabel('AI TOOLS'),
          const SizedBox(height: 8),
          ...[
            ('✨', 'AI Background Remove'),
            ('👤', 'AI Face Enhance'),
            ('🎨', 'AI Style Transfer'),
            ('🔆', 'Auto Enhance'),
            ('📐', 'Smart Crop'),
          ].map((t) => _AiToolBtn(emoji: t.$1, label: t.$2)),
          const SizedBox(height: 16),
          const _PanelLabel('COLOR'),
          const SizedBox(height: 8),
          _SliderField(label: 'Brightness', value: 0.5,
            onChanged: (_) {}, color: C.gold),
          const SizedBox(height: 6),
          _SliderField(label: 'Contrast',   value: 0.5,
            onChanged: (_) {}, color: C.cyan),
          const SizedBox(height: 6),
          _SliderField(label: 'Saturation', value: 0.6,
            onChanged: (_) {}, color: C.pink),
          const SizedBox(height: 6),
          _SliderField(label: 'Warmth',     value: 0.4,
            onChanged: (_) {}, color: C.amber),
          const SizedBox(height: 16),
          const _PanelLabel('EXPORT'),
          const SizedBox(height: 8),
          _GoldBtn(label: '📤 Export Image', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image exported.')));
          }, filled: true),
          const SizedBox(height: 6),
          _GoldBtn(label: '📱 Share to Social', onTap: () {}),
        ]),
      ),
    );
  }
}

class _AiToolBtn extends StatelessWidget {
  final String emoji, label;
  const _AiToolBtn({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.border),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: C.tx2, fontSize: 11))),
            const Icon(Icons.auto_awesome, size: 12, color: C.purple),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MODULE: API HUB
// ─────────────────────────────────────────

class _DeliveryPathTile extends StatelessWidget {
  final String n;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _DeliveryPathTile({
    required this.n,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(n,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: C.tx2, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7), size: 18),
          ],
        ),
      ),
    );
  }
}

class ApiHubModule extends StatelessWidget {
  final StudioState state;
  const ApiHubModule({required this.state});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ApiConnection>>{};
    for (final api in state.apiConnections) {
      (grouped[api.category] ??= []).add(api);
    }

    return Column(children: [
      _ModuleHeader(title: 'API & Integration Hub',
        subtitle: 'Streaming · Video Calls · Social · Developer',
        icon: '🔗', actions: [
          _HeaderChip(
            label: '${state.apiConnections.where((a) => a.connected).length} CONNECTED',
            color: C.green),
        ]),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [

              _PanelLabel('DELIVERY PATHS'),
              const SizedBox(height: 8),
              _DeliveryPathTile(
                n: '1',
                title: 'Virtual Cam',
                subtitle: 'Endless cam for Zoom, Teams, Meet, Discord',
                color: C.cyan,
                onTap: () => state.setModule(AppModule.obsStream),
              ),
              const SizedBox(height: 8),
              _DeliveryPathTile(
                n: '2',
                title: 'WebRTC',
                subtitle: 'Browser low-latency — webrtc_server.py :8787',
                color: C.purple,
                onTap: () => state.setModule(AppModule.obsStream),
              ),
              const SizedBox(height: 8),
              _DeliveryPathTile(
                n: '3',
                title: 'RTMP + NVENC',
                subtitle: 'Public live with NVIDIA hardware encode',
                color: C.gold,
                onTap: () => state.setModule(AppModule.obsStream),
              ),
              const SizedBox(height: 8),
              _DeliveryPathTile(
                n: '4',
                title: 'WHIP ingest',
                subtitle: 'RFC 9725 WebRTC · :8788/whip/endpoint',
                color: C.teal,
                onTap: () => state.setModule(AppModule.obsStream),
              ),
              const SizedBox(height: 16),
            ...grouped.entries.map((e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              _PanelLabel(e.key.toUpperCase()),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: e.value.map((api) => _ApiCard(
                  api: api,
                  onToggle: () => state.toggleApi(api.id),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ])).toList(),
          ],
        ),
      )),
    ]);
  }
}

class _ApiCard extends StatelessWidget {
  final ApiConnection api;
  final VoidCallback onToggle;
  const _ApiCard({required this.api, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: api.connected ? C.green.withOpacity(0.08) : C.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: api.connected ? C.green.withOpacity(0.5) : C.border,
          ),
        ),
        child: Row(children: [
          Text(api.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(api.name, style: const TextStyle(
                color: C.tx1, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(api.connected ? 'Connected' : 'Tap to connect',
                style: TextStyle(
                  color: api.connected ? C.green : C.tx3, fontSize: 9)),
            ],
          )),
          Container(width: 8, height: 8,
            decoration: BoxDecoration(
              color: api.connected ? C.green : C.tx3,
              shape: BoxShape.circle,
            )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MODULE: AI CHAT
// ─────────────────────────────────────────
class AiChatModule extends StatefulWidget {
  final StudioState state;
  const AiChatModule({required this.state});
  @override
  State<AiChatModule> createState() => _AiChatModuleState();
}

class _AiChatModuleState extends State<AiChatModule> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onUpdate);
    if (widget.state.chatHistory.isEmpty) {
      Future.microtask(() {
        widget.state.chatHistory.add(ChatMessage(
          text: "Hi! Just type what you want — or tap a chip.\n\nExamples:\n• use my cam in Zoom\n• face swap live\n• face swap photo\n• go live on Twitch\n• setup OBS\n\nI will reply with short click-by-click steps.",
          isUser: false,
          time: DateTime.now(),
        ));
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onUpdate);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onUpdate() {
    setState(() {});
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    widget.state.sendChat(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(children: [
      _ModuleHeader(title: 'AI Studio Assistant',
        subtitle: s.userMode == UserMode.amateur ? 'Easy Mode — Natural Language Control' : 'Pro Mode — Advanced Prompt Engine',
        icon: '🤖', actions: [
          _HeaderChip(
            label: s.userMode == UserMode.amateur ? 'EASY' : 'PRO',
            color: s.userMode == UserMode.amateur ? C.cyan : C.gold),
        ]),
      // Quick prompts
      if (s.userMode == UserMode.amateur)
        _QuickPrompts(state: s),
      // Chat
      Expanded(child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: s.chatHistory.length + (s.aiTyping ? 1 : 0),
        itemBuilder: (_, i) {
          if (s.aiTyping && i == s.chatHistory.length) {
            return const _TypingIndicator();
          }
          return _ChatBubble(msg: s.chatHistory[i]);
        },
      )),
      // Input
      _ChatInput(ctrl: _ctrl, onSend: _send, state: s),
    ]);
  }
}

class _QuickPrompts extends StatelessWidget {
  final StudioState state;
  const _QuickPrompts({required this.state});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Use cam in Zoom',
      'Use cam in Teams',
      'Use cam in Discord',
      'Face swap live',
      'Face swap photo',
      'Go live on Twitch',
      'Setup OBS',
      'Setup WHIP stream',
      'WhatsApp photo swap',
    ];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: ListView(scrollDirection: Axis.horizontal,
        children: prompts.map((p) => GestureDetector(
          onTap: () => state.sendChat(p.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim()),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.gold.withOpacity(0.3)),
            ),
            child: Text(p, style: const TextStyle(color: C.gold, fontSize: 11)),
          ),
        )).toList()),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: msg.isUser ? C.gold.withOpacity(0.15) : C.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: msg.isUser ? C.gold.withOpacity(0.4) : C.border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!msg.isUser) Row(children: [
            const Text('🤖', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            const Text('Studio AI', style: TextStyle(
              color: C.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              '${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}',
              style: const TextStyle(color: C.tx3, fontSize: 9)),
          ]),
          if (!msg.isUser) const SizedBox(height: 6),
          Text(msg.text, style: const TextStyle(color: C.tx1, fontSize: 13, height: 1.5)),
        ]),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🤖', style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Text('Studio AI is thinking...', style: TextStyle(
            color: C.tx2, fontSize: 12, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final StudioState state;
  const _ChatInput({required this.ctrl, required this.onSend, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: ctrl,
          style: const TextStyle(color: C.tx1, fontSize: 13),
          decoration: InputDecoration(
            hintText: state.userMode == UserMode.amateur
                ? 'Ask me anything about the studio...'
                : 'Enter prompt or command...',
            hintStyle: const TextStyle(color: C.tx3, fontSize: 13),
            filled: true,
            fillColor: C.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: C.gold),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onSubmitted: (_) => onSend(),
        )),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: C.goldGrad,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// MODULE: CAPTURE
// ─────────────────────────────────────────

// ─────────────────────────────────────────
// MODULE: AI VOICE CLONE
// ─────────────────────────────────────────
class VoiceCloneModule extends StatefulWidget {
  final StudioState state;
  const VoiceCloneModule({required this.state});
  @override
  State<VoiceCloneModule> createState() => _VoiceCloneModuleState();
}

class _VoiceCloneModuleState extends State<VoiceCloneModule> {
  final _textCtrl = TextEditingController(
    text: 'Welcome to the studio. This line will be spoken in the cloned voice.',
  );
  String _speaker = 'narrator';
  double _speed = 1.0;
  double _pitch = 0.0;
  String? _status;
  bool _busy = false;

  static const _speakers = [
    ('default', 'Studio Default'),
    ('narrator', 'Film Narrator'),
    ('hero', 'Hero Lead'),
    ('custom1', 'Custom Clone 1'),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkService() async {
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:8766/voice/status'))
          .timeout(const Duration(seconds: 2));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _status = j['connected'] == true
            ? 'Clone service online'
            : 'Demo mode — start local voice API (VOICE_CLONE_URL)';
      });
    } catch (_) {
      setState(() => _status = 'Bridge offline — start virtual_cam_bridge.py');
    }
  }

  Future<void> _clone() async {
    setState(() => _busy = true);
    try {
      final res = await http
          .post(
            Uri.parse('http://127.0.0.1:8766/voice/clone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': _textCtrl.text,
              'speakerId': _speaker,
              'speed': _speed,
              'pitch': _pitch,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200 &&
          (res.headers['content-type'] ?? '').contains('audio')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice clone audio received — add to timeline A1.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.statusCode == 503
                  ? 'Service offline (demo). Connect OpenVoice/Coqui/RVC on port 8777.'
                  : 'Clone response ${res.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice clone failed: $e')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkService();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(
        title: 'AI Voice Clone',
        subtitle: 'Clone · Narration · VO for films & shorts',
        icon: '🎙️',
        actions: [
          _HeaderChip(
            label: _status?.contains('online') == true ? 'SERVICE ON' : 'DEMO',
            color: _status?.contains('online') == true ? C.green : C.amber,
          ),
        ],
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_status!,
                      style: const TextStyle(color: C.tx2, fontSize: 11)),
                ),
              _SectionCard(title: 'Script / line', children: [
                TextField(
                  controller: _textCtrl,
                  maxLines: 5,
                  style: const TextStyle(color: C.tx1, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type dialogue or narration…',
                    hintStyle: const TextStyle(color: C.tx3),
                    filled: true,
                    fillColor: C.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: C.border),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _SectionCard(title: 'Voice / speaker', children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _speakers.map((s) {
                    final sel = _speaker == s.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _speaker = s.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? C.purple.withValues(alpha: 0.2)
                              : C.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel
                                ? C.purple.withValues(alpha: 0.6)
                                : C.border,
                          ),
                        ),
                        child: Text(s.$2,
                            style: TextStyle(
                                color: sel ? C.purple : C.tx2,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _SliderField(
                  label: 'Speed ${( _speed).toStringAsFixed(2)}x',
                  value: ((_speed - 0.5) / 1.5).clamp(0.0, 1.0),
                  onChanged: (v) =>
                      setState(() => _speed = 0.5 + v * 1.5),
                  color: C.cyan,
                ),
                _SliderField(
                  label: 'Pitch ${(_pitch >= 0 ? "+" : "")}${_pitch.toStringAsFixed(1)}',
                  value: (_pitch + 6) / 12,
                  onChanged: (v) =>
                      setState(() => _pitch = v * 12 - 6),
                  color: C.gold,
                ),
              ]),
              const SizedBox(height: 16),
              _GoldBtn(
                label: _busy ? '⏳ Cloning…' : '🎙️  Generate cloned voice',
                onTap: _busy ? () {} : _clone,
                filled: true,
                color: C.purple,
              ),
              const SizedBox(height: 8),
              _GoldBtn(
                label: '➕ Add to timeline (A1 / VO)',
                onTap: () {
                  widget.state.setModule(AppModule.videoEdit);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Switch to Video Edit — drop VO on A1 track.')),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Connect a local clone API (OpenVoice, Coqui XTTS, RVC) on port 8777, '
                'or set VOICE_CLONE_URL. Bridge proxies /voice/clone.',
                style: const TextStyle(color: C.tx3, fontSize: 10, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class CaptureModule extends StatelessWidget {
  final StudioState state;
  const CaptureModule({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(title: 'Capture Studio',
        subtitle: 'Camera · Screen · Audio · Webcam',
        icon: '📷', actions: [_HeaderChip(label: '1080p 60FPS', color: C.green)]),
      Expanded(child: Row(children: [
        Expanded(child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.border),
          ),
          child: Stack(children: [
            CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_outlined, size: 72, color: C.gold),
              SizedBox(height: 12),
              Text('Camera Preview', style: TextStyle(color: C.tx2, fontSize: 16)),
              Text('Select input source below', style: TextStyle(color: C.tx3, fontSize: 11)),
            ])),
            // Capture controls
            Positioned(bottom: 16, left: 0, right: 0, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CaptureBtn(icon: Icons.fiber_manual_record, label: 'Record', color: C.red),
                const SizedBox(width: 12),
                _CaptureBtn(icon: Icons.camera_alt, label: 'Photo', color: C.gold),
                const SizedBox(width: 12),
                _CaptureBtn(icon: Icons.screen_share, label: 'Screen', color: C.cyan),
                const SizedBox(width: 12),
                _CaptureBtn(icon: Icons.podcasts, label: 'Broadcast', color: C.green),
              ],
            )),
          ]),
        )),
        Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: C.panel,
            border: Border(left: BorderSide(color: C.border)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelLabel('INPUT SOURCES'),
            const SizedBox(height: 10),
            ...[
              ('📷', 'Camera (Default)'),
              ('🖥️', 'Screen Capture'),
              ('🎤', 'Microphone'),
              ('🔊', 'Desktop Audio'),
              ('📱', 'Mobile Camera'),
              ('🎮', 'Game Capture'),
            ].map((s) => _InputSourceRow(emoji: s.$1, name: s.$2)),
            const SizedBox(height: 16),
            const _PanelLabel('RECORDING'),
            const SizedBox(height: 8),
            _StatRow('Format',   'MP4 / H.264', color: C.tx2),
            _StatRow('Quality',  '4K UHD',      color: C.gold),
            _StatRow('Duration', '00:00:00',    color: C.green),
            _StatRow('Size',     '0 MB',        color: C.tx2),
          ]),
        ),
      ])),
    ]);
  }
}

class _CaptureBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CaptureBtn({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _InputSourceRow extends StatelessWidget {
  final String emoji, name;
  const _InputSourceRow({required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: C.border),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(color: C.tx2, fontSize: 11)),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// MODULE: TIMELINE
// ─────────────────────────────────────────
class TimelineModule extends StatelessWidget {
  final StudioState state;
  const TimelineModule({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(title: 'Project Timeline',
        subtitle: 'Multi-track · AI Edit · Chapter Marks',
        icon: '🎞️', actions: [_HeaderChip(label: 'AUTO-SAVE', color: C.green)]),
      Expanded(child: Column(children: [
        // Ruler
        _TimelineRuler(),
        Expanded(child: _FullTimeline(state: state)),
      ])),
    ]);
  }
}

class _TimelineRuler extends StatelessWidget {
  const _TimelineRuler();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      color: C.elevated,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: List.generate(20, (i) => Expanded(child: Text(
        '${i * 10}s', style: const TextStyle(color: C.tx3, fontSize: 8),
      )))),
    );
  }
}

class _FullTimeline extends StatelessWidget {
  final StudioState state;
  const _FullTimeline({required this.state});

  @override
  Widget build(BuildContext context) {
    final tracks = [
      ('🎥 Video 1', C.gold,   state.timelineClips),
      ('🎭 FX',      C.purple, ['Face Swap', 'Color Grade']),
      ('📝 Text',    C.cyan,   ['Title Card', 'Lower Third']),
      ('🎵 Music',   C.green,  ['Background Music']),
      ('🎤 Voice',   C.pink,   ['VO Take 1', 'VO Take 2']),
      ('🔊 SFX',     C.amber,  ['Ambient', 'Transition SFX']),
    ];
    return ListView(children: tracks.map((t) => _FullTrackRow(
      label: t.$1, color: t.$2, clips: t.$3,
    )).toList());
  }
}

class _FullTrackRow extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> clips;
  const _FullTrackRow({required this.label, required this.color, required this.clips});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.divider)),
      ),
      child: Row(children: [
        // Label
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: C.panel,
            border: Border(right: BorderSide(color: C.border)),
          ),
          child: Text(label, style: const TextStyle(color: C.tx2, fontSize: 10)),
        ),
        // Clips
        Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: clips.asMap().entries.map((e) => Container(
            width: 120 + e.key * 30.0,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(child: Text(e.value,
              style: TextStyle(color: color, fontSize: 9),
              overflow: TextOverflow.ellipsis)),
          )).toList()),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// MODULE: FX LAB
// ─────────────────────────────────────────
class FxLabModule extends StatelessWidget {
  final StudioState state;
  const FxLabModule({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ModuleHeader(title: 'FX Laboratory',
        subtitle: 'LUTs · Shaders · Particles · Transitions',
        icon: '✨', actions: [_HeaderChip(label: 'GPU ACCELERATED', color: C.purple)]),
      Expanded(child: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12, mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: _fxItems.map((fx) => _FxCard(fx: fx)).toList(),
      )),
    ]);
  }

  static const _fxItems = [
    ('🎨', 'Custom LUT',       'Upload .cube file',      C.gold),
    ('🌈', 'Color Grading',    'Wheels + curves',         C.cyan),
    ('📽️', 'Film Emulation',   'Kodak · Fuji · Ilford',   C.amber),
    ('🔆', 'HDR Tone Map',     'Reinhard · ACES',         C.gold),
    ('🎭', 'Chroma Key',       'Green / Blue screen',     C.green),
    ('🌊', 'Warp & Distort',   'Liquify · Ripple · Wave', C.blue),
    ('⚡', 'Particle FX',      'Sparks · Stars · Rain',   C.cyan),
    ('🖤', 'Vignette',         'Edge darkening',          C.tx2),
    ('🔈', 'Audio FX',         'Reverb · EQ · Compressor',C.purple),
    ('🎬', 'Transition Pack',  '50+ pro transitions',     C.pink),
    ('🤖', 'AI Upscale',       '2x / 4x super-res',       C.gold),
    ('🌀', 'Motion Blur',      'Directional · Radial',    C.blue),
  ];
}

class _FxCard extends StatelessWidget {
  final (String, String, String, Color) fx;
  const _FxCard({required this.fx});

  @override
  Widget build(BuildContext context) {
    final (emoji, name, desc, color) = fx;
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(
            color: C.tx1, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(color: C.tx3, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STATUS BAR
// ─────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final StudioState state;
  const _StatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(top: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _StatChip('FPS',      state.isLive ? '${state.fps}' : '--',   C.green),
        _StatChip('LATENCY',  state.isLive ? '${state.latency.toStringAsFixed(1)}ms' : '--', C.cyan),
        _StatChip('CPU',      state.isLive ? '${state.cpu.toStringAsFixed(0)}%' : '--', C.amber),
        _StatChip('GPU',      state.isLive ? '${state.gpu.toStringAsFixed(0)}%' : '--', C.purple),
        _StatChip('VRAM',     state.isLive ? '${state.vram.toStringAsFixed(1)}G' : '--', C.gold),
        _StatChip('VIEWERS',  state.isLive ? '${state.viewerCount}' : '--', C.pink),
        const Spacer(),
        if (state.targetFace != null)
          Text('Face: ${state.targetFace!.name}  •  ',
            style: const TextStyle(color: C.tx3, fontSize: 10)),
        Text(
          'Mode: ${state.userMode == UserMode.professional ? "Professional" : "Easy"}  •  '
          'Module: ${state.module.name}  •  '
          '${state.apiConnections.where((a) => a.connected).length} APIs connected',
          style: const TextStyle(color: C.tx3, fontSize: 10),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label  ', style: const TextStyle(color: C.tx3, fontSize: 9, letterSpacing: 1)),
        Text(value, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────
class _ModuleHeader extends StatelessWidget {
  final String title, subtitle, icon;
  final List<Widget> actions;
  const _ModuleHeader({
    required this.title, required this.subtitle,
    required this.icon, this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: C.elevated,
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
            color: C.tx1, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: C.tx3, fontSize: 10)),
        ]),
        const Spacer(),
        ...actions,
      ]),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color color;
  const _HeaderChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          color: C.tx2, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final bool obscure;
  const _FieldRow({required this.label, required this.hint,
    required this.ctrl, required this.icon, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: C.tx3, fontSize: 10, letterSpacing: 0.5)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: C.tx1, fontSize: 12, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: C.tx3, fontSize: 12),
          prefixIcon: Icon(icon, size: 15, color: C.tx3),
          filled: true, fillColor: C.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: C.gold),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
  }
}

class _EnumDropdown extends StatefulWidget {
  final String label, value;
  final List<String> options;
  const _EnumDropdown({required this.label, required this.value, required this.options});
  @override
  State<_EnumDropdown> createState() => _EnumDropdownState();
}

class _EnumDropdownState extends State<_EnumDropdown> {
  late String _val;
  @override
  void initState() { super.initState(); _val = widget.value; }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: const TextStyle(color: C.tx3, fontSize: 10)),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: C.card, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: C.border),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _val,
          isExpanded: true,
          dropdownColor: C.card,
          style: const TextStyle(color: C.tx1, fontSize: 12),
          items: widget.options.map((o) => DropdownMenuItem(
            value: o, child: Text(o))).toList(),
          onChanged: (v) { if (v != null) setState(() => _val = v); },
        )),
      ),
    ]);
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;
  const _SliderField({required this.label, required this.value,
    required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(color: C.tx2, fontSize: 11)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text('${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
      Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
    ]);
  }
}

class _GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color color;
  const _GoldBtn({required this.label, required this.onTap,
    this.filled = false, this.color = C.gold});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? Colors.transparent : color.withOpacity(0.5)),
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? Colors.black : color,
            fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5,
          )),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SectionTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatRow(this.label, this.value, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label, style: const TextStyle(color: C.tx3, fontSize: 10, letterSpacing: 0.8)),
        const Spacer(),
        Text(value, style: TextStyle(
          color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
      color: C.tx3, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.8));
  }
}

// ─────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF0F0F22)..strokeWidth = 0.5;
    const s = 28.0;
    for (double x = 0; x <= size.width; x += s)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y <= size.height; y += s)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(_) => false;
}

class _BracketPainter extends CustomPainter {
  final Color color;
  const _BracketPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height), Offset.zero, p);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
  }
  @override bool shouldRepaint(_) => false;
}
