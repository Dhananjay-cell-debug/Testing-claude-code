import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/life_event.dart';
import '../widgets/timeline_item.dart';
import '../utils/constants.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _db = DatabaseHelper();
  DateTime _selectedDay = DateTime.now();
  List<LifeEvent> _events = [];
  bool _loading = true;

  final _typeFilters = <String>{};
  static const _allTypes = ['app_usage', 'location', 'activity', 'screen', 'step'];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    var events = await _db.getEventsForDay(_selectedDay);

    if (_typeFilters.isNotEmpty) {
      events = events.where((e) => _typeFilters.contains(e.type)).toList();
    }

    // Deduplicate similar consecutive events
    final deduplicated = _deduplicate(events);

    setState(() {
      _events = deduplicated;
      _loading = false;
    });
  }

  List<LifeEvent> _deduplicate(List<LifeEvent> events) {
    if (events.isEmpty) return events;
    final result = <LifeEvent>[events.first];

    for (int i = 1; i < events.length; i++) {
      final prev = result.last;
      final curr = events[i];
      // Skip duplicate app_usage events within 2 minutes
      if (curr.type == 'app_usage' &&
          prev.type == 'app_usage' &&
          curr.data['package_name'] == prev.data['package_name'] &&
          curr.timestamp.difference(prev.timestamp).inMinutes < 2) {
        continue;
      }
      result.add(curr);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildDaySelector(),
          _buildFilterChips(),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _events.isEmpty
                    ? _buildEmptyState()
                    : _buildTimeline(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: AppSizes.padding,
        right: AppSizes.padding,
        bottom: 12,
      ),
      child: Row(
        children: [
          Text('TIMELINE', style: AppTextStyles.label.copyWith(color: AppColors.primary, fontSize: 14)),
          const Spacer(),
          Text(
            '${_events.length} events',
            style: AppTextStyles.label,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, _selectedDay);
          final isToday = _isSameDay(day, DateTime.now());

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDay = day);
              _loadEvents();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                          ? AppColors.primary.withAlpha(100)
                          : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final typeLabels = {
      'app_usage': '📱 Apps',
      'location': '📍 Places',
      'activity': '🏃 Activity',
      'screen': '💡 Screen',
      'step': '👟 Steps',
    };

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
        itemCount: _allTypes.length,
        itemBuilder: (context, index) {
          final type = _allTypes[index];
          final isActive = _typeFilters.contains(type);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isActive) {
                  _typeFilters.remove(type);
                } else {
                  _typeFilters.add(type);
                }
              });
              _loadEvents();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary.withAlpha(26) : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                typeLabels[type] ?? type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.padding),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        return TimelineItem(
          event: _events[index],
          isLast: index == _events.length - 1,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📭', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            _typeFilters.isEmpty
                ? 'No events recorded yet'
                : 'No events match your filter',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 8),
          Text(
            'The app tracks your activity automatically\nin the background.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
