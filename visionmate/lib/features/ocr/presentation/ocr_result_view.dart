import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import 'ocr_viewmodel.dart';
import 'scanner_view.dart';

class OCRResultView extends ConsumerStatefulWidget {
  final String imagePath;
  const OCRResultView({super.key, required this.imagePath});

  @override
  ConsumerState<OCRResultView> createState() => _OCRResultViewState();
}

class _OCRResultViewState extends ConsumerState<OCRResultView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _voiceReminderTimer;
  StreamSubscription? _voskSubscription;
  bool _isReading = true;
  bool _canListen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.microtask(() => _processAndReadText());
  }

  Future<void> _processAndReadText() async {
    final ocrViewModel = ref.read(ocrViewModelProvider.notifier);
    final tts = ref.read(ttsServiceProvider);
    
    // Stop Vosk during initial processing
    ref.read(voskServiceProvider).stop();

    String text = await ocrViewModel.scanText(widget.imagePath);
    bool hasText = text.isNotEmpty;
    
    if (!mounted) return;

    // 1. Set the handler for when the RESULT finishes reading
    tts.onComplete(() {
      if (mounted) {
        // 2. When result ends, speak the prompt IMMEDIATELY
        String prompt = hasText ? "Do you want to scan another, or exit?" : "I couldn't detect any clear text. Say Try Again or Exit.";
        
        // 3. Set a new handler for when the PROMPT finishes
        tts.onComplete(() {
          if (mounted) {
            setState(() {
              _isReading = false;
              _canListen = true;
            });
            _startVoiceControl();
            _resetVoiceReminder(!hasText);
          }
          tts.onComplete(() {}); // Reset handler
        });

        tts.speak(prompt);
      }
    });

    // Start reading the actual detected text
    if (!hasText) {
      // If no text, trigger the prompt logic directly
      await tts.speak("No text found."); 
    } else {
      await tts.speak(text);
    }
  }

  void _resetVoiceReminder(bool failed) {
    _voiceReminderTimer?.cancel();
    _voiceReminderTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _canListen) {
        String prompt = failed ? "Say Try Again or Exit." : "Say Scan Another or Exit.";
        ref.read(ttsServiceProvider).speak(prompt);
        _resetVoiceReminder(failed);
      }
    });
  }

  void _startVoiceControl() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    vosk.start();
    
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_canListen) return;
      
      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
        if (text.contains("scan") || text.contains("again") || text.contains("another") || text.contains("try") || text.contains("shuru")) {
          _handleRescan();
        } else if (text.contains("exit") || text.contains("back") || text.contains("home") || text.contains("stop")) {
          _handleExit();
        }
      }
    });
  }

  void _handleRescan() {
    _cleanup();
    ref.read(ocrViewModelProvider.notifier).clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ScannerView()),
    );
  }

  void _handleExit() {
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting text reader.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cleanup() {
    _voiceReminderTimer?.cancel();
    _voskSubscription?.cancel();
    ref.read(voskServiceProvider).stop();
  }

  @override
  void dispose() {
    _cleanup();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrViewModelProvider);
    final hasText = ocrState.detectedText.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [Colors.orangeAccent.withOpacity(0.05), Colors.transparent],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeaderBadge(_isReading),
                  const SizedBox(height: 30),
                  _buildImagePreview(),
                  const SizedBox(height: 30),
                  Expanded(
                    child: _buildTextContainer(ocrState.detectedText, _isReading),
                  ),
                  const SizedBox(height: 20),
                  if (_canListen) _buildVoiceIndicator(!hasText),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleRescan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 65),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                    child: Text(
                      !hasText ? "TRY AGAIN" : "SCAN ANOTHER", 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(bool loading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading 
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent))
            : const Icon(Icons.check_circle_outline, color: Colors.orangeAccent, size: 14),
          const SizedBox(width: 10),
          Text(
            loading ? "RECOGNIZING TEXT..." : "READING COMPLETE", 
            style: const TextStyle(color: Colors.white54, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 10)
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildTextContainer(String text, bool loading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: loading 
        ? const Center(child: Text("Processing...", style: TextStyle(color: Colors.white24)))
        : SingleChildScrollView(
            child: Text(
              text.isEmpty ? "No text found in this image." : text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
            ),
          ),
    );
  }

  Widget _buildVoiceIndicator(bool failed) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_rounded, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            Text(
              failed ? "SAY 'TRY AGAIN' OR 'EXIT'" : "SAY 'SCAN ANOTHER' OR 'EXIT'", 
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)
            ),
          ],
        ),
      ),
    );
  }
}
