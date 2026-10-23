import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m15_sleep/models/sleep_entry.dart';
import 'package:vitacoach/modules/m18_insights/services/insight_engine.dart';
import 'package:vitacoach/modules/m18_insights/services/trend_math.dart';
import 'package:vitacoach/modules/m19_heart/models/heart_measurement.dart';
import 'package:vitacoach/modules/m19_heart/services/ppg_processor.dart';

final now = DateTime(2026, 9, 30, 20);
DateTime daysAgo(int d, [int hour = 8]) =>
    DateTime(now.year, now.month, now.day - d, hour);
String key(int d) => daysAgo(d).toIso8601String().substring(0, 10);

List<BloodPressureEntry> bp(double Function(int dayIndex) sys) => [
  for (var i = 13; i >= 0; i--)
    BloodPressureEntry(systolic: sys(13 - i), diastolic: 85, date: daysAgo(i)),
];

Set<String> ids(InsightInput input) =>
    InsightEngine.analyze(input).map((i) => i.id).toSet();

void main() {
  group('İstatistik', () {
    test('regresyon eğim ve R²', () {
      final fit = TrendMath.fit([0, 1, 2, 3, 4], [10, 12, 14, 16, 18])!;
      expect(fit.slope, closeTo(2, 1e-9));
      expect(fit.r2, closeTo(1, 1e-9));
      expect(fit.predict(10), closeTo(30, 1e-9));
    });

    test('değiştirilmiş z-skoru uç değeri yakalar, normali yakalamaz', () {
      final ref = <double>[100, 104, 98, 102, 101, 99, 103, 100];
      expect(TrendMath.modifiedZ(150, ref)!, greaterThan(3.5));
      expect(TrendMath.modifiedZ(102, ref)!.abs(), lessThan(3.5));
    });

    test('Pearson', () {
      expect(
        TrendMath.pearson([1, 2, 3, 4, 5], [2, 4, 6, 8, 10]),
        closeTo(1, 1e-9),
      );
      expect(TrendMath.pearson([1, 2, 3, 4], [1, 1, 1, 1]), isNull);
    });
  });

  group('Tansiyon', () {
    test('yükselen eğilim ve eşik tahmini', () {
      final result = InsightEngine.analyze(
        InsightInput(now: now, pressures: bp((i) => 122 + i * 1.2)),
      );
      final rising = result.firstWhere((i) => i.id == 'bp_rising');
      expect(rising.severity, InsightSeverity.warning);
      expect(rising.message, contains('140 mmHg'));
      expect(rising.evidence.join(), contains('R²'));
    });

    test('düşen eğilim olumlu bulgu', () {
      expect(
        ids(InsightInput(now: now, pressures: bp((i) => 150 - i * 1.0))),
        contains('bp_falling'),
      );
    });

    test('kriz eşiği acil uyarı verir', () {
      final list = bp((i) => 130)
        ..add(
          BloodPressureEntry(
            systolic: 185,
            diastolic: 110,
            date: daysAgo(0, 19),
          ),
        );
      final result = InsightEngine.analyze(
        InsightInput(now: now, pressures: list),
      );
      expect(result.first.id, 'bp_crisis');
      expect(result.first.severity, InsightSeverity.alert);
    });

    test('olağandışı tek ölçüm', () {
      final list = bp((i) => 130 + (i % 3).toDouble())
        ..add(
          BloodPressureEntry(
            systolic: 162,
            diastolic: 95,
            date: daysAgo(0, 19),
          ),
        );
      expect(
        ids(InsightInput(now: now, pressures: list)),
        contains('bp_anomaly'),
      );
    });

    test('eski veride uyarı üretilmez', () {
      final old = [
        BloodPressureEntry(systolic: 190, diastolic: 125, date: daysAgo(40)),
      ];
      expect(
        InsightEngine.analyze(InsightInput(now: now, pressures: old)),
        isEmpty,
      );
    });
  });

  group('Kan şekeri', () {
    List<HealthEntry> sugars(List<double> values) => [
      for (var i = 0; i < values.length; i++)
        HealthEntry(value: values[i], date: daysAgo(values.length - 1 - i, 7)),
    ];

    test('hipoglisemi acil', () {
      final r = InsightEngine.analyze(
        InsightInput(now: now, sugars: sugars([95, 92, 64])),
      );
      expect(r.first.id, 'sugar_low');
    });

    test('anomali ve prediyabet ortalaması', () {
      final r = ids(
        InsightInput(
          now: now,
          sugars: sugars([104, 106, 101, 108, 103, 105, 107, 102, 150]),
        ),
      );
      expect(r, containsAll(['sugar_anomaly', 'sugar_avg_prediabetes']));
    });

    test('diyabet aralığı ortalaması', () {
      expect(
        ids(InsightInput(now: now, sugars: sugars([130, 135, 128]))),
        contains('sugar_avg_diabetes'),
      );
    });
  });

  group('Kilo', () {
    List<HealthEntry> w(double from, double to) => [
      HealthEntry(value: from, date: daysAgo(28)),
      HealthEntry(value: to, date: daysAgo(0)),
    ];
    test('hedefle uyumlu kilo kaybı olumlu', () {
      final r = InsightEngine.analyze(
        InsightInput(now: now, weights: w(78, 76), goals: ['Kilo ver']),
      );
      expect(r.single.id, 'weight_goal');
      expect(r.single.severity, InsightSeverity.positive);
    });
    test('istemsiz kilo kaybı uyarı', () {
      expect(
        ids(InsightInput(now: now, weights: w(80, 74))),
        contains('weight_unintended_loss'),
      );
    });
  });

  group('İlişkiler', () {
    test('kısa uyku günlerinde düşük ruh hali', () {
      final hours = [5.5, 8, 6, 7.5, 6.2, 8.2, 5.8, 7.8];
      final moods = [2, 4, 3, 4, 3, 5, 2, 4];
      final sleep = <SleepEntry>[];
      final moodByDay = <String, int>{};
      for (var i = 0; i < hours.length; i++) {
        final wake = daysAgo(i, 7);
        sleep.add(
          SleepEntry(
            bedTime: wake.subtract(Duration(minutes: (hours[i] * 60).round())),
            wakeTime: wake,
            quality: 3,
          ),
        );
        moodByDay[key(i)] = moods[i];
      }
      final r = InsightEngine.analyze(
        InsightInput(now: now, sleep: sleep, moodByDay: moodByDay),
      );
      final insight = r.firstWhere((i) => i.id == 'sleep_mood');
      expect(insight.message, contains('7 saatten az'));
      expect(insight.evidence.last, contains('r ='));
    });

    test('adım ve ruh hali', () {
      final steps = {
        key(0): 9000,
        key(1): 3000,
        key(2): 11000,
        key(3): 2500,
        key(4): 8000,
      };
      final moods = {key(0): 4, key(1): 2, key(2): 5, key(3): 3, key(4): 4};
      expect(
        ids(InsightInput(now: now, stepsByDay: steps, moodByDay: moods)),
        contains('steps_mood'),
      );
    });
  });

  group('Nabız', () {
    HeartMeasurement m(
      int minutesAgo,
      int bpm,
      double rmssd, {
      bool after = false,
    }) => HeartMeasurement(
      date: now.subtract(Duration(minutes: minutesAgo)),
      bpm: bpm,
      rmssdMs: rmssd,
      stress: rmssd < 20
          ? StressLevel.high
          : rmssd < 40
          ? StressLevel.moderate
          : StressLevel.low,
      quality: 0.9,
      context: after ? 'after_breathing' : 'rest',
    );

    test('nefes egzersizi etkisi ve yüksek stres', () {
      final heart = [
        m(5, 70, 31, after: true),
        m(10, 76, 16),
        m(60 * 24, 78, 14),
      ];
      final r = ids(InsightInput(now: now, heart: heart));
      expect(r, containsAll(['breathing_effect', 'hrv_stress']));
    });

    test('veri yoksa bulgu yok', () {
      expect(InsightEngine.analyze(InsightInput(now: now)), isEmpty);
    });
  });
}
