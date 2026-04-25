import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'assistant_viewmodel.dart';
import '../../voice/intent.dart';
import '../../../core/services/connectivity_service.dart';
import '../../settings/data/settings_repository.dart';

class AssistantView extends ConsumerStatefulWidget {
  const AssistantView({super.key});

  @override
  ConsumerState<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends ConsumerState<AssistantView> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _orbController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _scannerController;
  late AnimationController _orbitRotationController;
  late AnimationController _onlineProcessingController;
  
  Timer? _tapTimer;
  int _tapCount = 0;
  int _lastMusicButtonPress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    
    _orbController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _scannerController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _orbitRotationController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _onlineProcessingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();

    Future.microtask(() {
      final notifier = ref.read(assistantViewModelProvider.notifier);
      notifier.setNavigationContext(context);
      notifier.init();
    });
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause || 
          event.logicalKey == LogicalKeyboardKey.mediaTrackNext ||
          event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastMusicButtonPress < 600) {
          ref.read(assistantViewModelProvider.notifier).handleIntent(VoiceIntent.sos, "sos");
        }
        _lastMusicButtonPress = now;
        return true;
      }
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(assistantViewModelProvider.notifier).resumeAssistant();
    } else if (state == AppLifecycleState.paused) {
      ref.read(assistantViewModelProvider.notifier).pauseAssistant();
    }
  }

  void _handleTapSequence() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(assistantViewModelProvider.notifier).handleTap(_tapCount);
        _tapCount = 0;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _orbController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _scannerController.dispose();
    _orbitRotationController.dispose();
    _onlineProcessingController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantViewModelProvider);

    if (state.isModelLoading) {
      return _buildLoadingScreen();
    }

    final isCamMode = state.view == AssistantUIState.camera;
    final themeColor = _getThemeColor(state);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTapSequence,
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 10) {
          ref.read(assistantViewModelProvider.notifier).handleIntent(VoiceIntent.sleep, "sleep");
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05050A),
        body: Stack(
          children: [
            _buildBackgroundGlow(themeColor, state.awake),

            if (isCamMode)
              const Positioned.fill(
                child: AndroidView(viewType: "visionmate/camera_preview"),
              ),
            
            if (isCamMode) _buildCameraOverlay(themeColor),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(state, themeColor),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: _buildMainArea(state, themeColor),
                          ),
                        ),
                      ),
                    ),
                    _buildTranscriptArea(state.currentText, themeColor, state.isSOSActive),
                    const SizedBox(height: 20),
                    _buildDynamicControlCenter(state, themeColor),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getThemeColor(AssistantState state) {
    if (state.isSOSActive) return Colors.redAccent;
    if (state.view == AssistantUIState.camera) return Colors.cyanAccent;
    if (state.isWalkthroughActive) return Colors.deepPurpleAccent;
    if (state.awake) return Colors.cyanAccent; 
    return Colors.deepPurple;
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF05050A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50, height: 50,
              child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 1.5),
            ),
            SizedBox(height: 40),
            Text(
              "NEURAL ENGINE INITIALIZING", 
              style: TextStyle(color: Colors.cyanAccent, letterSpacing: 5, fontSize: 9, fontWeight: FontWeight.w800)
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow(Color color, bool active) {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withOpacity(active ? 0.15 : 0.08),
              Colors.transparent
            ],
            radius: 1.5 + (_orbController.value * 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AssistantState state, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "VISION MATE", 
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 5, color: Colors.white24)
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 2, width: state.awake || state.isWalkthroughActive ? 40 : 12,
              decoration: BoxDecoration(
                color: color,
                boxShadow: [if (state.awake) BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
              ),
            ),
          ],
        ),
        _buildStatusBadge(state, color),
      ],
    );
  }

  Widget _buildStatusBadge(AssistantState state, Color color) {
    String label = state.isSOSActive ? "SOS" : (state.isWalkthroughActive ? "GUIDE" : (state.view == AssistantUIState.camera ? "VISION" : (state.awake ? "ONLINE" : "STANDBY")));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.connectivity == ConnectionStatus.offline)
            const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.wifi_off, size: 10, color: Colors.redAccent)),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2, color: color)),
        ],
      ),
    );
  }

  Widget _buildMainArea(AssistantState state, Color color) {
    if (state.isSOSActive) return _buildSOSDashboard(state, color);
    if (state.view == AssistantUIState.sleep) return _buildPulseVisual(Icons.nights_stay_rounded, color.withOpacity(0.3));
    if (state.isWalkthroughActive) return _buildWalkthroughStage(state, color);
    if (state.view == AssistantUIState.manual) return _buildSafetyVisual(state, color);
    if (state.view == AssistantUIState.settings) return _buildSettingsDashboard(color);
    if (state.isOnlineWaiting) return _buildOnlineProcessingVisual(color);
    if (state.view == AssistantUIState.camera) return const SizedBox.shrink();
    
    return _buildCentralCore(color, state.awake, state.isSpeaking);
  }

  Widget _buildSOSDashboard(AssistantState state, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            _buildRipple(1.0, color.withOpacity(0.1)),
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.1).animate(_pulseController),
              child: Container(
                height: 90, width: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color, width: 2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20)],
                ),
                child: Center(child: Icon(Icons.warning_rounded, size: 44, color: color)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text("EMERGENCY SYSTEM ACTIVE", style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 10)),
        const SizedBox(height: 8),
        Text("AWAITING YOUR RESPONSE", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 8)),
        if (state.isWaitingForSOSAnythingElse) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_rounded, size: 14, color: color),
                const SizedBox(width: 10),
                const Text("LISTENING...", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildOnlineProcessingVisual(Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120, height: 120,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.3)),
                strokeWidth: 2,
              ),
            ),
            Icon(Icons.cloud_sync_rounded, size: 40, color: color),
          ],
        ),
        const SizedBox(height: 32)
      ],
    );
  }

  Widget _buildWalkthroughStage(AssistantState state, Color color) {
    IconData icon = Icons.auto_awesome_rounded;
    String actionHint = "LEARNING...";

    if (state.walkthroughStep <= 2) { icon = Icons.touch_app_rounded; actionHint = "TAP 3 TIMES"; }
    else if (state.walkthroughStep <= 4) { icon = Icons.record_voice_over_rounded; actionHint = "SAY 'HELLO'"; }
    else if (state.walkthroughStep <= 6) { icon = Icons.touch_app_outlined; actionHint = "TAP ONCE"; }
    else if (state.walkthroughStep <= 8) { icon = Icons.swipe_down_rounded; actionHint = "SWIPE DOWN"; }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
             _buildRipple(1.2, color.withOpacity(0.05)),
             Container(
               width: 100, height: 100,
               decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.4), width: 2)),
               child: ScaleTransition(
                 scale: Tween(begin: 0.9, end: 1.1).animate(_pulseController),
                 child: Icon(icon, size: 40, color: color),
               ),
             ),
          ],
        ),
        const SizedBox(height: 32),
        if (state.isWaitingForAction)
          Text(actionHint, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 10)),
      ],
    );
  }

  Widget _buildPulseVisual(IconData icon, Color color) {
    return ScaleTransition(
      scale: Tween(begin: 0.95, end: 1.05).animate(_pulseController),
      child: Column(
        children: [
          Icon(icon, size: 70, color: color),
          const SizedBox(height: 20),
          Text("SYSTEM ACTIVE", style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildCentralCore(Color color, bool awake, bool isSpeaking) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (awake) _buildRipple(1.2, color.withOpacity(0.05)),
        RotationTransition(
          turns: _orbitRotationController,
          child: Container(
            height: 190, width: 190,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(awake ? 0.08 : 0.02))),
            child: Stack(children: [Positioned(top: 15, left: 95, child: _orbitDot(color, 6, awake))]),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 110, width: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF05050A),
            border: Border.all(color: color.withOpacity(awake ? 0.8 : 0.15), width: 2),
            boxShadow: [if (awake) BoxShadow(color: color.withOpacity(0.4), blurRadius: 20 + (_orbController.value * 10))],
          ),
          child: Center(
            child: Icon(isSpeaking || awake ? Icons.graphic_eq_rounded : Icons.mic_none_rounded, size: 40, color: awake ? Colors.white : Colors.white12),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsDashboard(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 70, width: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15)],
          ),
          child: Center(child: Icon(Icons.settings_suggest_rounded, size: 28, color: color)),
        ),
        const SizedBox(height: 24),
        Text("NEURAL CALIBRATION", style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 9)),
        const SizedBox(height: 24),
        _buildSettingsHUD(color),
      ],
    );
  }

  Widget _orbitDot(Color color, double size, bool awake) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(awake ? 0.8 : 0.2),
        boxShadow: [if (awake) BoxShadow(color: color, blurRadius: 4)],
      ),
    );
  }

  Widget _buildRipple(double scale, Color color) {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) => Transform.scale(
        scale: scale + (_orbController.value * 0.1),
        child: Container(
          height: 150, width: 150,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildSafetyVisual(AssistantState state, Color color) {
    final settings = ref.watch(settingsRepositoryProvider);
    
    // Priority Logic: Show temp values during setup, else saved ones
    final pName = (state.isSettingUpEmergency && state.tempPName.isNotEmpty) ? state.tempPName : settings.primaryContactName;
    final pNum = (state.isSettingUpEmergency && state.tempPNum.isNotEmpty) ? state.tempPNum : settings.primaryContactNumber;
    
    final sName = (state.isSettingUpEmergency && state.tempSName.isNotEmpty) ? state.tempSName : settings.secondaryContactName;
    final sNum = (state.isSettingUpEmergency && state.tempSNum.isNotEmpty) ? state.tempSNum : settings.secondaryContactNumber;

    return Column(
      children: [
        Icon(Icons.shield_rounded, size: 60, color: color),
        const SizedBox(height: 20),
        Text(state.isSettingUpEmergency ? "SECURITY CONFIGURATION" : "EMERGENCY CONTACTS", style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 9)),
        const SizedBox(height: 24),
        _buildContactCard("PRIMARY", pName, pNum, pNum.isNotEmpty, color),
        const SizedBox(height: 12),
        _buildContactCard("SECONDARY", sName, sNum, sNum.isNotEmpty, color),
      ],
    );
  }

  Widget _buildContactCard(String label, String name, String number, bool active, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(active ? 0.06 : 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color.withOpacity(0.3) : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.verified_user_rounded : Icons.person_outline_rounded, size: 20, color: active ? color : Colors.white12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: active ? color : Colors.white12, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 2)),
                Text(active ? name.toUpperCase() : "NO CONTACT", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (active) Icon(Icons.check_circle_outline_rounded, size: 16, color: color.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildTranscriptArea(String text, Color color, bool isSOS) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: text.isEmpty ? 0 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: isSOS ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 10, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildDynamicControlCenter(AssistantState state, Color color) {
    return AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: _getControlContent(state, color));
  }

  Widget _getControlContent(AssistantState state, Color color) {
    if (state.isWalkthroughActive) return _buildWalkthroughInfo(state, color);
    switch (state.view) {
      case AssistantUIState.time: return _buildLargeStatus(DateFormat('h:mm').format(DateTime.now()), DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(), color);
      case AssistantUIState.battery: return _buildLargeStatus("${state.batteryLevel}%", state.isCharging ? "CHARGING" : "SYSTEM POWER", color);
      case AssistantUIState.date: return _buildLargeStatus(DateFormat('dd').format(DateTime.now()), DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(), color);
      case AssistantUIState.settings: return const SizedBox.shrink();
      default: return _buildDefaultStatus(state, color);
    }
  }

  Widget _buildDefaultStatus(AssistantState state, Color color) {
    if (state.currentText.toLowerCase().contains("weather")) return _buildWeatherInfo(color);
    if (state.currentText.toLowerCase().contains("news")) return _buildNewsInfo(color);
    return Column(
      children: [
        const Text("SAY 'HELLO'", style: TextStyle(color: Colors.white12, letterSpacing: 8, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        _buildGuideButton(color),
      ],
    );
  }

  Widget _buildWeatherInfo(Color color) {
    return Column(key: const ValueKey("weather_info"), children: [Icon(Icons.wb_sunny_rounded, color: color, size: 36), const SizedBox(height: 12), const Text("METEO SERVICES", style: TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 3, fontWeight: FontWeight.bold))]);
  }

  Widget _buildNewsInfo(Color color) {
    return Column(key: const ValueKey("news_info"), children: [Icon(Icons.newspaper_rounded, color: color, size: 36), const SizedBox(height: 12), const Text("GLOBAL HEADLINES", style: TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 3, fontWeight: FontWeight.bold))]);
  }

  Widget _buildWalkthroughInfo(AssistantState state, Color color) {
    return Column(
      key: ValueKey("walkthrough_${state.walkthroughStep}"),
      children: [
        const SizedBox(height: 16),
        Text(state.isWaitingForAction ? "AWAITING ACTION" : "LISTENING TO GUIDE", style: TextStyle(color: color.withOpacity(0.4), fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildLargeStatus(String main, String sub, Color color) {
    return Column(key: ValueKey(main), children: [Text(main, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w100, color: Colors.white, letterSpacing: -2)), Text(sub, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 4, color: color))]);
  }

  Widget _buildSettingsHUD(Color color) {
    final settings = ref.watch(settingsRepositoryProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("ENGINE CONFIG", style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 3)), Icon(Icons.tune_rounded, size: 14, color: color.withOpacity(0.5))]),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _hudItem(Icons.speed_rounded, "RATE", settings.speechRate, (settings.speechRate * 2).toStringAsFixed(1), color)),
              Container(width: 1, height: 50, color: Colors.white.withOpacity(0.05), margin: const EdgeInsets.symmetric(horizontal: 10)),
              Expanded(child: _hudItem(Icons.waves_rounded, "PITCH", (settings.pitch - 0.5) / 1.5, settings.pitch.toStringAsFixed(1), color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudItem(IconData icon, String label, double progress, String val, Color color) {
    return Column(
      children: [
        Icon(icon, size: 12, color: Colors.white24),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w200, letterSpacing: -1)),
        const SizedBox(height: 8),
        SizedBox(width: 50, child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: Colors.white.withOpacity(0.05), valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.6)), minHeight: 1.5)),
      ],
    );
  }

  Widget _buildGuideButton(Color color) {
    return GestureDetector(
      onTap: () => ref.read(assistantViewModelProvider.notifier).handleIntent(VoiceIntent.openWalkthrough, "user guide"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.menu_book_rounded, size: 12, color: color), const SizedBox(width: 10), Text("USER GUIDE", style: TextStyle(color: color.withOpacity(0.7), fontSize: 8, letterSpacing: 2, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildCameraOverlay(Color color) {
    return Stack(
      children: [
        Positioned.fill(child: Opacity(opacity: 0.05, child: CustomPaint(painter: GridHUDPainter()))),
        AnimatedBuilder(
          animation: _scannerController,
          builder: (context, child) => Positioned(
            top: MediaQuery.of(context).size.height * 0.2 + (MediaQuery.of(context).size.height * 0.6 * _scannerController.value),
            left: 50, right: 50,
            child: Container(height: 1, decoration: BoxDecoration(color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)])),
          ),
        ),
      ],
    );
  }
}

class GridHUDPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 0.5;
    const double gap = 60;
    for (double i = 0; i <= size.width; i += gap) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i <= size.height; i += gap) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
