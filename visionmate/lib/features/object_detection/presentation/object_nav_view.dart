import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'object_nav_viewmodel.dart';
import '../object_detection_screen.dart';
import '../../../core/services/service_providers.dart';

class ObjectNavView extends ConsumerStatefulWidget {
  const ObjectNavView({super.key});

  @override
  ConsumerState<ObjectNavView> createState() => _ObjectNavViewState();
}

class _ObjectNavViewState extends ConsumerState<ObjectNavView> {
  StreamSubscription? _voskSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(objectNavViewModelProvider.notifier).init();
      _startVoiceCommands();
    });
  }

  void _startVoiceCommands() {
    final vosk = ref.read(voskServiceProvider);
    vosk.start();
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted) return;
      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      if (text.isEmpty) return;

      if (text.contains("exit") || text.contains("back") || text.contains("stop")) {
        _handleExit();
      }
    });
  }

  void _handleExit() {
    _cleanup();
    Navigator.of(context).pop();
  }

  void _cleanup() {
    _voskSubscription?.cancel();
    ref.read(voskServiceProvider).stop();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Forward to the new professional screen
    return const ObjectDetectionScreen();
  }
}
