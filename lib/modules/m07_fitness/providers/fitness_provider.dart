import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/hive_service.dart';
import '../models/fitness_model.dart';
import '../services/step_history.dart';

class FitnessProvider extends ChangeNotifier {
  FitnessProvider({StepHistory? stepHistory})
    : _stepHistory = stepHistory ?? StepHistory();

  final _hiveService = HiveService();
  final StepHistory _stepHistory;
  DateTime? _lastHistorySync;

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
    if (_trackingStarted) {
      unawaited(syncDeviceHistory());
      return;
    }
    // İzin reddedilirse bayrak kalkmaz; ekran yeniden açıldığında tekrar
    // denenir. Önceden ilk denemede kalıcı olarak kapanıyordu.
    if (!await _requestMotionPermission()) return;
    _trackingStarted = true;
    await _hiveService.getFitnessBox().put('step_tracking_enabled', true);
    await syncDeviceHistory();
    await _stepCountStream?.cancel();
    _stepCountStream = Pedometer.stepCountStream.listen(
      (StepCount event) {
        _stepEventQueue = _stepEventQueue.then(
          (_) => handleDeviceStepCount(event.steps),
        );
      },
      onError: (error) {
        debugPrint('Pedometer hatası: $error');
      },
    );
  }

  /// permission_handler'ın activityRecognition izni yalnızca Android'de
  /// vardır; iOS'ta her zaman "kalıcı olarak reddedildi" döndüğü için adım
  /// takibi iOS'ta hiç başlamıyordu. iOS'ta Hareket ve Fitness izni,
  /// CoreMotion'a ilk erişimde sistem tarafından sorulur.
  static Future<bool> _requestMotionPermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.activityRecognition.request()).isGranted;
  }

  /// Takip daha önce açıldıysa (ör. uygulama öne gelince) cihaz kaydını
  /// yeniden okur; izin hiç verilmediyse istem göstermez.
  Future<void> syncIfTrackingEnabled() async {
    final enabled = _hiveService.getFitnessBox().get('step_tracking_enabled');
    if (enabled == true) await syncDeviceHistory();
  }

  /// Cihazın adım kaydındaki gün toplamlarını işler. Bir günün cihaz
  /// adımı yalnızca artabilir: kayıt yeni başladıysa veya eksikse sensörle
  /// sayılmış adımlar korunur.
  Future<void> syncDeviceHistory() async {
    _lastHistorySync = DateTime.now();
    final totals = await _stepHistory.dailyTotals(days: 7);
    if (totals == null || totals.isEmpty) return;
    final box = _hiveService.getFitnessBox();
    var changed = false;
    for (final entry in totals.entries) {
      if (entry.value > _deviceStepsOf(box, entry.key)) {
        await _setDeviceSteps(box, entry.key, entry.value);
        changed = true;
      }
    }
    if (!changed) return;
    _refreshStepHistory(box, force: true);
    notifyListeners();
  }

  static int _stored(Box<dynamic> box, String key) =>
      (box.get(key) as num?)?.toInt() ?? 0;

  /// Cihazdan sayılan adımlar. Eski sürümler yalnızca toplamı tutuyordu;
  /// ayrım yoksa toplamın tamamı cihaz adımı sayılır.
  static int _deviceStepsOf(Box<dynamic> box, String day) =>
      box.containsKey('device_steps_$day')
      ? _stored(box, 'device_steps_$day')
      : _stored(box, 'steps_$day') - _stored(box, 'manual_steps_$day');

  /// Toplam (`steps_<gün>`) diğer modüllerin okuduğu anahtardır; cihaz ve
  /// elle eklenen adımlar ayrı tutulur ki senkron elle girileni silmesin.
  static Future<void> _setDeviceSteps(
    Box<dynamic> box,
    String day,
    int steps,
  ) => box.putAll({
    'device_steps_$day': steps,
    'steps_$day': steps + _stored(box, 'manual_steps_$day'),
  });

  /// Adım sensörünün olayı: açılıştan beri sayılan toplam adım.
  @visibleForTesting
  Future<void> handleDeviceStepCount(int deviceSteps) async {
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
      await _setDeviceSteps(
        box,
        currentDate,
        _deviceStepsOf(box, currentDate) + delta,
      );
      _refreshStepHistory(box, force: true);
      notifyListeners();
    } else if (dateChanged) {
      notifyListeners();
    }

    // Gün değişiminde sensör farkı sıfırlanır; uygulama açılmadan önce
    // atılan adımlar cihazın kendi kaydından gelir.
    final last = _lastHistorySync;
    if (dateChanged ||
        last == null ||
        DateTime.now().difference(last) > const Duration(minutes: 1)) {
      await syncDeviceHistory();
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

  /// Elle eklenen adımlar (ör. telefon yanınızda değilken yürüdüyseniz).
  Future<void> addSteps(int steps) async {
    if (steps <= 0) return;
    final box = _hiveService.getFitnessBox();
    final day = _today;
    final device = _deviceStepsOf(box, day);
    final manual = _stored(box, 'manual_steps_$day') + steps;
    await box.putAll({
      'device_steps_$day': device,
      'manual_steps_$day': manual,
      'steps_$day': device + manual,
    });
    _refreshStepHistory(box, force: true);
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
