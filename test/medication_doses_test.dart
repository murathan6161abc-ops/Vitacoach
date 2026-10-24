import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vitacoach/modules/m01_profile/providers/profile_provider.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/models/medication_adherence.dart';
import 'package:vitacoach/modules/m03_chronic/providers/chronic_provider.dart';
import 'package:vitacoach/modules/m03_chronic/screens/chronic_screen.dart';
import 'package:vitacoach/services/hive_service.dart';
import 'package:vitacoach/services/notification_actions.dart';
import 'package:vitacoach/services/notification_service.dart';
import 'package:vitacoach/services/notification_visuals.dart';

import 'helpers/memory_hive.dart';

/// Günde iki dozlu (08:00 ve 12:00) ilacın Hive'daki kayıtlı biçimi. Üst
/// düzeydeki saat, tek saatli eski sürümler okuyabilsin diye ilk dozdur.
Map<String, dynamic> _parol() => {
  'notification_id': 20001,
  'name': 'Parol',
  'dosage': '500 mg',
  'hour': 8,
  'minute': 0,
  'doses': [
    {'notification_id': 20001, 'hour': 8, 'minute': 0},
    {'notification_id': 20002, 'hour': 12, 'minute': 0},
  ],
  'is_active': true,
  'created_at': '2026-10-01T09:00:00.000',
};

/// 12:00 dozunun bildirimindeki veri. 12:00 ve öncesindeki dozlarda "Aldım"
/// günün hangi saatinde basılırsa basılsın bugüne yazılır.
const _noonPayload =
    '{"k":"medication","r":"/chronic","id":20002,"n":"Parol",'
    '"d":"500 mg","h":12,"m":0}';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

/// Bildirim eklentisine giden çağrılar; testte eklentinin yerel tarafı yok.
final _calls = <MethodCall>[];
var _pendingIds = <int>[];

List<MethodCall> get _scheduled =>
    _calls.where((c) => c.method == 'zonedSchedule').toList();

List<Object?> get _cancelledIds => [
  for (final c in _calls)
    if (c.method == 'cancel') (c.arguments as Map)['id'],
];

NotificationResponse _press(String actionId, String payload) =>
    NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      actionId: actionId,
      payload: payload,
    );

DoseLog _doseLog() =>
    DoseLog.fromRaw(HiveService().getMedicationBox().get('dose_log'));

List<Map<dynamic, dynamic>> _storedMedications() => [
  for (final m in HiveService().getMedicationBox().get('medications') as List)
    m as Map,
];

/// Dozun bugün "Aldım" ile işaretlendiğini doz günlüğüne yazar.
Future<void> _takenToday(int doseId) {
  final today = DateTime.now();
  return HiveService().getMedicationBox().put('dose_log', {
    DoseLog.dayKey(today): {
      '$doseId': {'status': 'taken', 'at': today.toIso8601String()},
    },
  });
}

/// Beklenmeden başlatılan işin (ör. açılışta bildirim kurulumu) bitmesini
/// bekler; koşul hiç sağlanmazsa yaklaşık bir saniye sonra döner.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await pumpEventQueue();
}

