import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import '../services/object_detector_service.dart';
import '../object_detection_screen.dart';

class ObjectResultView extends ConsumerStatefulWidget {
  final String imagePath;
  final String? targetObject;
  final String? mode;

  const ObjectResultView({
    super.key, 
    required this.imagePath, 
    this.targetObject,
    this.mode,
  });

  @override
  ConsumerState<ObjectResultView> createState() => _ObjectResultViewState();
}

class _ObjectResultViewState extends ConsumerState<ObjectResultView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _contentFadeController;
  Timer? _waitReminderTimer;
  StreamSubscription? _voskSubscription;
  bool _isAnalyzing = true;
  bool _canListen = false;
  String _resultText = "Analyzing surroundings...";
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

    Future.microtask(() => _runBackgroundAnalysis());
  }

  Future<void> _runBackgroundAnalysis() async {
    final tts = ref.read(ttsServiceProvider);
    
    // Safety: Stop listening while analyzing
    ref.read(voskServiceProvider).stop();

    String initialMsg = widget.mode == "room" ? "Identifying room, please wait." : "Analyzing surroundings, please wait.";
    await tts.speak(initialMsg);

    _waitReminderTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _isAnalyzing) {
        tts.speak("Processing the scene data, just a moment.");
      }
    });

    final detector = ObjectDetectorService();
    final result = await detector.analyzeScene(XFile(widget.imagePath));
    
    _waitReminderTimer?.cancel();

    String speech;
    if (widget.mode == "room") {
      speech = result.roomType.isNotEmpty 
        ? "It looks like you are in the ${result.roomType}." 
        : "I can see objects, but I'm not sure which room this is. It might be a common area.";
    } else if (widget.targetObject != null) {
      final found = result.objects.where((o) => o.label.toLowerCase() == widget.targetObject!.toLowerCase()).toList();
      speech = found.isNotEmpty 
        ? "Yes, I found a ${widget.targetObject}, ${found.first.proximity}." 
        : "No ${widget.targetObject} was detected nearby.";
    } else {
      speech = result.speech;
    }

    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _resultText = speech;
    });

    tts.onComplete(() {
      if (mounted) {
        String prompt = "Do you want to scan again, or exit?";
        tts.onComplete(() async {
          if (mounted) {
            // Anti-echo delay
            await Future.delayed(const Duration(milliseconds: 1000));
            if (!mounted) return;
            
            setState(() {
              _canListen = true;
              _listeningStartTime = DateTime.now();
            });
            _startVoiceControl();
          }
          tts.onComplete(() {}); 
        });
        tts.speak(prompt);
      }
    });

    await tts.speak(speech);
  }

  void _startVoiceControl() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    vosk.start();
    
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_canListen) return;
      
      if (DateTime.now().difference(_listeningStartTime).inMilliseconds < 500) return;

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
        if (text.contains("scan") || text.contains("again") || text.contains("try") || text.contains("room") || text.contains("shuru")) {
          _handleRescan();
        } else if (text.contains("exit") || text.contains("back") || text.contains("stop")) {
          _handleExit();
        }
      }
    });
  }

  void _handleRescan() {
    _cleanup();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ObjectDetectionScreen(
        initialMode: widget.mode ?? (widget.targetObject != null ? "find" : "scan"),
        targetObject: widget.targetObject,
      )),
    );
  }

  void _handleExit() {
    _cleanup();
    ref.read(ttsServiceProvider).speak("Exiting Smart Vision.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _cleanup() {
    _waitReminderTimer?.cancel();
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
    final hasResult = _resultText != "Analyzing surroundings...";
    const accentColor = Colors.blueAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
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
                    _buildHeader(accentColor, _isAnalyzing),
                    const SizedBox(height: 30),
                    _buildImagePreview(accentColor),
                    const SizedBox(height: 30),
                    Expanded(child: _buildResultContainer(_resultText, _isAnalyzing, accentColor)),
                    const SizedBox(height: 20),
                    if (_canListen) _buildVoiceHint(accentColor),
                    const SizedBox(height: 20),
                    _buildActionButton(accentColor),
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
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildResultContainer(String text, bool loading, Color color) {
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
              const Text("NEURAL SCENE PROCESSING", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ],
          )
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.6, fontWeight: FontWeight.w500),
            ),
          ),
    );
  }

  Widget _buildVoiceHint(Color color) {
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
              "SAY 'SCAN AGAIN' OR 'EXIT'", 
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Color color) {
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
        child: const Center(
          child: Text(
            "SCAN AGAIN",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
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
