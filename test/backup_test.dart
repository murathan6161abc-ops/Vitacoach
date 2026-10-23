import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/services/backup_service.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  // Testte düşük tur sayısı; uygulama 310 000 kullanır.
  final service = BackupService(iterations: 1000);
  const password = 'gizli-parola-123';

  Future<void> seed() async {
    final hive = HiveService();
    await hive.getProfileBox().putAll({'name': 'Ayşe', 'weight': 72.5});
    await hive.getHealthBox().put('blood_pressure', [
      {'systolic': 120.0, 'diastolic': 80.0, 'date': '2026-10-20T09:00:00'},
    ]);
    // İlaç günlüğü sayı anahtarlı harita kullanır.
    await hive.getMedicationBox().put('dose_log', {
      '2026-10-20': {
        10123: {'status': 'taken'},
      },
    });
    await hive.getSettingsBox().put('when', DateTime(2026, 10, 20, 8, 30));
  }

  test('yedek alınır, veriler silinir ve aynen geri yüklenir', () async {
    await seed();
    final backup = await service.export(password);
    expect(backup, isNot(contains('Ayşe')));

    await HiveService().clearAllData();
    expect(HiveService().getProfileBox().get('name'), isNull);

    await service.restore(backup, password);

    final hive = HiveService();
    expect(hive.getProfileBox().get('name'), 'Ayşe');
    expect(hive.getProfileBox().get('weight'), 72.5);
    expect(
      ((hive.getHealthBox().get('blood_pressure') as List).single
          as Map)['systolic'],
      120.0,
    );
    final doseLog = hive.getMedicationBox().get('dose_log') as Map;
    expect((doseLog['2026-10-20'] as Map).keys.single, 10123);
    expect(hive.getSettingsBox().get('when'), DateTime(2026, 10, 20, 8, 30));
  });

  test('yanlış parolada hiçbir veriye dokunulmaz', () async {
    await seed();
    final backup = await service.export(password);
    await HiveService().getProfileBox().put('name', 'Yeni');

    await expectLater(
      service.restore(backup, 'yanlis-parola'),
      throwsA(isA<BackupException>()),
    );
    expect(HiveService().getProfileBox().get('name'), 'Yeni');
  });

  test('değiştirilmiş yedek reddedilir', () async {
    await seed();
    final backup = await service.export(password);
    final tampered = backup.replaceFirst(
      RegExp(r'"data":"(.)'),
      backup.contains('"data":"A') ? '"data":"B' : '"data":"A',
    );

    await expectLater(
      service.restore(tampered, password),
      throwsA(isA<BackupException>()),
    );
  });

  test('kısa parola ve yabancı dosya anlaşılır hatayla reddedilir', () async {
    await expectLater(
      service.export('kisa'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('8'),
        ),
      ),
    );
    await expectLater(
      service.restore('{"merhaba": 1}', password),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('VitaCoach yedeği değil'),
        ),
      ),
    );
  });
}
