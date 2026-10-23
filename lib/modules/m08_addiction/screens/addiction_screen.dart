import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../../shared/widgets/vc_button.dart';
import '../providers/addiction_provider.dart';

class AddictionScreen extends StatelessWidget {
  const AddictionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sigara Bırakma'),
          actions: [
            // Önceden bırakma tarihi bir kez seçildikten sonra değiştirilemiyor,
            // nüks (yeniden başlama) kaydedilemiyor ve sigara bilgileri
            // düzenlenemiyordu; tek çıkış hesabı tamamen sıfırlamaktı.
            Consumer<AddictionProvider>(
              builder: (context, provider, _) => PopupMenuButton<String>(
                tooltip: 'Seçenekler',
                onSelected: (value) =>
                    _onMenuSelected(context, provider, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Sigara bilgilerini düzenle'),
                  ),
                  if (provider.profile.hasQuit) ...[
                    const PopupMenuItem(
                      value: 'change_date',
                      child: Text('Bırakma tarihini değiştir'),
                    ),
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Yeniden başla (sayacı sıfırla)'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          bottom: const TabBar(
            // Büyük yazı modunda "Zaman Çizelgesi" sabit genişliğe sığmıyor.
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'İlerleme'),
              Tab(text: 'Zaman Çizelgesi'),
              Tab(text: 'Rozetler'),
            ],
          ),
        ),
        body: Consumer<AddictionProvider>(
          builder: (context, provider, _) {
            return TabBarView(
              children: [
                _buildProgressTab(context, provider),
                _buildTimelineTab(provider),
                _buildBadgesTab(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickQuitDate(
    BuildContext context,
    AddictionProvider provider,
  ) async {
    final now = DateTime.now();
    final current = provider.profile.quitDate;
    final date = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(DateTime(2020))
          ? current
          : now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) await provider.setQuitDate(date);
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    AddictionProvider provider,
    String value,
  ) async {
    switch (value) {
      case 'settings':
        await _showSettingsDialog(context, provider);
      case 'change_date':
        await _pickQuitDate(context, provider);
      case 'reset':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Yeniden Başla'),
            content: const Text(
              'Sayaç sıfırlanacak. Nüks bir başarısızlık değildir; çoğu kişi '
              'kalıcı olarak bırakmadan önce birkaç deneme yapar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sıfırla'),
              ),
            ],
          ),
        );
        if (confirm == true) await provider.reset();
    }
  }

