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

  const ObjectResultView({
    super.key, 
    required this.imagePath, 
    this.targetObject,
  });

  @override
  ConsumerState<ObjectResultView> createState() => _ObjectResultViewState();
}

class _ObjectResultViewState extends ConsumerState<ObjectResultView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _waitReminderTimer;
  StreamSubscription? _voskSubscription;
  bool _isAnalyzing = true;
  bool _canListen = false;
  String _resultText = "Analyzing surroundings...";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.microtask(() => _runBackgroundAnalysis());
  }

  Future<void> _runBackgroundAnalysis() async {
    final tts = ref.read(ttsServiceProvider);
    
    // 1. Immediate feedback to avoid silence
    await tts.speak("Image captured. Analyzing surroundings, please wait.");

    // 2. Start a safety timer for long processing
    _waitReminderTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isAnalyzing) {
        tts.speak("Still working, just a moment.");
      }
    });

    final detector = ObjectDetectorService();
    final result = await detector.analyzeScene(XFile(widget.imagePath));
    
    _waitReminderTimer?.cancel();

    String speech;
    if (widget.targetObject != null) {
      final found = result.objects.where((o) => o.label.toLowerCase() == widget.targetObject!.toLowerCase()).toList();
      speech = found.isNotEmpty 
        ? "Yes, I found a ${widget.targetObject} ${found.first.proximity}." 
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
        tts.onComplete(() {
          if (mounted) {
            setState(() => _canListen = true);
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
      
      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      if (text.isNotEmpty) {
        if (text.contains("scan") || text.contains("again") || text.contains("try")) {
          _handleRescan();
        } else if (text.contains("exit") || text.contains("back")) {
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
        initialMode: widget.targetObject != null ? "find" : "scan",
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: Alignment.center, radius: 1.5, colors: [Colors.blueAccent.withOpacity(0.05), Colors.transparent]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeaderBadge(_isAnalyzing),
                  const SizedBox(height: 30),
                  _buildImagePreview(),
                  const SizedBox(height: 30),
                  Expanded(child: _buildResultContainer(_resultText, _isAnalyzing)),
                  const SizedBox(height: 20),
                  if (_canListen) _buildVoiceIndicator(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleRescan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 65),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                    child: const Text("SCAN AGAIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        loading ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)) : const Icon(Icons.check_circle_outline, color: Colors.blueAccent, size: 14),
        const SizedBox(width: 10),
        Text(loading ? "ANALYZING SCENE..." : "ANALYSIS COMPLETE", style: const TextStyle(color: Colors.white54, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 10)),
      ]),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 220, width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.file(File(widget.imagePath), fit: BoxFit.cover)),
    );
  }

  Widget _buildResultContainer(String text, bool loading) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: SingleChildScrollView(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5))),
    );
  }

  Widget _buildVoiceIndicator() {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.blueAccent.withOpacity(0.2))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.mic_rounded, color: Colors.blueAccent, size: 18),
          const SizedBox(width: 10),
          Text("SAY 'SCAN AGAIN' OR 'EXIT'", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ),
    );
  }
}
