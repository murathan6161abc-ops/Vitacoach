import 'package:flutter/foundation.dart';

import 'hive_service.dart';

/// "Jüri Demo Verisi" tüm gerçek verileri silip örnek veri yükler. Yayın
/// sürümünde yanlışlıkla basılmasın diye gizlidir: Ayarlar'daki sürüm
/// yazısına [tapsToUnlock] kez dokunulunca açılır. Geliştirme derlemesinde
/// her zaman görünür.
class DemoMode {
  DemoMode._();

  static const String _key = 'demo_mode_unlocked';
  static const int tapsToUnlock = 7;

  static bool isAvailable({bool releaseMode = kReleaseMode}) =>
      !releaseMode || HiveService().getSettingsBox().get(_key) == true;

  static Future<void> unlock() =>
      HiveService().getSettingsBox().put(_key, true);
}
