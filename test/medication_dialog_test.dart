import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/widgets/medication_dialog.dart';

/// Pencereyi açar; "Kaydet"/"Güncelle" ile dönen ilaç [onSaved]'e verilir.
/// [initial] verilirse kayıtlı ilacın saatleri düzenlenir.
Future<void> _open(
  WidgetTester tester,
  void Function(MedicationReminder?) onSaved, {
  MedicationReminder? initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // Saat seçici, uygulamadaki (tr) gibi 24 saat biçiminde.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onSaved(
            await showDialog<MedicationReminder>(
              context: context,
              builder: (_) => MedicationDialog(initial: initial),
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

/// Günde iki dozlu kayıtlı ilaç (08:00 ve 12:00).
MedicationReminder _parol() => MedicationReminder(
  name: 'Parol',
  dosage: '500 mg',
  doses: [
    MedicationDose(notificationId: 20001, hour: 8, minute: 0),
    MedicationDose(notificationId: 20002, hour: 12, minute: 0),
  ],
  createdAt: DateTime(2026, 10, 1, 9),
);

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

  testWidgets('düzenleme penceresi ilacın kayıtlı saatleriyle açılır', (
    tester,
  ) async {
    await _open(tester, (_) {}, initial: _parol());

    expect(find.text('Saatleri Düzenle'), findsOneWidget);
    expect(find.text('Parol'), findsOneWidget);
    expect(find.text('500 mg'), findsOneWidget);
    expect(find.text('Günde 2 doz'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '08:00'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '12:00'), findsOneWidget);
    // Burada yalnızca saatler değişir; ad ve doz alanı yoktur.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Güncelle'), findsOneWidget);
    expect(find.text('Kaydet'), findsNothing);
  });

  testWidgets(
    'düzenlemede saati değişen doz kimliğini korur, eklenen saat yeni kimlik alır',
    (tester) async {
      MedicationReminder? saved;
      await _open(tester, (m) => saved = m, initial: _parol());

      // 12:00 → 13:30, saat seçicinin klavye girişiyle.
      await tester.tap(find.text('12:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '13');
      await tester.enterText(find.byType(TextField).last, '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Önerilen yeni saat: 13:30 ile ertesi gün 08:00 arasının ortası.
      await tester.tap(find.text('Saat ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Güncelle'));
      await tester.pumpAndSettle();

      expect(saved?.name, 'Parol');
      expect(saved?.createdAt, DateTime(2026, 10, 1, 9));
      expect(saved?.timesDisplay, '08:00, 13:30, 22:45');
      final ids = [for (final d in saved!.doses) d.notificationId];
      expect(ids.take(2), [20001, 20002]);
      expect(ids.last, isNot(anyOf(20001, 20002)));
    },
  );
}
