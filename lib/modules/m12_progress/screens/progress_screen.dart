import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/vc_card.dart';
import '../providers/progress_provider.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ReloadOnOpen(child: _buildScaffold(context));
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlerleme')),
      body: Consumer<ProgressProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () async => provider.loadData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              child: Column(
                children: [
                  _buildStreakCard(provider),
                  const SizedBox(height: 16),
                  _buildHealthScoreCard(provider),
                  const SizedBox(height: 16),
                  _buildWeeklySummaryCard(provider),
                  const SizedBox(height: 16),
                  _buildBadgesCard(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakCard(ProgressProvider provider) {
    return VcCard(
      borderColor: AppColors.accentProgress.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentProgress.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department,
              size: 36,
              color: AppColors.accentProgress,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.moodStreak} gün',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Üst üste giriş serisi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Overall score badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Column(
              children: [
                Text(
                  provider.overallScore.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'skor',
                  style: TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(ProgressProvider provider) {
    final values = provider.healthScoreValues;
    final labels = provider.healthScoreLabels;

    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sağlık Skoru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Günlük aktivitelerinize göre hesaplanır.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          // Radar başlıkları grafiğin dışına taşar; üst/alt boşluk olmadan
          // "Beslenme" etiketi açıklama metninin üzerine biniyordu.
          const SizedBox(height: 40),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.primary.withValues(alpha: 0.2),
                    borderColor: AppColors.primary,
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries: values
                        .map((v) => RadarEntry(value: v))
                        .toList(),
                  ),
                  // Görünmez sınır veri setleri: ölçek her zaman 0-10 olsun.
                  // Aksi halde fl_chart ölçeği en yüksek skora göre kurar ve
                  // "2.3 / 4.5 / 6.8" gibi düzensiz etiketler çıkar.
                  for (final bound in const [0.0, 10.0])
                    RadarDataSet(
                      fillColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      borderWidth: 0,
                      entryRadius: 0,
                      dataEntries: List.filled(
                        values.length,
                        RadarEntry(value: bound),
                      ),
                    ),
                ],
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                getTitle: (index, angle) {
                  final score = values[index].toStringAsFixed(1);
                  return RadarChartTitle(text: '${labels[index]}\n$score');
                },
                tickCount: 5,
                ticksTextStyle: TextStyle(
                  fontSize: 9,
                  color: AppColors.textHint,
                ),
                tickBorderData: BorderSide(
                  color: AppColors.textHint.withValues(alpha: 0.2),
                ),
                gridBorderData: BorderSide(
                  color: AppColors.textHint.withValues(alpha: 0.2),
                ),
                radarBorderData: BorderSide(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          // Legend for score ranges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreLegend(
                label: '0-3',
                desc: 'Düşük',
                color: AppColors.danger,
              ),
              _ScoreLegend(
                label: '4-6',
                desc: 'Orta',
                color: AppColors.warning,
              ),
              _ScoreLegend(
                label: '7-10',
                desc: 'İyi',
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummaryCard(ProgressProvider provider) {
    final summary = provider.weeklySummary;
    final avgMood = (summary['avg_mood'] as double);
    final moodEmoji = avgMood >= 4
        ? '😊'
        : avgMood >= 3
        ? '😐'
        : avgMood >= 2
        ? '😟'
        : avgMood > 0
        ? '😢'
        : '—';

    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_view_week,
                color: AppColors.accentProgress,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Haftalık Özet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.directions_walk,
                  color: AppColors.accentFitness,
                  value: '${summary['avg_steps']}',
                  label: 'Ort. Adım/gün',
                ),
              ),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.water_drop,
                  color: Colors.blue,
                  value: '${summary['total_water_glasses']}',
                  label: 'Toplam Su (bardak)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.mood,
                  color: AppColors.accentMental,
                  value: avgMood > 0
                      ? '$moodEmoji ${avgMood.toStringAsFixed(1)}'
                      : '—',
                  label: 'Ort. Ruh Hali',
                ),
              ),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.restaurant,
                  color: AppColors.accentNutrition,
                  value: '${summary['meal_days']}/7',
                  label: 'Öğün Kaydı Gün',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesCard(ProgressProvider provider) {
    // All possible badges with lock state
    final allBadges = [
      {
        'name': 'Başlangıç',
        'icon': Icons.star_outline,
        'color': Colors.amber,
        'desc': '3 gün üst üste giriş',
      },
      {
        'name': 'Hafta Ustası',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'desc': '7 gün üst üste',
      },
      {
        'name': 'Ay Kahramanı',
        'icon': Icons.military_tech,
        'color': Colors.amber,
        'desc': '30 gün üst üste',
      },
      {
        'name': 'Su Perisi',
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'desc': 'Günlük su hedefini tamamla',
      },
      {
        'name': 'Yürüyüş Ustası',
        'icon': Icons.directions_walk,
        'color': Colors.teal,
        'desc': '10.000 adım',
      },
      {
        'name': 'Düzenli Beslenme',
        'icon': Icons.restaurant,
        'color': Colors.green,
        'desc': '3+ öğün kaydet',
      },
      {
        'name': 'Sigara: İlk Adım',
        'icon': Icons.smoke_free,
        'color': Colors.deepOrange,
        'desc': '1 gün sigarasız',
      },
      {
        'name': 'Sigara: Bir Hafta',
        'icon': Icons.emoji_events,
        'color': Colors.deepOrange,
        'desc': '7 gün sigarasız',
      },
      {
        'name': 'Sigara: Bir Ay',
        'icon': Icons.workspace_premium,
        'color': Colors.green,
        'desc': '30 gün sigarasız',
      },
      {
        'name': 'Yarı Maraton',
        'icon': Icons.run_circle,
        'color': Colors.tealAccent,
        'desc': '5.000 adım at',
      },
      {
        'name': 'Maratoncu',
        'icon': Icons.directions_run,
        'color': Colors.cyan,
        'desc': '20.000 adım at',
      },
      {
        'name': 'Erken Uyanan',
        'icon': Icons.wb_sunny,
        'color': Colors.yellow,
        'desc': 'Bugün saat 10\'dan önce egzersiz yap',
      },
      {
        'name': 'Huzur Arayan',
        'icon': Icons.self_improvement,
        'color': Colors.purple,
        'desc': 'CBT egzersizi tamamla',
      },
      {
        'name': 'Mental Güç',
        'icon': Icons.psychology,
        'color': Colors.purpleAccent,
        'desc': 'Ruh sağlığı testi çöz',
      },
      {
        'name': 'Sağlık Bilgesi',
        'icon': Icons.health_and_safety,
        'color': Colors.indigo,
        'desc': 'Risk analizini tamamla',
      },
      {
        'name': 'Vitamin Deposu',
        'icon': Icons.apple,
        'color': Colors.lightGreen,
        'desc': 'Bugün 2 porsiyon sebze/meyve ekle',
      },
      {
        'name': 'Şeker Düşmanı',
        'icon': Icons.no_food,
        'color': Colors.redAccent,
        'desc': 'Şekerli yiyecek eklemeden öğün kaydet',
      },
      {
        'name': 'Uyku Şampiyonu',
        'icon': Icons.bedtime,
        'color': Colors.indigoAccent,
        'desc': 'Dün gece 8+ saat uyu',
      },
      {
        'name': 'Düzenli İlaç',
        'icon': Icons.medication,
        'color': Colors.pink,
        'desc': 'Haftalık ilaç uyumu %80+',
      },
      {
        'name': 'Hazırlıklı',
        'icon': Icons.medical_information,
        'color': Colors.red,
        'desc': 'Acil sağlık kartını doldur',
      },
    ];

    final earnedNames = provider.badges.map((b) => b['name'] as String).toSet();

    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rozetler',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentProgress.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.totalBadges}/${allBadges.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentProgress,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allBadges.map((badge) {
              final isEarned = earnedNames.contains(badge['name']);
              final color = badge['color'] as Color;
              return GestureDetector(
                onTap: () {},
                child: Tooltip(
                  message: '${badge['desc']}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? color.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEarned
                            ? color.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          badge['icon'] as IconData,
                          color: isEarned
                              ? color
                              : Colors.grey.withValues(alpha: 0.4),
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['name'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isEarned
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                          ),
                        ),
                        if (!isEarned)
                          Icon(Icons.lock, size: 10, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ScoreLegend extends StatelessWidget {
  final String label;
  final String desc;
  final Color color;

  const _ScoreLegend({
    required this.label,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $desc',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _SummaryTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// İlerleme verileri doğrudan Hive'dan hesaplanır ve provider yalnızca ilk
/// kez oluşturulduğunda yükleniyordu. Kullanıcı su/adım/ruh hali ekleyip bu
/// ekrana döndüğünde skorlar, seri ve rozetler eski kalıyordu (yalnızca
/// aşağı çekip yenileyince güncelleniyordu). Ekran her açıldığında yeniden
/// hesapla.
class _ReloadOnOpen extends StatefulWidget {
  final Widget child;

  const _ReloadOnOpen({required this.child});

  @override
  State<_ReloadOnOpen> createState() => _ReloadOnOpenState();
}

class _ReloadOnOpenState extends State<_ReloadOnOpen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProgressProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
