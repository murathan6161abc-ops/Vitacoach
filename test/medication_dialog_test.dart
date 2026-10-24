import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/widgets/medication_dialog.dart';

/// Pencereyi açar; "Kaydet" ile dönen ilaç [onSaved]'e verilir.
Future<void> _open(
  WidgetTester tester,
  void Function(MedicationReminder?) onSaved,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onSaved(
            await showDialog<MedicationReminder>(
              context: context,
              builder: (_) => const MedicationDialog(),
            ),
          ),
          child: const Text('Aç'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bir ilaca birden çok doz saati eklenir', (tester) async {
    MedicationReminder? saved;
    await _open(tester, (m) => saved = m);

    await tester.enterText(
      find.widgetWithText(TextField, 'İlaç adı'),
      'Metformin',
    );
    // Önerilen saat, saatler arasındaki en uzun boşluğun ortasıdır:
    // 08:00'e 20:00, ardından 14:00 eklenir.
    for (final expected in ['20:00', '14:00']) {
      await tester.tap(find.text('Saat ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    }
    expect(find.text('Günde 3 doz'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Metformin');
    expect(saved?.timesDisplay, '08:00, 14:00, 20:00');
  });

  testWidgets('eklenen saat silinir; tek kalan saat silinemez', (tester) async {
    await _open(tester, (_) {});

    await tester.tap(find.text('Saat ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('20:00 saatini kaldır'), findsOneWidget);

    await tester.tap(find.byTooltip('20:00 saatini kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('20:00'), findsNothing);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.byTooltip('08:00 saatini kaldır'), findsNothing);
  });
}
