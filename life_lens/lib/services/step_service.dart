import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class StepService {
  final _db = DatabaseHelper();
  int _lastStepCount = 0;
  int _todaySteps = 0;
  String _lastDate = '';
  late Stream<StepCount> _stepCountStream;

  Future<void> initialize() async {
    try {
      _lastDate = _dateKey(DateTime.now());

      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('step_last_date') ?? _lastDate;

      if (savedDate == _lastDate) {
        // Same day — restore accumulated steps
        _todaySteps = prefs.getInt('today_steps') ?? 0;
      } else {
        // New day — reset
        _todaySteps = 0;
        await prefs.setInt('today_steps', 0);
        await prefs.setString('step_last_date', _lastDate);
      }

      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen(_onStepCount, onError: _onStepError);
    } catch (e) {
      // Pedometer not available on this device
    }
  }

  void _onStepCount(StepCount event) async {
    final today = _dateKey(DateTime.now());

    // Midnight crossed — reset counter
    if (today != _lastDate) {
      _lastDate = today;
      _todaySteps = 0;
      _lastStepCount = event.steps;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_steps', 0);
      await prefs.setString('step_last_date', today);
      return;
    }

    final currentCount = event.steps;
    if (_lastStepCount == 0) {
      _lastStepCount = currentCount;
      return;
    }

    final stepsDelta = currentCount - _lastStepCount;
    if (stepsDelta > 0 && stepsDelta < 10000) {
      _todaySteps += stepsDelta;
      _lastStepCount = currentCount;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_steps', _todaySteps);
    }
  }

  void _onStepError(error) {
    // Pedometer error, ignore
  }

  /// Save today's step total to the database (called every 2 minutes by background service).
  /// Uses upsert — one row per day, overwritten each time. No summation bugs.
  Future<void> collectAndSave() async {
    final today = _dateKey(DateTime.now());

    // Check for midnight rollover
    if (today != _lastDate) {
      _lastDate = today;
      _todaySteps = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_steps', 0);
      await prefs.setString('step_last_date', today);
    }

    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('today_steps') ?? 0;
    if (steps == 0) return;

    await _db.saveDailySteps(today, steps);
  }

  int get todaySteps => _todaySteps;

  String getStepsSummary() {
    if (_todaySteps >= 10000) return '$_todaySteps steps - Amazing!';
    if (_todaySteps >= 7500) return '$_todaySteps steps - Great!';
    if (_todaySteps >= 5000) return '$_todaySteps steps - Good';
    if (_todaySteps >= 2500) return '$_todaySteps steps - Keep moving!';
    return '$_todaySteps steps - Try to walk more';
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
