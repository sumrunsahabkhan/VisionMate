import 'package:flutter/services.dart';

class ColorDetectionResult {
  final String name;
  final int confidence;
  final String hex;
  final String? imagePath;

  ColorDetectionResult({required this.name, required this.confidence, required this.hex, this.imagePath});

  factory ColorDetectionResult.fromMap(Map<dynamic, dynamic> map) {
    return ColorDetectionResult(
      name: map['color'] ?? "Unknown",
      confidence: map['confidence'] ?? 0,
      hex: map['hex'] ?? "#000000",
      imagePath: map['imagePath'],
    );
  }
}

class ColorRepository {
  static const MethodChannel _channel = MethodChannel('visionmate/color_engine');

  Future<void> startCamera() async {
    await _channel.invokeMethod('startCamera');
  }

  Future<void> stopCamera() async {
    await _channel.invokeMethod('stopCamera');
  }

  Future<ColorDetectionResult> captureAndProcess() async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod('captureAndProcess');
    return ColorDetectionResult.fromMap(result);
  }

  void setFeedbackHandler(Function(String) onFeedback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onCameraFeedback") {
        onFeedback(call.arguments as String);
      }
    });
  }
}
