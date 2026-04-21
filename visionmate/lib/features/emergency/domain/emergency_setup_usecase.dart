import '../../voice/intent.dart';
import '../../settings/data/settings_repository.dart';

class SetupResult {
  final String speechText;
  final int nextStep;
  final bool isFinished;
  final String? pName, pNum, sName, sNum;
  final bool shouldSavePartial;

  SetupResult({
    required this.speechText,
    required this.nextStep,
    this.isFinished = false,
    this.pName, this.pNum, this.sName, this.sNum,
    this.shouldSavePartial = false,
  });
}

class EmergencySetupUseCase {
  final SettingsRepository _settingsRepo;

  EmergencySetupUseCase(this._settingsRepo);

  SetupResult next(int currentStep, String text, VoiceIntent intent, {
    String? tempPName, String? tempPNum, String? tempSName, String? tempSNum
  }) {
    if (text.contains("exit") || text.contains("cancel") || text.contains("stop")) {
      return SetupResult(speechText: "Action cancelled.", nextStep: -1, isFinished: true);
    }

    if (currentStep == -1) {
      if (intent == VoiceIntent.manageContacts || text.contains("update")) {
        return SetupResult(speechText: "Okay, let's update. Who should be your primary contact?", nextStep: 0);
      } else if (intent == VoiceIntent.deleteContacts || text.contains("delete")) {
        return SetupResult(speechText: "Emergency contacts have been deleted.", nextStep: -1, isFinished: true);
      } else if (intent == VoiceIntent.back || text.contains("back")) {
        return SetupResult(speechText: "Returning to settings.", nextStep: -1, isFinished: true);
      }
    }

    switch (currentStep) {
      case 0:
        return SetupResult(speechText: "What is the phone number for $text? Please say the digits clearly.", nextStep: 1, pName: text);
      
      case 1:
        String cleanNum = _settingsRepo.extractDigits(text);
        if (cleanNum.length < 5) {
          return SetupResult(speechText: "That doesn't sound like a valid number. Please say the digits clearly.", nextStep: 1);
        }
        return SetupResult(
          speechText: "I have captured the primary number as ${cleanNum.split('').join(' ')}. Is this correct? Say yes to continue, or no to re-enter.",
          nextStep: 10,
          pNum: cleanNum
        );

      case 10:
        if (intent == VoiceIntent.confirm || text.contains("yes")) {
          return SetupResult(
            speechText: "Primary contact saved. Now, who should be your secondary contact? Say their name.", 
            nextStep: 2,
            shouldSavePartial: true,
          );
        } else {
          return SetupResult(speechText: "Okay, please say the primary phone number again.", nextStep: 1);
        }

      case 2:
        return SetupResult(speechText: "What is the phone number for $text?", nextStep: 3, sName: text);

      case 3:
        String cleanNum = _settingsRepo.extractDigits(text);
        if (cleanNum.length < 5) {
          return SetupResult(speechText: "Please say the digits clearly.", nextStep: 3);
        }
        return SetupResult(
          speechText: "Captured secondary number as ${cleanNum.split('').join(' ')}. Is everything correct? Say yes to save, or no to re-enter secondary number.",
          nextStep: 4,
          sNum: cleanNum
        );

      case 4:
        if (intent == VoiceIntent.confirm || text.contains("yes")) {
          return SetupResult(speechText: "Emergency contacts saved successfully.", nextStep: -1, isFinished: true);
        } else {
          // 🔥 FIXED: If user says 'no' at the final step, only ask for secondary name again
          return SetupResult(speechText: "Okay, please say the name for your secondary contact again.", nextStep: 2);
        }
    }

    return SetupResult(speechText: "Sorry, I didn't get that.", nextStep: currentStep);
  }

  Future<void> saveContacts({String? pName, String? pNum, String? sName, String? sNum}) async {
    await _settingsRepo.updateEmergencyContacts(pName: pName, pNum: pNum, sName: sName, sNum: sNum);
  }

  Future<void> deleteContacts() async {
    await _settingsRepo.updateEmergencyContacts(pName: "", pNum: "", sName: "", sNum: "");
  }
}
