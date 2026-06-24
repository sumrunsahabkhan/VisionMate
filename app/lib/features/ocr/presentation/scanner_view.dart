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

class _ScannerViewState extends ConsumerState<ScannerView> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  StreamSubscription? _voskSubscription;
  bool _introFinished = false;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScannerSequence();
    });
  }

  Future<void> _startScannerSequence() async {
    final tts = ref.read(ttsServiceProvider);
    ref.read(cameraServiceProvider).openOCR();

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
    _scannerController.dispose();
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Colors.orangeAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _captureAndScan,
        child: Stack(
          children: [
            // Camera Preview
            const Positioned.fill(
              child: AndroidView(
                viewType: "visionmate/camera_preview",
              ),
            ),
            
            // HUD Overlay
            _buildHUD(accentColor),

            // Processing State
            if (_isProcessing)
              _buildProcessingOverlay(accentColor),
            
            // Screen Accessibility
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

  Widget _buildHUD(Color color) {
    return Stack(
      children: [
        // Grid background (Low opacity)
        Positioned.fill(
          child: Opacity(
            opacity: 0.1,
            child: CustomPaint(painter: GridPainter()),
          ),
        ),

        // Header
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SCANNER MODE",
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 30, height: 2,
                          decoration: BoxDecoration(
                            color: color,
                            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                    _buildStatusBadge(color),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Scanner Line
        AnimatedBuilder(
          animation: _scannerController,
          builder: (context, child) => Positioned(
            top: MediaQuery.of(context).size.height * 0.15 + (MediaQuery.of(context).size.height * 0.7 * _scannerController.value),
            left: 40, right: 40,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, color.withOpacity(0.5), color, color.withOpacity(0.5), Colors.transparent],
                ),
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
              ),
            ),
          ),
        ),

        // Corner Markers
        _buildScannerFrame(color),

        // Bottom Instruction
        Positioned(
          bottom: 60,
          left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, color: color, size: 18),
                  const SizedBox(width: 12),
                  const Text(
                    "DOUBLE TAP TO CAPTURE",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 8),
          const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildScannerFrame(Color color) {
    return IgnorePointer(
      child: Stack(
        children: [
          _buildCorner(Alignment.topLeft, color),
          _buildCorner(Alignment.topRight, color),
          _buildCorner(Alignment.bottomLeft, color),
          _buildCorner(Alignment.bottomRight, color),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment align, Color color) {
    return Align(
      alignment: align,
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border(
            top: align == Alignment.topLeft || align == Alignment.topRight ? BorderSide(color: color, width: 3) : BorderSide.none,
            bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight ? BorderSide(color: color, width: 3) : BorderSide.none,
            left: align == Alignment.topLeft || align == Alignment.bottomLeft ? BorderSide(color: color, width: 3) : BorderSide.none,
            right: align == Alignment.topRight || align == Alignment.bottomRight ? BorderSide(color: color, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(Color color) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(color: color, strokeWidth: 2),
            ),
            const SizedBox(height: 30),
            Text(
              "NEURAL PROCESSING",
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 8),
            const Text(
              "EXTRACTING TEXT DATA",
              style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 0.3;
    const double gap = 40;
    for (double i = 0; i <= size.width; i += gap) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += gap) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
