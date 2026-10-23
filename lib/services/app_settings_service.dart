import 'package:flutter/material.dart';

import 'hive_service.dart';

/// Görünüm ve erişilebilirlik tercihleri.
@immutable
class AppSettings {
  final ThemeMode themeMode;
  final bool largeText;
  final bool highContrast;
  final bool ttsEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.largeText = false,
    this.highContrast = false,
    this.ttsEnabled = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? largeText,
    bool? highContrast,
    bool? ttsEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      largeText: largeText ?? this.largeText,
      highContrast: highContrast ?? this.highContrast,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    );
  }

  /// Büyük yazı modunda uygulanan yazı ölçeği.
  double get textScaleFactor => largeText ? 1.25 : 1.0;
}

/// Tercihleri Hive'da saklar ve değişiklikleri uygulamaya yayınlar.
class AppSettingsService {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  static const _themeKey = 'appearance_theme_mode';
  static const _largeTextKey = 'appearance_large_text';
  static const _highContrastKey = 'appearance_high_contrast';
  static const _ttsKey = 'appearance_tts_enabled';

  final ValueNotifier<AppSettings> settings = ValueNotifier(
    const AppSettings(),
  );

  AppSettings get current => settings.value;

  void load() {
    final box = HiveService().getSettingsBox();
    settings.value = AppSettings(
      themeMode: _parseTheme(box.get(_themeKey)),
      largeText: box.get(_largeTextKey) == true,
      highContrast: box.get(_highContrastKey) == true,
      ttsEnabled: box.get(_ttsKey) == true,
    );
  }

  Future<void> update(AppSettings next) async {
    final box = HiveService().getSettingsBox();
    await box.putAll({
      _themeKey: next.themeMode.name,
      _largeTextKey: next.largeText,
      _highContrastKey: next.highContrast,
      _ttsKey: next.ttsEnabled,
    });
    settings.value = next;
  }

  static ThemeMode _parseTheme(dynamic raw) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}
