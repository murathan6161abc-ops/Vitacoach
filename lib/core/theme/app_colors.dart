import 'package:flutter/material.dart';

/// Uygulama renkleri.
///
/// Nötr renkler (metin, yüzey, arka plan) ve okunabilirliği temaya bağlı
/// olan birkaç vurgu rengi, etkin temaya (açık/koyu) ve yüksek kontrast
/// tercihine göre değişir. [configure] tema oluşturulurken çağrılır;
/// değişiklikte uygulama ağacı yeniden kurulduğu için tüm ekranlar güncel
/// değerleri okur.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static bool _highContrast = false;

  static bool get isDark => _dark;
  static bool get isHighContrast => _highContrast;

  static void configure({required bool dark, required bool highContrast}) {
    _dark = dark;
    _highContrast = highContrast;
  }

  // Marka/ana renkler
  static Color get primary => _dark
      ? const Color(0xFF6FCF97)
      : (_highContrast ? const Color(0xFF1B5E20) : const Color(0xFF2A7D4F));
  static const Color primaryDark = Color(0xFF1E5E3B);
  static Color get primaryLight =>
      _dark ? const Color(0xFF8EDBB0) : const Color(0xFF48B07A);
  static Color get primaryContainer =>
      _dark ? const Color(0xFF1E3A2B) : const Color(0xFFE8F5EE);
  static Color get secondary =>
      _dark ? const Color(0xFF4DB6AC) : const Color(0xFF00897B);
  static Color get danger =>
      _dark ? const Color(0xFFEF6C6C) : const Color(0xFFD32F2F);
  static Color get warning =>
      _dark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);
  static Color get success =>
      _dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

  // Yüzeyler
  static Color get background =>
      _dark ? const Color(0xFF101714) : const Color(0xFFF4F9F6);
  static Color get surface =>
      _dark ? const Color(0xFF1A2420) : const Color(0xFFFFFFFF);

  // Modül vurgu renkleri (her iki temada da okunaklı orta tonlar)
  static const Color accentMaternal = Color(0xFFEC407A);
  static const Color accentInfectious = Color(0xFFFF7043);
  static const Color accentChronic = Color(0xFF42A5F5);
  static const Color accentMental = Color(0xFFAB47BC);
  static const Color accentNutrition = Color(0xFF66BB6A);
  static const Color accentFitness = Color(0xFF26C6DA);
  static const Color accentAddiction = Color(0xFFFF8A65);
  static const Color accentEnvironment = Color(0xFF78909C);
  static const Color accentAccess = Color(0xFF5C6BC0);
  static const Color accentProgress = Color(0xFFFFCA28);
  static const Color accentSleep = Color(0xFF7E57C2);
  static const Color accentRisk = Color(0xFFEF5350);

  // Metin renkleri
  static Color get textPrimary {
    if (_dark) return _highContrast ? Colors.white : const Color(0xFFE8EFEB);
    return _highContrast ? Colors.black : const Color(0xFF1B1B1B);
  }

  static Color get textSecondary {
    if (_dark) {
      return _highContrast ? const Color(0xFFE0E0E0) : const Color(0xFFB4C0BA);
    }
    return _highContrast ? const Color(0xFF212121) : const Color(0xFF616161);
  }

  static Color get textHint {
    if (_dark) {
      return _highContrast ? const Color(0xFFCFD8DC) : const Color(0xFF8A9A92);
    }
    return _highContrast ? const Color(0xFF424242) : const Color(0xFF9E9E9E);
  }

  /// Kart kenarlığı; yüksek kontrastta belirgin.
  static Color get cardBorder => _highContrast
      ? (_dark ? Colors.white70 : Colors.black87)
      : Colors.transparent;
}
