import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ocr_viewmodel.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import 'ocr_result_view.dart';

class ScannerView extends ConsumerStatefulWidget {
  const ScannerView({super.key});

  @override
  ConsumerState<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends ConsumerState<ScannerView> {
  bool _isProcessing = false;
  StreamSubscription? _voskSubscription;
  bool _introFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScannerSequence();
    });
  }

  Future<void> _startScannerSequence() async {
    final tts = ref.read(ttsServiceProvider);
    ref.read(cameraServiceProvider).openOCR();

    // Set onComplete to know when intro is done
    tts.onComplete(() {
      if (mounted) {
        setState(() => _introFinished = true);
        _startVoskListening();
        tts.onComplete(() {}); 
      }
    });

    await tts.speak(
      "Text reader is active. Please move your camera slowly over the text. I will notify you as soon as I detect any words. Once detected, hold your phone steady and double-tap anywhere on the screen to capture."
    );
  }

  void _startVoskListening() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    vosk.start();
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted) return;
      final text = (data['text'] ?? "").toString().toLowerCase().trim();

      if (text.isNotEmpty) {
        if (text.contains("exit") || text.contains("back") || text.contains("home") || text.contains("go back")) {
          _handleExit();
        }
      }
    });
  }

  void _handleExit() {
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting scanner.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _captureAndScan() async {
    // Only allow capture if intro is done and not already processing
    if (!_introFinished || _isProcessing || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ref.read(cameraServiceProvider).captureAndProcess();
      
      if (!mounted) return;

      if (result != null && result['imagePath'] != null) {
        _cleanup();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OCRResultView(imagePath: result['imagePath']),
          ),
        );
      } else {
        if (mounted) setState(() { _isProcessing = false; });
      }
    } catch (e) {
      debugPrint("Error in capture and scan: $e");
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _cleanup() {
    _voskSubscription?.cancel();
    ref.read(voskServiceProvider).stop();
    ref.read(cameraServiceProvider).stopCamera();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _captureAndScan,
        child: Stack(
          children: [
            const Positioned.fill(
              child: AndroidView(
                viewType: "visionmate/camera_preview",
              ),
            ),
            
            _buildScannerOverlay(),

            if (_isProcessing)
              const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
            
            Semantics(
              label: "Scanner active",
              hint: "Double tap anywhere to capture text",
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 20),
            ),
          ),
          Center(
            child: Icon(Icons.add, color: Colors.cyanAccent.withOpacity(0.5), size: 40),
          ),
          _buildCorner(Alignment.topLeft),
          _buildCorner(Alignment.topRight),
          _buildCorner(Alignment.bottomLeft),
          _buildCorner(Alignment.bottomRight),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment align) {
    return Align(
      alignment: align,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          border: Border(
            top: align == Alignment.topLeft || align == Alignment.topRight ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
            bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
            left: align == Alignment.topLeft || align == Alignment.bottomLeft ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
            right: align == Alignment.topRight || align == Alignment.bottomRight ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
