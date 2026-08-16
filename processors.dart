/// Built-in and bridge processors.
/// Real face-swap is expected to live in a native module or external service
/// (see ExternalFaceSwapProcessor). Pure-Dart processors here are for
/// beautify / color / placeholder behavior until the model is wired.

import 'dart:typed_data';

import 'pipeline.dart';

/// Pass-through (keeps pipeline alive).
class IdentityProcessor implements FrameProcessor {
  @override
  final String id = 'identity';
  @override
  final String name = 'Identity';
  @override
  bool enabled = true;

  @override
  Future<StudioFrame> process(StudioFrame input) async => input;
}

/// Placeholder that marks frames as “beautified”.
/// Replace body with real skin smoothing / relighting when model is ready.
class BeautifyProcessor implements FrameProcessor {
  @override
  final String id = 'beautify';
  @override
  final String name = 'Face Beautify';
  @override
  bool enabled = true;

  double strength = 0.7;

  @override
  Future<StudioFrame> process(StudioFrame input) async {
    // TODO: run real beautify model or GPU shader here.
    return input;
  }
}

/// Calls an external face-swap service (local HTTP or WebSocket).
/// Recommended production path:
///   Python process with InsightFace / DeepFace / FaceFusion
///   → HTTP POST /frame or WS binary frames
///   → returns swapped JPEG
class ExternalFaceSwapProcessor implements FrameProcessor {
  @override
  final String id = 'face_swap_external';
  @override
  final String name = 'Face Swap (External)';
  @override
  bool enabled = false;

  /// e.g. http://127.0.0.1:8765/swap
  String endpoint = 'http://127.0.0.1:8765/swap';

  /// Target face id or path known to the external service.
  String targetFaceId = '';

  @override
  Future<StudioFrame> process(StudioFrame input) async {
    if (!enabled || targetFaceId.isEmpty) return input;

    // Production: use package:http to POST input.bytes + targetFaceId
    // and return the response bytes as a new StudioFrame.
    // Kept as identity here so the app runs without the service.
    return input;
  }
}

/// Simple virtual-background style stage (mask + composite).
/// Full quality needs a segmentation model (MediaPipe Selfie Segmentation, etc.).
class BackgroundProcessor implements FrameProcessor {
  @override
  final String id = 'background';
  @override
  final String name = 'Background Replace / Blur';
  @override
  bool enabled = false;

  bool blur = true;
  Uint8List? virtualBgJpeg;

  @override
  Future<StudioFrame> process(StudioFrame input) async {
    // TODO: segmentation + composite
    return input;
  }
}

/// Color grade / LUT stage.
class ColorGradeProcessor implements FrameProcessor {
  @override
  final String id = 'color_grade';
  @override
  final String name = 'Color Grade';
  @override
  bool enabled = true;

  double brightness = 0;
  double contrast = 0;
  double saturation = 0;
  String lutName = 'Natural';

  @override
  Future<StudioFrame> process(StudioFrame input) async {
    // TODO: apply LUT or matrix in isolate
    return input;
  }
}
