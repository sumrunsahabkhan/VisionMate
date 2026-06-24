import 'dart:async';
import 'dart:ui';
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

class _ObjectIntroViewState extends ConsumerState<ObjectIntroView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
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

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    Future.microtask(() => _startIntroSequence());
  }

  Future<void> _startIntroSequence() async {
    final tts = ref.read(ttsServiceProvider);
    _isSpeaking = true;
    _canListen = false;
    
    ref.read(voskServiceProvider).stop();
    _voskSubscription?.cancel();
    
    tts.onComplete(() {
      if (mounted) {
        // 🔥 Reduced delay to be more responsive
        Future.delayed(const Duration(milliseconds: 200), () {
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
      "Smart Vision activated. Say Scan to hear everything around you, Find to search for an object, or Room to identify your location. You can also say Exit to go back."
    );
  }

  void _resetReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _canListen && !_isSpeaking) {
        final tts = ref.read(ttsServiceProvider);
        final vosk = ref.read(voskServiceProvider);
        
        // 🔥 STOP listening before reminder to avoid false positives
        vosk.stop();
        _isSpeaking = true;

        tts.onComplete(() {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                _isSpeaking = false;
                vosk.start(); // Restart listening
                _resetReminderTimer();
                tts.onComplete(() {});
              }
            });
          }
        });
        
        tts.speak("Awaiting command. Say Scan, Find, Room, or Exit.");
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

      if (text.contains("smart vision") || text.contains("activated")) return;

      if (text.contains("scan") || text.contains("around") || text.contains("everything")) {
        _navigateToDetection(mode: "scan");
      } else if (text.contains("find") || text.contains("search")) {
        _askWhichObject();
      } else if (text.contains("room") || text.contains("location") || text.contains("jagah") || text.contains("kahan")) {
        _navigateToDetection(mode: "room");
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
    
    vosk.stop();
    _voskSubscription?.cancel();
    
    tts.onComplete(() {
      if (mounted) {
        // 🔥 Faster response
        Future.delayed(const Duration(milliseconds: 200), () {
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
      if (text.isEmpty || text.length < 3) return;
      if (text == "which object are you looking for" || text.contains("common object")) return;

      String? matchedLabel;
      final words = text.split(" ");
      
      for (var label in _yoloLabels) {
        if (words.contains(label)) {
          matchedLabel = label;
          break;
        }
      }

      if (matchedLabel == null) {
        if (text.contains("phone")) matchedLabel = "cell phone";
        else if (text.contains("table")) matchedLabel = "dining table";
        else if (text.contains("sofa")) matchedLabel = "couch";
        else if (text.contains("laptop") || text.contains("macbook")) matchedLabel = "laptop";
      }

      if (matchedLabel != null) {
        _confirmAndStart(matchedLabel);
      }
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
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Colors.blueAccent;

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
                    center: Alignment.center,
                    radius: 1.5 + (_pulseController.value * 0.2),
                    colors: [accentColor.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(accentColor),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          _buildCentralVisual(accentColor),
                          const SizedBox(height: 30),
                          _buildStatusInfo(accentColor),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButtons(accentColor),
                      const SizedBox(height: 5),
                      _buildBackButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "VISION ENGINE",
                style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 5),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30, height: 2,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.online_prediction_rounded, size: 12, color: Colors.blueAccent),
                const SizedBox(width: 5),
                Text("READY", style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralVisual(Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 170, height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.1), width: 1),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0, left: 85,
                  child: Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 6)]),
                  ),
                ),
              ],
            ),
          ),
        ),
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
          child: Container(
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF05050A),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 30)],
            ),
            child: Icon(Icons.remove_red_eye_rounded, size: 60, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(Color color) {
    return Column(
      children: [
        const Text(
          "SMART VISION",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        const Text(
          "I can help you explore your surroundings or identify your room.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6, letterSpacing: 0.5),
        ),
        if (_canListen) ...[
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_rounded, size: 14, color: color),
                const SizedBox(width: 10),
                const Text(
                  "SAY 'SCAN' OR 'ROOM'",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(Color color) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _customButton(
                "SCAN", 
                Icons.explore_rounded, 
                color, 
                true, 
                () => _navigateToDetection(mode: "scan")
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _customButton(
                "FIND", 
                Icons.search_rounded, 
                Colors.white.withOpacity(0.05), 
                false, 
                _askWhichObject
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _customButton(
          "IDENTIFY ROOM", 
          Icons.home_work_rounded, 
          Colors.white.withOpacity(0.05), 
          false, 
          () => _navigateToDetection(mode: "room"),
          isFullWidth: true
        ),
      ],
    );
  }

  Widget _customButton(String label, IconData icon, Color color, bool filled, VoidCallback onTap, {bool isFullWidth = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        width: isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: filled ? Colors.transparent : Colors.white10),
          boxShadow: filled ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton(
      onPressed: _handleExit,
      style: TextButton.styleFrom(foregroundColor: Colors.white24),
      child: const Text(
        "GO BACK",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4),
      ),
    );
  }
}
