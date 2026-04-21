import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../../assistant/presentation/assistant_viewmodel.dart';
import '../object_detection_screen.dart';

class ObjectIntroView extends ConsumerStatefulWidget {
  const ObjectIntroView({super.key});

  @override
  ConsumerState<ObjectIntroView> createState() => _ObjectIntroViewState();
}

class _ObjectIntroViewState extends ConsumerState<ObjectIntroView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _reminderTimer;
  StreamSubscription? _voskSubscription;
  bool _canListen = false;
  bool _isSpeaking = false;

  final List<String> _yoloLabels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat', 
    'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 
    'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 
    'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 
    'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 
    'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 
    'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 
    'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 
    'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];

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
    _isSpeaking = true;
    _canListen = false;
    
    // Stop mic while app is talking
    ref.read(voskServiceProvider).stop();
    _voskSubscription?.cancel();
    
    tts.onComplete(() {
      if (mounted) {
        // 🔥 Wait for echoes to die down
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _canListen = true);
            _isSpeaking = false;
            _startModeListening();
            _resetReminderTimer();
            tts.onComplete(() {}); 
          }
        });
      }
    });

    await tts.speak(
      "Smart Vision activated. Say Scan to hear everything around you, or say Find to search for a specific object. You can also say Exit to go back."
    );
  }

  void _resetReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _canListen && !_isSpeaking) {
        ref.read(ttsServiceProvider).speak("Awaiting command. Say Scan, Find, or Exit.");
        _resetReminderTimer();
      }
    });
  }

  void _startModeListening() {
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    vosk.stop();
    vosk.start();

    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_canListen || _isSpeaking) return;
      
      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      if (text.isEmpty || text.length < 3) return;

      // Ignore if it's just the app's own words echoing back
      if (text.contains("smart vision") || text.contains("activated")) return;

      if (text.contains("scan") || text.contains("around") || text.contains("everything")) {
        _navigateToDetection(mode: "scan");
      } else if (text.contains("find") || text.contains("search")) {
        _askWhichObject();
      } else if (text.contains("exit") || text.contains("back")) {
        _handleExit();
      }
    });
  }

  Future<void> _askWhichObject() async {
    setState(() {
      _canListen = false;
      _isSpeaking = true;
    });
    
    final tts = ref.read(ttsServiceProvider);
    final vosk = ref.read(voskServiceProvider);
    
    // Force mic OFF
    vosk.stop();
    _voskSubscription?.cancel();
    
    tts.onComplete(() {
      if (mounted) {
        // 🔥 Critical delay to ensure zero self-hearing
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _canListen = true);
            _isSpeaking = false;
            _listenForTargetObject();
            tts.onComplete(() {});
          }
        });
      }
    });
    await tts.speak("Which object are you looking for?");
  }

  void _listenForTargetObject() {
    final vosk = ref.read(voskServiceProvider);
    vosk.stop();
    vosk.start();
    _voskSubscription?.cancel();
    
    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted || !_canListen || _isSpeaking) return;

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      
      // Strict noise gate
      if (text.isEmpty || text.length < 3) return;
      
      // 🚫 HEURISTIC: Ignore if the recognized text is exactly what the app just said
      if (text == "which object are you looking for" || text.contains("common object")) return;

      debugPrint("Confirmed user search request: $text");

      String? matchedLabel;
      final words = text.split(" ");
      
      // 1. Precise Match
      for (var label in _yoloLabels) {
        if (words.contains(label)) {
          matchedLabel = label;
          break;
        }
      }

      // 2. Fuzzy Mapping
      if (matchedLabel == null) {
        if (text.contains("phone")) matchedLabel = "cell phone";
        else if (text.contains("table")) matchedLabel = "dining table";
        else if (text.contains("sofa")) matchedLabel = "couch";
        else if (text.contains("laptop") || text.contains("macbook")) matchedLabel = "laptop";
      }

      if (matchedLabel != null) {
        _confirmAndStart(matchedLabel);
      }
      // No 'else' auto-jump. It will stay listening until a valid label is heard.
    });
  }

  Future<void> _confirmAndStart(String label) async {
    setState(() {
      _canListen = false;
      _isSpeaking = true;
    });
    
    final tts = ref.read(ttsServiceProvider);
    ref.read(voskServiceProvider).stop();
    
    tts.onComplete(() {
      if (mounted) {
        _isSpeaking = false;
        _navigateToDetection(mode: "find", target: label);
        tts.onComplete(() {});
      }
    });
    
    await tts.speak("Okay, searching for $label. Opening camera now.");
  }

  void _navigateToDetection({required String mode, String? target}) {
    _cleanup();
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => ObjectDetectionScreen(initialMode: mode, targetObject: target))
    );
  }

  void _handleExit() {
    _cleanup();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: const Alignment(0, -0.5), radius: 1.2, colors: [Colors.blueAccent.withOpacity(0.15), Colors.transparent]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Spacer(),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                      child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1.5))),
                    ),
                    Container(padding: const EdgeInsets.all(45), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 3)), child: const Icon(Icons.remove_red_eye_rounded, size: 80, color: Colors.blueAccent)),
                  ],
                ),
                const SizedBox(height: 60),
                const Text("SMART VISION", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
                const SizedBox(height: 20),
                const Text("I can help you explore your surroundings or find specific objects.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.6)),
                const Spacer(),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () => _navigateToDetection(mode: "scan"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(0, 75), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))), child: const Text("SCAN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)))),
                    const SizedBox(width: 15),
                    Expanded(child: ElevatedButton(onPressed: _askWhichObject, style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: Colors.white, minimumSize: const Size(0, 75), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))), child: const Text("FIND", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)))),
                  ],
                ),
                const SizedBox(height: 30),
                TextButton(onPressed: _handleExit, child: const Text("GO BACK", style: TextStyle(color: Colors.white38, letterSpacing: 4, fontSize: 13, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
