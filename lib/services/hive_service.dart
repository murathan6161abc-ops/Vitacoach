import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import 'secure_storage_service.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  static const String _migrationCompleteKey =
      '__vitacoach_secure_migration_complete__';

  static const List<String> _boxNames = [
    AppConstants.hiveProfileBox,
    AppConstants.hiveHealthBox,
    AppConstants.hiveNutritionBox,
    AppConstants.hiveMoodBox,
    AppConstants.hiveSettingsBox,
    AppConstants.hiveMedicationBox,
    AppConstants.hiveAddictionBox,
    AppConstants.hiveVaccineBox,
    AppConstants.hiveFitnessBox,
    AppConstants.hiveBadgeBox,
  ];

  Future<void> init({String? testPath}) async {
    if (testPath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(testPath);
    }
    final encryptionKey = await _loadOrCreateEncryptionKey();
    await _openBoxes(HiveAesCipher(encryptionKey));
  }

  Future<List<int>> _loadOrCreateEncryptionKey() async {
    final secureStorage = SecureStorageService();
    var encodedKey = await secureStorage.read(
      SecureStorageService.hiveEncryptionKey,
    );

    if (encodedKey == null) {
      final newKey = Hive.generateSecureKey();
      encodedKey = base64UrlEncode(newKey);
      await secureStorage.write(
        SecureStorageService.hiveEncryptionKey,
        encodedKey,
      );
      return newKey;
    }

    try {
      final key = base64Url.decode(encodedKey);
      if (key.length != 32) throw const FormatException();
      return key;
    } on FormatException {
      throw StateError('Güvenli veri anahtarı geçersiz.');
    }
  }

  Future<void> _openBoxes(HiveCipher cipher) async {
    for (final boxName in _boxNames) {
      await _openEncryptedBox(boxName, cipher);
    }
  }

  Future<Box<dynamic>> _openEncryptedBox(
    String boxName,
    HiveCipher cipher,
  ) async {
    final migrationBoxName = '${boxName}_secure_migration_v1';
    final encryptionMarker = 'hive_box_encrypted_v1_$boxName';
    final secureStorage = SecureStorageService();
    final isMarkedEncrypted =
        await secureStorage.read(encryptionMarker) == 'true';

    if (isMarkedEncrypted) {
      try {
        final box = await Hive.openBox<dynamic>(
          boxName,
          encryptionCipher: cipher,
          crashRecovery: false,
        );
        if (await Hive.boxExists(migrationBoxName)) {
          await Hive.deleteBoxFromDisk(migrationBoxName);
        }
        return box;
      } catch (_) {
        throw StateError(
          'Yerel sağlık verileri açılamadı. Veriler korunmak için silinmedi.',
        );
      }
    }

    if (await Hive.boxExists(migrationBoxName)) {
      late final Box<dynamic> migrationBox;
      try {
        migrationBox = await Hive.openBox<dynamic>(
          migrationBoxName,
          encryptionCipher: cipher,
          crashRecovery: false,
        );
      } catch (_) {
        throw StateError(
          'Güvenli veri geçişi tamamlanamadı. Kurtarma kopyası silinmedi.',
        );
      }

      final isComplete =
          migrationBox.get(_migrationCompleteKey, defaultValue: false) == true;
      if (!isComplete) {
        await migrationBox.close();
        await Hive.deleteBoxFromDisk(migrationBoxName);
      } else {
        final snapshot = _snapshotWithoutMarker(migrationBox);
        await migrationBox.close();
        if (Hive.isBoxOpen(boxName)) await Hive.box(boxName).close();
        if (await Hive.boxExists(boxName)) {
          await Hive.deleteBoxFromDisk(boxName);
        }
        try {
          final recoveredBox = await Hive.openBox<dynamic>(
            boxName,
            encryptionCipher: cipher,
            crashRecovery: false,
          );
          await recoveredBox.putAll(snapshot);
          await recoveredBox.flush();
          await secureStorage.write(encryptionMarker, 'true');
          await Hive.deleteBoxFromDisk(migrationBoxName);
          return recoveredBox;
        } catch (_) {
          throw StateError(
            'Güvenli veri geçişi tamamlanamadı. Kurtarma kopyası silinmedi.',
          );
        }
      }
    }

    if (!await Hive.boxExists(boxName)) {
      final newBox = await Hive.openBox<dynamic>(
        boxName,
        encryptionCipher: cipher,
        crashRecovery: false,
      );
      await secureStorage.write(encryptionMarker, 'true');
      return newBox;
    }

    late final Box<dynamic> plainBox;
    try {
      plainBox = await Hive.openBox<dynamic>(boxName, crashRecovery: false);
    } catch (_) {
      if (Hive.isBoxOpen(boxName)) await Hive.box(boxName).close();
      try {
        final alreadyEncryptedBox = await Hive.openBox<dynamic>(
          boxName,
          encryptionCipher: cipher,
          crashRecovery: false,
        );
        await secureStorage.write(encryptionMarker, 'true');
        return alreadyEncryptedBox;
      } catch (_) {
        throw StateError(
          'Yerel sağlık verileri açılamadı. Veriler korunmak için silinmedi.',
        );
      }
    }

    final snapshot = Map<dynamic, dynamic>.from(plainBox.toMap());
    final migrationBox = await Hive.openBox<dynamic>(
      migrationBoxName,
      encryptionCipher: cipher,
      crashRecovery: false,
    );
    await migrationBox.clear();
    await migrationBox.putAll(snapshot);
    await migrationBox.put(_migrationCompleteKey, true);
    await migrationBox.flush();
    await migrationBox.close();

    await plainBox.close();
    await Hive.deleteBoxFromDisk(boxName);

    final encryptedBox = await Hive.openBox<dynamic>(
      boxName,
      encryptionCipher: cipher,
      crashRecovery: false,
    );
    await encryptedBox.putAll(snapshot);
    await encryptedBox.flush();
    await secureStorage.write(encryptionMarker, 'true');
    await Hive.deleteBoxFromDisk(migrationBoxName);
    return encryptedBox;
  }

  Map<dynamic, dynamic> _snapshotWithoutMarker(Box<dynamic> box) {
    final snapshot = Map<dynamic, dynamic>.from(box.toMap());
    snapshot.remove(_migrationCompleteKey);
    return snapshot;
  }

  Box getProfileBox() => Hive.box(AppConstants.hiveProfileBox);
  Box getHealthBox() => Hive.box(AppConstants.hiveHealthBox);
  Box getNutritionBox() => Hive.box(AppConstants.hiveNutritionBox);
  Box getMoodBox() => Hive.box(AppConstants.hiveMoodBox);
  Box getSettingsBox() => Hive.box(AppConstants.hiveSettingsBox);
  Box getMedicationBox() => Hive.box(AppConstants.hiveMedicationBox);
  Box getAddictionBox() => Hive.box(AppConstants.hiveAddictionBox);
  Box getVaccineBox() => Hive.box(AppConstants.hiveVaccineBox);
  Box getFitnessBox() => Hive.box(AppConstants.hiveFitnessBox);
  Box getBadgeBox() => Hive.box(AppConstants.hiveBadgeBox);

  // Profile
  bool get isOnboardingCompleted =>
      getProfileBox().get('onboarding_completed', defaultValue: false);

  Future<void> setOnboardingCompleted(bool value) async {
    await getProfileBox().put('onboarding_completed', value);
  }

  // Generic put/get
  Future<void> putData(String boxName, String key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  dynamic getData(String boxName, String key, {dynamic defaultValue}) {
    final box = Hive.box(boxName);
    return box.get(key, defaultValue: defaultValue);
  }

  Future<void> deleteData(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  Future<void> clearAllData() async {
    await Future.wait(_boxNames.map((name) => Hive.box(name).clear()));
  }
}
