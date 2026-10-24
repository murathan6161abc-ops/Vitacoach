import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/models/medication_adherence.dart';
import 'package:vitacoach/services/notification_actions.dart';
import 'package:vitacoach/services/notification_service.dart';

MedicationReminder med(int id, int hour, {DateTime? createdAt}) =>
    MedicationReminder(
      name: 'İlaç $id',
      dosage: '1 tablet',
      doses: [MedicationDose(notificationId: id, hour: hour, minute: 0)],
      createdAt: createdAt,
    );

void main() {
  // 30 Eylül 2026 Çarşamba, 21:00
  final now = DateTime(2026, 9, 30, 21);
  final started = DateTime(2026, 9, 1);

  group('İlaç uyumu', () {
    test('tüm dozlar alınınca %100', () {
      final m = med(1, 8, createdAt: started);
      final log = DoseLog.empty();
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2026, 9, 30 - i);
        log.set(
          day,
          1,
          DoseRecord(
            status: DoseStatus.taken,
            at: day.add(const Duration(hours: 8, minutes: 10)),
          ),
        );
      }
      final r = AdherenceCalculator.compute(
        medications: [m],
        log: log,
        now: now,
      );
      expect(r.scheduled, 7);
      expect(r.percent, 100);
      expect(r.patterns, isEmpty);
    });

    test('saati gelmemiş bugünkü doz sayılmaz', () {
      final m = med(1, 22, createdAt: started); // bugün 22:00 henüz gelmedi
      final r = AdherenceCalculator.compute(
        medications: [m],
        log: DoseLog.empty(),
        now: now,
      );
      expect(r.scheduled, 6);
      expect(r.taken, 0);
    });

    test('eklenmeden önceki dozlar sayılmaz', () {
      final m = med(1, 8, createdAt: DateTime(2026, 9, 29, 12));
      final r = AdherenceCalculator.compute(
        medications: [m],
        log: DoseLog.empty(),
        now: now,
      );
      // 29 Eylül 08:00 eklenmeden önceydi; yalnızca 30 Eylül 08:00 sayılır.
      expect(r.scheduled, 1);
    });

    test('eski ilaç takip başlangıcından önce kaçırılmış sayılmaz', () {
      final m = med(1, 8); // createdAt yok
      final r = AdherenceCalculator.compute(
        medications: [m],
        log: DoseLog.empty(),
        now: now,
        trackingSince: DateTime(2026, 9, 30, 20),
      );
      expect(r.scheduled, 0);
      expect(r.percent, isNull);
    });

    test('sık kaçırma ve geç alma örüntüsü açıklanır', () {
      final m = med(3, 20, createdAt: started);
      final log = DoseLog.empty();
      for (var i = 1; i <= 6; i++) {
        if (i == 2 || i == 5) continue; // kaçırıldı
        final day = DateTime(2026, 9, 30 - i);
        log.set(
          day,
          3,
          DoseRecord(
            status: DoseStatus.taken,
            at: day.add(const Duration(hours: 21, minutes: 30)),
          ),
        );
      }
      final r = AdherenceCalculator.compute(
        medications: [m],
        log: log,
        now: now,
      );
      expect(r.perDose.single.missed, 3); // 2 gün + bugünkü 20:00
      expect(
        r.patterns.map((p) => p.message).join(' '),
        contains('kaçırdınız'),
      );
      final late = r.patterns.firstWhere((p) => p.message.contains('geç'));
      expect(late.message, contains('90 dakika'));
      expect(late.suggestion, contains('21:30'));
    });

    test('iki dozlu ilacın her dozu ayrı sayılır', () {
      // Kayıtlı biçimdeki ilaç: 08:00 ve 20:00.
      final m = MedicationReminder.fromMap({
        'notification_id': 11,
        'name': 'Metformin',
        'dosage': '500 mg',
        'hour': 8,
        'minute': 0,
        'doses': [
          {'notification_id': 11, 'hour': 8, 'minute': 0},
          {'notification_id': 12, 'hour': 20, 'minute': 0},
        ],
        'created_at': started.toIso8601String(),
      });
      final log = DoseLog.empty();
      for (var i = 0; i < 7; i++) {
        final day = DateTime(2026, 9, 30 - i);
        log.set(
          day,
          11,
          DoseRecord(
            status: DoseStatus.taken,
            at: day.add(const Duration(hours: 8, minutes: 5)),
          ),
        );
        // Akşam dozu son üç gün kaçırıldı.
        if (i < 3) continue;
        log.set(
          day,
          12,
          DoseRecord(
            status: DoseStatus.taken,
            at: day.add(const Duration(hours: 20, minutes: 5)),
          ),
        );
      }
      final r = AdherenceCalculator.compute(
        medications: [m],
        log: log,
        now: now,
      );
      // Saat 21:00: iki dozun da yedişer günlük vakti geçti.
      expect(r.scheduled, 14);
      expect(r.taken, 11);
      expect(r.patterns.single.message, contains('Metformin (20:00)'));
    });

    test('doz kaydı Hive biçimine gidip gelir ve bozuk girdiyi atlar', () {
      final log = DoseLog.empty();
      log.set(
        DateTime(2026, 9, 30),
        5,
        DoseRecord(status: DoseStatus.skipped, at: now),
      );
      final raw = log.toRaw();
      raw['bozuk'] = 'x';
      final back = DoseLog.fromRaw(raw);
      expect(back.get(DateTime(2026, 9, 30), 5)?.status, DoseStatus.skipped);
    });

    test('tablo hücre durumları', () {
      final m = med(1, 8, createdAt: started);
      final log = DoseLog.empty();
      log.set(
        DateTime(2026, 9, 29),
        1,
        DoseRecord(status: DoseStatus.taken, at: now),
      );
      DoseCellState cell(DateTime d, {DateTime? at}) =>
          AdherenceCalculator.cellState(
            medication: m,
            dose: m.doses.single,
            log: log,
            day: d,
            now: at ?? now,
          );
      expect(cell(DateTime(2026, 9, 29)), DoseCellState.taken);
      expect(cell(DateTime(2026, 9, 28)), DoseCellState.missed);
      expect(cell(DateTime(2026, 10, 1)), DoseCellState.notScheduled);
      expect(
        cell(DateTime(2026, 9, 30), at: DateTime(2026, 9, 30, 7)),
        DoseCellState.upcoming,
      );
    });
  });

  group('Bildirim eylemleri', () {
    test('gece yarısından sonra basılan akşam dozu önceki güne yazılır', () {
      final action = PendingNotificationAction(
        action: NotificationActionIds.medicationTaken,
        at: DateTime(2026, 10, 1, 0, 30),
        doseId: 1,
        hour: 23,
        minute: 0,
      );
      expect(action.doseDay, DateTime(2026, 9, 30));
      final morning = PendingNotificationAction(
        action: NotificationActionIds.medicationTaken,
        at: DateTime(2026, 10, 1, 8, 20),
        doseId: 1,
        hour: 8,
        minute: 0,
      );
      expect(morning.doseDay, DateTime(2026, 10, 1));
    });

    test('eylem ve bildirim verisi JSON ile gidip gelir', () {
      final action = PendingNotificationAction(
        action: NotificationActionIds.waterAdd,
        at: now,
      );
      final back = PendingNotificationAction.fromJson(
        '{"a":"water_add","t":"${now.toIso8601String()}"}',
      );
      expect(back?.action, action.action);
      expect(PendingNotificationAction.fromJson('bozuk'), isNull);

      final m = med(42, 8);
      final content = NotificationContent.medication(m, m.doses.single);
      final payload = NotificationPayload.decode(content.payload.encode());
      expect(payload?.doseId, 42);
      expect(payload?.route, '/chronic');
      expect(NotificationPayload.decode('{bozuk'), isNull);
    });

    test('ertelenen bildirim kimliği günlük bildirimle çakışmaz', () {
      expect(NotificationIds.snoozeFor(10000), isNegative);
      expect(NotificationIds.snoozeFor(123456789), isNot(123456789));
    });

    test('su bildirimleri her saat için farklı metin içerir', () {
      final titles = {
        for (var i = 0; i < 3; i++) NotificationContent.water(i).title,
      };
      expect(titles.length, 3);
    });
  });
}
