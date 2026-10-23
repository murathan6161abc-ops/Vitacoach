import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitacoach/modules/m01_profile/providers/profile_provider.dart';
import 'package:vitacoach/modules/m03_chronic/models/blood_sugar.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/providers/chronic_provider.dart';
import 'package:vitacoach/modules/m03_chronic/screens/chronic_screen.dart';
import 'package:vitacoach/modules/m04_maternal/models/maternal_model.dart';
import 'package:vitacoach/modules/m18_insights/services/insight_engine.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

BloodPressureEntry _bp(double s, double d) =>
    BloodPressureEntry(systolic: s, diastolic: d, date: DateTime(2026));

Future<void> _pumpChronic(WidgetTester tester) => tester.pumpWidget(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ProfileProvider()..loadProfile()),
      ChangeNotifierProvider(create: (_) => ChronicProvider()..loadData()),
    ],
    child: const MaterialApp(home: ChronicScreen()),
  ),
);

void main() {
  group('tansiyon', () {
    test('180/120 ve üstü hipertansif kriz', () {
      expect(_bp(185, 100).category, 'Hipertansif kriz');
      expect(_bp(170, 125).category, 'Hipertansif kriz');
      expect(_bp(179, 119).category, 'Evre 2 Hipertansiyon');
    });

    test('90/60 altı düşük; yüksek büyük tansiyon düşük sayılmaz', () {
      expect(_bp(85, 55).category, 'Düşük tansiyon');
      expect(_bp(150, 55).category, 'Evre 2 Hipertansiyon');
    });
  });

  group('kan şekeri ölçüm zamanına göre', () {
    test('aynı değer açlıkta yüksek, toklukta normal', () {
      expect(assessBloodSugar(135, SugarTiming.fasting).level, SugarLevel.high);
      expect(
        assessBloodSugar(135, SugarTiming.postMeal).level,
        SugarLevel.normal,
      );
    });

    test('hipoglisemi seviyeleri ve çok yüksek değer', () {
      expect(assessBloodSugar(50, null).level, SugarLevel.severeLow);
      expect(assessBloodSugar(65, SugarTiming.postMeal).isLow, isTrue);
      expect(
        assessBloodSugar(320, SugarTiming.postMeal).level,
        SugarLevel.veryHigh,
      );
    });

    test('ölçüm zamanı kayıtla birlikte saklanır', () {
      final entry = HealthEntry(
        value: 135,
        date: DateTime(2026),
        timing: SugarTiming.postMeal.name,
      );
      final restored = HealthEntry.fromMap(entry.toMap());
      expect(SugarTiming.parse(restored.timing), SugarTiming.postMeal);
    });
  });

  group('akıllı analiz açlık ortalaması', () {
    final now = DateTime(2026, 10, 24, 12);
    List<HealthEntry> sugars(double value, SugarTiming timing) => [
      for (var i = 0; i < 4; i++)
        HealthEntry(
          value: value,
          date: now.subtract(Duration(days: i * 2)),
          timing: timing.name,
        ),
    ];
    Set<String> ids(List<HealthEntry> s) => InsightEngine.analyze(
      InsightInput(now: now, sugars: s),
    ).map((i) => i.id).toSet();

    test('tokluk ölçümleri açlık uyarısı üretmez', () {
      expect(
        ids(sugars(160, SugarTiming.postMeal)),
        isNot(contains('sugar_avg_diabetes')),
      );
    });

    test('yüksek açlık ölçümleri uyarı üretir', () {
      expect(
        ids(sugars(140, SugarTiming.fasting)),
        contains('sugar_avg_diabetes'),
      );
    });
  });

  test('1. trimester 13. haftayı kapsar', () {
    PregnancyProfile atWeek(int week) => PregnancyProfile(
      lastPeriodDate: DateTime.now().subtract(Duration(days: week * 7 + 1)),
    );
    expect(atWeek(13).trimester, 1);
    expect(atWeek(14).trimester, 2);
    expect(atWeek(28).trimester, 3);
  });

  group('tehlikeli ölçümden sonra yönlendirme', () {
    setUp(openMemoryBoxes);
    tearDown(closeMemoryBoxes);

    testWidgets('çok yüksek tansiyon girilince kriz uyarısı çıkar', (
      tester,
    ) async {
      await _pumpChronic(tester);
      await tester.tap(find.byTooltip('Tansiyon ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Sistolik (büyük tansiyon)'),
        '185',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Diastolik (küçük tansiyon)'),
        '125',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Tansiyonunuz çok yüksek'), findsOneWidget);
      expect(find.text("112'yi Ara"), findsOneWidget);
      expect(
        (HiveService().getHealthBox().get('blood_pressure') as List).length,
        1,
      );
    });

    testWidgets('düşük kan şekeri girilince 15-15 yönlendirmesi çıkar', (
      tester,
    ) async {
      await _pumpChronic(tester);
      await tester.tap(find.byTooltip('Kan şekeri ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Ciddi düşük kan şekeri'), findsOneWidget);
      expect(find.textContaining('15-15 kuralı'), findsOneWidget);
    });

    testWidgets('tokluk ölçümü kaydedilir ve normal değerlendirilir', (
      tester,
    ) async {
      await _pumpChronic(tester);
      await tester.tap(find.byTooltip('Kan şekeri ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '135');
      await tester.tap(find.text(SugarTiming.postMeal.label));
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Toklukta normal'), findsOneWidget);
      final saved =
          (HiveService().getHealthBox().get('blood_sugar') as List).single
              as Map;
      expect(saved['timing'], 'postMeal');
    });
  });
}
