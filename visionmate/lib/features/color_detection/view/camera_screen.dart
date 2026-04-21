import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_providers.dart';
import '../viewmodel/color_viewmodel.dart';
import 'result_screen.dart';

class ColorCameraScreen extends ConsumerStatefulWidget {
  final bool showIntro;
  const ColorCameraScreen({super.key, this.showIntro = true});

  @override
  ConsumerState<ColorCameraScreen> createState() => _ColorCameraScreenState();
}

class _ColorCameraScreenState extends ConsumerState<ColorCameraScreen> with TickerProviderStateMixin {
  late AnimationController _scannerController;
  late AnimationController _pulseController;
  bool isBackCamera = true;
  StreamSubscription? _voskSubscription;
  bool _instructionsDone = false;
  bool _isSwitching = false;
  DateTime? _micStartTime;

  @override
  void initState() {
    super.initState();
    _instructionsDone = !widget.showIntro;
    _scannerController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    Future.microtask(() => _initCameraFlow());
  }

  Future<void> _initCameraFlow() async {
    if (!mounted) return;
    final tts = ref.read(ttsServiceProvider);
    final viewModel = ref.read(colorViewModelProvider.notifier);
    
    viewModel.reset();
    viewModel.enableGuidance(false);

    try {
      const channel = MethodChannel('visionmate/camera');
      isBackCamera = await channel.invokeMethod<bool>('isBackCamera') ?? true;
    } catch (e) {
      debugPrint("Camera state sync failed: $e");
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    await viewModel.startScanning();

    tts.onComplete(() {
      if (mounted) {
        // High delay to ensure room is quiet
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() => _instructionsDone = true);
            viewModel.enableGuidance(true);
            _startVoiceCommands();
          }
        });
        tts.onComplete(() {}); 
      }
    });

    if (widget.showIntro) {
      String cameraName = isBackCamera ? "back" : "front";
      await tts.speak(
        "Camera is ready. Double tap to take a picture. You are using the $cameraName lens. To change it, say: Switch Camera."
      );
    } else {
      String cameraName = isBackCamera ? "back" : "front";
      await tts.speak("Starting new scan with $cameraName camera.");
    }
  }

  void _startVoiceCommands() {
    if (!mounted) return;
    _voskSubscription?.cancel();
    final vosk = ref.read(voskServiceProvider);
    
    vosk.stop();
    vosk.start(); 
    _micStartTime = DateTime.now();

    _voskSubscription = vosk.speechStream.listen((data) {
      if (!mounted) return;

      // Ignore noise within 2s of starting
      if (_micStartTime != null && DateTime.now().difference(_micStartTime!).inMilliseconds < 2000) {
        return;
      }

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
        debugPrint("Color Camera Mic: $text");
        
        if (text.contains("which camera") || text.contains("check camera")) {
          _announceCameraState();
        }
        else if (text.contains("switch camera") || text.contains("change camera")) {
          _switchCamera();
        } 
        else if (text == "capture" || text == "take photo" || text == "lelo") {
          ref.read(colorViewModelProvider.notifier).capture();
        }
      }
    });
  }

  void _announceCameraState() {
    String msg = "You are currently using the ${isBackCamera ? "back" : "front"} camera.";
    ref.read(ttsServiceProvider).speak(msg);
  }

  void _switchCamera() async {
    if (_isSwitching || !mounted) return;
    _isSwitching = true;

    final tts = ref.read(ttsServiceProvider);
    final viewModel = ref.read(colorViewModelProvider.notifier);
    
    viewModel.enableGuidance(false);
    
    setState(() => isBackCamera = !isBackCamera);
    await ref.read(cameraServiceProvider).switchCamera();
    
    String msg = "Using ${isBackCamera ? "back" : "front"} camera now.";
    
    tts.onComplete(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            viewModel.enableGuidance(true);
            _isSwitching = false;
            _startVoiceCommands(); 
          }
        });
        tts.onComplete(() {});
      }
    });

    await tts.speak(msg);
  }

  @override
  void dispose() {
    _voskSubscription?.cancel();
    _scannerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(colorViewModelProvider);

    ref.listen(colorViewModelProvider, (previous, next) {
      if (next.status == ColorDetectionState.success && mounted) {
        _voskSubscription?.cancel();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ColorResultScreen()));
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onDoubleTap: () {
          if (state.status != ColorDetectionState.processing) {
            ref.read(colorViewModelProvider.notifier).capture();
          }
        },
        child: Stack(
          children: [
            const Positioned.fill(
              child: AndroidView(
                key: ValueKey("visionmate_camera_view"),
                viewType: "visionmate/camera_preview"
              )
            ),
            
            Positioned.fill(
              child: CustomPaint(
                painter: SpotlightPainter(opacity: _instructionsDone ? 0.6 : 0.3),
              ),
            ),

            Center(
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: _instructionsDone ? 0.4 : 0.1), width: 1),
                ),
                child: Stack(
                  children: [
                    _buildCorner(top: 0, left: 0), _buildCorner(top: 0, right: 0),
                    _buildCorner(bottom: 0, left: 0), _buildCorner(bottom: 0, right: 0),
                    if (_instructionsDone)
                      AnimatedBuilder(
                        animation: _scannerController,
                        builder: (context, child) => Positioned(
                          top: 280 * _scannerController.value, left: 30, right: 30,
                          child: Container(height: 2, decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.6), blurRadius: 15, spreadRadius: 2)], gradient: const LinearGradient(colors: [Colors.transparent, Colors.cyanAccent, Colors.transparent]))),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTopBar(),
                  const SizedBox(height: 30),
                  if (_instructionsDone) _buildGuidanceBox(state.guidance),
                  const Spacer(),
                  _buildCaptureHint(),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            if (state.status == ColorDetectionState.processing)
              Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.8), child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)))),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassButton(icon: Icons.arrow_back_ios_new_rounded, onPressed: () => Navigator.pop(context)),
          _buildGlassButton(icon: isBackCamera ? Icons.camera_rear_rounded : Icons.camera_front_rounded, onPressed: _switchCamera, color: Colors.cyanAccent),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onPressed, Color color = Colors.white}) {
    return ClipRRect(borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: Colors.white.withValues(alpha: 0.05), child: IconButton(onPressed: onPressed, icon: Icon(icon, color: color, size: 20))),
      ),
    );
  }

  Widget _buildCorner({double? top, double? left, double? right, double? bottom}) {
    return Positioned(top: top, left: left, right: right, bottom: bottom,
      child: Container(width: 35, height: 35, decoration: BoxDecoration(border: Border(top: top != null ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none, bottom: bottom != null ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none, left: left != null ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none, right: right != null ? const BorderSide(color: Colors.cyanAccent, width: 4) : BorderSide.none))),
    );
  }

  Widget _buildGuidanceBox(String guidance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Text(guidance.toUpperCase(), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 10)),
    );
  }

  Widget _buildCaptureHint() {
    return Column(
      children: [
        ScaleTransition(scale: _pulseController, child: Icon(Icons.touch_app_rounded, color: Colors.white.withValues(alpha: 0.3), size: 30)),
        const SizedBox(height: 10),
        Text("DOUBLE TAP TO CAPTURE", style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final double opacity;
  SpotlightPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: opacity);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    final holeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2), 
      width: 280, 
      height: 280,
    );
    final holeRRect = RRect.fromRectAndRadius(holeRect, const Radius.circular(40));

    canvas.drawPath(
      Path.combine(
        PathOperation.difference, 
        Path()..addRect(rect), 
        Path()..addRRect(holeRRect),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) => oldDelegate.opacity != opacity;
}
