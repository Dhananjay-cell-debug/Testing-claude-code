import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/safety_incident.dart';
import '../services/safety_service.dart';
import '../utils/constants.dart';
import 'safety_checkin_popup.dart';

/// The main Safety Mode screen.
/// Opened when user taps SOS button.
///
/// Path A (Uncomfortable): activates immediately, starts 5-min checkin
/// Path B (Being Followed): activates immediately, starts recording + 5-min checkin
/// Path C (Immediate Danger): shows 3-second countdown, then fires everything
///
/// The 3-second countdown ONLY appears for Path C.
class SafetyModeScreen extends StatefulWidget {
  const SafetyModeScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const SafetyModeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<SafetyModeScreen> createState() => _SafetyModeScreenState();
}

class _SafetyModeScreenState extends State<SafetyModeScreen>
    with SingleTickerProviderStateMixin {
  final _safety = SafetyService();
  StreamSubscription? _eventSub;

  // Path C countdown state
  bool _countdownActive = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;
  late AnimationController _countdownAnim;

  // Stealth mode
  bool _stealthMode = false;
  int _stealthTapCount = 0;

  @override
  void initState() {
    super.initState();
    _countdownAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _eventSub = _safety.events.listen((event) {
      if (!mounted) return;
      if (event.type == SafetyEventType.stealthMode) {
        setState(() => _stealthMode = true);
      } else if (event.type == SafetyEventType.checkinRequired) {
        _showCheckinPopup(event.level ?? ThreatLevel.uncomfortable);
      } else if (event.type == SafetyEventType.resolved) {
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownAnim.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  // ── Path Actions ────────────────────────────────────────────────────────────

  Future<void> _activatePath(ThreatLevel level) async {
    HapticFeedback.heavyImpact();
    await _safety.activate(level);
    if (mounted && level != ThreatLevel.immediate) {
      // Show confirmation and keep screen open for checkins
      setState(() {});
    }
  }

  void _startImmediateDangerCountdown() {
    HapticFeedback.heavyImpact();
    setState(() {
      _countdownActive = true;
      _countdownSeconds = 3;
    });
    _countdownAnim.forward(from: 0);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdownSeconds--);
      HapticFeedback.mediumImpact();
      if (_countdownSeconds <= 0) {
        t.cancel();
        _fireImmediate();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownAnim.stop();
    setState(() {
      _countdownActive = false;
      _countdownSeconds = 3;
    });
  }

  Future<void> _fireImmediate() async {
    await _safety.triggerImmediate();
  }

  // ── Stealth Mode ─────────────────────────────────────────────────────────────

  void _onStealthTap() {
    _stealthTapCount++;
    if (_stealthTapCount >= 5) {
      _stealthTapCount = 0;
      setState(() => _stealthMode = false);
    }
  }

  // ── Check-in Popup ──────────────────────────────────────────────────────────

  void _showCheckinPopup(ThreatLevel currentLevel) {
    SafetyCheckinPopup.show(context, currentLevel: currentLevel);
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Stealth mode — completely black screen
    if (_stealthMode) {
      return GestureDetector(
        onTap: _onStealthTap,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Active safety mode (Path A or B running)
    if (_safety.isActive && _safety.currentLevel != ThreatLevel.immediate) {
      return _buildActiveScreen();
    }

    // Main selection screen
    return WillPopScope(
      onWillPop: () async {
        if (_countdownActive) {
          _cancelCountdown();
          return false;
        }
        return !_safety.isActive;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0008),
        body: SafeArea(
          child: _countdownActive ? _buildCountdown() : _buildSelectionScreen(),
        ),
      ),
    );
  }

  Widget _buildSelectionScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Safety Mode',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Tell Drishti how you feel right now',
                    style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Path A
          _ThreatButton(
            label: 'Uncomfortable',
            sublabel: 'Feeling uneasy, just want someone to know',
            icon: Icons.sentiment_dissatisfied_rounded,
            color: const Color(0xFFFFB020),
            onTap: () => _activatePath(ThreatLevel.uncomfortable),
          ),
          const SizedBox(height: 14),

          // Path B
          _ThreatButton(
            label: 'Being Followed',
            sublabel: 'Someone is following me or watching me',
            icon: Icons.remove_red_eye_rounded,
            color: const Color(0xFFFF6B35),
            onTap: () => _activatePath(ThreatLevel.following),
          ),
          const SizedBox(height: 14),

          // Path C — triggers countdown, NOT immediate action
          _ThreatButton(
            label: 'IMMEDIATE DANGER',
            sublabel: 'Physical threat, attack, or rape — calls 112 now',
            icon: Icons.warning_rounded,
            color: const Color(0xFFFF2D2D),
            isEmergency: true,
            onTap: _startImmediateDangerCountdown,
          ),

          const Spacer(),
          Center(
            child: Text(
              'All data stays on your device.\nRecording is silent and screen-safe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(80), height: 1.6),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'CALLING 112',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: AnimatedBuilder(
                  animation: _countdownAnim,
                  builder: (_, __) => CircularProgressIndicator(
                    value: 1 - _countdownAnim.value,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withAlpha(20),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2D2D)),
                  ),
                ),
              ),
              Text(
                '$_countdownSeconds',
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF2D2D),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _cancelCountdown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white.withAlpha(60)),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveScreen() {
    final level = _safety.currentLevel;
    final color = level == ThreatLevel.following ? const Color(0xFFFF6B35) : const Color(0xFFFFB020);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0008),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Safety Mode Active — ${level.label}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Recording. Contacts notified. Check-in in 5 min.',
                style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(150)),
              ),
              const Spacer(),

              // Escalate to immediate danger
              _ThreatButton(
                label: 'ESCALATE — IMMEDIATE DANGER',
                sublabel: 'Situation got worse — call 112 now',
                icon: Icons.warning_rounded,
                color: const Color(0xFFFF2D2D),
                isEmergency: true,
                onTap: _startImmediateDangerCountdown,
              ),
              const SizedBox(height: 16),

              // Resolve
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await _safety.resolve();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withAlpha(60)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'I am Safe Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable threat button ────────────────────────────────────────────────────

class _ThreatButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEmergency;

  const _ThreatButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withAlpha(isEmergency ? 40 : 25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(isEmergency ? 150 : 80), width: isEmergency ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: isEmergency ? 28 : 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isEmergency ? 16 : 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: isEmergency ? 0.5 : 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withAlpha(180),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withAlpha(120), size: 20),
          ],
        ),
      ),
    );
  }
}
