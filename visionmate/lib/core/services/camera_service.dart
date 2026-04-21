import 'package:flutter/services.dart';
import 'tts_service.dart';

class CameraService {
  static const MethodChannel _channel = MethodChannel('visionmate/camera');
  final TtsService _ttsService;

  CameraService(this._ttsService) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCameraFeedback':
        final String message = call.arguments as String;
        await _ttsService.speak(message);
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  Future<void> openOCR() async {
    try {
      await _channel.invokeMethod('openOCR');
    } on PlatformException catch (e) {
      print("Failed to open OCR: '${e.message}'.");
    }
  }

  Future<void> openColorDetection() async {
    try {
      await _channel.invokeMethod('openColor');
    } on PlatformException catch (e) {
      print("Failed to open Color Detection: '${e.message}'.");
    }
  }

  Future<void> openObjectDetection() async {
    try {
      await _channel.invokeMethod('openObject');
    } on PlatformException catch (e) {
      print("Failed to open Object Detection: '${e.message}'.");
    }
  }

  Future<void> capture() async {
    try {
      await _channel.invokeMethod('capture');
    } on PlatformException catch (e) {
      print("Failed to capture: '${e.message}'.");
    }
  }

  Future<dynamic> captureAndProcess() async {
    try {
      return await _channel.invokeMethod('captureAndProcess');
    } on PlatformException catch (e) {
      print("Failed to capture and process: '${e.message}'.");
      return null;
    }
  }

  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod('switchCamera');
    } on PlatformException catch (e) {
      print("Failed to switch camera: '${e.message}'.");
    }
  }

  Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
    } on PlatformException catch (e) {
      print("Failed to stop camera: '${e.message}'.");
    }
  }
}
