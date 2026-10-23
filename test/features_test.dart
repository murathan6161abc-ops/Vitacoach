import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m18_insights/services/insight_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vitacoach/modules/m03_chronic/services/drug_interaction_service.dart';
import 'package:vitacoach/modules/m06_nutrition/models/food_model.dart';
import 'package:vitacoach/modules/m06_nutrition/services/meal_planner.dart';
import 'package:vitacoach/modules/m12_progress/providers/progress_provider.dart';
import 'package:vitacoach/modules/m14_risk/models/risk_models.dart';
import 'package:vitacoach/modules/m15_sleep/models/sleep_entry.dart';
import 'package:vitacoach/modules/m16_emergency/models/emergency_info.dart';
import 'package:vitacoach/services/demo_data_service.dart';
import 'package:vitacoach/services/hive_service.dart';

DrugInteractionChecker _checker() => DrugInteractionChecker.fromJson(
  json.decode(File('assets/data/drug_interactions.json').readAsStringSync())
      as Map<String, dynamic>,
);

Map<String, List<Food>> _foods() {
  final data = json.decode(File('assets/data/foods_tr.json').readAsStringSync());
  return {
    for (final c in data['categories'])
      '${c['id']}': [
        for (final f in c['foods']) Food.fromJson(Map<String, dynamic>.from(f)),
      ],
  };
}

