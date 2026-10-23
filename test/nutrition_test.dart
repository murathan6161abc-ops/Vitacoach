import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitacoach/modules/m06_nutrition/providers/nutrition_provider.dart';
import 'package:vitacoach/modules/m06_nutrition/screens/nutrition_screen.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

List<String?> _names(dynamic raw) => [
  for (final meal in raw as List) (meal as Map)['name'] as String?,
];

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  test('gece yarısını geçen oturumda dünkü öğünler bozulmaz', () async {
    var now = DateTime(2026, 10, 22, 23, 50);
    final provider = NutritionProvider(clock: () => now);
    await provider.addMeal({'name': 'Menemen', 'calories': 250});

    now = DateTime(2026, 10, 23, 0, 10);
    await provider.addMeal({'name': 'Simit', 'calories': 280});

    final box = HiveService().getNutritionBox();
    expect(_names(box.get('meals_2026-10-22')), ['Menemen']);
    expect(_names(box.get('meals_2026-10-23')), ['Simit']);
    expect(provider.totalCalories, 280);
  });

  test('bildirimden eklenen su, ekrandan eklenen bardakla ezilmez', () async {
    final day = NutritionProvider.dayKey(DateTime.now());
    final box = HiveService().getNutritionBox();
    await box.put('water_$day', 3);
    final provider = NutritionProvider()..reloadToday();
    expect(provider.waterCount, 3);

    // Uygulama arka plandayken bildirimden "+1 bardak" işlendi.
    await box.put('water_$day', 4);
    await provider.addWater();

    expect(box.get('water_$day'), 5);
    expect(provider.waterCount, 5);
  });

  testWidgets('beslenme ekranı bildirimden gelen suyu gösterir', (
    tester,
  ) async {
    final day = NutritionProvider.dayKey(DateTime.now());
    final box = HiveService().getNutritionBox();
    await box.put('water_$day', 3);
    final provider = NutritionProvider()..reloadToday();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: NutritionScreen()),
      ),
    );
    expect(find.text('750 / 2500 ml'), findsOneWidget);

    // app.dart bildirim eylemi işlendikten sonra reloadToday çağırır.
    await box.put('water_$day', 4);
    provider.reloadToday();
    await tester.pump();
    expect(find.text('1000 / 2500 ml'), findsOneWidget);

    await tester.tap(find.text('+ 1 Bardak (250ml)'));
    await tester.pump();
    expect(box.get('water_$day'), 5);
    expect(find.text('1250 / 2500 ml'), findsOneWidget);
  });
}
