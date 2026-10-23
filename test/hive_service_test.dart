import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vitacoach/core/constants/app_constants.dart';
import 'package:vitacoach/services/hive_service.dart';
import 'package:vitacoach/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'vitacoach_hive_test_',
    );
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await Hive.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('migrates existing plaintext data into encrypted boxes', () async {
    Hive.init(temporaryDirectory.path);
    final plainBox = await Hive.openBox<dynamic>(AppConstants.hiveProfileBox);
    await plainBox.put('name', 'Güvenli Kullanıcı');
    await plainBox.put('conditions', ['Diyabet']);
    await Hive.close();

    await HiveService().init(testPath: temporaryDirectory.path);

    expect(HiveService().getProfileBox().get('name'), 'Güvenli Kullanıcı');
    expect(
      HiveService().getProfileBox().get('conditions'),
      contains('Diyabet'),
    );
    expect(
      await SecureStorageService().read(SecureStorageService.hiveEncryptionKey),
      isNotNull,
    );
  });

  test('reopens encrypted data with the persisted device key', () async {
    await HiveService().init(testPath: temporaryDirectory.path);
    await HiveService().getHealthBox().put('blood_sugar', [
      {'value': 95.0, 'date': DateTime(2026).toIso8601String()},
    ]);
    await Hive.close();

    await HiveService().init(testPath: temporaryDirectory.path);

    final values = HiveService().getHealthBox().get('blood_sugar') as List;
    expect(values.single['value'], 95.0);
  });
}
