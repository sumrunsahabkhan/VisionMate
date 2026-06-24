import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'object_result_view.dart';
import '../../../core/services/service_providers.dart';

enum DetectionState { idle, scanning, speaking, listening }

class ObjectNavState {
  final bool isInitialized;
  final DetectionState status;

  ObjectNavState({
    this.isInitialized = false,
    this.status = DetectionState.idle,
  });

  ObjectNavState copyWith({bool? isInitialized, DetectionState? status}) {
    return ObjectNavState(
      isInitialized: isInitialized ?? this.isInitialized,
      status: status ?? this.status,
    );
  }
}

class ObjectNavViewModel extends StateNotifier<ObjectNavState> {
  final Ref _ref;
  CameraController? camera;

  ObjectNavViewModel(this._ref) : super(ObjectNavState());

  Future<void> init() async {
    if (camera != null) return;
    
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    camera = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await camera!.initialize();
    state = state.copyWith(isInitialized: true);
  }

  Future<void> captureAndAnalyze(BuildContext context, {String? targetObject, String? mode}) async {
    if (camera == null || !camera!.value.isInitialized) return;

    state = state.copyWith(status: DetectionState.scanning);

    try {
      final image = await camera!.takePicture();
      
      if (!mounted) return;

      state = state.copyWith(status: DetectionState.idle);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ObjectResultView(
            imagePath: image.path, 
            targetObject: targetObject,
            mode: mode,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Capture error: $e");
      state = state.copyWith(status: DetectionState.idle);
    }
  }

  @override
  void dispose() {
    camera?.dispose();
    super.dispose();
  }
}

final objectNavViewModelProvider = StateNotifierProvider<ObjectNavViewModel, ObjectNavState>((ref) {
  return ObjectNavViewModel(ref);
});
