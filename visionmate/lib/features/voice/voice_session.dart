import '../../core/services/vosk_service.dart';
import 'intent_parser.dart';
import 'intent.dart';

class VoiceSession {
  final VoskService _vosk = VoskService();
  bool _isActive = false;
  
  // 🔥 Restoring properties from original VoiceBrain/Session logic
  bool awake = false;
  DateTime? lastHeard;

  void start(Function(String text, VoiceIntent intent, bool isFinal) onSpeech) {
    _isActive = true;
    _vosk.start();
    _vosk.listen((data) {
      if (!_isActive) return;
      final String text = (data['text'] ?? "").toString().trim();
      final bool isFinal = data['isFinal'] ?? false;
      
      if (text.isNotEmpty) {
        heardSomething();
      }

      final intent = IntentParser.parse(text);
      onSpeech(text, intent, isFinal);
    });
  }

  void stop() {
    _isActive = false;
    _vosk.stop();
  }

  // 🔥 Re-implementing original session helper methods
  void heardSomething() {
    lastHeard = DateTime.now();
  }

  void reset() {
    awake = false;
    lastHeard = null;
  }

  bool isSilentTooLong() {
    if (lastHeard == null) return false;
    final diff = DateTime.now().difference(lastHeard!).inSeconds;
    return diff > 15; // Silence threshold
  }
}
