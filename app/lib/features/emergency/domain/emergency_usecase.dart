import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../../settings/data/settings_repository.dart';
import '../../../core/services/tts_service.dart';

class EmergencyUseCase {
  final TtsService _tts;
  final SettingsRepository _settingsRepo;

  EmergencyUseCase(this._tts, this._settingsRepo);

  String getInitialSpeech() => "Emergency detected. Initializing S O S.";
  
  String getPrimaryCallingSpeech(String name) => "Calling to your primary number, $name.";
  
  String getSecondaryCallingSpeech(String name) => "Now calling your secondary number, $name.";
  
  String getDidYouConnectSpeech(String name) => "I have returned from the call to $name. Did you connect successfully?";

  String getAreYouSafeSpeech() => "Okay, are you safe now? Say yes or no.";

  /// Generates speech for next action based on who was just called.
  String getNextActionSpeech({
    required bool isCurrentPrimary,
    required bool hasPrimary,
    required bool hasSecondary,
    required String pName,
    required String sName,
  }) {
    if (isCurrentPrimary) {
      if (hasSecondary) {
        return "Understood. Should I call your secondary contact $sName, or redial $pName?";
      } else {
        return "Understood. Should I redial $pName, or deactivate emergency mode?";
      }
    } else {
      if (hasPrimary) {
        return "Understood. Should I call your primary contact $pName, or redial $sName?";
      } else {
        return "Understood. Should I redial $sName, or deactivate emergency mode?";
      }
    }
  }

  String getFailedSpeech() => "I was unable to connect with your emergency contacts.";
  
  String getSafeExitSpeech() => "I am glad you are safe. Emergency mode deactivated.";

  Future<bool> makeCall(String number) async {
    if (number.isEmpty) return false;
    try {
      bool? res = await FlutterPhoneDirectCaller.callNumber(number);
      if (res == null || !res) {
        return await launchUrl(Uri.parse("tel:$number"));
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
