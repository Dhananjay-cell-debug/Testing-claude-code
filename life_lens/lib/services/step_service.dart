import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/life_event.dart';

class StepService {
  final _db = DatabaseHelper();
  int _lastStepCount = 0;
  int _todaySteps = 0;
  late Stream<StepCount> _stepCountStream;

  Future<void> initialize() async {
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen(_onStepCount, onError: _onStepError);

      // Load today's steps from prefs
      final prefs = await SharedPreferences.getInstance();
      _todaySteps = prefs.getInt('today_steps') ?? 0;
    } catch (e) {
      // Pedometer not available on this device
    }
  }

  void _onStepCount(StepCount event) async {
    final currentCount = event.steps;
    if (_lastStepCount == 0) {
      _lastStepCount = currentCount;
      return;
    }

    final stepsDelta = currentCount - _lastStepCount;
    if (stepsDelta > 0 && stepsDelta < 10000) {
      // Sanity check
      _todaySteps += stepsDelta;
      _lastStepCount = currentCount;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_steps', _todaySteps);
    }
  }

  void _onStepError(error) {
    // Pedometer error, ignore
  }

  Future<void> collectAndSave() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('today_steps') ?? 0;

    if (steps == 0) return;

    await _db.insertEvent(LifeEvent(
      type: 'step',
      timestamp: DateTime.now(),
      data: {
        'steps': steps.toString(),
        'delta': '0',
      },
    ));
  }

  int get todaySteps => _todaySteps;

  String getStepsSummary() {
    if (_todaySteps >= 10000) return '$_todaySteps steps - Amazing!';
    if (_todaySteps >= 7500) return '$_todaySteps steps - Great!';
    if (_todaySteps >= 5000) return '$_todaySteps steps - Good';
    if (_todaySteps >= 2500) return '$_todaySteps steps - Keep moving!';
    return '$_todaySteps steps - Try to walk more';
  }
}
