import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../providers/environment_provider.dart';

class EnvironmentScreen extends StatelessWidget {
  const EnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Çevre & Trafik'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: [
              Tab(text: 'Hava Kalitesi'),
              Tab(text: 'İlk Yardım'),
              Tab(text: 'Trafik Güvenliği'),
            ],
          ),
        ),
        body: Consumer<EnvironmentProvider>(
          builder: (context, provider, _) {
            return TabBarView(
              children: [
                _buildAqiTab(context, provider),
                _buildFirstAidTab(provider),
                _buildTrafficSafetyTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAqiTab(BuildContext context, EnvironmentProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        children: [
          VcCard(
            child: Column(
              children: [
                const Icon(
                  Icons.air,
                  size: 48,
                  color: AppColors.accentEnvironment,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hava Kalitesi İndeksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (provider.isLoadingAqi)
                  const CircularProgressIndicator()
                else if (provider.aqi != null)
                  _buildAqiDisplay(provider)
                else if (provider.aqiError != null)
                  Column(
                    children: [
                      Text(
                        provider.aqiError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      // Ağ/zaman aşımı hatalarında önceden hiçbir düğme
                      // yoktu; kullanıcı ekrandan çıkıp girmek zorundaydı.
                      ElevatedButton.icon(
                        onPressed: () => provider.fetchAqi(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => provider.fetchAqi(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Hava Kalitesini Kontrol Et'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yalnızca yaklaşık konumunuz (yaklaşık 10 km) hava '
                        'kalitesi servisine gönderilir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (provider.aqi != null)
            VcCard(
              borderColor: provider.aqiColor.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Öneri',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.aqiRecommendation,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _buildAqiLegend(),
        ],
      ),
    );
  }

  Widget _buildAqiDisplay(EnvironmentProvider provider) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          '${provider.aqi}',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: provider.aqiColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: provider.aqiColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            provider.aqiLevel,
            style: TextStyle(
              color: provider.aqiColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (provider.pm25 != null) ...[
          const SizedBox(height: 8),
          Text(
            'PM2,5: ${provider.pm25!.toStringAsFixed(1).replaceAll('.', ',')} µg/m³',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => provider.fetchAqi(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Güncelle'),
        ),
        Text(
          EnvironmentProvider.attribution,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildAqiLegend() {
    final levels = [
      {'range': '0-50', 'label': 'İyi', 'color': const Color(0xFF2E7D32)},
      {
        'range': '51-100',
        'label': 'Orta',
        'color': EnvironmentProvider.colorFor(100),
      },
      {
        'range': '101-150',
        'label': 'Hassas Gruplar',
        'color': EnvironmentProvider.colorFor(150),
      },
      {
        'range': '151-200',
        'label': 'Sağlıksız',
        'color': const Color(0xFFD32F2F),
      },
      {
        'range': '201-300',
        'label': 'Çok Sağlıksız',
        'color': EnvironmentProvider.colorFor(300),
      },
      {'range': '300+', 'label': 'Tehlikeli', 'color': const Color(0xFF880E4F)},
    ];

    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AQI Değerlendirmesi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...levels.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: l['color'] as Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${l['range']}: ${l['label']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAidTab(EnvironmentProvider provider) {
    if (provider.firstAidGuides.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: provider.firstAidGuides.length,
      itemBuilder: (context, index) {
        final guide = provider.firstAidGuides[index];
        final isEmergency = guide['severity'] == 'emergency';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VcCard(
            borderColor: isEmergency
                ? AppColors.danger.withValues(alpha: 0.3)
                : null,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(
                isEmergency ? Icons.emergency : Icons.healing,
                color: isEmergency
                    ? AppColors.danger
                    : AppColors.accentEnvironment,
              ),
              title: Text(
                guide['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: SpeakButton(
                    id: 'first-aid-${guide['id']}',
                    text:
                        '${guide['title']}. ${(guide['steps'] as List).asMap().entries.map((s) => '${s.key + 1}. ${s.value}').join(' ')}',
                  ),
                ),
                ...(guide['steps'] as List).asMap().entries.map((step) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            '${step.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrafficSafetyTab() {
    final tips = EnvironmentProvider.trafficSafetyTips;

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: tips.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VcCard(
              borderColor: AppColors.warning.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trafik Güvenliği',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Türkiye\'de her yıl yaklaşık 7.000 kişi trafik kazalarında hayatını kaybetmektedir.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final tip = tips[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VcCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentEnvironment.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  tip['icon'] as IconData,
                  color: AppColors.accentEnvironment,
                  size: 20,
                ),
              ),
              title: Text(
                tip['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tip['category'] == 'araç'
                      ? 'Araç İçi'
                      : tip['category'] == 'yaya'
                      ? 'Yaya'
                      : 'Bisiklet',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    tip['content'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
