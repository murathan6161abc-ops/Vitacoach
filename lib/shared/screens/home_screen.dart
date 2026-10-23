import 'package:flutter/material.dart';
import '../../core/utils/input_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../modules/m01_profile/providers/profile_provider.dart';
import '../../modules/m03_chronic/providers/chronic_provider.dart';
import '../../modules/m15_sleep/providers/sleep_provider.dart';
import '../../modules/m18_insights/screens/insights_screen.dart';
import '../../modules/m18_insights/services/insight_repository.dart';
import '../widgets/today_card.dart';
import '../widgets/vc_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              label: 'Acil durum ekranını aç',
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => context.push(AppConstants.routeSos),
                icon: const Icon(Icons.emergency_share, size: 18),
                label: const Text(
                  'SOS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(context),
            const SizedBox(height: 12),
            const TodayCard(),
            const SizedBox(height: 12),
            const _AssistantBar(),
            const _InsightBanner(),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            Text(
              'Sağlık Modülleri',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildModuleGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Günaydın';
    } else if (hour < 18) {
      greeting = 'İyi günler';
    } else {
      greeting = 'İyi akşamlar';
    }

    final profile = context.watch<ProfileProvider>().profile;
    final name = profile.name.isNotEmpty ? ', ${profile.name}' : '';

    return VcCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryContainer,
            child: profile.name.isNotEmpty
                ? Text(
                    InputUtils.upperTr(profile.name[0]),
                    style: TextStyle(
                      fontSize: 24,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(Icons.person, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting$name!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Bugün sağlığınız için ne yapalım?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.medical_services,
            label: 'Belirti\nSorgula',
            color: AppColors.danger,
            onTap: () => context.go(AppConstants.routeSymptom),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.restaurant,
            label: 'Öğün\nEkle',
            color: AppColors.accentNutrition,
            onTap: () => context.go(AppConstants.routeNutrition),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.mood,
            label: 'Ruh\nHali',
            color: AppColors.accentMental,
            onTap: () => context.push(AppConstants.routeMental),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final modules = [
      _ModuleItem(
        'Kronik Hastalık',
        Icons.monitor_heart,
        AppColors.accentChronic,
        AppConstants.routeChronic,
      ),
      _ModuleItem(
        'Anne & Bebek',
        Icons.child_care,
        AppColors.accentMaternal,
        AppConstants.routeMaternal,
      ),
      _ModuleItem(
        'Ruh Sağlığı',
        Icons.psychology,
        AppColors.accentMental,
        AppConstants.routeMental,
      ),
      _ModuleItem(
        'Fitness',
        Icons.fitness_center,
        AppColors.accentFitness,
        AppConstants.routeFitness,
      ),
      _ModuleItem(
        'Bağımlılık',
        Icons.smoke_free,
        AppColors.accentAddiction,
        AppConstants.routeAddiction,
      ),
      _ModuleItem(
        'Aşı & Bulaşıcı',
        Icons.vaccines,
        AppColors.accentInfectious,
        AppConstants.routeInfectious,
      ),
      _ModuleItem(
        'Çevre & Trafik',
        Icons.eco,
        AppColors.accentEnvironment,
        AppConstants.routeEnvironment,
      ),
      _ModuleItem(
        'Sağlık Erişimi',
        Icons.local_hospital,
        AppColors.accentAccess,
        AppConstants.routeAccess,
      ),
      _ModuleItem(
        'Uyku Takibi',
        Icons.bedtime,
        AppColors.accentSleep,
        AppConstants.routeSleep,
      ),
      _ModuleItem(
        'Risk Analizi',
        Icons.health_and_safety,
        AppColors.accentRisk,
        AppConstants.routeRisk,
      ),
      _ModuleItem(
        'Nabız & Stres',
        Icons.monitor_heart_outlined,
        AppColors.danger,
        AppConstants.routeHeart,
      ),
      _ModuleItem(
        'Akıllı Analiz',
        Icons.auto_graph,
        AppColors.primary,
        AppConstants.routeInsights,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return VcCard(
          onTap: () => context.push(module.route),
          borderColor: module.color.withValues(alpha: 0.3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(module.icon, color: module.color, size: 32),
              const SizedBox(height: 8),
              Text(
                module.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _ModuleItem(this.title, this.icon, this.color, this.route);
}

/// Ana sayfadaki "Asistana sor" çubuğu.
class _AssistantBar extends StatelessWidget {
  const _AssistantBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.push(AppConstants.routeAssistant),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sağlık asistanına sorun: "Başım ağrıyor"',
                  style: TextStyle(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_forward, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// En önemli akıllı analiz bulgusunu gösterir; veriler değişince yenilenir.
class _InsightBanner extends StatelessWidget {
  const _InsightBanner();

  @override
  Widget build(BuildContext context) {
    // Bu sağlayıcılar değişince (ör. yeni ölçüm) bulgular yeniden hesaplanır.
    context.watch<ChronicProvider>();
    context.watch<SleepProvider>();
    final insights = InsightRepository.analyze();
    if (insights.isEmpty) return const SizedBox.shrink();
    final top = insights.first;
    final color = insightColor(top.severity);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VcCard(
        onTap: () => context.push(AppConstants.routeInsights),
        borderColor: color.withValues(alpha: 0.5),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(insightIcon(top.severity), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Akıllı analiz · ${insights.length} bulgu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    top.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    top.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
