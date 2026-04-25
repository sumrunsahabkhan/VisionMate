import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import '../repository/color_repository.dart';
import '../viewmodel/color_viewmodel.dart';
import 'camera_screen.dart';

class ColorResultScreen extends ConsumerStatefulWidget {
  const ColorResultScreen({super.key});

  @override
  ConsumerState<ColorResultScreen> createState() => _ColorResultScreenState();
}

class _ColorResultScreenState extends ConsumerState<ColorResultScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  Timer? _voiceReminderTimer;
  StreamSubscription? _voskSubscription;
  bool _speechFinished = false;
  bool _isNavigating = false;
  bool _isListening = false; 
  int? _currentSpeechId;
  DateTime? _lastTtsEndTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    _fadeController.forward();
    
    Future.microtask(() {
      _handleInitialResultSpeech();
    });
  }

  Future<void> _handleInitialResultSpeech() async {
    if (!mounted) return;
    
    // Stop mic and any ongoing speech
    final vosk = ref.read(voskServiceProvider);
    final tts = ref.read(ttsServiceProvider);
    
    vosk.stop();
    await tts.stop();

    setState(() {
      _speechFinished = false;
      _isNavigating = false;
      _isListening = false; 
    });

    final state = ref.read(colorViewModelProvider);
    final result = state.result;
    
    String colorName = result?.name ?? "Unknown";
    int confidence = result?.confidence ?? 0;
    
    // Minimal delay prompt
    String message = (confidence < 40)
      ? "Detected $colorName. Match is weak. Say scan or close." 
      : "The color is $colorName. Scan or close?";
    
    final speechId = DateTime.now().millisecondsSinceEpoch;
    _currentSpeechId = speechId;

    tts.onComplete(() {
      if (mounted && !_isNavigating && _currentSpeechId == speechId) {
        _lastTtsEndTime = DateTime.now();
        // 🔥 Minimal delay for listening
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isNavigating && _currentSpeechId == speechId) {
            setState(() {
              _speechFinished = true;
              _isListening = true; 
            });
            _startVoiceControl(); 
            _resetVoiceReminder();
          }
        });
        tts.onComplete(() {}); 
      }
    });

    await tts.speak(message);
  }

  void _resetVoiceReminder() {
    _voiceReminderTimer?.cancel();
    _voiceReminderTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _speechFinished && !_isNavigating) {
        final tts = ref.read(ttsServiceProvider);
        
        setState(() {
          _isListening = false;
          _speechFinished = false;
        });
        ref.read(voskServiceProvider).stop();

        final speechId = DateTime.now().millisecondsSinceEpoch;
        _currentSpeechId = speechId;

        tts.onComplete(() {
          if (mounted && _currentSpeechId == speechId) {
            _lastTtsEndTime = DateTime.now();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isNavigating && _currentSpeechId == speechId) {
                setState(() {
                  _speechFinished = true;
                  _isListening = true;
                });
                _startVoiceControl();
                _resetVoiceReminder();
              }
            });
            tts.onComplete(() {});
          }
        });

        tts.speak("Scan again, or close?");
      }
    });
  }

  void _startVoiceControl() {
    if (_isNavigating || !mounted) return;
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    
    vosk.stop();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _isNavigating) return;
      vosk.start();
      
      _voskSubscription = vosk.speechStream.listen((data) {
        if (!mounted || !_isListening || !_speechFinished || _isNavigating) return;

        // Minimized echo guard
        if (_lastTtsEndTime != null && DateTime.now().difference(_lastTtsEndTime!).inMilliseconds < 300) {
          return;
        }

        final text = (data['text'] ?? "").toString().toLowerCase().trim();
        final isFinal = data['isFinal'] ?? false;
        
        if (isFinal && text.isNotEmpty) {
          debugPrint("Result Speech Heard: $text");
          
          if (text.split(' ').length > 3 || text.contains("the color is")) {
            return;
          }

          // Fuzzy matching preserved
          final isScan = text == "scan" || text == "again" || text == "retry" || 
                         text.contains("scan") || text.contains("again") || 
                         text.contains("another") || text.contains("screen") || 
                         text.contains("skein") || text.contains("skiing") || 
                         text.contains("scheme");

          final isClose = text == "close" || text == "exit" || text == "stop" || 
                          text == "back" || text == "no";

          if (isScan) {
            _handleRescan();
          } else if (isClose) {
            _handleExit();
          }
        }
      });
    });
  }

  void _handleRescan() {
    if (_isNavigating || !mounted) return;
    setState(() {
      _isListening = false;
      _isNavigating = true;
    });
    _cleanup();
    ref.read(colorViewModelProvider.notifier).reset();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ColorCameraScreen(showIntro: false)));
  }

  void _handleExit() {
    if (_isNavigating || !mounted) return;
    setState(() {
      _isListening = false;
      _isNavigating = true;
    });
    _cleanup();
    
    // 🔥 Restored original logic: Speech + Pop
    ref.read(ttsServiceProvider).speak("Exiting color detection.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    
    // Simple pop to land back on Home
    Navigator.of(context).pop();
  }

  void _cleanup() {
    _voiceReminderTimer?.cancel();
    _voskSubscription?.cancel();
    _currentSpeechId = null;
    try {
      ref.read(voskServiceProvider).stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanup();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(colorViewModelProvider);
    final result = state.result;

    Color detectedColor = Colors.cyanAccent;
    if (result?.hex != null && result!.hex.startsWith('#')) {
      try {
        final hex = result.hex.replaceAll('#', '');
        detectedColor = Color(int.parse("FF$hex", radix: 16));
      } catch (e) {
        detectedColor = Colors.cyanAccent;
      }
    }

    final isLowMatch = (result?.confidence ?? 0) < 40;

    return Scaffold(
      backgroundColor: const Color(0xFF08080E),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [detectedColor.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTopStatus(detectedColor),
                    const Spacer(),
                    _buildMainCard(result, detectedColor),
                    const SizedBox(height: 50),
                    if (isLowMatch) _buildWarningBox(),
                    const Spacer(),
                    if (_isListening && !_isNavigating) _buildMicFeedback(),
                    const SizedBox(height: 20),
                    _buildBottomAction(isLowMatch),
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

  Widget _buildTopStatus(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 10),
          const Text("SCAN COMPLETE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildMainCard(ColorDetectionResult? result, Color color) {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 40, spreadRadius: -10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            result?.imagePath != null 
              ? Image.file(File(result!.imagePath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
              : Container(color: Colors.white10),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 30, left: 0, right: 0,
              child: Column(
                children: [
                  Text(
                    result?.name.toUpperCase() ?? "UNKNOWN",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
                    child: Text("${result?.confidence ?? 0}% MATCH", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orangeAccent.withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("LOW CONFIDENCE", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text("Try scanning again with better light.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicFeedback() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 12),
          Text("SAY 'SCAN' OR 'CLOSE'", style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomAction(bool isLowMatch) {
    return ElevatedButton(
      onPressed: _handleRescan,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      child: Text(
        isLowMatch ? "TRY AGAIN" : "SCAN ANOTHER",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}
