import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  WALKTHROUGH DATA MODEL
// ─────────────────────────────────────────────────────────────

class _WalkthroughStep {
  final IconData icon;
  final String heading;
  final String sub;
  final Color accentColor;
  final String body;
  final List<_GestureHint> gestures;

  const _WalkthroughStep({
    required this.icon,
    required this.heading,
    required this.sub,
    required this.accentColor,
    required this.body,
    this.gestures = const [],
  });
}

class _GestureHint {
  final String key;
  final String desc;
  const _GestureHint(this.key, this.desc);
}

const List<_WalkthroughStep> _steps = [
  _WalkthroughStep(
    icon: Icons.remove_red_eye_outlined,
    heading: "Vision Mate",
    sub: "Your AI Companion",
    accentColor: Color(0xFF00FFF0),
    body:
        "Vision Mate is your voice-powered AI assistant — always listening, always ready. It works in the background and responds to your natural speech, tap gestures, and hardware keys.",
  ),
  _WalkthroughStep(
    icon: Icons.mic_none_rounded,
    heading: "Wake & Sleep",
    sub: "Voice Activation",
    accentColor: Color(0xFF00B4FF),
    body:
        'Speak naturally to activate your assistant. A gentle swipe down puts it to sleep when you need quiet. The orb glows cyan when active and dims to purple in standby.',
    gestures: [
      _GestureHint('SAY "HELLO"', 'Wake the assistant'),
      _GestureHint('SWIPE DOWN', 'Enter sleep / standby'),
    ],
  ),
  _WalkthroughStep(
    icon: Icons.touch_app_outlined,
    heading: "Tap Controls",
    sub: "Gesture Language",
    accentColor: Color(0xFF7850FF),
    body:
        "Single and double taps perform instant actions without saying a word. Learn these shortcuts to navigate at lightning speed.",
    gestures: [
      _GestureHint('1 TAP', 'Check the time'),
      _GestureHint('2 TAPS', 'Check battery level'),
      _GestureHint('3 TAPS', 'Read current date'),
    ],
  ),
  _WalkthroughStep(
    icon: Icons.emergency_share_rounded,
    heading: "Emergency SOS",
    sub: "Safety First",
    accentColor: Color(0xFFFF5050),
    body:
        "Your safety is our top priority. In any emergency, a quick double-press of your headphone button or saying SOS activates emergency mode and contacts your saved numbers.",
    gestures: [
      _GestureHint('"SOS"', 'Trigger emergency alert'),
      _GestureHint('2× PRESS', 'Headphone button shortcut'),
      _GestureHint('"CONTACTS"', 'Set up emergency contacts'),
    ],
  ),
  _WalkthroughStep(
    icon: Icons.camera_enhance_outlined,
    heading: "Camera Vision",
    sub: "See The World",
    accentColor: Color(0xFF00FF8C),
    body:
        'Say "look around" or "what\'s in front of me" to activate the camera scanner. Vision Mate will analyse your surroundings and describe them in real time.',
    gestures: [
      _GestureHint('"LOOK"', 'Activate camera mode'),
      _GestureHint('"DESCRIBE"', 'Analyse the scene'),
      _GestureHint('1 TAP', 'Exit camera view'),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────
//  WALKTHROUGH SCREEN  (standalone, pushed as a full route)
// ─────────────────────────────────────────────────────────────

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen>
    with TickerProviderStateMixin {
  int _cur = 0;

  late AnimationController _orbSpin;
  late AnimationController _orbPulse;
  late AnimationController _bgGlow;
  late AnimationController _cardFade;

  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();

    _orbSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _orbPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _bgGlow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _cardFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();

    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardFade, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardFade, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _orbSpin.dispose();
    _orbPulse.dispose();
    _bgGlow.dispose();
    _cardFade.dispose();
    super.dispose();
  }

  void _go(int dir) {
    final next = _cur + dir;
    if (next < 0 || next > _steps.length) return;
    if (next == _steps.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _cur = next);
    _cardFade.forward(from: 0);
  }

  void _jumpTo(int i) {
    if (i == _cur) return;
    setState(() => _cur = i);
    _cardFade.forward(from: 0);
  }

  // ── helpers ──────────────────────────────────────────────

  Color get _accent => _steps[_cur].accentColor;

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      body: Stack(
        children: [
          _buildGridLines(),
          _buildBgGlow(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 40), // Increased to compensate for removed progress
                _buildOrb(),
                const SizedBox(height: 40),
                Expanded(child: _buildCard()),
                const SizedBox(height: 20),
                _buildNavRow(),
                const SizedBox(height: 12),
                _buildSkipBtn(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── background ────────────────────────────────────────────

  Widget _buildGridLines() {
    return Positioned.fill(
      child: CustomPaint(painter: _GridPainter()),
    );
  }

  Widget _buildBgGlow() {
    return AnimatedBuilder(
      animation: _bgGlow,
      builder: (_, __) => Positioned(
        top: -60,
        left: 0,
        right: 0,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accent.withOpacity(0.07 + 0.04 * _bgGlow.value),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "VISIONMATE  ·  SYSTEM",
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 5,
                  color: Colors.white24,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                  children: [
                    const TextSpan(
                      text: "USER ",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: "GUIDE",
                      style: TextStyle(color: _accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _accent.withOpacity(0.25)),
            ),
            child: Text(
              "GETTING STARTED",
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── orb ───────────────────────────────────────────────────

  Widget _buildOrb() {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbSpin, _orbPulse]),
      builder: (_, __) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // outer ring
              _ring(110, _accent.withOpacity(0.12 + 0.06 * _orbPulse.value),
                  _orbSpin.value * 360),
              // middle ring
              _ring(
                  88,
                  _accent.withOpacity(0.08 + 0.04 * _orbPulse.value),
                  -_orbSpin.value * 360),
              // core gradient disc
              Transform.rotate(
                angle: _orbSpin.value * 2 * 3.14159,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _accent,
                        const Color(0xFF0088FF),
                        const Color(0xFF6600FF),
                        _accent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(
                            0.3 + 0.15 * _orbPulse.value),
                        blurRadius: 28 + 14 * _orbPulse.value,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // inner black disc + icon
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF05050A),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _steps[_cur].icon,
                      key: ValueKey(_cur),
                      size: 24,
                      color: _accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double size, Color color, double degrees) {
    return Transform.rotate(
      angle: degrees * 3.14159 / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1),
        ),
      ),
    );
  }

  // ── card ──────────────────────────────────────────────────

  Widget _buildCard() {
    final step = _steps[_cur];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeTransition(
        opacity: _cardOpacity,
        child: SlideTransition(
          position: _cardSlide,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _accent.withOpacity(0.15),
              ),
            ),
            child: Stack(
              children: [
                // top shimmer line
                Positioned(
                  top: 0,
                  left: 40,
                  right: 40,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _accent.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // accent blob
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withOpacity(0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      // icon + heading
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _accent.withOpacity(0.18),
                              ),
                            ),
                            child: Icon(step.icon,
                                size: 26, color: _accent),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.heading.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                step.sub.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2.5,
                                  color: _accent.withOpacity(0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // body
                      Text(
                        step.body,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.7,
                          color: Colors.white.withOpacity(0.52),
                        ),
                      ),
                      if (step.gestures.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...step.gestures.map(_buildGestureRow),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureRow(_GestureHint g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Text(
              g.key,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: _accent,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              g.desc,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withOpacity(0.48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── nav ───────────────────────────────────────────────────

  Widget _buildNavRow() {
    final isLast = _cur == _steps.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (_cur > 0) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => _go(-1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Center(
                    child: Text(
                      "← BACK",
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => _go(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: _accent.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isLast ? "GET STARTED ↗" : "NEXT →",
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipBtn() {
    if (_cur == _steps.length - 1) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Text(
        "SKIP GUIDE",
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 3,
          color: Colors.white.withOpacity(0.15),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  GRID PAINTER  (subtle background lines)
// ─────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFF0).withOpacity(0.025)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
