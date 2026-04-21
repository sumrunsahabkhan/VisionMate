import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import 'camera_screen.dart';

class ColorIntroScreen extends ConsumerStatefulWidget {
  const ColorIntroScreen({super.key});

  @override
  ConsumerState<ColorIntroScreen> createState() => _ColorIntroScreenState();
}

class _ColorIntroScreenState extends ConsumerState<ColorIntroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _reminderTimer;
  StreamSubscription? _voskSubscription;
  bool _canListen = false;
  DateTime? _micStartTime;

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
    final vosk = ref.read(voskServiceProvider);
    
    // Stop mic during announcement
    vosk.stop();
    setState(() => _canListen = false);

    tts.onComplete(() {
      if (mounted) {
        // Delay before listening to avoid picking up the tail end of the TTS
        // Increased to 2.5 seconds for extra safety
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() => _canListen = true);
            _startLocalListening();
            _resetReminderTimer();
          }
        });
        tts.onComplete(() {}); 
      }
    });

    // 🔥 Changed instruction to avoid trigger words like "Continue" or "Camera"
    await tts.speak(
      "Color identification mode activated. To proceed, say the word Go. Or say Back to leave."
    );
  }

  void _resetReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _canListen) {
        final tts = ref.read(ttsServiceProvider);
        final vosk = ref.read(voskServiceProvider);

        vosk.stop();
        setState(() => _canListen = false);

        tts.onComplete(() {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 2000), () {
              if (mounted) {
                setState(() => _canListen = true);
                _startLocalListening();
                _resetReminderTimer();
              }
            });
            tts.onComplete(() {});
          }
        });

        tts.speak("Awaiting your command. Say Go or Back.");
      }
    });
  }

  void _startLocalListening() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    
    vosk.stop();
    vosk.start();
    _micStartTime = DateTime.now();
    
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_canListen) return;
      
      // Ignore immediate noise/echo (2 seconds ignore window)
      if (_micStartTime != null && DateTime.now().difference(_micStartTime!).inMilliseconds < 2000) {
        return;
      }

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
        debugPrint("Intro Screen Voice: $text");
        
        final words = text.split(' ');
        bool wantsContinue = words.any((w) => ["go", "continue", "shuru", "start", "open"].contains(w));
        bool wantsExit = words.any((w) => ["back", "exit", "home", "stop"].contains(w));

        if (wantsContinue) {
          _navigateToCamera();
        } else if (wantsExit) {
          _handleExit();
        }
      }
    });
  }

  void _navigateToCamera() {
    _cleanup();
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => const ColorCameraScreen())
    );
  }

  void _handleExit() {
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting color identification.");
    
    // 🔥 Restore Assistant
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cleanup() {
    _reminderTimer?.cancel();
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
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Colors.cyanAccent.withOpacity(0.1), Colors.transparent],
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
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.palette_rounded, size: 100, color: Colors.cyanAccent),
                  ),
                ),
                const SizedBox(height: 50),
                const Text("COLOR DETECTOR", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const SizedBox(height: 20),
                const Text(
                  "Point your camera at an object and capture to hear its color name.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                ),
                const Spacer(),
                if (_canListen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                    child: const Text("SAY 'GO' TO START", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _navigateToCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                  ),
                  child: const Text("START CAMERA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
