import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/hive_service.dart';
import '../../m03_chronic/models/health_entry.dart';
import '../../m03_chronic/models/medication_adherence.dart';
import '../../m15_sleep/models/sleep_entry.dart';
import '../../m16_emergency/models/emergency_info.dart';

class ProgressProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  int _moodStreak = 0;
  List<Map<String, dynamic>> _badges = [];
  Map<String, double> _healthScores = {};

  int get moodStreak => _moodStreak;
  List<Map<String, dynamic>> get badges => _badges;
  Map<String, double> get healthScores => _healthScores;

  int get totalBadges => _badges.length;

  // Health score entries as list for radar chart
  List<double> get healthScoreValues {
    const keys = ['Beslenme', 'Fitness', 'Ruh Sağlığı', 'Uyku', 'Hidrasyon'];
    return keys.map((k) => _healthScores[k] ?? 0.0).toList();
  }

  List<String> get healthScoreLabels {
    return const ['Beslenme', 'Fitness', 'Ruh Sağlığı', 'Uyku', 'Hidrasyon'];
  }

  double get overallScore {
    if (_healthScores.isEmpty) return 0;
    final sum = _healthScores.values.fold(0.0, (a, b) => a + b);
    return sum / _healthScores.length;
  }

  void loadData() {
    _calculateStreak();
    _calculateHealthScores();
    _loadBadges();
    _persistBadges();
    notifyListeners();
  }

  void _calculateStreak() {
    final box = _hiveService.getMoodBox();
    DateTime date = DateTime.now();

    // Kullanıcı bugün henüz ruh halini kaydetmemiş olabilir (ör. sabah
    // uygulamayı açtığında); bu, önceki günlerden gelen seriyi bozmamalı.
    // Seri, bugün girilmişse bugünden, girilmemişse dünden sayılır.
    if (!box.containsKey(date.toIso8601String().substring(0, 10))) {
      date = date.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (box.containsKey(date.toIso8601String().substring(0, 10))) {
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    _moodStreak = streak;
  }

  void _calculateHealthScores() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final nutritionBox = _hiveService.getNutritionBox();
    final fitnessBox = _hiveService.getFitnessBox();
    final moodBox = _hiveService.getMoodBox();

    // Nutrition score (0-10)
    final meals =
        nutritionBox.get('meals_$today', defaultValue: <dynamic>[]) ?? [];
    final water = nutritionBox.get('water_$today', defaultValue: 0) ?? 0;
    double nutritionScore = 0;
    if ((meals as List).isNotEmpty) nutritionScore += 4;
    if (meals.length >= 3) nutritionScore += 2;
    nutritionScore += (water / 10.0).clamp(0, 4);

    // Fitness score (0-10)
    final steps = fitnessBox.get('steps_$today', defaultValue: 0) ?? 0;
    double fitnessScore = ((steps as int) / AppConstants.dailyStepGoal * 10)
        .clamp(0, 10);

    // Mental score (0-10)
    final mood = moodBox.get(today);
    double mentalScore = mood != null ? (mood as int) * 2.0 : 5.0;

    // Hydration score (0-10)
    double hydrationScore =
        ((water as int) *
                AppConstants.waterGlassMl /
                AppConstants.dailyWaterGoalMl *
                10)
            .clamp(0, 10);

    // Uyku skoru: önceden sabit 6.0 gösteriliyordu; artık uyku kaydından.
    // Kayıt yoksa 0 (veri yok) sayılır.
    final lastNight = _lastNightSleep();
    double sleepScore = lastNight == null ? 0 : SleepScore.compute(lastNight);

    _healthScores = {
      'Beslenme': nutritionScore.toDouble(),
      'Fitness': fitnessScore.toDouble(),
      'Ruh Sağlığı': mentalScore.toDouble(),
      'Uyku': sleepScore,
      'Hidrasyon': hydrationScore.toDouble(),
    };
  }

  SleepEntry? _lastNightSleep() {
    final entries = SleepEntry.parseList(
      _hiveService.getHealthBox().get('sleep_log'),
    );
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final yesterday = now
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    for (final e in entries) {
      if (e.dayKey == today || e.dayKey == yesterday) return e;
    }
    return null;
  }

  AdherenceReport? _medicationAdherence() {
    final box = _hiveService.getMedicationBox();
    final raw = box.get('medications');
    if (raw is! List || raw.isEmpty) return null;
    final meds = <MedicationReminder>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        meds.add(MedicationReminder.fromMap(item));
      } catch (_) {}
    }
    return AdherenceCalculator.compute(
      medications: meds,
      log: DoseLog.fromRaw(box.get('dose_log')),
      now: DateTime.now(),
      trackingSince: DateTime.tryParse('${box.get('adherence_since') ?? ''}'),
    );
  }

  static const Set<String> _sugaryFoods = {
    'Baklava',
    'Kola',
    'Çay (2 şekerli)',
    'Sütlaç',
    'Bal',
    'Tahin-pekmez',
    'Açma',
    'Poğaça (peynirli)',
  };

  void _loadBadges() {
    _badges = [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final nutritionBox = _hiveService.getNutritionBox();
    final fitnessBox = _hiveService.getFitnessBox();
    final addictionBox = _hiveService.getAddictionBox();

    // Streak badges
    if (_moodStreak >= 3) {
      _badges.add({
        'name': 'Başlangıç',
        'icon': Icons.star_outline,
        'color': Colors.amber,
        'desc': '3 gün üst üste giriş',
      });
    }
    if (_moodStreak >= 7) {
      _badges.add({
        'name': 'Hafta Ustası',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'desc': '7 gün üst üste',
      });
    }
    if (_moodStreak >= 30) {
      _badges.add({
        'name': 'Ay Kahramanı',
        'icon': Icons.military_tech,
        'color': Colors.amber,
        'desc': '30 gün üst üste',
      });
    }

    // Water badge
    final water = nutritionBox.get('water_$today', defaultValue: 0) ?? 0;
    if ((water as int) >= 8) {
      _badges.add({
        'name': 'Su Perisi',
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'desc': 'Günlük su hedefini tamamla',
      });
    }

    // Step badge
    final steps = fitnessBox.get('steps_$today', defaultValue: 0) ?? 0;
    if ((steps as int) >= AppConstants.dailyStepGoal) {
      _badges.add({
        'name': 'Yürüyüş Ustası',
        'icon': Icons.directions_walk,
        'color': Colors.teal,
        'desc': '10.000 adım',
      });
    }

    // Nutrition badge
    final meals =
        nutritionBox.get('meals_$today', defaultValue: <dynamic>[]) ?? [];
    if ((meals as List).length >= 3) {
      _badges.add({
        'name': 'Düzenli Beslenme',
        'icon': Icons.restaurant,
        'color': Colors.green,
        'desc': '3+ öğün kaydet',
      });
    }

    // Önceden rozet listesinde görünen ancak hiçbir koşulla kazanılamayan
    // rozetler; artık gerçek verilere bağlı.
    void add(String name) => _badges.add({'name': name});
    final todayMeals = meals.whereType<Map>().toList();
    if (steps >= 5000) add('Yarı Maraton');
    if (steps >= 20000) add('Maratoncu');
    final workouts = fitnessBox.get('workout_history');
    if (workouts is List &&
        workouts.whereType<Map>().any((w) {
          final d = DateTime.tryParse('${w['date']}');
          return d != null &&
              d.toIso8601String().substring(0, 10) == today &&
              d.hour < 10;
        })) {
      add('Erken Uyanan');
    }
    final moodBox = _hiveService.getMoodBox();
    final cbtDone = moodBox.get('cbt_completed');
    if (cbtDone is List && cbtDone.isNotEmpty) add('Huzur Arayan');
    final tests = moodBox.get('test_history');
    if (tests is List && tests.isNotEmpty) add('Mental Güç');
    final risks = _hiveService.getHealthBox().get('risk_history');
    if (risks is List && risks.isNotEmpty) add('Sağlık Bilgesi');
    final produce = todayMeals
        .where(
          (m) => m['category'] == 'fruits' || m['category'] == 'vegetables',
        )
        .length;
    if (produce >= 2) add('Vitamin Deposu');
    if (todayMeals.isNotEmpty &&
        !todayMeals.any((m) => _sugaryFoods.contains(m['name']))) {
      add('Şeker Düşmanı');
    }
    final lastNight = _lastNightSleep();
    if (lastNight != null && lastNight.hours >= 8) add('Uyku Şampiyonu');
    // Önceden ilaç eklemek yetiyordu; artık son 7 günde en az 5 dozun
    // %80'i gerçekten alınmış olmalı.
    final adherence = _medicationAdherence();
    if (adherence != null &&
        adherence.scheduled >= 5 &&
        (adherence.rate ?? 0) >= 0.8) {
      add('Düzenli İlaç');
    }
    if (EmergencyInfo.load().isFilled) add('Hazırlıklı');

    // Addiction badges
    final quitDate = addictionBox.get('quit_date');
    if (quitDate != null) {
      final days = DateTime.now().difference(DateTime.parse(quitDate)).inDays;
      if (days >= 1) {
        _badges.add({
          'name': 'Sigara: İlk Adım',
          'icon': Icons.smoke_free,
          'color': Colors.deepOrange,
          'desc': '1 gün sigarasız',
        });
      }
      if (days >= 7) {
        _badges.add({
          'name': 'Sigara: Bir Hafta',
          'icon': Icons.emoji_events,
          'color': Colors.deepOrange,
          'desc': '7 gün sigarasız',
        });
      }
      if (days >= 30) {
        _badges.add({
          'name': 'Sigara: Bir Ay',
          'icon': Icons.workspace_premium,
          'color': Colors.green,
          'desc': '30 gün sigarasız',
        });
      }
    }
  }

  /// Kazanılan rozet isimlerini Hive'a kaydet
  void _persistBadges() {
    try {
      final badgeBox = _hiveService.getBadgeBox();
      final earnedBadges = Set<String>.from(
        badgeBox.get('earned_badges', defaultValue: <dynamic>[]) ?? const [],
      );
      earnedBadges.addAll(_badges.map((badge) => badge['name'] as String));
      badgeBox.put('earned_badges', earnedBadges.toList()..sort());
      badgeBox.put('last_badge_check', DateTime.now().toIso8601String());
      badgeBox.put('total_earned', earnedBadges.length);
    } catch (e) {
      debugPrint('Rozet kaydetme hatası: $e');
    }
  }

  /// Daha önce kazanılan toplam rozet sayısı (tüm zamanlarda)
  int get allTimeMaxBadges {
    try {
      final badgeBox = _hiveService.getBadgeBox();
      return badgeBox.get('total_earned', defaultValue: 0) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Weekly summary
  Map<String, dynamic> get weeklySummary {
    int totalSteps = 0;
    int totalWater = 0;
    int moodDays = 0;
    double moodSum = 0;
    int mealDays = 0;

    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = date.toIso8601String().substring(0, 10);

      final steps =
          _hiveService.getFitnessBox().get('steps_$key', defaultValue: 0) ?? 0;
      totalSteps += steps as int;

      final water =
          _hiveService.getNutritionBox().get('water_$key', defaultValue: 0) ??
          0;
      totalWater += water as int;

      final mood = _hiveService.getMoodBox().get(key);
      if (mood != null) {
        moodSum += (mood as int);
        moodDays++;
      }

      final meals =
          _hiveService.getNutritionBox().get(
            'meals_$key',
            defaultValue: <dynamic>[],
          ) ??
          [];
      if ((meals as List).isNotEmpty) mealDays++;
    }

    return {
      'total_steps': totalSteps,
      'avg_steps': totalSteps ~/ 7,
      'total_water_glasses': totalWater,
      'avg_mood': moodDays > 0 ? (moodSum / moodDays) : 0.0,
      'mood_days': moodDays,
      'streak': _moodStreak,
      'meal_days': mealDays,
    };
  }
}
