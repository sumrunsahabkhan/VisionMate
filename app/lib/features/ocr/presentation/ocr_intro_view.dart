import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import 'scanner_view.dart';
import 'pdf_reader_view.dart';

class OCRIntroView extends ConsumerStatefulWidget {
  const OCRIntroView({super.key});

  @override
  ConsumerState<OCRIntroView> createState() => _OCRIntroViewState();
}

class _OCRIntroViewState extends ConsumerState<OCRIntroView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  Timer? _reminderTimer;
  StreamSubscription? _voskSubscription;
  bool _canListen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    Future.microtask(() => _startIntroSequence());
  }

  Future<void> _startIntroSequence() async {
    final tts = ref.read(ttsServiceProvider);
    
    tts.onComplete(() {
      if (mounted) {
        setState(() => _canListen = true);
        _startLocalListening();
        _resetReminderTimer();
        tts.onComplete(() {}); 
      }
    });

    await tts.speak(
      "Smart OCR activated. Say Scan to open the camera, or PDF to select a document file. You can also say Exit to go back."
    );
  }

  void _resetReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _canListen) {
        ref.read(ttsServiceProvider).speak("Awaiting command. Say Scan, PDF, or Exit.");
        _resetReminderTimer();
      }
    });
  }

  void _startLocalListening() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    vosk.start();
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_canListen) return;
      
      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      
      if (text.isNotEmpty) {
        debugPrint("OCR Intro Voice: $text");
        // Added 'skin' as an alias for 'scan' to improve voice detection reliability
        if (text.contains("scan") || text.contains("skin") || text.contains("camera") || text.contains("shuru") || text.contains("photo")) {
          _navigateToScanner();
        } else if (text.contains("pdf") || text.contains("document") || text.contains("file") || text.contains("parho")) {
          _navigateToPdfReader();
        } else if (text.contains("exit") || text.contains("back") || text.contains("home") || text.contains("go back")) {
          _handleExit();
        }
      }
    });
  }

  void _navigateToScanner() {
    _cleanup();
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const ScannerView())
    );
  }

  void _navigateToPdfReader() {
    _cleanup();
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const PdfReaderView())
    );
  }

  void _handleExit() {
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting OCR.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cleanup() {
    _reminderTimer?.cancel();
    _voskSubscription?.cancel();
    try {
       ref.read(voskServiceProvider).stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _voskSubscription?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Colors.orangeAccent;
    
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5 + (_pulseController.value * 0.2),
                    colors: [accentColor.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(accentColor),
                  const Spacer(),
                  _buildCentralVisual(accentColor),
                  const Spacer(),
                  _buildStatusInfo(accentColor),
                  const SizedBox(height: 40),
                  _buildActionButtons(accentColor),
                  const SizedBox(height: 20),
                  _buildBackButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Column(
      children: [
        const Text(
          "VISION ENGINE",
          style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 6),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
          ),
        ),
      ],
    );
  }

  Widget _buildCentralVisual(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating Ring
        RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.1), width: 1),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 110,
                  child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Pulsing Core
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
          child: Container(
            padding: const EdgeInsets.all(45),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.03),
              border: Border.all(color: color.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 30)],
            ),
            child: Icon(Icons.document_scanner_rounded, size: 80, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(Color color) {
    return Column(
      children: [
        const Text(
          "TEXT RECOGNITION",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        const Text(
          "Neural processing active. I can read physical text or digital documents for you.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5, letterSpacing: 0.5),
        ),
        if (_canListen) ...[
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_rounded, size: 14, color: color),
                const SizedBox(width: 8),
                Text(
                  "SAY 'SCAN' OR 'PDF'",
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(Color color) {
    return Row(
      children: [
        Expanded(
          child: _customButton(
            "SCAN", 
            Icons.camera_alt_rounded, 
            color, 
            true, 
            _navigateToScanner
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _customButton(
            "PDF", 
            Icons.picture_as_pdf_rounded, 
            Colors.white10, 
            false, 
            _navigateToPdfReader
          ),
        ),
      ],
    );
  }

  Widget _customButton(String label, IconData icon, Color color, bool filled, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: Colors.white10),
          boxShadow: filled ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton(
      onPressed: _handleExit,
      style: TextButton.styleFrom(foregroundColor: Colors.white24),
      child: const Text(
        "GO BACK",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
      ),
    );
  }
}
