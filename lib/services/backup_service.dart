import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';

/// Yedek dosyası açılamadığında kullanıcıya gösterilecek neden.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// Şifreli yedek: tüm yerel kutular JSON'a çevrilir, paroladan türetilen
/// anahtarla AES-256-GCM ile şifrelenir.
///
/// Uygulamanın verileri cihaza bağlı bir anahtarla şifreli ve Android
/// yedeği kapalı olduğu için telefon değişince veya uygulama silinince
/// tüm sağlık geçmişi kayboluyordu. Yedek dosyası parolasız açılamaz;
/// parola unutulursa kurtarılamaz.
class BackupService {
  BackupService({this.iterations = defaultIterations});

  static const String format = 'vitacoach-backup';
  static const int version = 1;

  /// PBKDF2-HMAC-SHA256 tur sayısı (OWASP 2021 önerisi). Testler daha düşük
  /// değer kullanır.
  static const int defaultIterations = 310000;
  static const int minPasswordLength = 8;

  static const List<String> boxNames = [
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

  final int iterations;

  static final _aad = utf8.encode('$format-v$version');

  /// Açık kutulardaki tüm veriyi şifreli yedek metnine çevirir.
  Future<String> export(String password, {DateTime? now}) async {
    _checkPassword(password);
    final plaintext = jsonEncode({
      'created': (now ?? DateTime.now()).toIso8601String(),
      'boxes': {
        for (final name in boxNames)
          name: encodeValue(Hive.box<dynamic>(name).toMap()),
      },
    });
    final salt = _randomBytes(16);
    final iterations = this.iterations;
    // PBKDF2 saf Dart'ta yüz binlerce tur sürer; arayüz donmasın.
    final sealed = await Isolate.run(() async {
      final key = await _deriveKey(password, salt, iterations);
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(plaintext),
        secretKey: key,
        aad: _aad,
      );
      return (box.nonce, box.cipherText, box.mac.bytes);
    });
    return jsonEncode({
      'format': format,
      'version': version,
      'kdf': {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': iterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'name': 'aes-256-gcm',
        'nonce': base64Encode(sealed.$1),
        'mac': base64Encode(sealed.$3),
      },
      'data': base64Encode(sealed.$2),
    });
  }

  /// Yedeği çözer ve kutuların içeriğini yedektekiyle değiştirir.
  /// Parola yanlışsa veya dosya bozuksa hiçbir veriye dokunmaz.
  Future<DateTime?> restore(String backup, String password) async {
    final payload = await decrypt(backup, password);
    final boxes = payload['boxes'];
    if (boxes is! Map) {
      throw const BackupException('Yedek dosyasının içeriği geçersiz.');
    }
    final decoded = <String, Map<dynamic, dynamic>>{};
    for (final name in boxNames) {
      final value = decodeValue(boxes[name] ?? const <String, dynamic>{});
      if (value is! Map) {
        throw const BackupException('Yedek dosyasının içeriği geçersiz.');
      }
      decoded[name] = value;
    }
    // Önce hepsi çözülür, sonra yazılır: yarım geri yükleme olmaz.
    for (final entry in decoded.entries) {
      final box = Hive.box<dynamic>(entry.key);
      await box.clear();
      await box.putAll(entry.value);
    }
    return DateTime.tryParse('${payload['created']}');
  }

  /// Yedeğin şifresini çözüp içeriği döndürür (geri yükleme yapmaz).
  Future<Map<String, dynamic>> decrypt(String backup, String password) async {
    final Map<String, dynamic> header;
    try {
      header = jsonDecode(backup) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('Bu dosya bir VitaCoach yedeği değil.');
    }
    if (header['format'] != format) {
      throw const BackupException('Bu dosya bir VitaCoach yedeği değil.');
    }
    if (header['version'] != version) {
      throw const BackupException(
        'Bu yedek, uygulamanın başka bir sürümüyle oluşturulmuş.',
      );
    }
    final List<int> salt, nonce, mac, data;
    final int iterations;
    try {
      final kdf = header['kdf'] as Map<String, dynamic>;
      final cipher = header['cipher'] as Map<String, dynamic>;
      iterations = kdf['iterations'] as int;
      salt = base64Decode(kdf['salt'] as String);
      nonce = base64Decode(cipher['nonce'] as String);
      mac = base64Decode(cipher['mac'] as String);
      data = base64Decode(header['data'] as String);
    } catch (_) {
      throw const BackupException('Yedek dosyası bozuk.');
    }
    final List<int>? clear = await Isolate.run(() async {
      final key = await _deriveKey(password, salt, iterations);
      try {
        return await AesGcm.with256bits().decrypt(
          SecretBox(data, nonce: nonce, mac: Mac(mac)),
          secretKey: key,
          aad: _aad,
        );
      } on SecretBoxAuthenticationError {
        return null;
      }
    });
    if (clear == null) {
      throw const BackupException('Parola yanlış veya yedek dosyası bozuk.');
    }
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }

  static void _checkPassword(String password) {
    if (password.length < minPasswordLength) {
      throw const BackupException(
        'Parola en az $minPasswordLength karakter olmalı.',
      );
    }
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return [for (var i = 0; i < length; i++) random.nextInt(256)];
  }

  /// Hive değerini JSON'a çevirir. Metin olmayan anahtarlı haritalar ve
  /// DateTime türleri korunur; desteklenmeyen bir tür sessizce bozulmaz,
  /// hata verir.
  static Object? encodeValue(Object? value) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is DateTime) return {'__dt': value.toIso8601String()};
    if (value is List) return [for (final e in value) encodeValue(e)];
    if (value is Map) {
      if (value.keys.every((k) => k is String)) {
        return {
          for (final e in value.entries) e.key as String: encodeValue(e.value),
        };
      }
      return {
        '__map': [
          for (final e in value.entries)
            [encodeValue(e.key), encodeValue(e.value)],
        ],
      };
    }
    throw BackupException('Yedeklenemeyen veri türü: ${value.runtimeType}');
  }

  static Object? decodeValue(Object? value) {
    if (value is List) return [for (final e in value) decodeValue(e)];
    if (value is Map) {
      if (value.length == 1 && value['__dt'] is String) {
        return DateTime.parse(value['__dt'] as String);
      }
      if (value.length == 1 && value['__map'] is List) {
        return {
          for (final pair in value['__map'] as List)
            decodeValue((pair as List)[0]): decodeValue(pair[1]),
        };
      }
      return {for (final e in value.entries) e.key: decodeValue(e.value)};
    }
    return value;
  }
}