void main() {
  group('FINDRISC', () {
    FindriscInput input({
      int age = 40,
      double bmi = 22,
      double waist = 75,
      bool male = false,
      bool active = true,
      bool veg = true,
      bool bpMed = false,
      bool glucose = false,
      FamilyDiabetesHistory family = FamilyDiabetesHistory.none,
    }) => FindriscInput(
      age: age,
      bmi: bmi,
      waistCm: waist,
      isMale: male,
      activeDaily30Min: active,
      eatsVegFruitDaily: veg,
      takesBpMedication: bpMed,
      hadHighBloodGlucose: glucose,
      familyHistory: family,
    );

    test('en düşük ve en yüksek puan 0 ve 26', () {
      expect(FindriscCalculator.calculate(input()).score, 0);
      final worst = FindriscCalculator.calculate(
        input(
          age: 70,
          bmi: 32,
          waist: 110,
          male: true,
          active: false,
          veg: false,
          bpMed: true,
          glucose: true,
          family: FamilyDiabetesHistory.firstDegree,
        ),
      );
      expect(worst.score, 26);
      expect(worst.level, RiskLevel.veryHigh);
    });

    test('yaş, BMI ve bel çevresi sınırları yayımlanan tabloyla aynı', () {
      int s(FindriscInput i) => FindriscCalculator.calculate(i).score;
      expect(s(input(age: 44)), 0);
      expect(s(input(age: 45)), 2);
      expect(s(input(age: 55)), 3);
      expect(s(input(age: 65)), 4);
      expect(s(input(bmi: 25)), 1);
      expect(s(input(bmi: 30)), 1);
      expect(s(input(bmi: 30.1)), 3);
      expect(s(input(waist: 80)), 3); // kadın
      expect(s(input(waist: 89)), 4);
      expect(s(input(male: true, waist: 93)), 0);
      expect(s(input(male: true, waist: 94)), 3);
    });

    test('risk kategorileri', () {
      expect(const FindriscResult(6, {}).level, RiskLevel.low);
      expect(const FindriscResult(7, {}).level, RiskLevel.slightlyElevated);
      expect(const FindriscResult(12, {}).level, RiskLevel.moderate);
      expect(const FindriscResult(15, {}).level, RiskLevel.high);
      expect(const FindriscResult(21, {}).level, RiskLevel.veryHigh);
    });
  });

  group('Framingham (BMI tabanlı)', () {
    FraminghamResult calc({
      int age = 50,
      bool male = true,
      double bmi = 27,
      double sbp = 130,
      bool treated = false,
      bool smoker = false,
      bool diabetic = false,
    }) => FraminghamCalculator.calculate(
      FraminghamInput(
        age: age,
        isMale: male,
        bmi: bmi,
        systolicBp: sbp,
        bpTreated: treated,
        smoker: smoker,
        diabetic: diabetic,
      ),
    );

    test('ideal risk faktörlerinde damar yaşı gerçek yaşa eşit', () {
      expect(calc(bmi: 22.5, sbp: 125).vascularAge, 50);
      expect(calc(male: false, age: 60, bmi: 22.5, sbp: 125).vascularAge, 60);
    });

    test('risk faktörleri riski artırır', () {
      final base = calc().risk;
      expect(calc(smoker: true).risk, greaterThan(base));
      expect(calc(diabetic: true).risk, greaterThan(base));
      expect(calc(sbp: 160).risk, greaterThan(base));
      expect(calc(age: 65).risk, greaterThan(base));
    });

    test('50 yaş erkek BMI 27 SKB 130 için makul aralıkta (~%10)', () {
      expect(calc().percent, inInclusiveRange(9, 12));
      expect(calc(male: false).percent, inInclusiveRange(4, 7));
    });

    test('yaş aralığı denetimi', () {
      expect(FraminghamCalculator.isAgeSupported(29), isFalse);
      expect(FraminghamCalculator.isAgeSupported(30), isTrue);
      expect(FraminghamCalculator.isAgeSupported(75), isFalse);
    });
  });

  group('İlaç etkileşimleri', () {
    final checker = _checker();

    test('marka adını etken madde grubuna eşler', () {
      expect(checker.groupsFor('Nurofen 400 mg'), contains('nsaid'));
      expect(checker.groupsFor('Coraspin'), contains('aspirin'));
      expect(checker.groupsFor('Delix (Ramipril)'), contains('ace_arb'));
      expect(checker.groupsFor('İBUPROFEN'), contains('nsaid'));
    });

    test('bilinen tehlikeli kombinasyonları uyarır', () {
      final w = checker.checkPair('Coumadin', 'Nurofen');
      expect(w, isNotEmpty);
      expect(w.first.severity, InteractionSeverity.high);
      expect(
        checker.checkPair('Viagra', 'Isordil').first.severity,
        InteractionSeverity.high,
      );
      expect(checker.checkPair('Lustral', 'Contramal'), isNotEmpty);
    });

    test('etkileşimsiz ilaçlarda uyarı vermez', () {
      expect(checker.checkPair('Parol', 'Glucophage'), isEmpty);
      expect(checker.checkPair('Norvasc', 'Euthyrox'), isEmpty);
    });

    test('aynı ilacın iki hatırlatıcısı birbiriyle karşılaştırılmaz', () {
      expect(checker.checkPair('Nurofen', 'nurofen'), isEmpty);
      expect(checker.checkAll(['Metformin', 'Metformin']), isEmpty);
    });

    test('aynı gruptan iki farklı ağrı kesici uyarılır', () {
      final w = checker.checkPair('Nurofen', 'Majezik');
      expect(w.single.message, contains('aynı ilaç grubunda'));
    });

    test('demo ilaç listesinde iki etkileşim bulunur', () {
      final w = checker.checkAll(['Delix (Ramipril)', 'Coraspin', 'Nurofen']);
      expect(w.length, 2);
    });
  });

  group('Uyku', () {
    test('gece yarısını geçen uyku doğru hesaplanır', () {
      final e = SleepEntry.fromTimes(
        wakeDate: DateTime(2026, 9, 29),
        bedHour: 23,
        bedMinute: 30,
        wakeHour: 7,
        wakeMinute: 0,
        quality: 4,
      );
      expect(e.hours, 7.5);
      expect(e.bedTime.day, 28);
      expect(e.dayKey, '2026-09-29');
    });

    test('önerilen süre yüksek, kısa uyku düşük puan alır', () {
      SleepEntry entry(int wake, int quality) => SleepEntry.fromTimes(
        wakeDate: DateTime(2026, 9, 29),
        bedHour: 23,
        bedMinute: 0,
        wakeHour: wake,
        wakeMinute: 0,
        quality: quality,
      );
      expect(SleepScore.compute(entry(7, 3)), 9); // 8 saat
      expect(SleepScore.compute(entry(3, 3)), 2); // 4 saat
      expect(SleepScore.compute(entry(7, 5)), 10);
    });

    test('bozuk kayıtları atlar', () {
      final list = SleepEntry.parseList([
        {'bed': 'bozuk', 'wake': '2026-09-29T07:00:00', 'quality': 3},
        {'bed': '2026-09-28T23:00:00', 'wake': '2026-09-29T07:00:00'},
      ]);
      expect(list.length, 1);
    });
  });

  group('Öğün planlayıcı', () {
    final foods = _foods();

    test('günlük hedef aktivite ve kilo verme hedefini uygular', () {
      expect(
        MealPlanner.dailyTarget(bmr: 1400, wantsToLoseWeight: false, isMale: false),
        1950,
      );
      expect(
        MealPlanner.dailyTarget(bmr: 1400, wantsToLoseWeight: true, isMale: false),
        1450,
      );
      expect(
        MealPlanner.dailyTarget(bmr: 1000, wantsToLoseWeight: true, isMale: false),
        1200,
      );
      expect(
        MealPlanner.dailyTarget(
          bmr: 0,
          wantsToLoseWeight: false,
          isMale: true,
          hasProfileData: false,
        ),
        2000,
      );
    });

    test('plan hedefe yakın ve dört öğün içerir', () {
      for (final seed in [0, 1, 2, 7]) {
        final plan = MealPlanner.generate(
          foodsByCategory: foods,
          targetCalories: 1800,
          diabetic: false,
          seed: seed,
        );
        expect(plan.meals.length, 4);
        expect(plan.calories, inInclusiveRange(1800 * 0.75, 1800 * 1.25));
      }
    });

    test('diyabette yüksek glisemik indeksli yiyecek önerilmez', () {
      for (final seed in List.generate(10, (i) => i)) {
        final plan = MealPlanner.generate(
          foodsByCategory: foods,
          targetCalories: 1600,
          diabetic: true,
          seed: seed,
        );
        for (final meal in plan.meals) {
          for (final f in meal.items) {
            expect(f.isHighGI, isFalse, reason: '${f.name} GI ${f.gi}');
          }
        }
      }
    });
  });

  group('Acil sağlık kartı', () {
    test('QR metni kritik bilgileri içerir ve sınırı aşmaz', () {
      final text = EmergencyCardText.build(
        name: 'Ayşe Demir',
        birthDate: DateTime(1974, 4, 12),
        age: 52,
        info: const EmergencyInfo(
          bloodType: 'A Rh+',
          allergies: 'Penisilin',
          contacts: [
            EmergencyContact(name: 'Mehmet', phone: '0500 000 00 00'),
          ],
        ),
        conditions: ['Hipertansiyon'],
        medications: List.generate(80, (i) => 'İlaç $i 10 mg'),
      );
      expect(text, contains('Kan grubu: A Rh+'));
      expect(text, contains('Penisilin'));
      expect(text.length, lessThanOrEqualTo(EmergencyCardText.maxLength));
    });

    test('telefon doğrulama', () {
      expect(EmergencyContact.isValidPhone('0555 123 45 67'), isTrue);
      expect(EmergencyContact.isValidPhone('+90 555 123 45 67'), isTrue);
      expect(EmergencyContact.isValidPhone('112'), isFalse);
      expect(
        const EmergencyContact(name: 'x', phone: '+90 (555) 123-45-67').dialable,
        '+905551234567',
      );
    });
  });

  group('Jüri demo verisi', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vitacoach_demo_test_');
      FlutterSecureStorage.setMockInitialValues({});
      TestWidgetsFlutterBinding.ensureInitialized();
      await HiveService().init(testPath: dir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    test('tutarlı veri yükler ve rozetler gerçek verilerden kazanılır', () async {
      await DemoDataService.load();
      expect(HiveService().isOnboardingCompleted, isTrue);
      expect(HiveService().getProfileBox().get('name'), 'Ayşe Demir');
      expect(EmergencyInfo.load().bloodType, 'A Rh+');
      expect(
        (HiveService().getHealthBox().get('blood_pressure') as List).length,
        14,
      );

      final progress = ProgressProvider()..loadData();
      final names = progress.badges.map((b) => b['name']).toSet();
      expect(progress.moodStreak, 12);
      expect(names, containsAll(['Başlangıç', 'Hafta Ustası', 'Yarı Maraton']));
      expect(names, containsAll(['Mental Güç', 'Sağlık Bilgesi', 'Hazırlıklı']));
      expect(names, contains('Düzenli İlaç'));
      expect(names, contains('Vitamin Deposu'));
      expect(progress.healthScores['Uyku'], greaterThan(0));

      // Akıllı analiz demo verisinde her yöntemi gösterebilmeli.
      final insightIds = InsightRepository.analyze().map((i) => i.id).toSet();
      expect(
        insightIds,
        containsAll([
          'sugar_anomaly',
          'bp_falling',
          'weight_goal',
          'sleep_mood',
          'steps_mood',
          'hrv_stress',
          'breathing_effect',
        ]),
      );
      expect(insightIds.any((id) => id.startsWith('adherence_')), isTrue);
    });
  });
}
