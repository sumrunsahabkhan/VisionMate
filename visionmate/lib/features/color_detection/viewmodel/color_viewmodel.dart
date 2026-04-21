import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/color_repository.dart';
import '../../../core/services/service_providers.dart';

enum ColorDetectionState { idle, scanning, processing, success, error }

class ColorState {
  final ColorDetectionState status;
  final ColorDetectionResult? result;
  final String guidance;

  ColorState({
    this.status = ColorDetectionState.idle,
    this.result,
    this.guidance = "Initializing...",
  });

  ColorState copyWith({
    ColorDetectionState? status,
    ColorDetectionResult? result,
    String? guidance,
  }) {
    return ColorState(
      status: status ?? this.status,
      result: result ?? this.result,
      guidance: guidance ?? this.guidance,
    );
  }
}

class ColorViewModel extends StateNotifier<ColorState> {
  final ColorRepository _repository;
  final Ref _ref;
  String _lastSpokenGuidance = "";
  DateTime? _lastGuidanceTime;
  bool _isGuidanceEnabled = false;

  ColorViewModel(this._repository, this._ref) : super(ColorState()) {
    _repository.setFeedbackHandler((message) {
      if (state.status == ColorDetectionState.scanning) {
        state = state.copyWith(guidance: message);
        if (_isGuidanceEnabled) {
          _speakGuidanceIfNeeded(message);
        }
      }
    });
  }

  void enableGuidance(bool enable) {
    _isGuidanceEnabled = enable;
    if (!enable) {
      _lastSpokenGuidance = "";
      _lastGuidanceTime = null;
    }
  }

  void _speakGuidanceIfNeeded(String message) {
    if (!_isGuidanceEnabled) return;
    
    final now = DateTime.now();
    final lowerMsg = message.toLowerCase();
    
    // 🔥 If state changed from Blurry to Ready, allow immediate speech
    bool isBlurry = lowerMsg.contains("blurry") || lowerMsg.contains("steady");
    bool isReady = lowerMsg.contains("ready");

    if (isReady) {
      // Allow if it's been 10s OR if the last message was NOT 'ready' (state change)
      if (_lastSpokenGuidance.contains("ready") && 
          _lastGuidanceTime != null && 
          now.difference(_lastGuidanceTime!).inSeconds < 10) {
        return;
      }
    }

    if (isBlurry) {
      if (_lastSpokenGuidance == message && 
          _lastGuidanceTime != null && 
          now.difference(_lastGuidanceTime!).inSeconds < 5) {
        return;
      }
    }

    // Special handling for camera switching feedback
    if (message.startsWith("__CAMERA_SWITCHED__:")) {
      final lens = message.split(":")[1];
      _ref.read(ttsServiceProvider).speak("$lens camera active.");
      _lastSpokenGuidance = message;
      return;
    }

    _ref.read(ttsServiceProvider).speak(message);
    _lastSpokenGuidance = message;
    _lastGuidanceTime = now;
  }

  Future<void> startScanning() async {
    state = state.copyWith(status: ColorDetectionState.scanning, guidance: "Lens active");
    await _repository.startCamera();
  }

  Future<void> capture() async {
    if (state.status == ColorDetectionState.processing || state.status == ColorDetectionState.success) return;
    
    enableGuidance(false);
    state = state.copyWith(status: ColorDetectionState.processing);
    
    await _ref.read(ttsServiceProvider).speak("Capturing.");
    
    try {
      final result = await _repository.captureAndProcess();
      state = state.copyWith(status: ColorDetectionState.success, result: result);
    } catch (e) {
      state = state.copyWith(status: ColorDetectionState.error, guidance: "Scan failed");
      _ref.read(ttsServiceProvider).speak("Failed. Please try again.");
      enableGuidance(true);
    }
  }

  void reset() {
    enableGuidance(false);
    _lastSpokenGuidance = "";
    _lastGuidanceTime = null;
    state = ColorState();
  }

  @override
  void dispose() {
    _repository.stopCamera();
    super.dispose();
  }
}

final colorRepositoryProvider = Provider((ref) => ColorRepository());
final colorViewModelProvider = StateNotifierProvider<ColorViewModel, ColorState>((ref) {
  return ColorViewModel(ref.read(colorRepositoryProvider), ref);
});
