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
  Timer? _voiceReminderTimer;
  StreamSubscription? _voskSubscription;
  bool _speechFinished = false;
  bool _isNavigating = false;
  DateTime? _micStartTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.microtask(() => _handleInitialResultSpeech());
  }

  Future<void> _handleInitialResultSpeech() async {
    if (!mounted) return;
    final state = ref.read(colorViewModelProvider);
    final result = state.result;
    final tts = ref.read(ttsServiceProvider);
    final vosk = ref.read(voskServiceProvider);
    
    // 🔥 Stop mic and reset state immediately
    vosk.stop();
    setState(() {
      _speechFinished = false;
      _isNavigating = false;
    });

    String colorName = result?.name ?? "Unknown";
    int confidence = result?.confidence ?? 0;
    bool isLowMatch = confidence < 40;
    
    // 🔥 CRITICAL: Instruction NO LONGER says the trigger words to prevent self-triggering
    String message = isLowMatch 
      ? "I detected $colorName, but the match is weak. I am listening for your command now."
      : "The color is $colorName. I am listening for your command now.";
    
    tts.onComplete(() {
      if (mounted && !_isNavigating) {
        // 🔥 Increased to 5 seconds. This ensures TTS is 100% done and room is quiet.
        Future.delayed(const Duration(milliseconds: 5000), () {
          if (mounted && !_isNavigating) {
            setState(() => _speechFinished = true);
            _startVoiceControl();
            _resetVoiceReminder(isLowMatch);
          }
        });
        tts.onComplete(() {}); 
      }
    });

    await tts.speak(message);
  }

  void _resetVoiceReminder(bool isLowMatch) {
    _voiceReminderTimer?.cancel();
    _voiceReminderTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _speechFinished && !_isNavigating) {
        final tts = ref.read(ttsServiceProvider);
        final vosk = ref.read(voskServiceProvider);

        vosk.stop();
        setState(() => _speechFinished = false);

        tts.onComplete(() {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 3000), () {
              if (mounted && !_isNavigating) {
                setState(() => _speechFinished = true);
                _startVoiceControl();
                _resetVoiceReminder(isLowMatch);
              }
            });
            tts.onComplete(() {});
          }
        });

        tts.speak("Still listening. What would you like to do next?");
      }
    });
  }

  void _startVoiceControl() {
    if (_isNavigating || !mounted) return;
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    
    vosk.stop();
    vosk.start();
    _micStartTime = DateTime.now();
    
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_speechFinished || _isNavigating) return;
      
      // Strict 2.5s ignore window for any leftover noise
      if (_micStartTime != null && DateTime.now().difference(_micStartTime!).inMilliseconds < 2500) {
        return;
      }

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
        debugPrint("Result Screen Voice recognized: $text");
        
        final state = ref.read(colorViewModelProvider);
        final isLowMatch = (state.result?.confidence ?? 0) < 40;

        // 🔥 STRICT Trigger Matching: Only act if the command is clear
        if (isLowMatch) {
          // Low accuracy commands
          if (text.contains("try again") || text.contains("again") || text.contains("redo")) {
            _handleRescan();
            return;
          }
        } else {
          // Good accuracy commands
          if (text.contains("scan another") || text.contains("another") || text.contains("scan") || text.contains("next")) {
            _handleRescan();
            return;
          }
        }

        // Common exit commands
        if (text.contains("close") || text.contains("exit") || text.contains("finish") || text.contains("stop") || text.contains("back")) {
          _handleExit();
        }
      }
    });
  }

  void _handleRescan() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _cleanup();
    ref.read(colorViewModelProvider.notifier).reset();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ColorCameraScreen(showIntro: false)),
    );
  }

  void _handleExit() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting color identification.");
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
    _isNavigating = true;
    _cleanup();
    _pulseController.dispose();
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
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [detectedColor.withOpacity(0.2), const Color(0xFF05050A)],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  _buildHeaderBadge(detectedColor),
                  const Spacer(),
                  _buildResultCard(result, detectedColor),
                  const SizedBox(height: 40),
                  if (isLowMatch) _buildAdviceBox(),
                  const Spacer(),
                  
                  if (_speechFinished && !_isNavigating) _buildVoiceIndicator(isLowMatch),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleRescan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 65),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                    child: Text(
                      isLowMatch ? "TRY AGAIN" : "SCAN ANOTHER", 
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

  Widget _buildHeaderBadge(Color color) {
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
          Icon(Icons.auto_awesome, color: color, size: 14),
          const SizedBox(width: 10),
          const Text("ANALYSIS COMPLETE", style: TextStyle(color: Colors.white54, letterSpacing: 3, fontWeight: FontWeight.bold, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildResultCard(ColorDetectionResult? result, Color color) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 40, spreadRadius: 5)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38.5),
            child: result?.imagePath != null 
              ? Image.file(File(result!.imagePath!), fit: BoxFit.cover)
              : Container(color: Colors.white10),
          ),
        ),
        
        Positioned(
          bottom: -20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Text(
                      result?.name.toUpperCase() ?? "UNKNOWN",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        "${result?.confidence ?? 0}% MATCH",
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdviceBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates_rounded, color: Colors.orangeAccent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("IMPROVE ACCURACY", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text("Try moving closer for a better match.", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceIndicator(bool isLowMatch) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_rounded, color: Colors.cyanAccent, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isLowMatch ? "SAY 'TRY AGAIN' OR 'CLOSE'" : "SAY 'SCAN ANOTHER' OR 'CLOSE'", 
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)
              ),
            ),
          ],
        ),
      ),
    );
  }
}
