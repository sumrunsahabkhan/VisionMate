import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'presentation/object_nav_viewmodel.dart';
import 'widgets/scan_animation.dart';
import '../assistant/presentation/assistant_viewmodel.dart';
import '../../core/services/service_providers.dart';

class ObjectDetectionScreen extends ConsumerStatefulWidget {
  final String? initialMode;
  final String? targetObject;

  const ObjectDetectionScreen({
    super.key, 
    this.initialMode, 
    this.targetObject
  });

  @override
  ConsumerState<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends ConsumerState<ObjectDetectionScreen> {
  Timer? _guidanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(objectNavViewModelProvider.notifier).init().then((_) {
        if (!mounted) return;
        
        // Only provide guidance, don't auto-capture
        String guidance = "Camera is ready. Double tap anywhere to take a picture.";
        if (widget.targetObject != null) {
          guidance = "Searching for ${widget.targetObject}. Aim your phone and double tap to take a picture.";
        }
        
        ref.read(ttsServiceProvider).speak(guidance);
        _startGuidanceTimer();
      });
    });
  }

  void _startGuidanceTimer() {
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (mounted) {
        ref.read(ttsServiceProvider).speak(
          "Camera active. Aim your phone and double tap the screen to take a picture."
        );
      }
    });
  }

  void _handleExit() {
    _guidanceTimer?.cancel();
    ref.read(ttsServiceProvider).speak("Exiting Smart Vision.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _guidanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(objectNavViewModelProvider);
    final viewModel = ref.read(objectNavViewModelProvider.notifier);

    if (!state.isInitialized || viewModel.camera == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          _guidanceTimer?.cancel();
          viewModel.captureAndAnalyze(context, targetObject: widget.targetObject);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 1 / viewModel.camera!.value.aspectRatio,
                child: CameraPreview(viewModel.camera!),
              ),
            ),

            ScanAnimation(isScanning: state.status == DetectionState.scanning),
            
            Positioned(
              top: 52,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getStatusIcon(state.status),
                      const SizedBox(width: 10),
                      Text(
                        _getStateLabel(state.status), 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 52,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: _handleExit,
              ),
            ),

            const Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Text(
                "DOUBLE TAP TO CAPTURE",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusIcon(DetectionState status) {
    if (status == DetectionState.scanning) {
      return const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent));
    }
    return const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 18);
  }

  String _getStateLabel(DetectionState status) {
    switch (status) {
      case DetectionState.idle: return "READY TO SCAN";
      case DetectionState.scanning: return "CAPTURING...";
      case DetectionState.speaking: return "DESCRIBING...";
      case DetectionState.listening: return "LISTENING...";
    }
  }
}
