import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/hive_service.dart';
import '../models/mental_model.dart';

class MentalProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  List<MoodEntry> _moodHistory = [];
  List<TestResult> _testHistory = [];
  List<dynamic> _cbtExercises = [];

  List<MoodEntry> get moodHistory => _moodHistory;
  List<TestResult> get testHistory => _testHistory;
  List<dynamic> get cbtExercises => _cbtExercises;

  MoodEntry? get todayMood {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      return _moodHistory.firstWhere(
        (m) => m.date.toIso8601String().substring(0, 10) == today,
      );
    } catch (_) {
      return null;
    }
  }

  // Last 7 days mood average
  double get weeklyMoodAverage {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _moodHistory.where((m) => m.date.isAfter(cutoff)).toList();
    if (recent.isEmpty) return 0;
    return recent.map((m) => m.value).reduce((a, b) => a + b) / recent.length;
  }

  bool _hasEntryOn(DateTime date) {
    final key = date.toIso8601String().substring(0, 10);
    return _moodHistory.any(
      (m) => m.date.toIso8601String().substring(0, 10) == key,
    );
  }

  /// Bugün henüz giriş yapılmamışsa seri bozulmuş sayılmaz; dünden sayılır.
  int get moodStreak {
    DateTime date = DateTime.now();
    if (!_hasEntryOn(date)) {
      date = date.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (_hasEntryOn(date)) {
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> init() async {
    _loadMoodHistory();
    _loadTestHistory();
    await _loadCbtExercises();
  }

  void _loadMoodHistory() {
    final box = _hiveService.getMoodBox();
    _moodHistory = [];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is int) {
        _moodHistory.add(
          MoodEntry(
            value: value,
            date: DateTime.tryParse('${key}T00:00:00') ?? DateTime.now(),
          ),
        );
      } else if (value is Map) {
        _moodHistory.add(MoodEntry.fromMap(value));
      }
    }
    _moodHistory.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  void _loadTestHistory() {
    final box = _hiveService.getMoodBox();
    final tests = box.get('test_history', defaultValue: <dynamic>[]) ?? [];
    _testHistory = tests.map<TestResult>((t) => TestResult.fromMap(t)).toList();
    _testHistory.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _loadCbtExercises() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/cbt_exercises.json',
      );
      final data = json.decode(jsonString);
      _cbtExercises = data['exercises'];
      notifyListeners();
    } catch (e) {
      debugPrint('CBT yükleme hatası: $e');
    }
  }

  Future<void> saveMood(int value, {String? note}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final box = _hiveService.getMoodBox();
    await box.put(today, value);

    final entry = MoodEntry(value: value, date: DateTime.now(), note: note);
    _moodHistory.removeWhere(
      (m) => m.date.toIso8601String().substring(0, 10) == today,
    );
    _moodHistory.insert(0, entry);
    notifyListeners();
  }

  Future<void> saveTestResult(
    String testType,
    int score,
    String severity,
  ) async {
    final result = TestResult(
      testType: testType,
      score: score,
      severity: severity,
      date: DateTime.now(),
    );
    _testHistory.insert(0, result);

    final box = _hiveService.getMoodBox();
    await box.put('test_history', _testHistory.map((t) => t.toMap()).toList());
    notifyListeners();
  }
}
