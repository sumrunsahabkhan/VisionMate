import '../../voice/intent.dart';
import '../../../core/services/time_date_service.dart';
import '../../../core/services/battery_service.dart';

enum IntentAction {
  none,
  back,
  sos,
  manageContacts,
  deleteContacts,
  time,
  date,
  battery,
  sleep,
  walkthrough,
  settings,
  redial,
  callPrimary,
  callSecondary,
  readPdf,
  scanText,
  ocr,
  colorDetection,
  objectDetection,
  unknown
}

class IntentResult {
  final String speechText;
  final IntentAction action;
  final bool isOnline;

  IntentResult({
    required this.speechText,
    this.action = IntentAction.none,
    this.isOnline = false,
  });
}

class HandleIntentUseCase {
  final TimeDateService _timeDateService;
  final BatteryService _batteryService;

  HandleIntentUseCase(this._timeDateService, this._batteryService);

  Future<IntentResult> execute(VoiceIntent intent, String rawText) async {
    final lowerText = rawText.toLowerCase().trim();
    
    // 🔥 FIX: Redirect "how can you help" queries to the Help/Features action
    if (lowerText.contains("how can you help") || 
        lowerText.contains("what can you do") || 
        lowerText.contains("features") || 
        lowerText.contains("know my features") ||
        lowerText.contains("kya kar sakte ho")) {
      intent = VoiceIntent.help;
    }

    // Prevent feedback loops
    if (lowerText.contains("sorry") || lowerText.contains("connect") || lowerText.contains("internet")) {
      return IntentResult(speechText: "");
    }

    switch (intent) {
      case VoiceIntent.time:
        return IntentResult(speechText: "Time is ${_timeDateService.getCurrentTime()}", action: IntentAction.time);

      case VoiceIntent.date:
        String text = rawText.contains("day") 
            ? "Today is ${_timeDateService.getCurrentDay()}" 
            : "Today is ${_timeDateService.getCurrentDate()}";
        return IntentResult(speechText: text, action: IntentAction.date);

      case VoiceIntent.battery:
        final level = await _batteryService.batteryLevel;
        final isCharging = await _batteryService.isCharging();
        final chargingStatus = isCharging ? "and it is currently charging." : "and it is not charging.";
        return IntentResult(speechText: "Battery level is $level percent $chargingStatus", action: IntentAction.battery);

      case VoiceIntent.help:
        return IntentResult(
          speechText: "I am Vision Mate, your personal assistant. Offline, I can provide time, date, and battery status. My Smart Camera can identify colors, detect objects, read printed text, and read PDF files. I also have an SOS feature for emergency calls. Online, I can answer any question, read news, or give weather reports. You can also customize my voice speed and pitch in settings by saying: Open Settings. For a full tutorial, say: User Guide.",
          action: IntentAction.none,
        );

      case VoiceIntent.manual:
      case VoiceIntent.openWalkthrough:
        return IntentResult(
          speechText: "Vision Mate supports intuitive touch gestures. Triple tap anywhere to wake me up instantly. Double tap has a smart function. If I am speaking, a double tap will silence me immediately. If I am silent, it will repeat my last sentence. To send me to standby mode, simply swipe down anywhere on the screen. You can also use the smart camera for reading text, PDF reading, color, and object detection.",
          action: IntentAction.walkthrough,
        );

      case VoiceIntent.sos:
        return IntentResult(speechText: "Initializing emergency sequence.", action: IntentAction.sos);

      case VoiceIntent.redial:
        return IntentResult(speechText: "", action: IntentAction.redial, isOnline: false);
      case VoiceIntent.callPrimary:
        return IntentResult(speechText: "", action: IntentAction.callPrimary, isOnline: false);
      case VoiceIntent.callSecondary:
        return IntentResult(speechText: "", action: IntentAction.callSecondary, isOnline: false);

      case VoiceIntent.readPdf:
        return IntentResult(speechText: "Opening PDF reader.", action: IntentAction.readPdf);
      case VoiceIntent.ocr:
      case VoiceIntent.scanText:
        return IntentResult(speechText: "Opening Smart OCR.", action: IntentAction.ocr);
      case VoiceIntent.colorDetection:
        return IntentResult(speechText: "Opening color detector.", action: IntentAction.colorDetection);
      case VoiceIntent.objectDetection:
        return IntentResult(speechText: "Identifying objects. Please hold the phone steady.", action: IntentAction.objectDetection);

      case VoiceIntent.sleep:
        return IntentResult(speechText: "Going to standby.", action: IntentAction.sleep);

      case VoiceIntent.news:
      case VoiceIntent.weather:
      case VoiceIntent.chatbot:
        return IntentResult(speechText: "", isOnline: true);

      default:
        bool likelyQuery = lowerText.split(' ').length > 1;
        return IntentResult(
          speechText: "", 
          isOnline: likelyQuery, 
          action: IntentAction.unknown
        );
    }
  }
}
