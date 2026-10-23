import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/screens/splash_screen.dart';
import '../../shared/screens/main_shell.dart';
import '../../shared/screens/home_screen.dart';
import '../../modules/m01_profile/screens/onboarding_screen.dart';
import '../../modules/m01_profile/screens/profile_screen.dart';
import '../../modules/m02_symptom/screens/symptom_screen.dart';
import '../../modules/m03_chronic/screens/chronic_screen.dart';
import '../../modules/m04_maternal/screens/maternal_screen.dart';
import '../../modules/m05_mental/screens/mental_screen.dart';
import '../../modules/m06_nutrition/screens/nutrition_screen.dart';
import '../../modules/m07_fitness/screens/fitness_screen.dart';
import '../../modules/m08_addiction/screens/addiction_screen.dart';
import '../../modules/m09_infectious/screens/infectious_screen.dart';
import '../../modules/m10_environment/screens/environment_screen.dart';
import '../../modules/m11_access/screens/access_screen.dart';
import '../../modules/m12_progress/screens/progress_screen.dart';
import '../../modules/m13_settings/screens/settings_screen.dart';
import '../../modules/m14_risk/screens/risk_screen.dart';
import '../../modules/m15_sleep/screens/sleep_screen.dart';
import '../../modules/m16_emergency/screens/emergency_card_screen.dart';
import '../../modules/m16_emergency/screens/sos_screen.dart';
import '../../modules/m17_report/screens/report_screen.dart';
import '../../modules/m18_insights/screens/insights_screen.dart';
import '../../modules/m19_heart/screens/heart_rate_screen.dart';
import '../../modules/m20_assistant/screens/assistant_screen.dart';

/// Sağlayıcılara servis katmanından erişmek için (ör. bildirim eylemleri).
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppConstants.routeSplash,
  routes: [
    GoRoute(
      path: AppConstants.routeSplash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppConstants.routeOnboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppConstants.routeHome,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppConstants.routeSymptom,
          builder: (context, state) => const SymptomScreen(),
        ),
        GoRoute(
          path: AppConstants.routeNutrition,
          builder: (context, state) => const NutritionScreen(),
        ),
        GoRoute(
          path: AppConstants.routeProgress,
          builder: (context, state) => const ProgressScreen(),
        ),
        GoRoute(
          path: AppConstants.routeProfile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppConstants.routeSettings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: AppConstants.routeChronic,
      builder: (context, state) => const ChronicScreen(),
    ),
    GoRoute(
      path: AppConstants.routeMaternal,
      builder: (context, state) => const MaternalScreen(),
    ),
    GoRoute(
      path: AppConstants.routeMental,
      builder: (context, state) => const MentalScreen(),
    ),
    GoRoute(
      path: AppConstants.routeFitness,
      builder: (context, state) => const FitnessScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAddiction,
      builder: (context, state) => const AddictionScreen(),
    ),
    GoRoute(
      path: AppConstants.routeInfectious,
      builder: (context, state) => const InfectiousScreen(),
    ),
    GoRoute(
      path: AppConstants.routeEnvironment,
      builder: (context, state) => const EnvironmentScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAccess,
      builder: (context, state) => const AccessScreen(),
    ),
    GoRoute(
      path: AppConstants.routeRisk,
      builder: (context, state) => const RiskScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSleep,
      builder: (context, state) => const SleepScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSos,
      builder: (context, state) => const SosScreen(),
    ),
    GoRoute(
      path: AppConstants.routeEmergencyCard,
      builder: (context, state) => const EmergencyCardScreen(),
    ),
    GoRoute(
      path: AppConstants.routeReport,
      builder: (context, state) => const ReportScreen(),
    ),
    GoRoute(
      path: AppConstants.routeHeart,
      builder: (context, state) => const HeartRateScreen(),
    ),
    GoRoute(
      path: AppConstants.routeInsights,
      builder: (context, state) => const InsightsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAssistant,
      builder: (context, state) =>
          AssistantScreen(initialQuestion: state.extra as String?),
    ),
  ],
);
