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
    _scannerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

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
        Future.delayed(const Duration(milliseconds: 100), () {
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
        "Camera ready. Double tap to capture. Using $cameraName lens. Say Switch Camera to change."
      );
    } else {
      String cameraName = isBackCamera ? "back" : "front";
      await tts.speak("Starting scan with $cameraName camera.");
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

      if (_micStartTime != null && DateTime.now().difference(_micStartTime!).inMilliseconds < 200) {
        return;
      }

      final text = (data['text'] ?? "").toString().toLowerCase().trim();
      final isFinal = data['isFinal'] ?? false;
      
      if (isFinal && text.isNotEmpty) {
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
    String msg = "Using ${isBackCamera ? "back" : "front"} camera.";
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
    
    String msg = "Switched to ${isBackCamera ? "back" : "front"} camera.";
    
    tts.onComplete(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
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
    // Stop mic when leaving
    try {
      ref.read(voskServiceProvider).stop();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(colorViewModelProvider);

    ref.listen(colorViewModelProvider, (previous, next) {
      if (next.status == ColorDetectionState.success && mounted) {
        _voskSubscription?.cancel();
        // Stop mic before navigating to result screen
        ref.read(voskServiceProvider).stop();
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
            // Camera Preview
            const Positioned.fill(
              child: AndroidView(
                key: ValueKey("visionmate_camera_view"),
                viewType: "visionmate/camera_preview"
              )
            ),
            
            // Professional Overlay
            Positioned.fill(
              child: CustomPaint(
                painter: CameraOverlayPainter(
                  borderColor: Colors.cyanAccent.withOpacity(0.5),
                  isScanning: _instructionsDone
                ),
              ),
            ),

            // Scanner Animation
            if (_instructionsDone)
              Center(
                child: AnimatedBuilder(
                  animation: _scannerController,
                  builder: (context, child) {
                    return Container(
                      width: 280,
                      height: 280,
                      alignment: Alignment.topCenter,
                      child: Transform.translate(
                        offset: Offset(0, 280 * _scannerController.value),
                        child: Container(
                          height: 2,
                          width: 240,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)
                            ],
                            gradient: const LinearGradient(colors: [Colors.transparent, Colors.cyanAccent, Colors.transparent])
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const Spacer(),
                  if (_instructionsDone) _buildGuidancePanel(state.guidance),
                  const Spacer(),
                  _buildBottomControls(),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            if (state.status == ColorDetectionState.processing)
              _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(Icons.close_rounded, () => Navigator.pop(context)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lens_blur_rounded, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  isBackCamera ? "BACK LENS" : "FRONT LENS",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ],
            ),
          ),
          _buildCircleButton(Icons.flip_camera_ios_rounded, _switchCamera),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24)
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidancePanel(String guidance) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Text(
        guidance.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseController,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.touch_app_rounded, color: Colors.white54, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "DOUBLE TAP TO CAPTURE",
          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black87,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
                const SizedBox(height: 20),
                Text("ANALYZING COLOR...", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CameraOverlayPainter extends CustomPainter {
  final Color borderColor;
  final bool isScanning;
  CameraOverlayPainter({required this.borderColor, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final center = Offset(size.width / 2, size.height / 2);
    const rectSize = 280.0;
    final holeRect = Rect.fromCenter(center: center, width: rectSize, height: rectSize);
    
    // Outer overlay
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(holeRect, const Radius.circular(30))),
      ),
      paint,
    );

    // Corner Borders
    final borderPaint = Paint()
      ..color = isScanning ? Colors.cyanAccent : Colors.white24
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 40.0;
    final rrect = RRect.fromRectAndRadius(holeRect, const Radius.circular(30));
    
    // Top Left
    canvas.drawPath(Path()..moveTo(rrect.left, rrect.top + cornerLength)..lineTo(rrect.left, rrect.top)..lineTo(rrect.left + cornerLength, rrect.top), borderPaint);
    // Top Right
    canvas.drawPath(Path()..moveTo(rrect.right - cornerLength, rrect.top)..lineTo(rrect.right, rrect.top)..lineTo(rrect.right, rrect.top + cornerLength), borderPaint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(rrect.left, rrect.bottom - cornerLength)..lineTo(rrect.left, rrect.bottom)..lineTo(rrect.left + cornerLength, rrect.bottom), borderPaint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(rrect.right - cornerLength, rrect.bottom)..lineTo(rrect.right, rrect.bottom)..lineTo(rrect.right, rrect.bottom - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
