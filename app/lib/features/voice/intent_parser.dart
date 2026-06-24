import 'intent.dart';

class IntentParser {
  static final Map<VoiceIntent, List<String>> _commandMap = {
    // 🔥 SOS
    VoiceIntent.sos: ["sos", "emergency", "urgency"],
    
    // 🔥 Navigation
    VoiceIntent.back: [
      "back", "go back", "exit", "cancel", "home", 
      "close", "go home", "exit settings", "stop camera"
    ],
    
    // 🔥 Smart Camera
    VoiceIntent.colorDetection: [
      "what color is this", "detect color", "tell me the color", "identify color", "color"
    ],
    
    VoiceIntent.ocr: [
      "read text", "read this", "read that", "read dext", "read", 
      "text reader", "open ocr", "scan text", "ocr"
    ],

    VoiceIntent.objectDetection: [
      "detect objects", "object detection", "find objects", "what is in front of me",
      "identify objects", "navigation mode", "find things", "object detector"
    ],
    
    VoiceIntent.readPdf: ["pdf", "read pdf", "document", "file"],
    VoiceIntent.capture: ["capture", "photo", "picture", "take picture", "scan"],

    // 🔥 Settings & Contacts
    VoiceIntent.openSettings: ["voice settings", "change voice", "open settings", "setting"],
    VoiceIntent.manageContacts: [
      "manage contacts", "manage contact", "manage", "contacts", "contact",
      "edit contacts", "emergency contacts", "update contacts", "change number", "contact settings"
    ],

    // 🔥 Pitch & Speed (Flexible mapping)
    VoiceIntent.speedSlow: ["slow", "slower", "slow speed", "reduce speed", "decrease speed"],
    VoiceIntent.speedNormal: ["normal speed", "reset speed", "default speed", "standard speed"],
    VoiceIntent.speedFast: ["fast", "faster", "fast speed", "increase speed", "quick"],
    
    VoiceIntent.pitchLow: ["low pitch", "deep voice", "low voice", "heavy voice", "deep pitch"],
    VoiceIntent.pitchNormal: ["normal pitch", "natural voice", "default pitch", "reset pitch"],
    VoiceIntent.pitchHigh: ["high pitch", "high voice", "thin voice", "sharp voice"],
    
    // 🔥 General
    VoiceIntent.wake: ["vision mate", "hey vision", "hello vision", "hello", "hi", "wake up"],
    VoiceIntent.time: ["time"],
    VoiceIntent.date: ["date", "day"],
    VoiceIntent.battery: [
      "battery", "percentage", "battery percentage", 
      "what is my battery", "check battery", "how much battery", "battery status"
    ],
    VoiceIntent.weather: ["weather", "temperature", "forecast", "mausam", "mosam"],
    VoiceIntent.news: ["news", "headlines", "what's happening", "khabar", "taza khabar"],
    VoiceIntent.sleep: ["sleep", "go to sleep", "stop listening", "standby"],
    
    // 🔥 Features / Help / Guide
    VoiceIntent.help: [
      "help", "what can you do", "features", "what are your features", 
      "help me", "how can you help", "commands"
    ],
    VoiceIntent.manual: ["manual", "user guide", "tutdorial", "guide me", "how to use"],
    
    VoiceIntent.confirm: ["continue", "start", "yes", "sure", "ok", "save"],
    VoiceIntent.reject: ["no", "incorrect", "stop", "cancel"],
  };

  static VoiceIntent parse(String text) {
    final lowerText = text.toLowerCase().trim();
    if (lowerText.isEmpty) return VoiceIntent.unknown;

    for (var entry in _commandMap.entries) {
      if (entry.value.any((phrase) => lowerText.contains(phrase))) {
        return entry.key;
      }
    }
    return VoiceIntent.unknown;
  }
}
