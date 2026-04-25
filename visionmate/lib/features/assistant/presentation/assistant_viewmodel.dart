import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../voice/intent.dart';
import '../../voice/intent_parser.dart';
import '../domain/walkthrough_usecase.dart';
import '../domain/handle_intent_usecase.dart';
import '../data/assistant_providers.dart';
import '../../../core/services/service_providers.dart';
import '../../../core/services/connectivity_service.dart';
import '../../settings/data/settings_repository.dart';
import '../../color_detection/view/intro_screen.dart';
import '../../ocr/presentation/ocr_intro_view.dart';
import '../../ocr/presentation/pdf_reader_view.dart';
import '../../object_detection/presentation/object_intro_view.dart'; 

enum AssistantUIState { home, time, battery, help, date, settings, manual, sleep, walkthrough, camera }

class AssistantState {
  final bool awake, ready, isSpeaking, isOnlineWaiting, isModelLoading;
  final String currentText, lastSpokenText;
  final AssistantUIState view;
  final int batteryLevel;
  final bool isCharging;
  final String? currentCity, currentCountry;
  final ConnectionStatus connectivity;
  final bool isWalkthroughActive, isWaitingForAction, isSOSActive;
  final int walkthroughStep;

  final double? tempSpeechRate, tempPitch;
  final bool isWaitingForSettingsConfirm, isSettingUpEmergency, isWaitingForSOSAnythingElse;
  final bool isWaitingForConnectChoice, isWaitingForSafeChoice;
  final int setupStep;
  final String tempPName, tempPNum, tempSName, tempSNum;
  final bool isSubModuleActive;

  AssistantState({
    required this.awake, required this.ready, required this.isSpeaking, required this.isOnlineWaiting, required this.isModelLoading,
    required this.currentText, required this.lastSpokenText, required this.view, required this.batteryLevel, required this.isCharging,
    this.currentCity, this.currentCountry, required this.connectivity, required this.isWalkthroughActive, required this.walkthroughStep,
    required this.isWaitingForAction, required this.isSOSActive, this.tempSpeechRate, this.tempPitch, required this.isWaitingForSettingsConfirm,
    required this.isSettingUpEmergency, required this.setupStep, required this.tempPName, required this.tempPNum, required this.tempSName,
    required this.tempSNum, required this.isWaitingForSOSAnythingElse,
    required this.isWaitingForConnectChoice, required this.isWaitingForSafeChoice,
    this.isSubModuleActive = false,
  });

  factory AssistantState.initial() => AssistantState(
    awake: false, ready: false, isSpeaking: false, isOnlineWaiting: false, isModelLoading: true,
    currentText: "", lastSpokenText: "", view: AssistantUIState.home, batteryLevel: 0, isCharging: false,
    connectivity: ConnectionStatus.online, isWalkthroughActive: false, walkthroughStep: 0, isWaitingForAction: false,
    isSOSActive: false, isWaitingForSettingsConfirm: false, isSettingUpEmergency: false, setupStep: 0,
    tempPName: "", tempPNum: "", tempSName: "", tempSNum: "", isWaitingForSOSAnythingElse: false,
    isWaitingForConnectChoice: false, isWaitingForSafeChoice: false,
  );

