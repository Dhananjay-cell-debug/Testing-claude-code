import 'package:flutter/material.dart';
import '../models/life_event.dart';
import '../utils/constants.dart';

class TimelineItem extends StatelessWidget {
  final LifeEvent event;
  final bool isLast;

  const TimelineItem({
    super.key,
    required this.event,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(event.type);
    final timeStr = _formatTime(event.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 52,
            child: Text(
              timeStr,
              style: AppTextStyles.label.copyWith(fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          // Line + dot
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(100), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    event.displayIcon,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.displayTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (event.durationSeconds > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withAlpha(26),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _formatDuration(event.durationSeconds),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_hasSubtitle(event)) ...[
                      const SizedBox(height: 4),
                      Text(
                        _subtitleText(event),
                        style: AppTextStyles.body.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasSubtitle(LifeEvent event) {
    if (event.type == 'location' && event.data['address']?.isNotEmpty == true) return true;
    if (event.type == 'app_usage' && event.data['category']?.isNotEmpty == true) return true;
    if (event.type == 'step') return true;
    return false;
  }

  String _subtitleText(LifeEvent event) {
    switch (event.type) {
      case 'location':
        return event.data['address'] ?? '';
      case 'app_usage':
        return (event.data['category'] ?? '').toUpperCase();
      case 'step':
        return 'Total today: ${event.data['steps'] ?? 0} steps';
      default:
        return '';
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'app_usage':
        return AppColors.primary;
      case 'location':
        return AppColors.secondary;
      case 'activity':
        return AppColors.scoreHigh;
      case 'screen':
        return AppColors.scoreMid;
      case 'step':
        return AppColors.tertiary;
      case 'wifi':
        return AppColors.messaging;
      case 'sleep':
        return AppColors.primaryLight;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute\n$suffix';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}
