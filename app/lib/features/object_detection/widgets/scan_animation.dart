import 'package:flutter/material.dart';

class ScanAnimation extends StatefulWidget {
  final bool isScanning;
  const ScanAnimation({super.key, required this.isScanning});

  @override
  State<ScanAnimation> createState() => _ScanAnimationState();
}

class _ScanAnimationState extends State<ScanAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.isScanning) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ScanAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (!widget.isScanning && _controller.isDismissed) return const SizedBox.shrink();
        
        return Stack(
          children: [
            // Darken overlay
            if (widget.isScanning)
              Container(color: Colors.black.withAlpha(77)),
            
            // Scanning Line
            Positioned(
              top: MediaQuery.of(context).size.height * _animation.value,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: widget.isScanning ? 1.0 : 0.0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withAlpha(128),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
