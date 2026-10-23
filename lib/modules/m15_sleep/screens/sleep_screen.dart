import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/vc_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../models/sleep_entry.dart';
import '../providers/sleep_provider.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  static const _qualityLabels = {
    1: 'Çok kötü',
    2: 'Kötü',
    3: 'Orta',
    4: 'İyi',
    5: 'Çok iyi',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uyku Takibi')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentSleep,
        foregroundColor: Colors.white,
        onPressed: () => _addSleep(context),
        icon: const Icon(Icons.bedtime),
        label: const Text('Uyku Ekle'),
      ),
      body: Consumer<SleepProvider>(
        builder: (context, provider, _) {
          final last = provider.lastNight;
          final average = provider.weeklyAverageHours;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMD,
              AppConstants.paddingMD,
              AppConstants.paddingMD,
              96,
            ),
            children: [
              _summaryCard(last, average),
              const SizedBox(height: 16),
              _chartCard(provider.last7DaysHours),
              const SizedBox(height: 16),
              _tipsCard(),
              const SizedBox(height: 16),
              if (provider.entries.isNotEmpty) ...[
                const Text(
                  'Kayıtlar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...provider.entries.take(14).map(
                  (e) => VcCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.nights_stay,
                        color: AppColors.accentSleep,
                      ),
                      title: Text(
                        '${_date(e.wakeTime)} • ${e.durationLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${_time(e.bedTime)} → ${_time(e.wakeTime)} • '
                        'Kalite: ${_qualityLabels[e.quality]}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Sil',
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        onPressed: () => provider.removeEntry(e),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _date(DateTime t) => '${_two(t.day)}.${_two(t.month)}';

  Widget _summaryCard(SleepEntry? last, double? average) {
    final score = last == null ? null : SleepScore.compute(last);
    return VcCard(
      borderColor: AppColors.accentSleep.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentSleep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.bedtime,
              color: AppColors.accentSleep,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null ? 'Dün gece kaydı yok' : last.durationLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  last == null
                      ? 'Sabah uyandığınızda uykunuzu ekleyin.'
                      : '${SleepScore.assessment(last)} • Puan ${score!.toStringAsFixed(1)}/10',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                if (average != null)
                  Text(
                    'Haftalık ortalama: ${average.toStringAsFixed(1).replaceAll('.', ',')} saat',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(List<double> hours) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final now = DateTime.now();
    final labels = List.generate(
      7,
      (i) => days[now.subtract(Duration(days: 6 - i)).weekday - 1],
    );
    // Eksen etiketleri 3'er saat aralıklı; üst sınır da 3'ün katı olsun ki
    // en üstte "11" gibi düzensiz bir etiket çıkmasın.
    final longest = [10.0, ...hours].reduce((a, b) => a > b ? a : b);
    final maxY = ((longest + 1) / 3).ceil() * 3.0;
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son 7 Gece',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Yeşil bant: önerilen 7-9 saat',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: 7,
                      y2: 9,
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 3,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        labels[v.toInt()],
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final h = hours[i];
                  final color = h == 0
                      ? AppColors.textHint.withValues(alpha: 0.3)
                      : (h >= 7 && h <= 9)
                      ? AppColors.accentSleep
                      : AppColors.warning;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: h == 0 ? 0.15 : h,
                        color: color,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipsCard() {
    const tips = [
      'Her gün aynı saatte yatıp kalkmaya çalışın.',
      'Yatmadan 1 saat önce ekranlardan uzak durun.',
      'Öğleden sonra kafein tüketimini sınırlayın.',
      'Yatak odasını serin, karanlık ve sessiz tutun.',
    ];
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uyku Hijyeni',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.accentSleep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSleep(BuildContext context) async {
    final provider = context.read<SleepProvider>();
    var bed = const TimeOfDay(hour: 23, minute: 0);
    var wake = const TimeOfDay(hour: 7, minute: 0);
    var quality = 3;
    var wakeDate = DateTime.now();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Uyku Ekle',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.today),
                title: const Text('Uyandığım gün'),
                trailing: Text(
                  _isToday(wakeDate) ? 'Bugün' : _date(wakeDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: wakeDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => wakeDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Yattığım saat'),
                trailing: Text(
                  bed.format(sheetContext),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: sheetContext,
                    initialTime: bed,
                  );
                  if (picked != null) setSheetState(() => bed = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Uyandığım saat'),
                trailing: Text(
                  wake.format(sheetContext),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: sheetContext,
                    initialTime: wake,
                  );
                  if (picked != null) setSheetState(() => wake = picked);
                },
              ),
              const SizedBox(height: 8),
              const Text('Uyku kalitesi'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _qualityLabels.entries
                    .map(
                      (q) => ChoiceChip(
                        label: Text(q.value),
                        selected: quality == q.key,
                        onSelected: (_) =>
                            setSheetState(() => quality = q.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              VcButton(
                text: 'Kaydet',
                color: AppColors.accentSleep,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;
    final entry = SleepEntry.fromTimes(
      wakeDate: wakeDate,
      bedHour: bed.hour,
      bedMinute: bed.minute,
      wakeHour: wake.hour,
      wakeMinute: wake.minute,
      quality: quality,
    );
    if (entry.hours < 1 || entry.hours > 16) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uyku süresi 1-16 saat arasında olmalı.'),
          ),
        );
      }
      return;
    }
    await provider.addEntry(entry);
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
