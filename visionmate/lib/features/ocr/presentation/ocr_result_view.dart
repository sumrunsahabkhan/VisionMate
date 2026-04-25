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

class _OCRResultViewState extends ConsumerState<OCRResultView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _contentFadeController;
  Timer? _voiceReminderTimer;
  StreamSubscription? _voskSubscription;
  bool _isReading = true;
  bool _canListen = false;
  DateTime _listeningStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _contentFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    Future.microtask(() => _processAndReadText());
  }

  Future<void> _processAndReadText() async {
    final ocrViewModel = ref.read(ocrViewModelProvider.notifier);
    final tts = ref.read(ttsServiceProvider);
    
    // Stop listening while reading result
    ref.read(voskServiceProvider).stop();

    String text = await ocrViewModel.scanText(widget.imagePath);
    bool hasText = text.isNotEmpty;
    
    if (!mounted) return;

    tts.onComplete(() {
      if (mounted) {
        String prompt = hasText ? "Do you want to scan another, or exit?" : "I couldn't detect any clear text. Say Try Again or Exit.";
        
        tts.onComplete(() async {
          if (mounted) {
            // Added a small delay to prevent the mic from catching the end of the TTS prompt
            await Future.delayed(const Duration(milliseconds: 800));
            if (!mounted) return;
            
            setState(() {
              _isReading = false;
              _canListen = true;
              _listeningStartTime = DateTime.now();
            });
            _startVoiceControl();
            _resetVoiceReminder(!hasText);
          }
          tts.onComplete(() {}); 
        });

        tts.speak(prompt);
      }
    });

    if (!hasText) {
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
      
      // Safety: Ignore any voice results that might have started processing before we were ready
      if (DateTime.now().difference(_listeningStartTime).inMilliseconds < 500) return;

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
        debugPrint("OCR Result Voice: $text");
        // Added 'skin' as an alias for 'scan' and improved matching
        if (text.contains("scan") || text.contains("skin") || text.contains("again") || text.contains("another") || text.contains("try") || text.contains("shuru")) {
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
    try {
      ref.read(voskServiceProvider).stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanup();
    _pulseController.dispose();
    _contentFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrViewModelProvider);
    final hasText = ocrState.detectedText.isNotEmpty;
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
                    center: Alignment.topCenter,
                    radius: 1.2 + (_pulseController.value * 0.1),
                    colors: [accentColor.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _contentFadeController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(accentColor, _isReading),
                    const SizedBox(height: 30),
                    _buildImagePreview(accentColor),
                    const SizedBox(height: 30),
                    Expanded(
                      child: _buildTextContent(ocrState.detectedText, _isReading, accentColor),
                    ),
                    const SizedBox(height: 20),
                    if (_canListen) _buildVoiceHint(accentColor, !hasText),
                    const SizedBox(height: 20),
                    _buildActionButton(accentColor, !hasText),
                    const SizedBox(height: 20),
                    _buildExitLink(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color, bool loading) {
    return Column(
      children: [
        Text(
          loading ? "PROCESSING" : "ANALYSIS COMPLETE",
          style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: loading ? 60 : 30,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(Color color) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned.fill(child: Image.file(File(widget.imagePath), fit: BoxFit.cover)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(String text, bool loading, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: loading 
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: color, strokeWidth: 2)),
              const SizedBox(height: 20),
              const Text("NEURAL TEXT EXTRACTION", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ],
          )
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              text.isEmpty ? "No clear text could be identified in the captured frame." : text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: text.isEmpty ? Colors.white38 : Colors.white, 
                fontSize: 18, 
                height: 1.6,
                fontWeight: text.isEmpty ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
    );
  }

  Widget _buildVoiceHint(Color color, bool failed) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.03).animate(_pulseController),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded, color: color, size: 16),
            const SizedBox(width: 10),
            Text(
              failed ? "SAY 'TRY AGAIN' OR 'EXIT'" : "SAY 'SCAN ANOTHER' OR 'EXIT'", 
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Color color, bool failed) {
    return GestureDetector(
      onTap: _handleRescan,
      child: Container(
        height: 65,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Center(
          child: Text(
            failed ? "TRY AGAIN" : "SCAN ANOTHER",
            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildExitLink() {
    return TextButton(
      onPressed: _handleExit,
      child: const Text(
        "GO BACK",
        style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
      ),
    );
  }
}
