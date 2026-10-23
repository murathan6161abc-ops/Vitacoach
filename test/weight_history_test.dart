import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vitacoach/core/constants/app_constants.dart';
import 'package:vitacoach/modules/m01_profile/providers/profile_provider.dart';
import 'package:vitacoach/modules/m01_profile/screens/onboarding_screen.dart';
import 'package:vitacoach/modules/m01_profile/screens/profile_screen.dart';
import 'package:vitacoach/modules/m03_chronic/providers/chronic_provider.dart';
import 'package:vitacoach/modules/m03_chronic/screens/chronic_screen.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

List<double> _historyValues() {
  final raw = HiveService().getHealthBox().get('weight_history');
  if (raw is! List) return const [];
  return [for (final e in raw) ((e as Map)['value'] as num).toDouble()];
}

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  testWidgets('profilde kilo güncellenince kilo geçmişine kayıt düşer', (
    tester,
  ) async {
    await HiveService().getProfileBox().putAll({
      'height': 170.0,
      'weight': 80.0,
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ProfileProvider()..loadProfile(),
          ),
          ChangeNotifierProvider(create: (_) => ChronicProvider()..loadData()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    // İlk kalem simgesi başlıktaki boy/kilo düzenleme düğmesidir.
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kilo (kg)'), '78,5');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(_historyValues(), [78.5]);
    expect(HiveService().getProfileBox().get('weight'), 78.5);
  });

  testWidgets('ilk kurulumda girilen kilo, geçmişin ilk kaydı olur', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppConstants.routeOnboarding,
      routes: [
        GoRoute(
          path: AppConstants.routeOnboarding,
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppConstants.routeHome,
          builder: (_, _) => const Text('ana sayfa'),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ChronicProvider()..loadData(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Boy (cm)'), '165');
    await tester.enterText(find.widgetWithText(TextField, 'Kilo (kg)'), '70');
    for (var page = 0; page < 3; page++) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }
    // Hatırlatıcılar kapalı: bildirim eklentisi test ortamında yok.
    for (final tile in find.byType(SwitchListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(tile.widget));
    }
    await tester.tap(find.text('Tamamla'));
    await tester.pumpAndSettle();

    expect(find.text('ana sayfa'), findsOneWidget);
    expect(_historyValues(), [70.0]);
  });

  testWidgets('kronik takipte kilo eklenir; profil ve trend güncellenir', (
    tester,
  ) async {
    await HiveService().getHealthBox().put('weight_history', [
      {
        'value': 74.0,
        'date': DateTime.now()
            .subtract(const Duration(days: 20))
            .toIso8601String(),
      },
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ProfileProvider()..loadProfile(),
          ),
          ChangeNotifierProvider(create: (_) => ChronicProvider()..loadData()),
        ],
        child: const MaterialApp(home: ChronicScreen()),
      ),
    );

    final addButton = find.byTooltip('Kilo ekle');
    await tester.scrollUntilVisible(addButton, 300);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '72,5');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(_historyValues(), [74.0, 72.5]);
    expect(HiveService().getProfileBox().get('weight'), 72.5);
    expect(find.text('72,5 kg'), findsWidgets);
    expect(find.text('Son 30 günde -1,5 kg'), findsOneWidget);
  });
}