Widget _chronicScreen() => MultiProvider(
  providers: [
    ChangeNotifierProvider<ProfileProvider>(
      create: (_) => ProfileProvider()..loadProfile(),
    ),
    ChangeNotifierProvider<ChronicProvider>(
      create: (_) => ChronicProvider()..loadData(),
    ),
  ],
  child: const MaterialApp(home: ChronicScreen()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    await NotificationVisuals.largeIcon(NotificationKind.medication);
  });

  setUp(() async {
    await openMemoryBoxes();
    SharedPreferences.setMockInitialValues({});
    _calls.clear();
    _pendingIds = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          _calls.add(call);
          if (call.method == 'pendingNotificationRequests') {
            return [
              for (final id in _pendingIds)
                {'id': id, 'title': '', 'body': '', 'payload': ''},
            ];
          }
          return null;
        });
  });
  tearDown(closeMemoryBoxes);

  group('Göç', () {
    test('eski tek saatli kayıt kayıpsız doz listesine taşınır', () async {
      final box = HiveService().getMedicationBox();
      await box.put('medications', [
        {
          'notification_id': 45678,
          'name': 'Delix',
          'dosage': '5 mg',
          'hour': 9,
          'minute': 15,
          'is_active': true,
          'created_at': '2026-09-01T10:00:00.000',
        },
      ]);
      // Eski sürüm doz günlüğünü ilacın bildirim kimliğiyle tutar.
      final today = DateTime.now();
      await box.put('dose_log', {
        DoseLog.dayKey(today): {
          '45678': {'status': 'taken', 'at': today.toIso8601String()},
        },
      });

      final provider = ChronicProvider()..loadData();
      await pumpEventQueue();

      final stored = _storedMedications().single;
      expect(stored['doses'], [
        {'notification_id': 45678, 'hour': 9, 'minute': 15},
      ]);
      expect(stored['name'], 'Delix');
      expect(stored['dosage'], '5 mg');
      expect(stored['is_active'], isTrue);
      expect(stored['created_at'], '2026-09-01T10:00:00.000');
      // Doz eski kimliği koruduğu için bugünkü "Aldım" kaydı sayılmaya
      // devam eder.
      expect(provider.adherence().taken, 1);
    });

    test('ilaçlar arasında çakışan doz kimliği yenilenir', () async {
      await HiveService().getMedicationBox().put('medications', [
        _parol(),
        // Eski kayıt, Parol'ün 12:00 dozuyla aynı kimliği taşıyor.
        {
          'notification_id': 20002,
          'name': 'Coraspin',
          'dosage': '100 mg',
          'hour': 21,
          'minute': 0,
        },
      ]);

      ChronicProvider().loadData();
      await pumpEventQueue();

      final ids = [
        for (final m in _storedMedications())
          for (final d in m['doses'] as List) (d as Map)['notification_id'],
      ];
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
      // İlk gelen kimliğini korur.
      expect(ids.take(2), [20001, 20002]);
    });
  });

  group('Bildirimler', () {
    test('her doz saati ayrı günlük bildirim olarak kurulur', () async {
      await NotificationService().scheduleMedicationReminder(
        MedicationReminder.fromMap(_parol()),
      );

      expect(_scheduled.map((c) => c.arguments['id']), [20001, 20002]);
      for (final c in _scheduled) {
        expect(
          c.arguments['matchDateTimeComponents'],
          DateTimeComponents.time.index,
        );
      }
      expect(
        _scheduled.map((c) => c.arguments['scheduledDateTime'] as String),
        [endsWith('T08:00:00'), endsWith('T12:00:00')],
      );
      expect(_scheduled.map((c) => c.arguments['body']), [
        contains('08:00 dozu'),
        contains('12:00 dozu'),
      ]);
      // "Aldım" ve "10 dk sonra" dozu bildirim verisindeki kimlik ve saatten
      // tanır.
      final payloads = [
        for (final c in _scheduled)
          jsonDecode(c.arguments['payload'] as String) as Map,
      ];
      expect(payloads.map((p) => (p['id'], p['h'], p['m'])), [
        (20001, 8, 0),
        (20002, 12, 0),
      ]);
    });

    test('açılışta yalnızca eksik doz bildirimi yeniden kurulur', () async {
      await HiveService().getMedicationBox().put('medications', [_parol()]);
      _pendingIds = [20001];

      ChronicProvider().loadData();
      await _until(() => _scheduled.isNotEmpty);

      expect(_scheduled.map((c) => c.arguments['id']), [20002]);
    });
  });

  group('Bildirim eylemleri', () {
    test('"Aldım" yalnızca bildirimin ait olduğu dozu işaretler', () async {
      await HiveService().getMedicationBox().put('medications', [_parol()]);

      await NotificationActions.handleAction(
        _press(NotificationActionIds.medicationTaken, _noonPayload),
        background: false,
      );
      await NotificationActions.applyPending();

      final today = DateTime.now();
      expect(_doseLog().get(today, 20002)?.status, DoseStatus.taken);
      expect(_doseLog().get(today, 20001), isNull);
    });

    test(
      '"10 dk sonra" ile ertelenen bildirimin "Aldım"ı aynı doza işlenir',
      () async {
        await HiveService().getMedicationBox().put('medications', [_parol()]);

        await NotificationActions.handleAction(
          _press(NotificationActionIds.medicationSnooze, _noonPayload),
          background: false,
        );
        final snoozed = _scheduled.single;
        expect(snoozed.arguments['id'], NotificationIds.snoozeFor(20002));

        await NotificationActions.handleAction(
          _press(
            NotificationActionIds.medicationTaken,
            snoozed.arguments['payload'] as String,
          ),
          background: false,
        );
        await NotificationActions.applyPending();

        final today = DateTime.now();
        expect(_doseLog().get(today, 20002)?.status, DoseStatus.taken);
        expect(_doseLog().get(today, 20001), isNull);
      },
    );
  });

  group('Saatleri düzenleme', () {
    /// Kayıtlı Parol ile sağlayıcıyı açar; açılıştaki bildirim denetimi
    /// bittikten sonra kanal çağrıları sıfırlanır.
    Future<ChronicProvider> openParol() async {
      await HiveService().getMedicationBox().put('medications', [_parol()]);
      _pendingIds = [20001, 20002];
      final provider = ChronicProvider()..loadData();
      await _until(
        () => _calls.any((c) => c.method == 'pendingNotificationRequests'),
      );
      _calls.clear();
      return provider;
    }

    test(
      'kalan dozlar kimliğini ve geçmişini korur; yeni saat yeni kimlik alır',
      () async {
        await _takenToday(20001);
        final provider = await openParol();

        await provider.updateMedicationDoses(0, [
          ...provider.medications.single.doses,
          MedicationDose(hour: 20, minute: 0),
        ]);

        final doses = provider.medications.single.doses;
        final ids = [for (final d in doses) d.notificationId];
        expect(ids.take(2), [20001, 20002]);
        expect(ids.last, isNot(anyOf(20001, 20002)));
        expect(doses.last.timeDisplay, '20:00');
        expect([
          for (final d in _storedMedications().single['doses'] as List)
            (d as Map)['notification_id'],
        ], ids);
        // Bugünkü "Aldım" kaydı 08:00 dozunda kalır.
        expect(provider.todayDose(doses.first)?.status, DoseStatus.taken);
        // Yalnızca yeni saat kurulur; kalan dozların bildirimine dokunulmaz.
        expect(_scheduled.map((c) => c.arguments['id']), [ids.last]);
        expect(
          _scheduled.single.arguments['scheduledDateTime'],
          endsWith('T20:00:00'),
        );
        expect(_cancelledIds, isEmpty);
      },
    );

    test(
      'kaldırılan dozun günlük bildirimi ve ertelenen hatırlatması iptal edilir',
      () async {
        final provider = await openParol();

        await provider.updateMedicationDoses(0, [
          provider.medications.single.doses.first,
        ]);

        expect(provider.medications.single.doses.map((d) => d.notificationId), [
          20001,
        ]);
        expect(_storedMedications().single['doses'], [
          {'notification_id': 20001, 'hour': 8, 'minute': 0},
        ]);
        expect(
          _cancelledIds,
          unorderedEquals([20002, NotificationIds.snoozeFor(20002)]),
        );
        expect(_scheduled, isEmpty);
      },
    );

    test(
      'saati değişen doz kimliğini ve bugünkü kaydını korur, yeni saatle kurulur',
      () async {
        await _takenToday(20002);
        final provider = await openParol();
        final [morning, noon] = provider.medications.single.doses;

        await provider.updateMedicationDoses(0, [
          morning,
          noon.copyWith(hour: 13, minute: 30),
        ]);

        final moved = provider.medications.single.doses.last;
        expect((moved.notificationId, moved.timeDisplay), (20002, '13:30'));
        // Bugün alınmış doz yeni saatinde yeniden "bekliyor" görünmez; aynı
        // gün ikinci kez alınmasın.
        expect(provider.todayDose(moved)?.status, DoseStatus.taken);
        // Aynı kimlikle kurulan bildirim 12:00 bildiriminin yerini alır.
        expect(_scheduled.map((c) => c.arguments['id']), [20002]);
        expect(
          _scheduled.single.arguments['scheduledDateTime'],
          endsWith('T13:30:00'),
        );
        final payload =
            jsonDecode(_scheduled.single.arguments['payload'] as String) as Map;
        expect((payload['id'], payload['h'], payload['m']), (20002, 13, 30));
        expect(_cancelledIds, isEmpty);
      },
    );

    test(
      'hatırlatıcılar kapalıyken yeni saat için bildirim kurulmaz',
      () async {
        await HiveService().getProfileBox().put(
          'medication_reminder_enabled',
          false,
        );
        final provider = await openParol();

        final ok = await provider.updateMedicationDoses(0, [
          ...provider.medications.single.doses,
          MedicationDose(hour: 20, minute: 0),
        ]);

        expect(ok, isTrue);
        expect(provider.medications.single.doses, hasLength(3));
        expect(_scheduled, isEmpty);
      },
    );

    test(
      'sonradan eklenen saat, eklenmeden önceki günlerde kaçırılmış sayılmaz',
      () async {
        // Parol 1 Ekim'den beri kayıtlı; akşam dozu 24 Ekim öğlen eklenir.
        final provider = await openParol();
        final editedAt = DateTime(2026, 10, 24, 12);

        await provider.updateMedicationDoses(0, [
          ...provider.medications.single.doses,
          MedicationDose(hour: 20, minute: 0),
        ], now: editedAt);

        final medication = provider.medications.single;
        final evening = medication.doses.last;
        final night = DateTime(2026, 10, 24, 21);
        final stats = provider
            .adherence(now: night)
            .perDose
            .singleWhere(
              (d) => d.dose.notificationId == evening.notificationId,
            );
        // Yalnızca eklendiği günün 20:00 dozu planlanmış sayılır.
        expect(stats.scheduled, 1);
        expect(
          provider.doseState(
            medication,
            evening,
            DateTime(2026, 10, 23),
            now: night,
          ),
          DoseCellState.notScheduled,
        );
        // Eklenme anı saklanır; uygulama yeniden açıldığında da geçerlidir.
        final stored = _storedMedications().single['doses'] as List;
        expect((stored.last as Map)['added_at'], editedAt.toIso8601String());
      },
    );
  });

  testWidgets('kronik ekranında her doz ayrı satırda "Aldım" ile görünür', (
    tester,
  ) async {
    await HiveService().getMedicationBox().put('medications', [_parol()]);

    await tester.pumpWidget(_chronicScreen());
    final noon = find.text('500 mg · 12:00');
    await tester.scrollUntilVisible(noon, 300);

    expect(find.text('500 mg · 08:00'), findsOneWidget);
    expect(find.text('Aldım'), findsNWidgets(2));

    // Satırlar saate göre sıralı: ikinci "Aldım" 12:00 dozunundur.
    await tester.tap(find.text('Aldım').last);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    expect(_doseLog().get(today, 20002)?.status, DoseStatus.taken);
    expect(_doseLog().get(today, 20001), isNull);
    expect(find.text('Aldım'), findsOneWidget);
  });

  testWidgets('"Saatleri düzenle" pencereyi kayıtlı saatlerle açar', (
    tester,
  ) async {
    await HiveService().getMedicationBox().put('medications', [_parol()]);
    _pendingIds = [20001, 20002];

    await tester.pumpWidget(_chronicScreen());
    await tester.scrollUntilVisible(find.text('500 mg · 12:00'), 300);
    // Satırlar saate göre sıralı: ikinci menü 12:00 dozunundur.
    await tester.tap(find.byTooltip('Diğer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saatleri düzenle'));
    await tester.pumpAndSettle();

    expect(find.text('Saatleri Düzenle'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '08:00'), findsOneWidget);
    expect(find.widgetWithText(InputChip, '12:00'), findsOneWidget);

    await tester.tap(find.byTooltip('12:00 saatini kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();

    expect(find.text('500 mg · 12:00'), findsNothing);
    expect(find.text('500 mg · 08:00'), findsOneWidget);
    expect(_storedMedications().single['doses'], [
      {'notification_id': 20001, 'hour': 8, 'minute': 0},
    ]);
    expect(_cancelledIds, contains(20002));
  });
}
