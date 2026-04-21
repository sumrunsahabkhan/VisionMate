import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;

class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setVolume(1.0);
    if (Platform.isAndroid) {
      await _tts.setEngine('com.google.android.tts');
    }
  }

  Future<void> speak(String text, {String language = 'en-US', double rate = 0.5, double pitch = 1.0}) async {
    await _tts.setLanguage(language);
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  void onComplete(Function callback) => _tts.setCompletionHandler(() => callback());
  void onCancel(Function callback) => _tts.setCancelHandler(() => callback());
  void onError(Function(String) callback) => _tts.setErrorHandler((msg) => callback(msg));
  
  // 🔥 Word Tracking Handler
  void setProgressHandler(Function(String text, int start, int end, String word) callback) {
    _tts.setProgressHandler((text, start, end, word) => callback(text, start, end, word));
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
