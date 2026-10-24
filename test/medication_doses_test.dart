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

/// Beklenmeden başlatılan işin (ör. açılışta bildirim kurulumu) bitmesini
/// bekler; koşul hiç sağlanmazsa yaklaşık bir saniye sonra döner.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await pumpEventQueue();
}

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

  testWidgets('kronik ekranında her doz ayrı satırda "Aldım" ile görünür', (
    tester,
  ) async {
    await HiveService().getMedicationBox().put('medications', [_parol()]);

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
}