  AssistantState copyWith({
    bool? awake, bool? ready, bool? isSpeaking, bool? isOnlineWaiting, bool? isModelLoading,
    bool? isWalkthroughActive, bool? isWaitingForAction, bool? isSOSActive, bool? isCharging,
    bool? isWaitingForSettingsConfirm, bool? isSettingUpEmergency, bool? isWaitingForSOSAnythingElse,
    bool? isWaitingForConnectChoice, bool? isWaitingForSafeChoice, bool? isSubModuleActive,
    String? currentText, String? lastSpokenText, String? currentCity, String? currentCountry,
    String? tempPName, String? tempPNum, String? tempSName, String? tempSNum,
    AssistantUIState? view, int? batteryLevel, int? walkthroughStep, int? setupStep,
    ConnectionStatus? connectivity, double? tempSpeechRate, double? tempPitch,
  }) => AssistantState(
    awake: awake ?? this.awake,
    ready: ready ?? this.ready,
    isSpeaking: isSpeaking ?? this.isSpeaking,
    isOnlineWaiting: isOnlineWaiting ?? this.isOnlineWaiting,
    isModelLoading: isModelLoading ?? this.isModelLoading,
    currentText: currentText ?? this.currentText,
    lastSpokenText: lastSpokenText ?? this.lastSpokenText,
    view: view ?? this.view,
    batteryLevel: batteryLevel ?? this.batteryLevel,
    isCharging: isCharging ?? this.isCharging,
    currentCity: currentCity ?? this.currentCity,
    currentCountry: currentCountry ?? this.currentCountry,
    connectivity: connectivity ?? this.connectivity,
    isWalkthroughActive: isWalkthroughActive ?? this.isWalkthroughActive,
    walkthroughStep: walkthroughStep ?? this.walkthroughStep,
    isWaitingForAction: isWaitingForAction ?? this.isWaitingForAction,
    isSOSActive: isSOSActive ?? this.isSOSActive,
    tempSpeechRate: tempSpeechRate ?? this.tempSpeechRate,
    tempPitch: tempPitch ?? this.tempPitch,
    isWaitingForSettingsConfirm: isWaitingForSettingsConfirm ?? this.isWaitingForSettingsConfirm,
    isSettingUpEmergency: isSettingUpEmergency ?? this.isSettingUpEmergency,
    setupStep: setupStep ?? this.setupStep,
    tempPName: tempPName ?? this.tempPName,
    tempPNum: tempPNum ?? this.tempPNum,
    tempSName: tempSName ?? this.tempSName,
    tempSNum: tempSNum ?? this.tempSNum,
    isWaitingForSOSAnythingElse: isWaitingForSOSAnythingElse ?? this.isWaitingForSOSAnythingElse,
    isWaitingForConnectChoice: isWaitingForConnectChoice ?? this.isWaitingForConnectChoice,
    isWaitingForSafeChoice: isWaitingForSafeChoice ?? this.isWaitingForSafeChoice,
    isSubModuleActive: isSubModuleActive ?? this.isSubModuleActive,
  );
}

class AssistantViewModel extends StateNotifier<AssistantState> {
  final Ref _ref;
  final WalkthroughUseCase _walkthroughUseCase = WalkthroughUseCase();

  StreamSubscription? _batterySubscription;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _voskSubscription;
  Timer? _silenceTimer, _walkthroughRetryTimer, _ttsTimeoutTimer, _sosRetryTimer;
  bool _isInternalStop = false;

  Completer<void>? _callReturnCompleter;
  bool _isAppPaused = false;
  bool _sosWaitingForReturn = false;
  String _sosCurrentContactName = "";
  Completer<void>? _ttsCompleter;

  BuildContext? _navigationContext;
  void setNavigationContext(BuildContext context) => _navigationContext = context;

  AssistantViewModel(this._ref) : super(AssistantState.initial());

  Future<void> init() async {
    state = state.copyWith(isModelLoading: true);
    _setupTtsListeners();
    final location = _ref.read(locationServiceProvider);
    final battery = _ref.read(batteryServiceProvider);

    await [Permission.microphone, Permission.location, Permission.notification, Permission.phone, Permission.camera, Permission.storage, Permission.manageExternalStorage].request();

    final pos = await location.getCurrentPosition();
    if (pos != null) {
      final pm = await location.getPlacemark(pos);
      state = state.copyWith(currentCity: pm?.locality, currentCountry: pm?.isoCountryCode?.toLowerCase());
    }

    _batterySubscription = battery.onBatteryStateChanged.listen((s) {
      final charging = s == BatteryState.charging;
      if (state.isCharging != charging) {
        state = state.copyWith(isCharging: charging);
        if (state.ready && state.awake && !state.isSpeaking && !state.isOnlineWaiting && !state.isSubModuleActive) speak(charging ? "Charger connected." : "Charger disconnected.");
      }
    });

    _connectivitySubscription = _ref.read(connectivityStatusProvider.future).asStream().listen((status) {
      _handleConnectivityUpdate(status);
    });

    _ref.listen(connectivityStatusProvider, (previous, next) {
      next.whenData((status) => _handleConnectivityUpdate(status));
    });

    state = state.copyWith(
      ready: true,
      isModelLoading: false,
      batteryLevel: await battery.batteryLevel,
      connectivity: await _ref.read(connectivityServiceProvider).checkConnectivity(),
    );

    SettingsState settings;
    while (true) {
      settings = _ref.read(settingsRepositoryProvider);
      if (settings.isLoaded) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (settings.isFirstLaunch) {
      await _ref.read(settingsRepositoryProvider.notifier).markFirstLaunchDone();
      _startWalkthrough(0);
    } else {
      state = state.copyWith(view: AssistantUIState.home, awake: false, isWalkthroughActive: false);
      // 🔥 Restored original long greeting
      await speak("Hello, VisionMate here. Say Hello or tap the screen three times to wake me up, or say: User Guide, for a tutorial.");
    }

    _voskSubscription = _ref.read(voskServiceProvider).speechStream.listen((data) => _onSpeech(data));
  }

  void _setupTtsListeners() {
    final tts = _ref.read(ttsServiceProvider);
    tts.onComplete(_onTtsComplete);
    tts.onCancel(_onTtsComplete);
    tts.onError((_) => _onTtsComplete());
  }

  void setSubModuleActive(bool active) {
    state = state.copyWith(isSubModuleActive: active);
    if (active) {
      _silenceTimer?.cancel();
      _ref.read(voskServiceProvider).stop();
    } else {
      _setupTtsListeners();
      _ref.read(voskServiceProvider).start();
    }
  }

  void _onTtsComplete() {
    if (_isInternalStop) return;
    _ttsTimeoutTimer?.cancel();

    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }

    state = state.copyWith(isSpeaking: false);
    if (state.isSubModuleActive) return;
    
    if (state.isSOSActive && (state.isWaitingForConnectChoice || state.isWaitingForSafeChoice) && !state.isWaitingForSOSAnythingElse) {
       state = state.copyWith(isWaitingForSOSAnythingElse: true);
       _ref.read(voskServiceProvider).start();
       _startSosRetryTimer();
       return;
    }

    if (!state.isOnlineWaiting) {
      if (state.awake && !state.isSOSActive && !state.isSettingUpEmergency) {
        state = state.copyWith(currentText: state.view == AssistantUIState.camera ? "Processing Camera..." : "Listening...");
      }

      if (state.isWalkthroughActive) {
        if (state.walkthroughStep == 100) {
          state = state.copyWith(isWalkthroughActive: false, isWaitingForAction: false, awake: false, view: AssistantUIState.home, currentText: "");
          _ref.read(voskServiceProvider).start();
        } else {
          _runWalkthroughLogic();
        }
      } else {
        // 🔥 Instant mic start
        _ref.read(voskServiceProvider).start();
        if (state.awake) _resetSilenceTimer();
        if (state.isSOSActive && state.isWaitingForSOSAnythingElse) _startSosRetryTimer();
      }
    }
  }

