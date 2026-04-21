import 'intent.dart';

class CommandMap {
  static final Map<VoiceIntent, List<String>> commands = {
    VoiceIntent.wake: ["hello", "hi", "wake up", "vision mate"],
    
    // Updated with Urdu and additional phrases from your request
    VoiceIntent.time: ["time", "current time", "what time is it", "waqt"],
    VoiceIntent.date: ["date", "day", "today", "what day is it"],
    VoiceIntent.battery: ["battery", "battery level", "charge", "level", "percent", "battery status"],
    
    VoiceIntent.help: ["help", "features", "what can you do", "how can you help", "capabilities", "tum kya kar sakti ho"],
    VoiceIntent.sos: ["emergency", "help me", "sos", "danger", "call for help", "call police"],
    
    VoiceIntent.sleep: ["sleep", "stop", "standby", "go to sleep", "shut down"],
    VoiceIntent.back: ["back", "exit", "return", "go back", "stop tutorial", "cancel guide", "quit", "cancel"],
    
    VoiceIntent.openWalkthrough: ["user guide", "walkthrough", "tutorial", "guide"],
    
    VoiceIntent.manageContacts: ["manage contact", "manage contacts", "update contact", "update contacts", "change contact", "change contacts", "setup emergency"],
    VoiceIntent.deleteContacts: ["delete contact", "delete contacts", "remove contact", "remove contacts", "clear contacts", "delete all contacts"],
    
    VoiceIntent.openSettings: ["settings", "open settings", "voice settings"],
    VoiceIntent.confirm: ["yes", "ok", "confirm", "save", "save settings", "yep", "correct", "true"],
    VoiceIntent.reject: ["no", "cancel", "wrong", "nope", "don't save", "false"],
    
    VoiceIntent.speedSlow: ["slow speed", "speak slow", "speed slow", "slow", "slower"],
    VoiceIntent.speedNormal: ["normal speed", "reset speed", "speed normal", "normal"], 
    VoiceIntent.speedFast: ["fast speed", "speak fast", "speed fast", "fast", "faster"],
    
    VoiceIntent.pitchLow: ["low pitch", "deep voice", "pitch low", "low"],
    VoiceIntent.pitchNormal: ["natural voice", "normal pitch", "pitch normal", "natural"],
    VoiceIntent.pitchHigh: ["high pitch", "high voice", "pitch high", "high"],
    
    VoiceIntent.news: ["news", "headlines", "latest news", "news update"],
    VoiceIntent.weather: ["weather", "forecast", "temperature", "outside"],

    VoiceIntent.colorDetection: ["color", "detect color", "identify color", "rang", "color detector"],
    VoiceIntent.ocr: ["read text", "ocr", "read this", "parho", "text reader", "scan document"],
    VoiceIntent.readPdf: ["read pdf", "open document", "read file", "open pdf"],
    VoiceIntent.objectDetection: ["object", "detect object", "what is this", "identify object"],
    VoiceIntent.capture: ["capture", "take picture", "photo", "le lo"],
  };
}
