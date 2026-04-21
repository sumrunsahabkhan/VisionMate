import 'dart:async';
import 'package:flutter/services.dart';

class VoskService {
  static const MethodChannel _channel = MethodChannel('visionmate/vosk');
  
  // Broadcast stream allows multiple parts of the app to listen simultaneously
  final StreamController<Map<String, dynamic>> _controller = StreamController<Map<String, dynamic>>.broadcast();
  
  VoskService() {
    // Only set this ONCE in the constructor
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onSpeech") {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
        _controller.add(data);
      }
    });
  }

  Stream<Map<String, dynamic>> get speechStream => _controller.stream;

  void start() {
    _channel.invokeMethod("startListening");
  }

  void stop() {
    _channel.invokeMethod("stopListening");
  }

  // Helper for sub-modules to listen without breaking the main assistant
  StreamSubscription<Map<String, dynamic>> listen(void Function(Map<String, dynamic>) onSpeechData) {
    return speechStream.listen(onSpeechData);
  }
}