  void _handleConnectivityUpdate(ConnectionStatus status) {
    if (state.connectivity != status) {
      state = state.copyWith(connectivity: status);
      if (state.ready && state.awake && !state.isSpeaking && !state.isOnlineWaiting && !state.isSubModuleActive) {
        if (status == ConnectionStatus.offline) {
          speak("Internet connection lost.");
        } else {
          speak("Internet connection restored.");
        }
      }
    }
  }

  void resumeAssistant() {
    bool previouslyPaused = _isAppPaused;
    _isAppPaused = false;
    _setupTtsListeners();

    if (state.isSOSActive && _sosWaitingForReturn && previouslyPaused) {
       state = state.copyWith(isSpeaking: false, isWaitingForSOSAnythingElse: false);
       if (_callReturnCompleter != null && !_callReturnCompleter!.isCompleted) {
         _callReturnCompleter!.complete();
       }
    } else if (previouslyPaused) {
       state = state.copyWith(isSpeaking: false, isOnlineWaiting: false);
       if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
         _ttsCompleter!.complete();
       }
    }
    
    if (state.ready && !state.isSubModuleActive && !state.isSOSActive) {
      _ref.read(voskServiceProvider).start();
    }
  }

  void pauseAssistant() {
    _isAppPaused = true;
    _ref.read(voskServiceProvider).stop();
  }

  void _onSpeech(Map<String, dynamic> data) {
    if (state.isSpeaking || state.isOnlineWaiting || !state.ready || state.isSubModuleActive) return;

    final text = (data['text'] ?? "").toString().trim().toLowerCase();
    final isFinal = data['isFinal'] ?? false;

    if (text.isNotEmpty && (state.awake || state.isSOSActive)) {
      state = state.copyWith(currentText: text);
    }

    if (!state.awake && !state.isSOSActive && text.isNotEmpty) {
      final intent = IntentParser.parse(text);
      if (intent == VoiceIntent.wake) {
        _wakeUp();
        return;
      }
    }

    if (isFinal && text.isEmpty && state.awake && !state.isWalkthroughActive && !state.isSettingUpEmergency && !state.isSOSActive) {
      return;
    }

    if (text.isEmpty) return;
    final intent = IntentParser.parse(text);

    if (isFinal) {
      _handleFinalSpeech(intent, text);
    }
  }

  void _handleFinalSpeech(VoiceIntent intent, String text) async {
    final lowerText = text.toLowerCase();

    if (state.isSOSActive) {
       _handleSosChoice(text);
       return;
    }

    if (intent == VoiceIntent.back) {
      if (state.view == AssistantUIState.camera) {
        _ref.read(cameraServiceProvider).stopCamera();
      }
      state = state.copyWith(view: AssistantUIState.home, currentText: "", isWalkthroughActive: false, isSettingUpEmergency: false, isSOSActive: false, isSubModuleActive: false);
      await speak("Exiting. Returning to home.");
      return;
    }

    if (state.isSettingUpEmergency) {
      _handleEmergencySetupInput(text);
      return;
    }

    if (state.isWalkthroughActive && state.isWaitingForAction) {
      if (lowerText.contains("hello") || lowerText.contains("hi") || lowerText.contains("hey") || lowerText.contains("vision")) {
        if (state.walkthroughStep == 4) {
          _walkthroughRetryTimer?.cancel();
          state = state.copyWith(isWaitingForAction: false, walkthroughStep: 5);
          speak("Great. I heard you clearly.");
        } else if (state.walkthroughStep == 10) {
          _wakeUp();
        }
        return;
      }
    }

    if (!state.awake) {
      if (intent == VoiceIntent.wake) {
        _wakeUp();
      } else if (intent == VoiceIntent.manual || intent == VoiceIntent.openWalkthrough) {
        _startWalkthrough(0);
      } else if (intent == VoiceIntent.sos || lowerText.contains("emergency") || lowerText.contains("urgency") || lowerText.contains("help")) {
        _triggerSOS();
      }
      return;
    }

    if (state.awake) {
      _silenceTimer?.cancel();
      handleIntent(intent, text);
    }
  }

  Future<void> handleIntent(VoiceIntent intent, String text) async {
    final lowerText = text.toLowerCase().trim();

    if (intent == VoiceIntent.back) {
      if (state.view == AssistantUIState.camera) {
        _ref.read(cameraServiceProvider).stopCamera();
      }
      state = state.copyWith(view: AssistantUIState.home, currentText: "", isSubModuleActive: false);
      speak("Exiting. Returning to home.");
      return;
    }

    if (intent == VoiceIntent.sos || lowerText.contains("emergency") || lowerText.contains("urgency")) {
      _triggerSOS();
      return;
    }

    if (intent == VoiceIntent.manageContacts) { _startEmergencySetup(); return; }

    if (state.view == AssistantUIState.settings || intent == VoiceIntent.openSettings) {
      _handleSettingsIntent(intent, text);
      return;
    }

    final useCase = _ref.read(handleIntentUseCaseProvider);
    final result = await useCase.execute(intent, text);

    switch (result.action) {
      case IntentAction.time: state = state.copyWith(view: AssistantUIState.time); break;
      case IntentAction.date: state = state.copyWith(view: AssistantUIState.date); break;
      case IntentAction.battery:
        final battery = _ref.read(batteryServiceProvider);
        final level = await battery.batteryLevel;
        state = state.copyWith(view: AssistantUIState.battery, batteryLevel: level);
        break;
      case IntentAction.sleep: _goToSleep(); return;
      case IntentAction.walkthrough: _startWalkthrough(0); return;

      case IntentAction.ocr:
        if (_navigationContext != null) {
          setSubModuleActive(true);
          await speak("Entering Reading mode. One moment", wait: true);
          Navigator.push(_navigationContext!, MaterialPageRoute(builder: (_) => const OCRIntroView()));
        }
        return;
        
      case IntentAction.readPdf:
        if (_navigationContext != null) {
          setSubModuleActive(true);
          await speak("Opening PDF reader.", wait: true);
          Navigator.push(_navigationContext!, MaterialPageRoute(builder: (_) => const PdfReaderView()));
        }
        return;

      case IntentAction.colorDetection:
        if (_navigationContext != null) {
          setSubModuleActive(true);
          await speak("Entering color identification mode. One moment.", wait: true);
          Navigator.push(_navigationContext!, MaterialPageRoute(builder: (_) => const ColorIntroScreen()));
        }
        return;
      case IntentAction.objectDetection:
        if (_navigationContext != null) {
          setSubModuleActive(true);
          await speak("Entering object detection mode on VisionMate. One moment.", wait: true);
          Navigator.push(_navigationContext!, MaterialPageRoute(builder: (_) => const ObjectIntroView()));
        }
        return;

      default: break;
    }

    if (result.isOnline) {
      _handleOnlineRequest(intent, text);
      return;
    }

    if (result.speechText.isNotEmpty) {
      await speak(result.speechText);
    }
  }

  void exitSubModule() {
    setSubModuleActive(false);
    state = state.copyWith(view: AssistantUIState.home, currentText: "");
  }

  void _handleSettingsIntent(VoiceIntent intent, String text) async {
    if (intent == VoiceIntent.openSettings && state.view != AssistantUIState.settings) {
      state = state.copyWith(view: AssistantUIState.settings, isWaitingForSettingsConfirm: false, awake: true);
      await speak("Voice settings are open. I can help you adjust how I speak. "
          "To change speed, say: slow, normal, or fast. "
          "To change voice tone, say: low pitch, natural, or high pitch. "
          "You can also say: manage contacts, to update your emergency numbers. "
          "Or say: back, to exit settings.");
      return;
    }

    if (intent != VoiceIntent.back) {
      final result = _ref.read(settingsUseCaseProvider).execute(intent, text, state.isWaitingForSettingsConfirm, state.tempSpeechRate, state.tempPitch);

      state = state.copyWith(
        isWaitingForSettingsConfirm: result.isWaitingForConfirm,
        tempSpeechRate: result.tempRate ?? state.tempSpeechRate,
        tempPitch: result.tempPitch ?? state.tempPitch,
      );

      if (result.shouldSave) {
        if (state.tempSpeechRate != null) await _ref.read(settingsRepositoryProvider.notifier).updateSpeechRate(state.tempSpeechRate!);
        if (state.tempPitch != null) await _ref.read(settingsRepositoryProvider.notifier).updatePitch(state.tempPitch!);
        state = state.copyWith(isWaitingForSettingsConfirm: false, tempSpeechRate: null, tempPitch: null);
      }

      if (result.shouldCancel) {
        state = state.copyWith(isWaitingForSettingsConfirm: false, tempSpeechRate: null, tempPitch: null);
      }

      if (result.shouldManageContacts) {
        _startEmergencySetup();
        return;
      }

      await speak(result.speechText,
          rate: result.tempRate ?? _ref.read(settingsRepositoryProvider).speechRate,
          pitch: result.tempPitch ?? _ref.read(settingsRepositoryProvider).pitch
      );
    }
  }

  Future<void> _handleOnlineRequest(VoiceIntent intent, String text) async {
    if (state.isSubModuleActive || state.isSOSActive) return;

    final conn = await _ref.read(connectivityServiceProvider).checkConnectivity();
    if (conn == ConnectionStatus.offline) {
      speak("No internet connection.");
      return;
    }

    _silenceTimer?.cancel();
    state = state.copyWith(isOnlineWaiting: true, currentText: "Checking online...");
    
    if (!state.isSOSActive) {
      await speak("One moment please.", wait: true);
    }

    try {
      final res = await _ref.read(assistantRepositoryProvider).getAssistantResponse(text, type: intent == VoiceIntent.news ? "news" : intent == VoiceIntent.weather ? "weather" : "ai", city: state.currentCity, country: state.currentCountry);

      if (state.isSubModuleActive || state.isSOSActive) return;

      state = state.copyWith(isOnlineWaiting: false);
      if (res.text != null) { state = state.copyWith(currentText: res.text!); await speak(res.text!); }
    } catch (e) {
      state = state.copyWith(isOnlineWaiting: false);
      if (!state.isSubModuleActive && !state.isSOSActive) speak("Sorry, I couldn't connect.");
    }
  }

  Future<void> speak(String text, {double? rate, double? pitch, bool wait = false}) async {
    if (text.isEmpty) { return; }

    _ref.read(voskServiceProvider).stop();
    _isInternalStop = true;
    
    _ref.read(ttsServiceProvider).stop();
    _isInternalStop = false;

    state = state.copyWith(isSpeaking: true, currentText: text, lastSpokenText: text);

    if (wait) {
      _ttsCompleter = Completer<void>();
    }

    _ttsTimeoutTimer?.cancel();
    _ttsTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (state.isSpeaking) state = state.copyWith(isSpeaking: false);
      if (wait && _ttsCompleter != null && !_ttsCompleter!.isCompleted) _ttsCompleter!.complete();
    });

    final s = _ref.read(settingsRepositoryProvider);
    _ref.read(ttsServiceProvider).speak(text, rate: rate ?? s.speechRate, pitch: pitch ?? s.pitch);

    if (wait) {
      await _ttsCompleter?.future;
    }
  }

  void handleTap(int count) {
    if (state.isSubModuleActive) return;
    if (count == 1) {
      if (state.isWalkthroughActive && state.walkthroughStep == 6) {
        _walkthroughRetryTimer?.cancel();
        state = state.copyWith(isWaitingForAction: false, walkthroughStep: 7);
        _runWalkthroughLogic();
      } else if (!state.isSpeaking) {
        speak(state.awake ? "Yes, I am listening." : "VisionMate is on standby.");
      }
    } else if (count == 2) {
      if (state.isSpeaking) {
        _isInternalStop = true;
        _ref.read(ttsServiceProvider).stop();
        state = state.copyWith(isSpeaking: false);
        _isInternalStop = false;
        _ref.read(voskServiceProvider).start();
      } else if (state.lastSpokenText.isNotEmpty) {
        speak(state.lastSpokenText);
      }
    } else if (count >= 3) {
      _wakeUp();
    }
  }

  void _wakeUp() {
    bool wasStep2 = state.isWalkthroughActive && state.walkthroughStep == 2;
    bool wasStep10 = state.isWalkthroughActive && state.walkthroughStep == 10;

    state = state.copyWith(awake: true, view: AssistantUIState.home, currentText: "");
    HapticFeedback.heavyImpact();

    if (state.isWalkthroughActive) {
      if (wasStep2) {
        _walkthroughRetryTimer?.cancel();
        state = state.copyWith(isWaitingForAction: false, walkthroughStep: 3);
        _runWalkthroughLogic();
      } else if (wasStep10) {
        _walkthroughRetryTimer?.cancel();
        state = state.copyWith(isWaitingForAction: false, walkthroughStep: 11);
        _runWalkthroughLogic();
      }
    } else {
      state = state.copyWith(currentText: "Listening...");
      speak("Yes, I am listening.");
    }
  }

  void _goToSleep() async {
    if (!state.awake) { return; }
    bool wasStep8 = state.isWalkthroughActive && state.walkthroughStep == 8;

    state = state.copyWith(awake: false, view: wasStep8 ? AssistantUIState.walkthrough : AssistantUIState.sleep, currentText: "");
    if (wasStep8) {
      _walkthroughRetryTimer?.cancel();
      state = state.copyWith(isWaitingForAction: false, walkthroughStep: 9);
      _runWalkthroughLogic();
    } else {
      HapticFeedback.vibrate();
      speak("Going to standby.");
    }
  }

  void _startWalkthrough(int step) {
    state = state.copyWith(isWalkthroughActive: true, walkthroughStep: step, isWaitingForAction: false, awake: false, view: AssistantUIState.walkthrough, currentText: "");
    _runWalkthroughLogic();
  }

  Future<void> _runWalkthroughLogic() async {
    if (!state.isWalkthroughActive || state.isSpeaking) { return; }

    final config = _walkthroughUseCase.getStepConfig(state.walkthroughStep);

    if (config.nextStep == 100) {
      state = state.copyWith(walkthroughStep: 100);
      await speak(config.text);
      return;
    }

    if (config.isAwake) state = state.copyWith(awake: true);

    if (config.text.isNotEmpty) {
      state = state.copyWith(walkthroughStep: config.nextStep);
      await speak(config.text);
      return;
    }

    if (config.isWaitingForAction) {
      state = state.copyWith(isWaitingForAction: true);
      _startWalkthroughRetry(config.isVoiceStep ? "Please say Hello." : "Please complete the required action.");
      if (config.isVoiceStep) { _ref.read(voskServiceProvider).start(); }
      return;
    }

    state = state.copyWith(walkthroughStep: config.nextStep, isWaitingForAction: false);
    if (config.text.isEmpty) { _runWalkthroughLogic(); }
  }

  void _startWalkthroughRetry(String text) {
    _walkthroughRetryTimer?.cancel();
    _walkthroughRetryTimer = Timer(const Duration(seconds: 8), () {
      if (state.isWalkthroughActive && state.isWaitingForAction && !state.isSpeaking) speak(text);
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    if (!state.awake || state.isSpeaking || state.isOnlineWaiting || state.isWalkthroughActive || state.isWaitingForSettingsConfirm || state.isSettingUpEmergency || state.isSOSActive || state.isSubModuleActive) { return; }

    final settings = _ref.read(settingsRepositoryProvider);
    _silenceTimer = Timer(Duration(seconds: settings.silenceTimeout), () async {
      if (state.awake && !state.isSpeaking && !state.isOnlineWaiting && !state.isSubModuleActive) {
        if (state.view == AssistantUIState.settings) {
          await speak("Voice settings are open. Say slow, normal, or fast to change speed. Or say back to exit.");
        } else {
          await speak("How can I help? You can ask for my features or say: User Guide, for a tutorial.");
        }
      }
    });
  }

  Future<void> _triggerSOS() async {
    final settings = _ref.read(settingsRepositoryProvider);
    if (settings.primaryContactNumber.isEmpty && settings.secondaryContactNumber.isEmpty) {
      await speak("No emergency contacts saved. Open settings to save emergency contacts.");
      return;
    }

    state = state.copyWith(isSOSActive: true, isWaitingForSOSAnythingElse: false, currentText: "PROCESSING SOS...");
    await speak(_ref.read(emergencyUseCaseProvider).getInitialSpeech(), wait: true);
    
    if (settings.primaryContactNumber.isNotEmpty) {
      _executeCallSequence(settings.primaryContactName, settings.primaryContactNumber, isPrimary: true);
    } else {
      _executeCallSequence(settings.secondaryContactName, settings.secondaryContactNumber, isPrimary: false);
    }
  }

  Future<void> _executeCallSequence(String name, String number, {required bool isPrimary}) async {
    final useCase = _ref.read(emergencyUseCaseProvider);
    _sosCurrentContactName = name;
    state = state.copyWith(currentText: "CALLING $name...", isWaitingForSOSAnythingElse: false);

    final speech = isPrimary ? useCase.getPrimaryCallingSpeech(name) : useCase.getSecondaryCallingSpeech(name);
    
    // 🔥 Ensure speech finishes BEFORE dialer opens
    await speak(speech, wait: true);

    _sosWaitingForReturn = true;
    _callReturnCompleter = Completer<void>();
    
    // 🔥 Start the call
    await useCase.makeCall(number);

    // Fallback timer if app never pauses or resumes
    Future.delayed(const Duration(minutes: 1), () {
      if (_callReturnCompleter != null && !_callReturnCompleter!.isCompleted) {
        _callReturnCompleter!.complete();
      }
    });

    // 🔥 This future will only complete when resumeAssistant() is called AFTER a pause
    await _callReturnCompleter?.future;
    _callReturnCompleter = null;
    _sosWaitingForReturn = false;
    
    _triggerSosChoice(name);
  }

  void _triggerSosChoice(String name) async {
    _sosCurrentContactName = name;
    final speech = _ref.read(emergencyUseCaseProvider).getDidYouConnectSpeech(name);
    state = state.copyWith(
      isWaitingForConnectChoice: true, 
      isWaitingForSafeChoice: false, 
      currentText: speech,
      isWaitingForSOSAnythingElse: false,
      isSpeaking: false
    );
    
    // Give audio a tiny moment to stabilize after app resume
    await Future.delayed(const Duration(milliseconds: 500));
    await speak(speech); 
    _startSosRetryTimer();
  }

  void _handleSosChoice(String text) async {
    final lowerText = text.toLowerCase();
    final settings = _ref.read(settingsRepositoryProvider);
    final emergency = _ref.read(emergencyUseCaseProvider);
    _sosRetryTimer?.cancel();

    bool saidYes = lowerText.contains("yes") || lowerText.contains("haan") || lowerText.contains("ji") || lowerText.contains("connect") || lowerText.contains("success") || lowerText.contains("thik") || lowerText.contains("gaya") || lowerText.contains("hogaya") || lowerText.contains("done") || lowerText.contains("mil gaya");
    bool saidNo = lowerText.contains("no") || lowerText.contains("nahi") || lowerText.contains("na") || lowerText.contains("fail") || lowerText.contains("not safe") || lowerText.contains("rehn") || lowerText.contains("ni");
    bool saidSecondary = lowerText.contains("secondary") || lowerText.contains("doosra") || lowerText.contains("other") || lowerText.contains(settings.secondaryContactName.toLowerCase()) || lowerText.contains("dusre");
    bool saidPrimary = lowerText.contains("primary") || lowerText.contains("pehla") || lowerText.contains(settings.primaryContactName.toLowerCase()) || lowerText.contains("pehle");

    if (state.isWaitingForSafeChoice) {
      if (saidYes || lowerText.contains("safe")) {
         state = state.copyWith(isSOSActive: false, isWaitingForSOSAnythingElse: false, view: AssistantUIState.home, awake: false);
         await speak(emergency.getSafeExitSpeech());
         return;
      } else if (saidNo) {
         state = state.copyWith(isWaitingForSafeChoice: false, isWaitingForConnectChoice: true, isWaitingForSOSAnythingElse: false);
         speak("Understood. Should I redial or call ${settings.secondaryContactName}?");
         return;
      }
    }

    if (saidYes) {
       state = state.copyWith(isWaitingForConnectChoice: false, isWaitingForSafeChoice: true, isWaitingForSOSAnythingElse: false);
       speak(emergency.getAreYouSafeSpeech());
    } else if (saidNo) {
       String nextSpeech = emergency.getNextActionSpeech(
         isCurrentPrimary: _sosCurrentContactName == settings.primaryContactName, 
         hasPrimary: settings.primaryContactNumber.isNotEmpty, 
         hasSecondary: settings.secondaryContactNumber.isNotEmpty, 
         pName: settings.primaryContactName, 
         sName: settings.secondaryContactName
       );
       state = state.copyWith(isWaitingForConnectChoice: true, isWaitingForSafeChoice: false, isWaitingForSOSAnythingElse: false); 
       speak(nextSpeech);
    } else if (lowerText.contains("redial") || lowerText.contains("again") || lowerText.contains("phir se") || lowerText.contains("dobara")) {
       _executeCallSequence(_sosCurrentContactName, _sosCurrentContactName == settings.primaryContactName ? settings.primaryContactNumber : settings.secondaryContactNumber, isPrimary: _sosCurrentContactName == settings.primaryContactName);
    } else if (saidSecondary && settings.secondaryContactNumber.isNotEmpty) {
       _executeCallSequence(settings.secondaryContactName, settings.secondaryContactNumber, isPrimary: false);
    } else if (saidPrimary && settings.primaryContactNumber.isNotEmpty) {
       _executeCallSequence(settings.primaryContactName, settings.primaryContactNumber, isPrimary: true);
    } else if (lowerText.contains("safe") || lowerText.contains("stop") || lowerText.contains("exit") || lowerText.contains("bas") || lowerText.contains("khala") || lowerText.contains("band")) {
       state = state.copyWith(isSOSActive: false, isWaitingForSOSAnythingElse: false, view: AssistantUIState.home, awake: false);
       await speak(emergency.getSafeExitSpeech());
    } else {
       _startSosRetryTimer();
    }
  }

  void _startSosRetryTimer() {
    _sosRetryTimer?.cancel();
    _sosRetryTimer = Timer(const Duration(seconds: 8), () {
      if (state.isSOSActive && !state.isSpeaking) {
         if (state.isWaitingForConnectChoice) {
           _triggerSosChoice(_sosCurrentContactName);
         } else if (state.isWaitingForSafeChoice) {
           speak(_ref.read(emergencyUseCaseProvider).getAreYouSafeSpeech());
         }
      }
    });
  }

  void _startEmergencySetup() async {
    final settings = _ref.read(settingsRepositoryProvider);
    if (settings.primaryContactNumber.isNotEmpty || settings.secondaryContactNumber.isNotEmpty) {
      String msg = "You have saved contacts. Primary is ${settings.primaryContactName} at number ${settings.primaryContactNumber.split('').join(' ')}. Secondary is ${settings.secondaryContactName} at number ${settings.secondaryContactNumber.split('').join(' ')}. Would you like to update them, delete them, or say back to exit?";
      state = state.copyWith(view: AssistantUIState.manual, isSettingUpEmergency: true, setupStep: -1);
      await speak(msg);
    } else {
      state = state.copyWith(isSettingUpEmergency: true, setupStep: 0, view: AssistantUIState.manual);
      await speak("Who should be your primary contact? Please say their name.");
    }
  }

  void _handleEmergencySetupInput(String text) async {
    final intent = IntentParser.parse(text);
    final result = _ref.read(emergencySetupUseCaseProvider).next(state.setupStep, text, intent, tempPName: state.tempPName, tempPNum: state.tempPNum, tempSName: state.tempSName, tempSNum: state.tempSNum);
    if (result.isFinished) {
      if (result.nextStep == -1 && state.setupStep == 4) { await _ref.read(emergencySetupUseCaseProvider).saveContacts(pName: state.tempPName, pNum: state.tempPNum, sName: state.tempSName, sNum: state.tempSNum); }
      state = state.copyWith(isSettingUpEmergency: false, view: AssistantUIState.home);
    } else {
      state = state.copyWith(setupStep: result.nextStep, tempPName: result.pName ?? state.tempPName, tempPNum: result.pNum ?? state.tempPNum, tempSName: result.sName ?? state.tempSName, tempSNum: result.sNum ?? state.tempSNum);
    }
    await speak(result.speechText);
  }

  @override
  void dispose() { _voskSubscription?.cancel(); _batterySubscription?.cancel(); _connectivitySubscription?.cancel(); _silenceTimer?.cancel(); _walkthroughRetryTimer?.cancel(); _ttsTimeoutTimer?.cancel(); _sosRetryTimer?.cancel(); super.dispose(); }
}

final assistantViewModelProvider = StateNotifierProvider<AssistantViewModel, AssistantState>((ref) => AssistantViewModel(ref));
