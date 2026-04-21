import 'dart:async';
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

class _OCRIntroViewState extends ConsumerState<OCRIntroView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
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
        if (text.contains("scan") || text.contains("camera") || text.contains("shuru") || text.contains("photo")) {
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
    // Use the provider context to stop Vosk, not 'ref' directly if we are in dispose
    // or just avoid calling ref in the actual dispose logic if it's already defunct.
    try {
       ref.read(voskServiceProvider).stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _voskSubscription?.cancel();
    // Don't call _cleanup() here because it uses 'ref' which might be defunct
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Colors.orangeAccent.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Spacer(),
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 100, color: Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 50),
                const Text("SMART OCR", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const SizedBox(height: 20),
                const Text(
                  "I can read text from your camera or PDF documents.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                ),
                const Spacer(),
                if (_canListen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                    child: const Text("SAY 'SCAN' OR 'PDF'", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _navigateToScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 70),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                        ),
                        child: const Text("SCAN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _navigateToPdfReader,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 70),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                        ),
                        child: const Text("PDF", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _handleExit,
                  child: const Text("GO BACK", style: TextStyle(color: Colors.white38, letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
