import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../../shared/widgets/vc_button.dart';
import '../providers/maternal_provider.dart';
import '../models/maternal_model.dart';

class MaternalScreen extends StatelessWidget {
  const MaternalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anne & Bebek'),
          actions: [
            Consumer<MaternalProvider>(
              builder: (context, provider, _) {
                if (provider.pregnancyProfile.lastPeriodDate == null) {
                  return const SizedBox.shrink();
                }
                return PopupMenuButton<String>(
                  tooltip: 'Seçenekler',
                  onSelected: (value) async {
                    if (value == 'change') {
                      await _pickLastPeriodDate(context, provider);
                    } else if (value == 'end') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Gebelik Takibini Sonlandır'),
                          content: const Text(
                            'Son adet tarihi silinecek. Emzirme kayıtlarınız '
                            'korunur.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('İptal'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sonlandır'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await provider.clearPregnancy();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'change',
                      child: Text('Son adet tarihini değiştir'),
                    ),
                    PopupMenuItem(
                      value: 'end',
                      child: Text('Gebelik takibini sonlandır'),
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: [
              Tab(text: 'Gebelik'),
              Tab(text: 'Hafta Rehberi'),
              Tab(text: 'Preeklampsi'),
              Tab(text: 'Emzirme'),
            ],
          ),
        ),
        body: Consumer<MaternalProvider>(
          builder: (context, provider, _) {
            return TabBarView(
              children: [
                _buildPregnancyOverview(context, provider),
                _buildWeeklyGuide(provider),
                _buildPreeclampsiaTab(provider),
                _buildBreastfeedingTab(context, provider),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<void> _pickLastPeriodDate(
    BuildContext context,
    MaternalProvider provider,
  ) async {
    final now = DateTime.now();
    final current = provider.pregnancyProfile.lastPeriodDate;
    final first = now.subtract(const Duration(days: 300));
    final date = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(first)
          ? current
          : now.subtract(const Duration(days: 60)),
      firstDate: first,
      lastDate: now,
    );
    if (date != null) await provider.setLastPeriodDate(date);
  }

  Widget _buildPregnancyOverview(
    BuildContext context,
    MaternalProvider provider,
  ) {
    final profile = provider.pregnancyProfile;

    if (profile.lastPeriodDate == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: VcCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.child_care,
                  size: 64,
                  color: AppColors.accentMaternal,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gebelik Takibi',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Son adet tarihinizi girerek gebelik takibine başlayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                VcButton(
                  text: 'Son Adet Tarihimi Gir',
                  onPressed: () => _pickLastPeriodDate(context, provider),
                  icon: Icons.calendar_today,
                  color: AppColors.accentMaternal,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 42 haftayı aşan bir gebelik gerçekçi değildir (doğum olmuş ya da
    // tarih yanlış). Önceden hafta sayısı sonsuza kadar artıyordu.
    if (profile.currentWeek > 42) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: VcCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  size: 56,
                  color: AppColors.accentMaternal,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gebelik süresi tamamlanmış görünüyor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Son adet tarihini güncelleyebilir veya gebelik takibini '
                  'sonlandırabilirsiniz. Emzirme sekmesi kullanılmaya devam eder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                VcButton(
                  text: 'Tarihi Güncelle',
                  onPressed: () => _pickLastPeriodDate(context, provider),
                  icon: Icons.edit_calendar,
                  color: AppColors.accentMaternal,
                ),
                TextButton(
                  onPressed: provider.clearPregnancy,
                  child: const Text('Takibi sonlandır'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final weekData = provider.currentWeekData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        children: [
          VcCard(
            borderColor: AppColors.accentMaternal.withValues(alpha: 0.3),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${profile.currentWeek}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentMaternal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hafta',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.accentMaternal,
                          ),
                        ),
                        Text(
                          '${profile.currentDay}. gün',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentMaternal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${profile.trimester}. Trimester',
                    style: const TextStyle(
                      color: AppColors.accentMaternal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tahmini doğum: ${profile.daysRemaining > 0 ? "${profile.daysRemaining} gün kaldı" : "Doğum zamanı!"}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (weekData != null) ...[
            const SizedBox(height: 16),
            VcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.child_care,
                        color: AppColors.accentMaternal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bebek: ${weekData['baby_size_comparison']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        weekData['baby_size'],
                        style: TextStyle(color: AppColors.textHint),
                      ),
                      SpeakButton(
                        id: 'pregnancy-week',
                        color: AppColors.accentMaternal,
                        text:
                            'Bebeğiniz ${weekData['baby_size_comparison']} büyüklüğünde. '
                            '${weekData['baby_development']} Annedeki değişimler: '
                            '${weekData['mother_changes']} Öneriler: ${weekData['tips']}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weekData['baby_development'],
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Annedeki Değişimler',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekData['mother_changes'],
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Öneriler',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(weekData['tips'], style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyGuide(MaternalProvider provider) {
    if (provider.weeks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: provider.weeks.length,
      itemBuilder: (context, index) {
        final week = provider.weeks[index];
        final isCurrent = provider.currentGuideWeek == week['week'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VcCard(
            borderColor: isCurrent ? AppColors.accentMaternal : null,
            padding: const EdgeInsets.all(12),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentMaternal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Şu an',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  Text(
                    '${week['week']}. Hafta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              subtitle: Text(
                '${week['baby_size_comparison']} (${week['baby_size']})',
                style: const TextStyle(
                  color: AppColors.accentMaternal,
                  fontSize: 12,
                ),
              ),
              children: [
                _infoRow('Gelişim', week['baby_development']),
                _infoRow('Anne', week['mother_changes']),
                _infoRow('Öneriler', week['tips']),
                if ((week['warnings'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...((week['warnings'] as List).map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              w,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPreeclampsiaTab(MaternalProvider provider) {
    if (provider.preeclampsiaRules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VcCard(
            borderColor: AppColors.danger.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text(
                      'Preeklampsi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  provider.preeclampsiaRules['action'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Risk Faktörleri',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...(List<String>.from(
            provider.preeclampsiaRules['risk_factors'] ?? [],
          )).map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Uyarı İşaretleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          ...(List<String>.from(
            provider.preeclampsiaRules['warning_signs'] ?? [],
          )).map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreastfeedingTab(
    BuildContext context,
    MaternalProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        children: [
          VcCard(
            child: Column(
              children: [
                const Icon(
                  Icons.child_care,
                  size: 40,
                  color: AppColors.accentMaternal,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bugünkü Emzirme',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${provider.todayFeedingCount}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentMaternal,
                          ),
                        ),
                        Text(
                          'Sefer',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${provider.todayFeedingMinutes}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentMaternal,
                          ),
                        ),
                        Text(
                          'Dakika',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                VcButton(
                  text: 'Emzirme Kaydet',
                  onPressed: () => _addBreastfeeding(context, provider),
                  icon: Icons.add,
                  color: AppColors.accentMaternal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (provider.breastfeedingLog.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Son Kayıtlar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ...provider.breastfeedingLog.take(10).map((entry) {
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.child_care,
                  color: AppColors.accentMaternal,
                  size: 20,
                ),
                title: Text('${entry.durationMinutes} dk - ${entry.side}'),
                subtitle: Text(
                  '${entry.startTime.hour}:${entry.startTime.minute.toString().padLeft(2, '0')}',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _addBreastfeeding(
    BuildContext context,
    MaternalProvider provider,
  ) async {
    final durationController = TextEditingController(text: '15');
    String side = 'Sol';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Emzirme Kaydet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Süre (dakika)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: ['Sol', 'Sağ', 'Her İki'].map((s) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        selected: side == s,
                        selectedColor: AppColors.accentMaternal.withValues(
                          alpha: 0.2,
                        ),
                        onSelected: (_) => setState(() => side = s),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Önceden geçersiz giriş sessizce 15 dk'ya dönüyor, 0 veya 900 dk
      // gibi değerler de kabul ediliyordu.
      final duration = InputUtils.inRange(
        InputUtils.parseInt(durationController.text),
        1,
        120,
      );
      if (duration == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Süre 1-120 dakika arasında olmalı.')),
          );
        }
        return;
      }
      await provider.addBreastfeeding(
        BreastfeedingEntry(
          startTime: DateTime.now(),
          durationMinutes: duration,
          side: side,
        ),
      );
    }
  }
}
