import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'presentation/object_nav_viewmodel.dart';
import 'widgets/scan_animation.dart';
import '../assistant/presentation/assistant_viewmodel.dart';
import '../../core/services/service_providers.dart';

class ObjectDetectionScreen extends ConsumerStatefulWidget {
  final String? initialMode;
  final String? targetObject;

  const ObjectDetectionScreen({
    super.key, 
    this.initialMode, 
    this.targetObject
  });

  @override
  ConsumerState<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends ConsumerState<ObjectDetectionScreen> with SingleTickerProviderStateMixin {
  Timer? _guidanceTimer;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(objectNavViewModelProvider.notifier).init().then((_) {
        if (!mounted) return;
        
        String guidance = "Camera is ready. Double tap anywhere to take a picture.";
        if (widget.initialMode == "room") {
          guidance = "Aim your phone around the room and double tap to identify it.";
        } else if (widget.targetObject != null) {
          guidance = "Searching for ${widget.targetObject}. Aim your phone and double tap to take a picture.";
        }
        
        ref.read(ttsServiceProvider).speak(guidance);
        _startGuidanceTimer();
      });
    });
  }

  void _startGuidanceTimer() {
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        String msg = "Camera active. Aim your phone and double tap the screen to take a picture.";
        if (widget.initialMode == "room") {
          msg = "Aim your phone around the room and double tap to identify where you are.";
        }
        ref.read(ttsServiceProvider).speak(msg);
      }
    });
  }

  void _handleExit() {
    _guidanceTimer?.cancel();
    ref.read(ttsServiceProvider).speak("Exiting Smart Vision.");
    ref.read(assistantViewModelProvider.notifier).exitSubModule();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _guidanceTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(objectNavViewModelProvider);
    final viewModel = ref.read(objectNavViewModelProvider.notifier);
    const accentColor = Colors.blueAccent;

    if (!state.isInitialized || viewModel.camera == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)),
              SizedBox(height: 20),
              Text("INITIALIZING SENSORS", style: TextStyle(color: accentColor, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          if (state.status == DetectionState.scanning) return;
          _guidanceTimer?.cancel();
          // 🔥 FIXED: Passing initialMode to the capture function
          viewModel.captureAndAnalyze(
            context, 
            targetObject: widget.targetObject,
            mode: widget.initialMode
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 1 / viewModel.camera!.value.aspectRatio,
                child: CameraPreview(viewModel.camera!),
              ),
            ),

            _buildHUD(accentColor, state.status),

            if (state.status == DetectionState.scanning)
              _buildProcessingOverlay(accentColor),
            
            Semantics(
              label: "Object detection active",
              hint: "Double tap anywhere to capture",
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD(Color color, DetectionState status) {
    String modeLabel = "SCANNER MODE";
    if (widget.initialMode == "room") modeLabel = "ROOM IDENTIFIER";
    else if (widget.targetObject != null) modeLabel = "OBJECT SEARCH";

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.1,
            child: CustomPaint(painter: GridPainter()),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: _handleExit,
                ),
                _buildStatusBadge(color, status),
              ],
            ),
          ),
        ),

        AnimatedBuilder(
          animation: _scannerController,
          builder: (context, child) => Positioned(
            top: MediaQuery.of(context).size.height * 0.2 + (MediaQuery.of(context).size.height * 0.6 * _scannerController.value),
            left: 50, right: 50,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, color.withOpacity(0.5), color, color.withOpacity(0.5), Colors.transparent],
                ),
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
              ),
            ),
          ),
        ),

        _buildScannerFrame(color),

        Positioned(
          top: 100, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
              child: Text(
                widget.targetObject != null 
                  ? "FINDING: ${widget.targetObject!.toUpperCase()}" 
                  : modeLabel, 
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)
              ),
            ),
          ),
        ),

        const Positioned(
          bottom: 60,
          left: 0, right: 0,
          child: Column(
            children: [
              Icon(Icons.touch_app_rounded, color: Colors.white38, size: 24),
              SizedBox(height: 12),
              Text(
                "DOUBLE TAP TO ANALYZE",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(Color color, DetectionState status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4)]),
          ),
          const SizedBox(width: 8),
          Text(
            status == DetectionState.scanning ? "PROCESSING" : "READY", 
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2)
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFrame(Color color) {
    return IgnorePointer(
      child: Stack(
        children: [
          _buildCorner(Alignment.topLeft, color),
          _buildCorner(Alignment.topRight, color),
          _buildCorner(Alignment.bottomLeft, color),
          _buildCorner(Alignment.bottomRight, color),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment align, Color color) {
    return Align(
      alignment: align,
      child: Container(
        width: 40, height: 40,
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border(
            top: align == Alignment.topLeft || align == Alignment.topRight ? BorderSide(color: color, width: 3) : BorderSide.none,
            bottom: align == Alignment.bottomLeft || align == Alignment.bottomRight ? BorderSide(color: color, width: 3) : BorderSide.none,
            left: align == Alignment.topLeft || align == Alignment.bottomLeft ? BorderSide(color: color, width: 3) : BorderSide.none,
            right: align == Alignment.topRight || align == Alignment.bottomRight ? BorderSide(color: color, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(Color color) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 50, height: 50, child: CircularProgressIndicator(color: color, strokeWidth: 2)),
            const SizedBox(height: 30),
            Text("CAPTURING ENVIRONMENT", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 4)),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 0.3;
    const double gap = 45;
    for (double i = 0; i <= size.width; i += gap) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i <= size.height; i += gap) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
