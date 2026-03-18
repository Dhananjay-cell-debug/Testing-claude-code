import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/safety_incident.dart';
import '../services/safety_service.dart';
import '../utils/constants.dart';

/// 5-minute check-in popup.
/// Appears automatically over any screen.
/// Cannot be dismissed — user MUST respond.
///
/// Options:
///   ✅ I am safe now → resolve
///   😟 Still uncomfortable → stay at current level, restart 5-min timer
///   😰 Getting worse → escalate to next level
///   🚨 IMMEDIATE DANGER → fire Path C immediately
class SafetyCheckinPopup extends StatefulWidget {
  final ThreatLevel currentLevel;

  const SafetyCheckinPopup({super.key, required this.currentLevel});

  /// Show as un-dismissible overlay
  static Future<void> show(BuildContext context, {required ThreatLevel currentLevel}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(180),
      builder: (_) => SafetyCheckinPopup(currentLevel: currentLevel),
    );
  }

  @override
  State<SafetyCheckinPopup> createState() => _SafetyCheckinPopupState();
}

class _SafetyCheckinPopupState extends State<SafetyCheckinPopup> {
  final _safety = SafetyService();
  bool _processing = false;

  Future<void> _respond(_CheckinOption option) async {
    if (_processing) return;
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    switch (option) {
      case _CheckinOption.safe:
        await _safety.resolve();
        if (mounted) Navigator.of(context).pop();
        break;

      case _CheckinOption.stillUncomfortable:
        // Stay at same level — explicitly restart the 5-min check-in timer
        _safety.restartCheckinTimer();
        if (mounted) Navigator.of(context).pop();
        break;

      case _CheckinOption.worse:
        final nextLevel = _nextLevel(widget.currentLevel);
        await _safety.escalate(nextLevel);
        if (mounted) Navigator.of(context).pop();
        break;

      case _CheckinOption.immediateDanger:
        await _safety.triggerImmediate();
        if (mounted) Navigator.of(context).pop();
        break;
    }
  }

  ThreatLevel _nextLevel(ThreatLevel current) {
    switch (current) {
      case ThreatLevel.uncomfortable:
        return ThreatLevel.following;
      case ThreatLevel.following:
        return ThreatLevel.immediate;
      default:
        return ThreatLevel.immediate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.crisis_alert_rounded, color: Color(0xFFFF6B35), size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Drishti Check-in',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How are you feeling right now?',
                    style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(160)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current: ${widget.currentLevel.label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 24),

            // Options
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  _Option(
                    label: 'I am safe now',
                    sublabel: 'Threat is gone, stop all alerts',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.scoreHigh,
                    onTap: () => _respond(_CheckinOption.safe),
                  ),
                  const SizedBox(height: 10),
                  _Option(
                    label: 'Still uncomfortable',
                    sublabel: 'Same situation, keep monitoring',
                    icon: Icons.sentiment_dissatisfied_rounded,
                    color: const Color(0xFFFFB020),
                    onTap: () => _respond(_CheckinOption.stillUncomfortable),
                  ),
                  const SizedBox(height: 10),
                  _Option(
                    label: 'Getting worse',
                    sublabel: 'Situation escalating — upgrade alert level',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFFFF6B35),
                    onTap: () => _respond(_CheckinOption.worse),
                  ),
                  const SizedBox(height: 10),
                  _Option(
                    label: 'IMMEDIATE DANGER',
                    sublabel: 'Physical threat NOW — calls 112 instantly',
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFFF2D2D),
                    isEmergency: true,
                    onTap: () => _respond(_CheckinOption.immediateDanger),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CheckinOption { safe, stillUncomfortable, worse, immediateDanger }

class _Option extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEmergency;

  const _Option({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(isEmergency ? 35 : 20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(isEmergency ? 120 : 60)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: isEmergency ? 22 : 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isEmergency ? 14 : 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(fontSize: 11, color: color.withAlpha(160)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
