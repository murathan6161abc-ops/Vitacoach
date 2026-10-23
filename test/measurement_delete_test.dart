import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vitacoach/modules/m01_profile/providers/profile_provider.dart';
import 'package:vitacoach/modules/m03_chronic/providers/chronic_provider.dart';
import 'package:vitacoach/modules/m03_chronic/screens/chronic_screen.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

Future<void> _pumpChronic(WidgetTester tester) => tester.pumpWidget(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ProfileProvider()..loadProfile()),
      ChangeNotifierProvider(create: (_) => ChronicProvider()..loadData()),
    ],
    child: const MaterialApp(home: ChronicScreen()),
  ),
);

Future<void> _tapDeleteIn(WidgetTester tester, String tileText) async {
  final tile = find.widgetWithText(ListTile, tileText);
  await tester.scrollUntilVisible(tile, 300);
  await tester.tap(find.descendant(of: tile, matching: find.byTooltip('Sil')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  testWidgets('yanlış tansiyon ölçümü silinir ve geri alınabilir', (
    tester,
  ) async {
    final box = HiveService().getHealthBox();
    await box.put('blood_pressure', [
      {
        'systolic': 120.0,
        'diastolic': 80.0,
        'date': DateTime(2026, 10, 20, 9).toIso8601String(),
      },
      {
        'systolic': 150.0,
        'diastolic': 95.0,
        'date': DateTime(2026, 10, 21, 9).toIso8601String(),
      },
    ]);
    List<num> systolics() => [
      for (final e in box.get('blood_pressure') as List)
        (e as Map)['systolic'] as num,
    ];

    await _pumpChronic(tester);
    await _tapDeleteIn(tester, '150/95 mmHg');
    expect(systolics(), [120.0]);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(systolics(), [120.0, 150.0]);
  });

  testWidgets('son kilo silinince profildeki kilo önceki ölçüme döner', (
    tester,
  ) async {
    final now = DateTime.now();
    await HiveService().getHealthBox().put('weight_history', [
      {
        'value': 74.0,
        'date': now.subtract(const Duration(days: 20)).toIso8601String(),
      },
      {'value': 72.5, 'date': now.toIso8601String()},
    ]);
    await HiveService().getProfileBox().put('weight', 72.5);

    await _pumpChronic(tester);
    await _tapDeleteIn(tester, '72,5 kg');

    expect(HiveService().getProfileBox().get('weight'), 74.0);
    expect(
      (HiveService().getHealthBox().get('weight_history') as List).length,
      1,
    );
  });
}
