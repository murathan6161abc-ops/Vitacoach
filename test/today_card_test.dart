import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/models/medication_adherence.dart';
import 'package:vitacoach/modules/m03_chronic/providers/chronic_provider.dart';
import 'package:vitacoach/modules/m06_nutrition/providers/nutrition_provider.dart';
import 'package:vitacoach/modules/m07_fitness/providers/fitness_provider.dart';
import 'package:vitacoach/services/hive_service.dart';
import 'package:vitacoach/shared/widgets/today_card.dart';

import 'helpers/memory_hive.dart';

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ChronicProvider()..loadData()),
      ChangeNotifierProvider(create: (_) => NutritionProvider()..reloadToday()),
      ChangeNotifierProvider(create: (_) => FitnessProvider()..loadData()),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: TodayCard())),
    ),
  ),
);

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  testWidgets('vakti gelen ilaç ana sayfadan "Aldım" ile işaretlenir', (
    tester,
  ) async {
    // 00:00 dozu günün her anında "vakti gelmiş" sayılır.
    final med = MedicationReminder(
      notificationId: 10123,
      name: 'Metformin',
      dosage: '500 mg',
      hour: 0,
      minute: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    await HiveService().getMedicationBox().put('medications', [med.toMap()]);

    await _pump(tester);
    expect(find.text('Metformin · 00:00'), findsOneWidget);

    await tester.tap(find.text('Aldım'));
    await tester.pumpAndSettle();

    expect(find.text('Alındı'), findsOneWidget);
    final log = DoseLog.fromRaw(
      HiveService().getMedicationBox().get('dose_log'),
    );
    expect(log.get(DateTime.now(), 10123)?.status, DoseStatus.taken);
  });

  testWidgets('su ve adım bugünün kaydını gösterir', (tester) async {
    final day = NutritionProvider.dayKey(DateTime.now());
    await HiveService().getNutritionBox().put('water_$day', 3);
    await HiveService().getFitnessBox().put('steps_$day', 5230);

    await _pump(tester);
    expect(find.text('Su: 3/10 bardak'), findsOneWidget);
    expect(find.text('Adım: 5.230 / 10.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Bir bardak su ekle'));
    await tester.pump();
    expect(HiveService().getNutritionBox().get('water_$day'), 4);
    expect(find.text('Su: 4/10 bardak'), findsOneWidget);
  });
}
