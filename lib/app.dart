import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'modules/m01_profile/providers/profile_provider.dart';
import 'modules/m02_symptom/providers/symptom_provider.dart';
import 'modules/m03_chronic/providers/chronic_provider.dart';
import 'modules/m04_maternal/providers/maternal_provider.dart';
import 'modules/m05_mental/providers/mental_provider.dart';
import 'modules/m06_nutrition/providers/nutrition_provider.dart';
import 'modules/m07_fitness/providers/fitness_provider.dart';
import 'modules/m08_addiction/providers/addiction_provider.dart';
import 'modules/m09_infectious/providers/infectious_provider.dart';
import 'modules/m10_environment/providers/environment_provider.dart';
import 'modules/m11_access/providers/access_provider.dart';
import 'modules/m12_progress/providers/progress_provider.dart';
import 'modules/m15_sleep/providers/sleep_provider.dart';
import 'services/app_settings_service.dart';
import 'services/app_state_service.dart';
import 'services/notification_actions.dart';

class VitaCoachApp extends StatefulWidget {
  const VitaCoachApp({super.key});

  @override
  State<VitaCoachApp> createState() => _VitaCoachAppState();
}

class _VitaCoachAppState extends State<VitaCoachApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationActions.onDataChanged = _refreshAfterNotificationAction;
    NotificationActions.onOpenRoute = _openRouteFromNotification;
    // Uygulama kapalıyken bildirimden "Aldım" / "+1 bardak" basılmış olabilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationActions.applyPending();
      _syncSteps();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationActions.applyPending();
      _syncSteps();
    }
  }

  /// Uygulama kapalıyken atılan adımlar cihazın adım kaydından okunur;
  /// ana sayfa ve ilerleme ekranı da güncel toplamı görür.
  Future<void> _syncSteps() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final fitness = context.read<FitnessProvider>();
    final progress = context.read<ProgressProvider>();
    await fitness.syncIfTrackingEnabled();
    progress.loadData();
  }

  void _refreshAfterNotificationAction() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    context.read<ChronicProvider>().reloadDoseLog();
    context.read<NutritionProvider>().reloadToday();
    context.read<ProgressProvider>().loadData();
  }

  void _openRouteFromNotification(String route) {
    // Açılış ekranı henüz yönlendirmediyse rota orada ele alınır.
    final current = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (current == AppConstants.routeSplash) return;
    appRouter.push(route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// "Sistem" teması seçiliyken cihaz teması değişirse uygula.
  @override
  void didChangePlatformBrightness() {
    if (AppSettingsService().current.themeMode == ThemeMode.system) {
      setState(() {});
    }
  }

  bool _isDark(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsService().settings,
      builder: (context, settings, _) => _buildApp(settings),
    );
  }

  Widget _buildApp(AppSettings settings) {
    final dark = _isDark(settings.themeMode);
    // Tema yalnızca etkin mod için kurulur; AppColors bu çağrıyla ayarlanır.
    final theme = AppTheme.build(
      dark: dark,
      highContrast: settings.highContrast,
    );
    return ValueListenableBuilder<int>(
      valueListenable: AppStateService().revision,
      builder: (context, revision, _) => MultiProvider(
        key: ValueKey(revision),
        providers: [
          ChangeNotifierProvider(
            create: (_) => ProfileProvider()..loadProfile(),
          ),
          ChangeNotifierProvider(
            create: (_) => SymptomProvider()..loadSymptoms(),
          ),
          ChangeNotifierProvider(create: (_) => ChronicProvider()..loadData()),
          ChangeNotifierProvider(create: (_) => MaternalProvider()..init()),
          ChangeNotifierProvider(create: (_) => MentalProvider()..init()),
          ChangeNotifierProvider(create: (_) => NutritionProvider()..init()),
          ChangeNotifierProvider(create: (_) => FitnessProvider()..loadData()),
          ChangeNotifierProvider(
            create: (_) => AddictionProvider()..loadData(),
          ),
          ChangeNotifierProvider(
            create: (_) => InfectiousProvider()..loadData(),
          ),
          ChangeNotifierProvider(create: (_) => EnvironmentProvider()..init()),
          ChangeNotifierProvider(create: (_) => AccessProvider()..init()),
          ChangeNotifierProvider(create: (_) => ProgressProvider()..loadData()),
          ChangeNotifierProvider(create: (_) => SleepProvider()..loadData()),
        ],
        child: MaterialApp.router(
          // Renkler temaya göre hesaplandığı için görünüm değişince tüm
          // ekranların yeniden kurulması gerekir.
          key: ValueKey('theme-$dark-${settings.highContrast}'),
          title: 'VitaCoach',
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) {
            if (!settings.largeText) return child!;
            final mediaQuery = MediaQuery.of(context);
            final systemScale = mediaQuery.textScaler.scale(14) / 14;
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  (systemScale * settings.textScaleFactor).clamp(1.0, 2.0),
                ),
              ),
              child: child!,
            );
          },
          // Uygulama tamamen Türkçe: tarih/saat seçiciler ve Material
          // bileşen etiketleri de Türkçe gösterilsin (aksi halde
          // İngilizce/AM-PM biçiminde render edilirler).
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
