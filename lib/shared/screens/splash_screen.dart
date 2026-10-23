import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Önceden her açılışta 2 saniye yapay bekleme vardı; veriler main()'de
    // zaten yüklendiği için ilk karede yönlendirilir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  void _navigate() {
    if (!mounted) return;

    final hiveService = HiveService();
    if (hiveService.isOnboardingCompleted) {
      context.go(AppConstants.routeHome);
      // Uygulama bir bildirime dokunularak açıldıysa ilgili ekrana geç.
      final route = NotificationService().takeLaunchRoute();
      if (route != null) context.push(route);
    } else {
      context.go(AppConstants.routeOnboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Marka rengi sabit: koyu temada da sistem açılış ekranıyla aynı.
      backgroundColor: const Color(0xFF2A7D4F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sistem açılış ekranındaki beyaz logoyla aynı; geçiş kesintisiz.
            Image.asset(
              'assets/images/logo_mark.png',
              height: 104,
              semanticLabel: 'VitaCoach logosu',
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kişisel Sağlık Koçunuz',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
