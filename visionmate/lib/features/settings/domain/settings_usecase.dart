import '../../voice/intent.dart';

class SettingsResult {
  final String speechText;
  final double? tempRate;
  final double? tempPitch;
  final bool shouldSave;
  final bool shouldCancel;
  final bool isWaitingForConfirm;
  final bool shouldManageContacts;

  SettingsResult({
    required this.speechText,
    this.tempRate,
    this.tempPitch,
    this.shouldSave = false,
    this.shouldCancel = false,
    this.isWaitingForConfirm = false,
    this.shouldManageContacts = false,
  });
}

class SettingsUseCase {
  SettingsResult execute(VoiceIntent intent, String text, bool isWaitingForConfirm, double? currentTempRate, double? currentTempPitch) {
    final lowerText = text.toLowerCase();

    // 1. Handle Confirmation Flow (Yes/No)
    if (isWaitingForConfirm) {
      if (intent == VoiceIntent.confirm || lowerText.contains("yes") || lowerText.contains("haan") || lowerText.contains("theek")) {
        return SettingsResult(speechText: "Settings saved successfully.", shouldSave: true);
      } else if (intent == VoiceIntent.reject || lowerText.contains("no") || lowerText.contains("nahi") || lowerText.contains("cancel")) {
        return SettingsResult(speechText: "Settings cancelled.", shouldCancel: true);
      }
    }

    // 2. Trigger Manage Contacts (Intent or Keyword fallback)
    if (intent == VoiceIntent.manageContacts || lowerText.contains("contact") || lowerText.contains("number")) {
      return SettingsResult(speechText: "", shouldManageContacts: true);
    }

    double? nr;
    double? np;
    String demo = "";

    // 3. Handle Speed Changes
    if (intent == VoiceIntent.speedSlow || lowerText.contains("slower") || lowerText.contains("slow")) {
      nr = 0.3;
      demo = "Setting speed to slow. Does this sound better? Say yes to save or no to cancel.";
    } else if (intent == VoiceIntent.speedNormal || lowerText.contains("reset speed") || lowerText.contains("normal")) {
      nr = 0.5;
      demo = "Resetting speed to normal. Does this sound better? Say yes to save or no to cancel.";
    } else if (intent == VoiceIntent.speedFast || lowerText.contains("faster") || lowerText.contains("fast")) {
      nr = 0.8;
      demo = "Setting speed to fast. Does this sound better? Say yes to save or no to cancel.";
    } 
    
    // 4. Handle Pitch Changes
    // 🔥 FIXED: Added "no pitch" and "low pitch" variations
    else if (intent == VoiceIntent.pitchLow || lowerText.contains("low pitch") || lowerText.contains("no pitch") || lowerText.contains("deep") || lowerText.contains("bhari") || lowerText.contains("low voice")) {
      np = 0.5;
      demo = "Setting pitch to low. Does this sound better? Say yes to save or no to cancel.";
    } else if (intent == VoiceIntent.pitchNormal || lowerText.contains("natural") || lowerText.contains("reset pitch") || lowerText.contains("normal voice")) {
      np = 1.0;
      demo = "Resetting pitch to natural. Does this sound better? Say yes to save or no to cancel.";
    } else if (intent == VoiceIntent.pitchHigh || lowerText.contains("high pitch") || lowerText.contains("high voice") || lowerText.contains("patli")) {
      np = 1.5;
      demo = "Setting pitch to high. Does this sound better? Say yes to save or no to cancel.";
    }

    if (nr != null || np != null) {
      return SettingsResult(
        speechText: demo,
        tempRate: nr,
        tempPitch: np,
        isWaitingForConfirm: true,
      );
    }

    // 5. Detailed Explanatory Response (If no command matched)
    return SettingsResult(
      speechText: "Voice settings are open. I can help you adjust how I speak. "
          "To change speed, say: slow, normal, or fast. "
          "To change voice tone, say: low pitch, natural, or high pitch. "
          "You can also say: manage contacts, to update your emergency numbers. "
          "Or say: back, to exit settings.",
    );
  }
}
