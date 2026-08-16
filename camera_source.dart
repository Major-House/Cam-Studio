/// Real camera frame source using the `camera` package.
/// On desktop, pair with camera_windows / camera_macos.
/// For full virtual-cam output you still need a FrameSink that talks to
/// OBS Virtual Camera, NDI, or a native driver.

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'pipeline.dart';

class CameraFrameSource implements FrameSource {
  CameraController? _controller;
  final _controllerReady = Completer<void>();
  final StreamController<StudioFrame> _out = StreamController.broadcast();
  bool _running = false;
  List<CameraDescription> _cameras = [];

  @override
  String get label => _controller?.description.name ?? 'Camera';

  @override
  bool get isRunning => _running;

  @override
  Stream<StudioFrame> get frames => _out.stream;

  Future<List<CameraDescription>> listCameras() async {
    _cameras = await availableCameras();
    return _cameras;
  }

  Future<void> selectCamera(CameraDescription camera, {
    ResolutionPreset preset = ResolutionPreset.high,
  }) async {
    await _controller?.dispose();
    _controller = CameraController(
      camera,
      preset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (!_controllerReady.isCompleted) {
      _controllerReady.complete();
    }
  }

  @override
  Future<void> start() async {
    if (_controller == null) {
      final cams = await listCameras();
      if (cams.isEmpty) {
        throw StateError('No cameras available');
      }
      await selectCamera(cams.first);
    }
    if (!_controller!.value.isInitialized) {
      await _controller!.initialize();
    }

    // Capture stream via startImageStream where supported (mobile).
    // On some desktop implementations image stream is limited; fall back
    // to periodic takePicture for demo continuity if needed.
    try {
      await _controller!.startImageStream(_onCameraImage);
      _running = true;
    } catch (e) {
      debugPrint('Image stream unavailable ($e). Using timed snapshots.');
      _running = true;
      _snapshotLoop();
    }
  }

  void _onCameraImage(CameraImage image) {
    // Convert to a simple JPEG-like payload for the pipeline.
    // Production: use YUV→RGB isolate conversion or pass planes to native.
    if (!_out.hasListener) return;
    final bytes = image.planes.isNotEmpty
        ? image.planes.first.bytes
        : Uint8List(0);
    _out.add(StudioFrame(
      bytes: bytes,
      width: image.width,
      height: image.height,
      timestamp: DateTime.now(),
      format: FrameFormat.yuv,
    ));
  }

  Future<void> _snapshotLoop() async {
    while (_running && _controller != null) {
      try {
        final file = await _controller!.takePicture();
        final bytes = await file.readAsBytes();
        _out.add(StudioFrame(
          bytes: bytes,
          width: _controller!.value.previewSize?.height.toInt() ?? 1280,
          height: _controller!.value.previewSize?.width.toInt() ?? 720,
          timestamp: DateTime.now(),
          format: FrameFormat.jpeg,
        ));
      } catch (e) {
        debugPrint('Snapshot error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 66)); // ~15 fps fallback
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    try {
      if (_controller?.value.isStreamingImages == true) {
        await _controller?.stopImageStream();
      }
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
  }

  CameraController? get controller => _controller;
}
