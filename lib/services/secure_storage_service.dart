import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  static const String hiveEncryptionKey = 'hive_encryption_key_v1';
  static const String iqAirApiKey = 'iqair_api_key_v1';

  // Uygulama artık hiçbir yapay zekâ servisine bağlanmıyor. Önceki
  // sürümlerde kaydedilmiş olabilecek Gemini anahtarları açılışta silinir.
  static const String _legacyGeminiSecureKey = 'gemini_api_key_v1';
  static const String _legacyGeminiPrefsKey = 'gemini_api_key';
  static const String _legacyAiConsentKey = 'ai_health_data_consent';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      migrateWithBackup: true,
      resetOnError: false,
      storageNamespace: 'vitacoach',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> read(String key) async {
    final value = await _storage.read(key: key);
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> write(String key, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await delete(key);
      return;
    }
    await _storage.write(key: key, value: normalized);
  }

  Future<void> delete(String key) => _storage.delete(key: key);

  /// Eski sürümlerden kalan yapay zekâ anahtarlarını ve rıza kaydını siler.
  /// Hata olursa açılışı engellemez.
  Future<void> purgeLegacyAiData({dynamic settingsBox}) async {
    try {
      await delete(_legacyGeminiSecureKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyGeminiPrefsKey);
    } catch (_) {}
    try {
      await settingsBox?.delete(_legacyAiConsentKey);
    } catch (_) {}
  }

  Future<void> clearUserSecrets() async {
    await Future.wait([delete(iqAirApiKey), delete(_legacyGeminiSecureKey)]);
  }
}
