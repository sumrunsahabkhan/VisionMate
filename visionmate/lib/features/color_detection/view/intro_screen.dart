import 'dart:async';
import 'dart:ui';
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

class _ColorIntroScreenState extends ConsumerState<ColorIntroScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  Timer? _reminderTimer;
  StreamSubscription? _voskSubscription;
  bool _canListen = false;
  DateTime? _micStartTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    
    _fadeController.forward();
    Future.microtask(() => _startIntroSequence());
  }

  Future<void> _startIntroSequence() async {
    final tts = ref.read(ttsServiceProvider);
    final vosk = ref.read(voskServiceProvider);
    
    vosk.stop();
    setState(() => _canListen = false);

    tts.onComplete(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() => _canListen = true);
            _startLocalListening();
            _resetReminderTimer();
          }
        });
        tts.onComplete(() {}); 
      }
    });

    await tts.speak(
      "Color identification mode activated. To proceed, say Go. Or say Back to leave."
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
            Future.delayed(const Duration(milliseconds: 100), () {
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
      
      if (_micStartTime != null && DateTime.now().difference(_micStartTime!).inMilliseconds < 200) {
        return;
      }

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
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
    _cleanup();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080E),
      body: Stack(
        children: [
          // Elegant Mesh Background
          _buildMeshBackground(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    
                    // Mode Indicator
                    _buildModeBadge(),
                    const SizedBox(height: 40),

                    // Hero Icon Section
                    _buildHeroIcon(),
                    
                    const SizedBox(height: 50),

                    // Balanced Typography
                    _buildTitle(),
                    const SizedBox(height: 16),
                    _buildDescription(),

                    const Spacer(flex: 4),

                    // Interactive Elements
                    _buildVoiceIndicator(),
                    const SizedBox(height: 24),
                    _buildActionButton(),
                    
                    const SizedBox(height: 12),
                    _buildSecondaryButton(),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshBackground() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.cyanAccent.withOpacity(0.08), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -100,
          child: Container(
            width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.blueAccent.withOpacity(0.05), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text("COLOR DETECTION MODE", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHeroIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple effect
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (index * 0.2) + (_pulseController.value * 0.1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.05 / (index + 1)), width: 1.5),
                  ),
                ),
              );
            },
          );
        }),
        
        // Main Disc
        Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF12121A),
            boxShadow: [
              BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 40, spreadRadius: 5),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: const Center(
            child: Icon(Icons.palette_rounded, size: 70, color: Colors.cyanAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Colors.cyanAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            "Color Identifier",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return const Text(
      "Point your camera at any surface to accurately identify colors and their shades in real-time.",
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white54,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildVoiceIndicator() {
    if (!_canListen) return const SizedBox(height: 50);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_rounded, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 8),
                const Text("SAY 'GO' TO START", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withOpacity(0.9)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _navigateToCamera,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text("START CAMERA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return TextButton(
      onPressed: _handleExit,
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        foregroundColor: Colors.white30,
      ),
      child: const Text("CLOSE FEATURE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
    );
  }
}
