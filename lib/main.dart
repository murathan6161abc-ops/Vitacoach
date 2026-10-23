import 'package:flutter/material.dart';
import 'services/app_settings_service.dart';
import 'services/hive_service.dart';
import 'services/secure_storage_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive şifrelemesi artık cihazın güvenli kasasındaki bir anahtara
  // bağımlı (bkz. HiveService). O anahtar kaybolur/bozulursa (ör. güvenli
  // depolama temizlenir, uyumsuz bir yedekten geri yüklenir) init() artık
  // bir StateError fırlatabilir. Bunu yakalamazsak uygulama hiç açılmadan,
  // kullanıcıya hiçbir açıklama göstermeden çöker.
  try {
    await HiveService().init();
  } catch (error) {
    debugPrint('Kritik başlatma hatası: $error');
    runApp(_StartupErrorApp(message: '$error'));
    return;
  }

  AppSettingsService().load();

  // Önceki sürümlerden kalmış yapay zekâ anahtarlarını temizle. Uygulama
  // artık hiçbir harici yapay zekâ servisine veri göndermiyor.
  await SecureStorageService().purgeLegacyAiData(
    settingsBox: HiveService().getSettingsBox(),
  );

  // Bildirimler isteğe bağlıdır; başarısız olması açılışı engellememeli.

  try {
    await NotificationService().init();
  } catch (error) {
    debugPrint('Bildirim servisi başlatılamadı: $error');
  }

  runApp(const VitaCoachApp());
}

/// Yerel veriler açılamadığında gösterilen, minimal ama bilgilendirici
/// bir hata ekranı. Sessiz çökme yerine kullanıcıya ne olduğunu ve neden
/// verilerin silinmediğini açıklar.
class _StartupErrorApp extends StatelessWidget {
  final String message;

  const _StartupErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFDECEA),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Color(0xFFB3261E),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uygulama başlatılamadı',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verileriniz güvenlik amacıyla otomatik olarak silinmedi. '
                  'Sorun devam ederse uygulamayı kaldırıp yeniden yüklemeniz '
                  'gerekebilir; bu durumda yerel sağlık verileriniz kaybolur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
