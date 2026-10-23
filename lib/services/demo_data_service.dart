import 'dart:math' as math;

import '../modules/m03_chronic/models/health_entry.dart';
import '../modules/m03_chronic/models/medication_adherence.dart';
import '../modules/m14_risk/models/risk_models.dart';
import '../modules/m15_sleep/models/sleep_entry.dart';
import '../modules/m16_emergency/models/emergency_info.dart';
import '../modules/m19_heart/models/heart_measurement.dart';
import '../modules/m19_heart/services/ppg_processor.dart';
import 'app_settings_service.dart';
import 'hive_service.dart';
import 'notification_service.dart';

/// Sunum/jüri için uygulamayı gerçekçi ve birbiriyle tutarlı örnek
/// verilerle doldurur. Mevcut tüm yerel veriler silinir.
class DemoDataService {
  DemoDataService._();

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  static Future<void> load({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final rnd = math.Random(42);
    final hive = HiveService();

    final appearance = AppSettingsService().current;
    try {
      await NotificationService().cancelAll();
    } catch (_) {
      // Bildirim eklentisi yoksa (ör. test ortamı) demo yine yüklenebilmeli.
    }
    await hive.clearAllData();
    // Görünüm/erişilebilirlik tercihleri demo verisi değildir; koru.
    await AppSettingsService().update(appearance);

    // Profil
    final profile = hive.getProfileBox();
    final birth = DateTime(today.year - 52, 4, 12);
    await profile.putAll({
      'name': 'Ayşe Demir',
      'birth_date': birth.toIso8601String(),
      'gender': 'Kadın',
      'height': 164.0,
      'weight': 76.0,
      'conditions': ['Hipertansiyon'],
      'goals': ['Kilo ver', 'Sağlıklı beslen', 'Stres azalt'],
      'water_reminder_enabled': false,
      'medication_reminder_enabled': false,
      'exercise_reminder_enabled': false,
      'notifications_enabled': false,
    });
    await const EmergencyInfo(
      bloodType: 'A Rh+',
      allergies: 'Penisilin',
      notes: 'Hipertansiyon tedavisi alıyor. (Demo verisi)',
      contacts: [
        EmergencyContact(
          name: 'Mehmet Demir',
          phone: '0500 000 00 00',
          relation: 'Eş (demo)',
        ),
      ],
    ).save();

    // Sağlık ölçümleri
    final health = hive.getHealthBox();
    final pressures = <Map<String, dynamic>>[];
    final sugars = <Map<String, dynamic>>[];
    for (var i = 13; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final trend = (13 - i) * 0.9; // tedaviyle yavaş düşüş
      pressures.add(
        BloodPressureEntry(
          systolic: (146 - trend + rnd.nextInt(7) - 3).roundToDouble(),
          diastolic: (92 - trend * 0.5 + rnd.nextInt(5) - 2).roundToDouble(),
          date: DateTime(day.year, day.month, day.day, 8, 10 + rnd.nextInt(30)),
        ).toMap(),
      );
      // Son ölçüm dün: bayram tatlısı sonrası olağandışı yüksek bir değer
      // (akıllı analizin anomali tespitini göstermek için).
      if (i >= 1 && (i % 2 == 0 || i < 3)) {
        sugars.add(
          HealthEntry(
            value: i == 1 ? 148 : const {12: 98.0, 10: 109.0, 8: 101.0, 6: 112.0, 4: 96.0, 2: 106.0}[i]!,
            date: DateTime(day.year, day.month, day.day, 7, 45),
            note: 'Açlık',
          ).toMap(),
        );
      }
    }
    final weights = [
      for (var i = 0; i < 6; i++)
        HealthEntry(
          value: double.parse((77.9 - i * 0.38).toStringAsFixed(1)),
          date: today.subtract(Duration(days: 25 - i * 5)),
        ).toMap(),
    ];

    // 12 gece uyku; kısa uyunan günler ruh halinin düşük olduğu günlerle
    // örtüşür (akıllı analiz bu ilişkiyi bulur). Sıra: en eski → bugün.
    final sleep = <Map<String, dynamic>>[];
    const sleepPlan = [
      [0, 30, 6, 50, 3], // ruh hali 3
      [0, 20, 6, 45, 3], // 3
      [23, 10, 6, 40, 4], // 4
      [1, 10, 6, 30, 2], // 2
      [0, 15, 6, 40, 3], // 3
      [23, 0, 6, 35, 4], // 4
      [23, 20, 6, 50, 4], // 4
      [0, 35, 6, 55, 3], // 3
      [23, 5, 6, 40, 4], // 4
      [22, 40, 6, 50, 5], // 5
      [23, 15, 6, 45, 4], // 4
      [23, 0, 6, 30, 4], // 4
    ];
    for (var i = 0; i < sleepPlan.length; i++) {
      final p = sleepPlan[i];
      sleep.add(
        SleepEntry.fromTimes(
          wakeDate: today.subtract(Duration(days: sleepPlan.length - 1 - i)),
          bedHour: p[0],
          bedMinute: p[1],
          wakeHour: p[2],
          wakeMinute: p[3],
          quality: p[4],
        ).toMap(),
      );
    }

    // Kamera ile nabız ölçümleri: dün akşam nefes egzersizi öncesi/sonrası.
    final yesterdayEvening = DateTime(today.year, today.month, today.day - 1, 21, 0);
    final heart = [
      HeartMeasurement(date: yesterdayEvening.add(const Duration(minutes: 3)), bpm: 72, rmssdMs: 31.4, stress: StressLevel.moderate, quality: 0.91, context: 'after_breathing'),
      HeartMeasurement(date: yesterdayEvening, bpm: 79, rmssdMs: 17.2, stress: StressLevel.high, quality: 0.88),
      HeartMeasurement(date: today.subtract(const Duration(days: 3, hours: 2)), bpm: 76, rmssdMs: 22.5, stress: StressLevel.moderate, quality: 0.9),
      HeartMeasurement(date: today.subtract(const Duration(days: 6, hours: 1)), bpm: 78, rmssdMs: 18.1, stress: StressLevel.high, quality: 0.86),
    ];

    // Risk skorları gerçek hesaplayıcılarla (verilerle tutarlı).
    const bmi = 76.0 / (1.64 * 1.64);
    final findrisc = FindriscCalculator.calculate(
      FindriscInput(
        age: today.year - birth.year - 1,
        bmi: bmi,
        waistCm: 91,
        isMale: false,
        activeDaily30Min: false,
        eatsVegFruitDaily: true,
        takesBpMedication: true,
        hadHighBloodGlucose: false,
        familyHistory: FamilyDiabetesHistory.firstDegree,
      ),
    );
    final framingham = FraminghamCalculator.calculate(
      FraminghamInput(
        age: today.year - birth.year - 1,
        isMale: false,
        bmi: bmi,
        systolicBp: 136,
        bpTreated: true,
        smoker: false,
        diabetic: false,
      ),
    );

    await health.putAll({
      'blood_pressure': pressures,
      'blood_sugar': sugars,
      'weight_history': weights,
      'sleep_log': sleep,
      HeartMeasurement.storageKey: [for (final h in heart) h.toMap()],
      'risk_history': [
        {
          'type': 'FINDRISC',
          'score': findrisc.score,
          'level': findrisc.level.label,
          'date': today.subtract(const Duration(days: 2)).toIso8601String(),
        },
        {
          'type': 'Framingham',
          'score': double.parse(framingham.percent.toStringAsFixed(1)),
          'level': framingham.level.label,
          'date': today.subtract(const Duration(days: 2)).toIso8601String(),
        },
      ],
      'symptom_history': [
        {
          'symptoms': ['Baş ağrısı', 'Baş dönmesi'],
          'triage': 'yellow',
          'flag': null,
          'date': today.subtract(const Duration(days: 9)).toIso8601String(),
        },
        {
          'symptoms': ['Öksürük', 'Ateş', 'Kas ağrısı'],
          'triage': 'yellow',
          'flag': 'Enfeksiyon Belirtileri',
          'date': today.subtract(const Duration(days: 4)).toIso8601String(),
        },
      ],
    });

    // İlaçlar — etkileşim uyarısını göstermek için aspirin + ağrı kesici
    // ve tansiyon ilacı + ağrı kesici birlikte.
    final started = today.subtract(const Duration(days: 14));
    final meds = [
      MedicationReminder(notificationId: 20001, name: 'Delix (Ramipril)', dosage: '5 mg', hour: 8, minute: 0, createdAt: started),
      MedicationReminder(notificationId: 20002, name: 'Coraspin', dosage: '100 mg', hour: 13, minute: 0, createdAt: started),
      MedicationReminder(notificationId: 20003, name: 'Nurofen', dosage: '400 mg', hour: 20, minute: 0, createdAt: started),
    ];
    await hive.getMedicationBox().put('medications', [for (final m in meds) m.toMap()]);

    // İlaç uyumu: sabah ilacı düzenli; akşam ilacı 2 kez kaçırılmış ve
    // genelde ~1,5 saat geç alınmış (örüntü önerisini göstermek için).
    final doseLog = DoseLog.empty();
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      for (final m in meds) {
        final due = DateTime(day.year, day.month, day.day, m.hour, m.minute);
        final missed = (m.notificationId == 20002 && i == 4) ||
            (m.notificationId == 20003 && (i == 2 || i == 5));
        if (missed) continue;
        final delay = m.notificationId == 20003 ? 80 + rnd.nextInt(20) : 5 + rnd.nextInt(20);
        final at = due.add(Duration(minutes: delay));
        if (at.isAfter(today)) continue; // henüz gerçekleşmemiş doz
        doseLog.set(day, m.notificationId, DoseRecord(status: DoseStatus.taken, at: at));
      }
    }
    await hive.getMedicationBox().put('dose_log', doseLog.toRaw());

    // Ruh hali: 12 günlük seri + testler
    final mood = hive.getMoodBox();
    const moods = [3, 3, 4, 2, 3, 4, 4, 3, 4, 5, 4, 4];
    for (var i = 0; i < moods.length; i++) {
      await mood.put(_day(today.subtract(Duration(days: moods.length - 1 - i))), moods[i]);
    }
    await mood.put('test_history', [
      {
        'test_type': 'PHQ-9',
        'score': 6,
        'severity': 'Hafif (6/27)',
        'date': today.subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'test_type': 'GAD-7',
        'score': 4,
        'severity': 'Minimal (4/21)',
        'date': today.subtract(const Duration(days: 5)).toIso8601String(),
      },
    ]);

    // Beslenme ve su
    final nutrition = hive.getNutritionBox();
    List<Map<String, dynamic>> meals(List<List<Object>> items) => [
      for (final m in items)
        {
          'name': m[0],
          'calories': m[1],
          'protein': m[2],
          'carbs': m[3],
          'fat': m[4],
          'fiber': m[5],
          'gi': m[6],
          'portion': m[7],
          'category': m[8],
        },
    ];
    final dailyMeals = meals([
      ['Menemen', 180, 10, 8, 12, 2, 20, '1 porsiyon', 'breakfast'],
      ['Tam buğday ekmeği', 75, 3, 13, 1, 2, 54, '1 dilim (30g)', 'grains'],
      ['Mercimek çorbası', 150, 9, 20, 4, 5, 44, '1 kase (250ml)', 'soups'],
      ['Zeytinyağlı fasulye', 120, 4, 14, 6, 5, 30, '1 porsiyon', 'vegetables'],
      ['Elma', 95, 0, 25, 0, 4, 36, '1 orta boy', 'fruits'],
    ]);
    for (var i = 0; i < 7; i++) {
      final key = _day(today.subtract(Duration(days: i)));
      await nutrition.put('meals_$key', dailyMeals);
      await nutrition.put('water_$key', i == 0 ? 5 : 6 + rnd.nextInt(4));
    }

    // Adımlar ve egzersiz
    final fitness = hive.getFitnessBox();
    const steps = [7400, 9100, 5200, 10400, 8800, 11800, 6400];
    for (var i = 0; i < steps.length; i++) {
      await fitness.put('steps_${_day(today.subtract(Duration(days: 6 - i)))}', steps[i]);
    }
    await fitness.put('workout_history', [
      {
        'exercise_name': 'Yürüyüş',
        'duration_minutes': 35,
        'calories_burned': 146,
        'date': DateTime(today.year, today.month, today.day, 7, 30)
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      },
      {
        'exercise_name': 'Yoga',
        'duration_minutes': 30,
        'calories_burned': 100,
        'date': today.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ]);

    // Sigara bırakma: 18 gün önce
    await hive.getAddictionBox().putAll({
      'quit_date': today.subtract(const Duration(days: 18)).toIso8601String(),
      'daily_cigarettes': 15,
      'daily_cigarette_price': 5.0,
      'craving_log': [
        '${today.subtract(const Duration(days: 3)).toIso8601String()}|Direndim',
      ],
    });

    await hive.getSettingsBox().put('demo_loaded_at', today.toIso8601String());
    await hive.setOnboardingCompleted(true);
  }
}
