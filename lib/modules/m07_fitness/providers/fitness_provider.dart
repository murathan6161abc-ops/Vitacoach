import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/hive_service.dart';
import '../models/fitness_model.dart';

class FitnessProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  int _todaySteps = 0;
  List<int> _weeklySteps = List.filled(7, 0);
  List<WorkoutEntry> _workoutHistory = [];

  StreamSubscription<StepCount>? _stepCountStream;
  Future<void> _stepEventQueue = Future<void>.value();
  int? _lastDeviceSteps;
  String? _lastDeviceStepsDate;
  String _loadedDate = '';
  bool _trackingStarted = false;

  int get todaySteps => _todaySteps;
  List<int> get weeklySteps => _weeklySteps;
  List<WorkoutEntry> get workoutHistory => _workoutHistory;

  double get todayProgress => _todaySteps / AppConstants.dailyStepGoal;
  double get todayKm => _todaySteps * 0.0007;
  int get todayCalories => (_todaySteps * 0.04).toInt();

  int get weeklyTotalSteps => _weeklySteps.reduce((a, b) => a + b);
  double get weeklyAvgSteps => weeklyTotalSteps / 7;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  void loadData() {
    final box = _hiveService.getFitnessBox();
    _refreshStepHistory(box, force: true);
    _lastDeviceSteps = (box.get('last_device_steps') as num?)?.toInt();
    _lastDeviceStepsDate = box.get('last_device_steps_date') as String?;

    final workouts =
        box.get('workout_history', defaultValue: <dynamic>[]) as List<dynamic>;
    _workoutHistory = [];
    for (var w in workouts) {
      if (w is Map) {
        _workoutHistory.add(WorkoutEntry.fromMap(Map<String, dynamic>.from(w)));
      }
    }
    _workoutHistory.sort((a, b) => b.date.compareTo(a.date));

    notifyListeners();
  }

  Future<void> startStepTracking() async {
    if (_trackingStarted) return;
    _trackingStarted = true;
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      await _stepCountStream?.cancel();
      _stepCountStream = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _stepEventQueue = _stepEventQueue.then(
            (_) => _handleDeviceStepCount(event.steps),
          );
        },
        onError: (error) {
          debugPrint('Pedometer hatası: $error');
        },
      );
    }
  }

  Future<void> _handleDeviceStepCount(int deviceSteps) async {
    final box = _hiveService.getFitnessBox();
    final currentDate = _today;
    final dateChanged = _refreshStepHistory(box);
    var delta = 0;

    if (_lastDeviceSteps != null &&
        _lastDeviceStepsDate == currentDate &&
        deviceSteps >= _lastDeviceSteps!) {
      delta = deviceSteps - _lastDeviceSteps!;
    }

    _lastDeviceSteps = deviceSteps;
    _lastDeviceStepsDate = currentDate;
    await box.putAll({
      'last_device_steps': deviceSteps,
      'last_device_steps_date': currentDate,
    });

    if (delta > 0) {
      await addSteps(delta);
    } else if (dateChanged) {
      notifyListeners();
    }
  }

  bool _refreshStepHistory(Box<dynamic> box, {bool force = false}) {
    final currentDate = _today;
    if (!force && _loadedDate == currentDate) return false;

    _loadedDate = currentDate;
    _todaySteps = box.get('steps_$currentDate', defaultValue: 0) ?? 0;
    _weeklySteps = List.filled(7, 0);
    for (var index = 0; index < 7; index++) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final key = 'steps_${date.toIso8601String().substring(0, 10)}';
      _weeklySteps[index] = box.get(key, defaultValue: 0) ?? 0;
    }
    return true;
  }

  @override
  void dispose() {
    _stepCountStream?.cancel();
    super.dispose();
  }

  Future<void> addSteps(int steps) async {
    if (steps <= 0) return;
    final box = _hiveService.getFitnessBox();
    _refreshStepHistory(box);
    _todaySteps += steps;
    await box.put('steps_$_today', _todaySteps);
    _weeklySteps[6] = _todaySteps;
    notifyListeners();
  }

  Future<void> addWorkout(
    String name,
    int durationMin,
    int caloriesPerHour,
  ) async {
    final calories = (caloriesPerHour * durationMin / 60).toInt();
    final entry = WorkoutEntry(
      exerciseName: name,
      durationMinutes: durationMin,
      caloriesBurned: calories,
      date: DateTime.now(),
    );
    _workoutHistory.insert(0, entry);

    final box = _hiveService.getFitnessBox();
    await box.put(
      'workout_history',
      _workoutHistory.map((w) => w.toMap()).toList(),
    );
    notifyListeners();
  }

  // Predefined exercises
  static final List<Exercise> exercises = [
    Exercise(
      id: 'walk',
      name: 'Yürüyüş',
      category: 'Kardiyo',
      durationMinutes: 30,
      caloriesPerHour: 250,
      difficulty: 'Kolay',
      muscleGroup: 'Bacak',
    ),
    Exercise(
      id: 'run',
      name: 'Koşu',
      category: 'Kardiyo',
      durationMinutes: 20,
      caloriesPerHour: 600,
      difficulty: 'Orta',
      muscleGroup: 'Bacak',
    ),
    Exercise(
      id: 'bike',
      name: 'Bisiklet',
      category: 'Kardiyo',
      durationMinutes: 30,
      caloriesPerHour: 400,
      difficulty: 'Orta',
      muscleGroup: 'Bacak',
    ),
    Exercise(
      id: 'swim',
      name: 'Yüzme',
      category: 'Kardiyo',
      durationMinutes: 30,
      caloriesPerHour: 500,
      difficulty: 'Orta',
      muscleGroup: 'Tüm vücut',
    ),
    Exercise(
      id: 'yoga',
      name: 'Yoga',
      category: 'Esneklik',
      durationMinutes: 45,
      caloriesPerHour: 200,
      difficulty: 'Kolay',
      muscleGroup: 'Tüm vücut',
    ),
    Exercise(
      id: 'pilates',
      name: 'Pilates',
      category: 'Esneklik',
      durationMinutes: 45,
      caloriesPerHour: 250,
      difficulty: 'Orta',
      muscleGroup: 'Core',
    ),
    Exercise(
      id: 'pushup',
      name: 'Şınav',
      category: 'Güç',
      durationMinutes: 10,
      caloriesPerHour: 350,
      difficulty: 'Orta',
      muscleGroup: 'Göğüs, kol',
    ),
    Exercise(
      id: 'squat',
      name: 'Squat',
      category: 'Güç',
      durationMinutes: 10,
      caloriesPerHour: 400,
      difficulty: 'Orta',
      muscleGroup: 'Bacak, kalça',
    ),
    Exercise(
      id: 'plank',
      name: 'Plank',
      category: 'Güç',
      durationMinutes: 5,
      caloriesPerHour: 250,
      difficulty: 'Orta',
      muscleGroup: 'Core',
    ),
    Exercise(
      id: 'jumping_jack',
      name: 'Jumping Jack',
      category: 'Kardiyo',
      durationMinutes: 10,
      caloriesPerHour: 500,
      difficulty: 'Kolay',
      muscleGroup: 'Tüm vücut',
    ),
    Exercise(
      id: 'burpee',
      name: 'Burpee',
      category: 'HIIT',
      durationMinutes: 10,
      caloriesPerHour: 700,
      difficulty: 'Zor',
      muscleGroup: 'Tüm vücut',
    ),
    Exercise(
      id: 'dance',
      name: 'Dans',
      category: 'Kardiyo',
      durationMinutes: 30,
      caloriesPerHour: 350,
      difficulty: 'Kolay',
      muscleGroup: 'Tüm vücut',
    ),
  ];
}
