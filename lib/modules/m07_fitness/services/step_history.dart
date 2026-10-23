import 'package:flutter/services.dart';

/// Cihazın kendi adım kaydından gün gün toplamlar: iOS'ta CoreMotion,
/// Android'de Google Play hizmetlerinin Kayıt API'si. Uygulama kapalıyken
/// atılan adımlar da gelir; adım sensörü ise yalnızca son okumadan bu yana
/// farkı verebildiği için gün değişiminde sabah adımlarını kaybediyordu.
class StepHistory {
  static const _channel = MethodChannel('vitacoach/step_history');

  /// Son [days] günün toplamları ('yyyy-MM-dd' -> adım). Cihaz
  /// desteklemiyorsa veya izin yoksa null.
  Future<Map<String, int>?> dailyTotals({int days = 7}) async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'dailyTotals',
        {'days': days},
      );
      if (raw == null) return null;
      return {
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: (entry.value as num).toInt(),
      };
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