  Widget _buildProgressTab(BuildContext context, AddictionProvider provider) {
    if (!provider.profile.hasQuit) {
      return _buildStartCard(context, provider);
    }

    if (provider.profile.isScheduled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: VcCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_available,
                  size: 64,
                  color: AppColors.accentAddiction,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bırakma gününe ${provider.profile.daysUntilQuit} gün kaldı',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sayaç bırakma gününüzde otomatik olarak başlayacak. '
                  'O güne kadar evdeki sigaraları azaltmayı ve tetikleyicilerinizi '
                  'not etmeyi deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        children: [
          VcCard(
            borderColor: AppColors.success.withValues(alpha: 0.3),
            child: Column(
              children: [
                Text(
                  'Sigarasız Geçen Süre',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _timeUnit('${provider.profile.daysSinceQuit}', 'Gün'),
                    const SizedBox(width: 20),
                    _timeUnit(
                      '${provider.profile.hoursSinceQuit % 24}',
                      'Saat',
                    ),
                    const SizedBox(width: 20),
                    _timeUnit(
                      '${provider.profile.minutesSinceQuit % 60}',
                      'Dakika',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VcCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.savings,
                        color: AppColors.success,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.profile.moneySaved.toStringAsFixed(0)} ₺',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Biriktirilen',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VcCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.smoke_free,
                        color: AppColors.accentAddiction,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.profile.cigarettesAvoided}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentAddiction,
                        ),
                      ),
                      Text(
                        'İçilmeyen',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          VcCard(
            child: Column(
              children: [
                Icon(Icons.favorite, color: AppColors.danger, size: 28),
                const SizedBox(height: 4),
                Text(
                  '${provider.profile.lifeDaysGained.toStringAsFixed(1)} gün',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
                Text(
                  'Kazanılan ömür',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          VcButton(
            text: 'İstek Geldi - Yardım',
            onPressed: () => _showCravingHelp(context, provider),
            icon: Icons.psychology,
            color: AppColors.accentAddiction,
          ),
        ],
      ),
    );
  }

  Widget _buildStartCard(BuildContext context, AddictionProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: VcCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.smoke_free,
                size: 72,
                color: AppColors.accentAddiction,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sigarayı Bırakmaya Hazır mısınız?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Bırakma tarihinizi belirleyin ve ilerlemenizi takip edin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              VcButton(
                text: 'Bırakma Tarihimi Belirle',
                onPressed: () => _pickQuitDate(context, provider),
                icon: Icons.calendar_today,
                color: AppColors.accentAddiction,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _showSettingsDialog(context, provider),
                child: const Text('Sigara bilgilerimi ayarla'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineTab(AddictionProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: provider.milestones.length,
      itemBuilder: (context, index) {
        final milestone = provider.milestones[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                milestone.achieved
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: milestone.achieved
                    ? AppColors.success
                    : AppColors.textHint,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VcCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: milestone.achieved
                      ? AppColors.success.withValues(alpha: 0.2)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestone.time,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: milestone.achieved
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        milestone.benefit,
                        style: TextStyle(
                          fontSize: 13,
                          color: milestone.achieved
                              ? AppColors.textSecondary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab(AddictionProvider provider) {
    final badges = provider.badges;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VcCard(
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: AppColors.accentProgress,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  '${provider.earnedBadgeCount} / ${badges.length} Rozet',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...badges.map((badge) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VcCard(
                padding: const EdgeInsets.all(12),
                borderColor: badge.earned
                    ? AppColors.accentProgress.withValues(alpha: 0.3)
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: badge.earned
                            ? AppColors.accentProgress.withValues(alpha: 0.1)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        badge.earned ? Icons.emoji_events : Icons.lock_outline,
                        color: badge.earned
                            ? AppColors.accentProgress
                            : AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: badge.earned
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                          ),
                          Text(
                            badge.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: badge.earned
                                  ? AppColors.textSecondary
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (badge.earned)
                      Icon(Icons.check, color: AppColors.success),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _timeUnit(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }

  Future<void> _showCravingHelp(
    BuildContext context,
    AddictionProvider provider,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: AppColors.accentAddiction),
            SizedBox(width: 8),
            Text('İstek ile Başa Çıkma'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu istek 3-5 dakika içinde geçecektir. Şunları deneyin:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('1. Derin nefes alın (4-7-8 tekniği)'),
            Text('2. Bir bardak su için'),
            Text('3. 5 dakika yürüyüş yapın'),
            Text('4. Sakız çiğneyin'),
            Text('5. Birini arayın ve konuşun'),
            Text('6. Bırakma nedenlerinizi hatırlayın'),
            SizedBox(height: 12),
            Text(
              'Her direniş sizi güçlendirir!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.logCraving('Direndim');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Harika! Direnciniz kaydedildi.')),
              );
            },
            child: Text(
              'Direndim!',
              style: TextStyle(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    AddictionProvider provider,
  ) async {
    final countController = TextEditingController(
      text: '${provider.profile.dailyCigarettes}',
    );
    final priceController = TextEditingController(
      text: '${provider.profile.pricePerCigarette}',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sigara Bilgileri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Günlük sigara sayısı',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Bir sigara fiyatı (₺)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              // Virgüllü fiyat ("5,5") önceden sessizce yok sayılıyordu.
              final count = InputUtils.inRange(
                InputUtils.parseInt(countController.text),
                1,
                100,
              );
              final price = InputUtils.inRange(
                InputUtils.parseDecimal(priceController.text),
                0.1,
                1000.0,
              );
              if (count == null || price == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Günlük sigara 1-100, tek sigara fiyatı 0,1-1000 ₺ olmalı.',
                    ),
                  ),
                );
                return;
              }
              provider.updateSettings(
                dailyCigarettes: count,
                pricePerCigarette: price,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
