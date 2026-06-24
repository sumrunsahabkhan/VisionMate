import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool isLoaded;
  final bool isFirstLaunch;
  final int walkthroughStep;
  final double speechRate;
  final double pitch;
  final int silenceTimeout;
  final String primaryContactName;
  final String primaryContactNumber;
  final String secondaryContactName;
  final String secondaryContactNumber;

  SettingsState({
    required this.isLoaded, required this.isFirstLaunch, required this.walkthroughStep,
    required this.speechRate, required this.pitch, required this.silenceTimeout,
    required this.primaryContactName, required this.primaryContactNumber,
    required this.secondaryContactName, required this.secondaryContactNumber,
  });

  SettingsState copyWith({
    bool? isLoaded, bool? isFirstLaunch, int? walkthroughStep,
    double? speechRate, double? pitch, int? silenceTimeout,
    String? primaryContactName, String? primaryContactNumber,
    String? secondaryContactName, String? secondaryContactNumber,
  }) {
    return SettingsState(
      isLoaded: isLoaded ?? this.isLoaded,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      walkthroughStep: walkthroughStep ?? this.walkthroughStep,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      primaryContactName: primaryContactName ?? this.primaryContactName,
      primaryContactNumber: primaryContactNumber ?? this.primaryContactNumber,
      secondaryContactName: secondaryContactName ?? this.secondaryContactName,
      secondaryContactNumber: secondaryContactNumber ?? this.secondaryContactNumber,
    );
  }
}

class SettingsRepository extends StateNotifier<SettingsState> {
  SettingsRepository() : super(SettingsState(
    isLoaded: false, isFirstLaunch: true, walkthroughStep: 0,
    speechRate: 0.5, pitch: 1.0, silenceTimeout: 10,
    primaryContactName: "", primaryContactNumber: "",
    secondaryContactName: "", secondaryContactNumber: "",
  )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      isLoaded: true,
      isFirstLaunch: prefs.getBool('isFirstLaunch') ?? true,
      walkthroughStep: prefs.getInt('walkthroughStep') ?? 0,
      speechRate: prefs.getDouble('speechRate') ?? 0.5,
      pitch: prefs.getDouble('pitch') ?? 1.0,
      silenceTimeout: prefs.getInt('silenceTimeout') ?? 10,
      primaryContactName: prefs.getString('primaryContactName') ?? "",
      primaryContactNumber: prefs.getString('primaryContactNumber') ?? "",
      secondaryContactName: prefs.getString('secondaryContactName') ?? "",
      secondaryContactNumber: prefs.getString('secondaryContactNumber') ?? "",
    );
  }

  // 🔥 Restored original digit extraction logic
  String extractDigits(String text) {
    final Map<String, String> wordToDigit = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'to': '2', 'too': '2', 'ate': '8', 'for': '4'
    };

    List<String> parts = text.toLowerCase().split(' ');
    String result = "";

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];

      if (part == "double" && i + 1 < parts.length) {
        String nextDigit = _wordToSingleDigit(parts[i+1]);
        result += nextDigit + nextDigit;
        i++; continue;
      }
      if (part == "triple" && i + 1 < parts.length) {
        String nextDigit = _wordToSingleDigit(parts[i+1]);
        result += nextDigit + nextDigit + nextDigit;
        i++; continue;
      }

      if (wordToDigit.containsKey(part)) {
        result += wordToDigit[part]!;
      } else {
        result += part.replaceAll(RegExp(r'[^0-9]'), '');
      }
    }
    return result;
  }

  String _wordToSingleDigit(String word) {
    final Map<String, String> map = {'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'to': '2', 'too': '2', 'ate': '8', 'for': '4'};
    return map[word.toLowerCase()] ?? word.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> updateEmergencyContacts({String? pName, String? pNum, String? sName, String? sNum}) async {
    final prefs = await SharedPreferences.getInstance();
    if (pName != null) { await prefs.setString('primaryContactName', pName); state = state.copyWith(primaryContactName: pName); }
    if (pNum != null) { await prefs.setString('primaryContactNumber', pNum); state = state.copyWith(primaryContactNumber: pNum); }
    if (sName != null) { await prefs.setString('secondaryContactName', sName); state = state.copyWith(secondaryContactName: sName); }
    if (sNum != null) { await prefs.setString('secondaryContactNumber', sNum); state = state.copyWith(secondaryContactNumber: sNum); }
  }

  Future<void> markFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    state = state.copyWith(isFirstLaunch: false);
  }

  Future<void> updateWalkthroughStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('walkthroughStep', step);
    state = state.copyWith(walkthroughStep: step);
  }

  Future<void> updateSpeechRate(double rate) async {
    state = state.copyWith(speechRate: rate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speechRate', rate);
  }

  Future<void> updatePitch(double pitch) async {
    state = state.copyWith(pitch: pitch);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pitch', pitch);
  }
}

final settingsRepositoryProvider = StateNotifierProvider<SettingsRepository, SettingsState>((ref) => SettingsRepository());
