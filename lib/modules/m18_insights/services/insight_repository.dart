import '../../../services/hive_service.dart';
import '../../m03_chronic/models/health_entry.dart';
import '../../m03_chronic/models/medication_adherence.dart';
import '../../m15_sleep/models/sleep_entry.dart';
import '../../m19_heart/models/heart_measurement.dart';
import 'insight_engine.dart';

/// Analiz girdilerini cihazdaki (Hive) verilerden toplar.
class InsightRepository {
  InsightRepository._();

  static List<T> _parse<T>(dynamic raw, T Function(Map<dynamic, dynamic>) f) {
    if (raw is! List) return <T>[];
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(f(item));
      } catch (_) {}
    }
    return out;
  }

  static InsightInput load({DateTime? now}) {
    final t = now ?? DateTime.now();
    final hive = HiveService();
    final health = hive.getHealthBox();
    final medBox = hive.getMedicationBox();
    final moodBox = hive.getMoodBox();
    final fitness = hive.getFitnessBox();

    final moodByDay = <String, int>{};
    final stepsByDay = <String, int>{};
    for (var i = 0; i < 30; i++) {
      final key = t
          .subtract(Duration(days: i))
          .toIso8601String()
          .substring(0, 10);
      final mood = moodBox.get(key);
      if (mood is int) moodByDay[key] = mood;
      final steps = fitness.get('steps_$key');
      if (steps is int && steps > 0) stepsByDay[key] = steps;
    }

    final meds = _parse(medBox.get('medications'), MedicationReminder.fromMap);
    final adherence = meds.isEmpty
        ? null
        : AdherenceCalculator.compute(
            medications: meds,
            log: DoseLog.fromRaw(medBox.get('dose_log')),
            now: t,
            trackingSince: DateTime.tryParse(
              '${medBox.get('adherence_since') ?? ''}',
            ),
          );

    final goals = hive.getProfileBox().get('goals');

    return InsightInput(
      now: t,
      pressures: _parse(
        health.get('blood_pressure'),
        BloodPressureEntry.fromMap,
      ),
      sugars: _parse(health.get('blood_sugar'), HealthEntry.fromMap),
      weights: _parse(health.get('weight_history'), HealthEntry.fromMap),
      sleep: SleepEntry.parseList(health.get('sleep_log')),
      moodByDay: moodByDay,
      stepsByDay: stepsByDay,
      adherence: adherence,
      heart: HeartMeasurement.parseList(
        health.get(HeartMeasurement.storageKey),
      ),
      goals: goals is List ? goals.map((g) => '$g').toList() : const [],
    );
  }

  static List<HealthInsight> analyze({DateTime? now}) =>
      InsightEngine.analyze(load(now: now));
}
