import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../services/object_detector_service.dart';
import '../models/detected_object.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import 'object_result_view.dart';

enum DetectionState { idle, scanning, speaking, listening }

class ObjectNavState {
  final DetectionState status;
  final List<DetectedObject> detectedObjects;
  final bool isInitialized;
  final String lastMessage;

  ObjectNavState({
    this.status = DetectionState.idle,
    this.detectedObjects = const [],
    this.isInitialized = false,
    this.lastMessage = "Initializing...",
  });

  ObjectNavState copyWith({
    DetectionState? status,
    List<DetectedObject>? detectedObjects,
    bool? isInitialized,
    String? lastMessage,
  }) {
    return ObjectNavState(
      status: status ?? this.status,
      detectedObjects: detectedObjects ?? this.detectedObjects,
      isInitialized: isInitialized ?? this.isInitialized,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}

class ObjectNavViewModel extends StateNotifier<ObjectNavState> {
  final Ref _ref;
  final ObjectDetectorService _detectorService = ObjectDetectorService();
  CameraController? _camera;
  StreamSubscription? _speechSub;
  bool _isSpeaking = false;

  ObjectNavViewModel(this._ref) : super(ObjectNavState());

  CameraController? get camera => _camera;

  Future<void> init() async {
    await _detectorService.initialize();
    
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _camera = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _camera!.initialize();
      if (!mounted) return;
      state = state.copyWith(isInitialized: true, status: DetectionState.idle);
      _startIdleListening();
    }
  }

  void _startIdleListening() {
    _speechSub?.cancel();
    final vosk = _ref.read(voskServiceProvider);
    vosk.stop();
    vosk.start();
    
    _speechSub = vosk.speechStream.listen((data) {
      if (state.status != DetectionState.idle || _isSpeaking) return;
      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      if (text.contains("exit") || text.contains("back")) {
        _handleExitCommand();
      }
    });
  }

  void _handleExitCommand() {
    _speechSub?.cancel();
    _ref.read(voskServiceProvider).stop();
    _ref.read(ttsServiceProvider).speak("Exiting Smart Vision.");
    _ref.read(assistantViewModelProvider.notifier).exitSubModule();
  }

  Future<void> captureAndAnalyze(BuildContext context, {String? targetObject}) async {
    if (state.status == DetectionState.scanning) return;
    
    _ref.read(voskServiceProvider).stop();
    
    // Feedback before capture
    await _ref.read(ttsServiceProvider).speak("Capturing image.");

    try {
      final image = await _camera!.takePicture();
      
      if (!mounted) return;

      // Navigate immediately to Result View exactly like OCR
      // We pass the targetObject if searching, otherwise null
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ObjectResultView(
            imagePath: image.path,
            targetObject: targetObject,
          ),
        ),
      );

    } catch (e) {
      debugPrint("Capture Error: $e");
      state = state.copyWith(status: DetectionState.idle);
      _startIdleListening();
    }
  }

  Future<void> startFullScan(BuildContext context) async {
    await captureAndAnalyze(context);
  }

  Future<void> startSearchFor(BuildContext context, String targetInput) async {
    final target = _matchWithYoloLabel(targetInput);
    if (target == null) {
      final msg = "I cannot search for $targetInput. Try a common object. Double tap to try again.";
      await _ref.read(ttsServiceProvider).speak(msg);
      return;
    }
    await captureAndAnalyze(context, targetObject: target);
  }

  String? _matchWithYoloLabel(String input) {
    const labels = [
      'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat', 
      'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 
      'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 
      'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 
      'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 
      'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 
      'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 
      'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 
      'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 
      'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
    ];
    for (var l in labels) {
      if (input.contains(l)) return l;
    }
    return null;
  }

  @override
  void dispose() {
    _speechSub?.cancel();
    _camera?.dispose();
    _detectorService.dispose();
    super.dispose();
  }
}

final objectNavViewModelProvider = StateNotifierProvider<ObjectNavViewModel, ObjectNavState>((ref) {
  return ObjectNavViewModel(ref);
});
