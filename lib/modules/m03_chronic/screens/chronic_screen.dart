import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../services/hive_service.dart';
import '../../../services/notification_service.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../m01_profile/providers/profile_provider.dart';
import '../providers/chronic_provider.dart';
import '../../m11_access/providers/access_provider.dart';
import '../models/blood_sugar.dart';
import '../models/health_entry.dart';
import '../services/drug_interaction_service.dart';
import '../widgets/adherence_widgets.dart';
import '../widgets/medication_dialog.dart';
import '../../../shared/widgets/speak_button.dart';

class ChronicScreen extends StatelessWidget {
  const ChronicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kronik Hastalık Takibi')),
      body: Consumer<ChronicProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSugarSection(context, provider),
                const SizedBox(height: 24),
                _buildPressureSection(context, provider),
                const SizedBox(height: 24),
                _buildWeightSection(context, provider),
                const SizedBox(height: 24),
                _buildMedicationSection(context, provider),
                const SizedBox(height: 24),
                _buildScreeningReminders(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Kan şekeri grafiği için (minY, maxY, aralık).
  (double, double, double) _sugarAxis(ChronicProvider provider) {
    final values = provider.bloodSugar7Days.map((e) => e.value).toList();
    if (values.isEmpty) return (0, 200, 50);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final step = hi - lo > 120 ? 50.0 : 20.0;
    final minY = (((lo - 5) / step).floor() * step).clamp(0.0, double.infinity);
    final maxY = ((hi + 5) / step).ceil() * step;
    return (minY, maxY, step);
  }

  Widget _buildSugarSection(BuildContext context, ChronicProvider provider) {
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kan Şekeri',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Kan şekeri ekle',
                onPressed: () => _addBloodSugar(context, provider),
                icon: Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          if (provider.bloodSugarEntries.isNotEmpty) ...[
            // Grafik son 7 günü çizer; koşul da o listeye bakmalı.
            // Aksi halde toplamda 2+ kayıt olup son 7 günde tek kayıt
            // kaldığında grafik tek noktayla (minX == maxX) çizilmeye çalışılır.
            if (provider.bloodSugar7Days.length > 1)
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    // Eksen sınırları 20'nin katlarına yuvarlanır; aksi halde
                    // fl_chart en küçük/en büyük değeri ayrıca etiketler ve
                    // "100" ile "99" gibi etiketler üst üste biner.
                    minY: _sugarAxis(provider).$1,
                    maxY: _sugarAxis(provider).$2,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: _sugarAxis(provider).$3,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: _sugarAxis(provider).$3,
                          // Büyük yazı modunda "120" iki satıra bölünüyordu.
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              value.toInt().toString(),
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: provider.bloodSugar7Days.asMap().entries.map((
                          e,
                        ) {
                          return FlSpot(e.key.toDouble(), e.value.value);
                        }).toList(),
                        isCurved: true,
                        // Eğrinin noktalar arasında gerçek ölçümlerin
                        // üstüne/altına taşmasını engeller.
                        preventCurveOverShooting: true,
                        color: AppColors.accentChronic,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.accentChronic.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Latest value — Wrap: büyük yazı modunda durum etiketi alt
            // satıra geçer (Row'da 81 px taşıyordu).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                Text(
                  'Son değer: ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  '${provider.bloodSugarEntries.last.value.toInt()} mg/dL',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _sugarColor(
                      provider.assessSugar(provider.bloodSugarEntries.last),
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider.assessSugar(provider.bloodSugarEntries.last).label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _sugarColor(
                        provider.assessSugar(provider.bloodSugarEntries.last),
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...provider.bloodSugarEntries.reversed
                .take(5)
                .map(
                  (entry) => ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.water_drop,
                      color: _sugarColor(provider.assessSugar(entry)),
                      size: 20,
                    ),
                    title: Text('${entry.value.toInt()} mg/dL'),
                    subtitle: Text(
                      [
                        if (SugarTiming.parse(entry.timing) case final t?)
                          t.label,
                        _shortDate(entry.date),
                      ].join(' • '),
                    ),
                    trailing: _deleteButton(
                      context,
                      label: 'Kan şekeri ölçümü',
                      remove: () => provider.removeBloodSugar(entry),
                      restore: () => provider.restoreBloodSugar(entry),
                    ),
                  ),
                ),
          ] else
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Henüz kayıt yok. + butonuna basarak ekleyin.',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Renk, durum etiketiyle aynı değerlendirmeden gelir. Hipoglisemi
  /// önceden turuncu gösteriliyordu; anlık tehlikesi yüksek olduğu için
  /// kırmızıdır.
  Color _sugarColor(SugarAssessment assessment) => switch (assessment.level) {
    SugarLevel.normal => AppColors.success,
    SugarLevel.elevated => AppColors.warning,
    SugarLevel.severeLow ||
    SugarLevel.low ||
    SugarLevel.high ||
    SugarLevel.veryHigh => AppColors.danger,
  };

  Future<void> _addBloodSugar(
    BuildContext context,
    ChronicProvider provider,
  ) async {
    final controller = TextEditingController();
    var timing = SugarTiming.fasting;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kan Şekeri Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Değer (mg/dL)',
                  hintText: 'Örn: 95',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Ölçüm zamanı'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in SugarTiming.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: timing == t,
                      onSelected: (_) => setDialogState(() => timing = t),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    // Önceden geçersiz/virgüllü giriş sessizce yok sayılıyordu; 0 veya
    // 5000 gibi fizyolojik olarak imkânsız değerler de kaydediliyordu.
    final value = InputUtils.inRange(
      InputUtils.parseDecimal(result),
      20.0,
      600.0,
    );
    if (value == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçersiz değer. Kan şekeri 20-600 mg/dL olmalı.'),
          ),
        );
      }
      return;
    }
    await provider.addBloodSugar(value, timing: timing);
    if (!context.mounted) return;
    final assessment = assessBloodSugar(value, timing);
    if (assessment.isLow) {
      await _showUrgentAdvice(
        context,
        title: assessment.level == SugarLevel.severeLow
            ? 'Ciddi düşük kan şekeri'
            : 'Düşük kan şekeri',
        message:
            '15-15 kuralı: Hemen 15 gram hızlı etkili şeker alın (yarım su '
            'bardağı meyve suyu, 3-4 küp şeker ya da 1 yemek kaşığı bal). '
            "15 dakika sonra tekrar ölçün; hâlâ 70 mg/dL'nin altındaysa "
            'tekrarlayın.\n\nBilinç bulanıklığı, nöbet veya yutamama varsa '
            "ağızdan bir şey vermeyin ve hemen 112'yi arayın.",
      );
    } else if (assessment.level == SugarLevel.veryHigh) {
      await _showUrgentAdvice(
        context,
        title: 'Çok yüksek kan şekeri',
        message:
            'Bol su için ve doktorunuza hemen ulaşın.\n\nBulantı-kusma, '
            'karın ağrısı, hızlı nefes alma, nefeste meyve kokusu veya '
            "bilinç bulanıklığı varsa 112'yi arayın; bunlar ketoasidoz "
            'belirtisi olabilir.',
      );
    }
  }

  /// Tehlikeli ölçümden hemen sonra gösterilen yönlendirme. Önceden yalnızca
  /// listedeki etiket değişiyordu.
  Future<void> _showUrgentAdvice(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              AccessProvider().callNumber(AppConstants.emergencyNumber);
            },
            icon: const Icon(Icons.call),
            label: const Text("112'yi Ara"),
          ),
        ],
      ),
    );
  }

  Widget _buildPressureSection(BuildContext context, ChronicProvider provider) {
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tansiyon',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Tansiyon ekle',
                onPressed: () => _addBloodPressure(context, provider),
                icon: Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          if (provider.bloodPressureEntries.isNotEmpty)
            ...(provider.bloodPressureEntries.reversed.take(5).map((entry) {
              return ListTile(
                dense: true,
                leading: Icon(
                  Icons.favorite,
                  color: AppColors.danger,
                  size: 20,
                ),
                title: Text(entry.display),
                subtitle: Text('${entry.category} • ${_shortDate(entry.date)}'),
                trailing: _deleteButton(
                  context,
                  label: 'Tansiyon ölçümü',
                  remove: () => provider.removeBloodPressure(entry),
                  restore: () => provider.restoreBloodPressure(entry),
                ),
              );
            }))
          else
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Henüz kayıt yok',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addBloodPressure(
    BuildContext context,
    ChronicProvider provider,
  ) async {
    final sysController = TextEditingController();
    final diaController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tansiyon Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sysController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Sistolik (büyük tansiyon)',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: diaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Diastolik (küçük tansiyon)',
              ),
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
    );

    final sys = InputUtils.inRange(
      InputUtils.parseDecimal(sysController.text),
      60.0,
      260.0,
    );
    final dia = InputUtils.inRange(
      InputUtils.parseDecimal(diaController.text),
      30.0,
      160.0,
    );
    if (result != true) return;

    if (sys == null || dia == null || sys <= dia) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Geçersiz değer. Büyük tansiyon 60-260, küçük tansiyon 30-160 '
              'mmHg olmalı ve büyük tansiyon küçükten yüksek olmalı.',
            ),
          ),
        );
      }
      return;
    }
    await provider.addBloodPressure(sys, dia);
    if (!context.mounted) return;
    final entry = BloodPressureEntry(
      systolic: sys,
      diastolic: dia,
      date: DateTime.now(),
    );
    if (entry.isCrisis) {
      await _showUrgentAdvice(
        context,
        title: 'Tansiyonunuz çok yüksek',
        message:
            'Hipertansif kriz olabilir. 5 dakika oturup dinlendikten sonra '
            'tekrar ölçün.\n\nGöğüs ağrısı, nefes darlığı, şiddetli baş '
            'ağrısı, görme bozukluğu, konuşma güçlüğü, kolda veya bacakta '
            "güçsüzlük ya da bilinç bulanıklığı varsa hemen 112'yi arayın. "
            'Belirti yoksa ve değer yine yüksekse aynı gün doktorunuza '
            'başvurun.',
      );
    } else if (entry.isLow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 8),
          content: Text(
            'Tansiyonunuz düşük. Baş dönmesi veya halsizlik varsa uzanıp '
            "bacaklarınızı yükseltin; bayılma varsa 112'yi arayın.",
          ),
        ),
      );
    }
  }

  static const _shortMonths = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  static String _shortDate(DateTime d) =>
      '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

  /// 72.5 -> "72,5", 72.0 -> "72"; Türkçe ondalık virgülüyle.
  static String _formatKg(double value) {
    final rounded = (value * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }

  /// Ölçümü siler; yanlışlıkla silindiyse "Geri al" ile aynı tarihiyle
  /// geri konur.
  Widget _deleteButton(
    BuildContext context, {
    required String label,
    required Future<void> Function() remove,
    required Future<void> Function() restore,
  }) {
    return IconButton(
      tooltip: 'Sil',
      icon: Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await remove();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$label silindi'),
              action: SnackBarAction(label: 'Geri al', onPressed: restore),
            ),
          );
      },
    );
  }

  // Kilo silinince profildeki güncel kilo da değişir; profil ekranı tazelenir.
  Future<void> _removeWeight(
    BuildContext context,
    ChronicProvider provider,
    HealthEntry entry,
  ) async {
    final profile = context.read<ProfileProvider>();
    await provider.removeWeight(entry);
    profile.loadProfile();
  }

  Future<void> _restoreWeight(
    BuildContext context,
    ChronicProvider provider,
    HealthEntry entry,
  ) async {
    final profile = context.read<ProfileProvider>();
    await provider.restoreWeight(entry);
    profile.loadProfile();
  }

  Widget _buildWeightSection(BuildContext context, ChronicProvider provider) {
    final entries = provider.weightEntries;
    final change = provider.weightChange30Days;
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kilo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Kilo ekle',
                onPressed: () => _addWeight(context, provider),
                icon: Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Henüz kayıt yok',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            )
          else ...[
            Text(
              '${_formatKg(entries.last.value)} kg',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (change != null)
              Text(
                'Son 30 günde ${change > 0 ? '+' : ''}${_formatKg(change)} kg',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 8),
            ...entries.reversed
                .take(5)
                .map(
                  (entry) => ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.monitor_weight,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text('${_formatKg(entry.value)} kg'),
                    subtitle: Text(_shortDate(entry.date)),
                    trailing: _deleteButton(
                      context,
                      label: 'Kilo ölçümü',
                      remove: () => _removeWeight(context, provider, entry),
                      restore: () => _restoreWeight(context, provider, entry),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Future<void> _addWeight(
    BuildContext context,
    ChronicProvider provider,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kilo Ekle'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Kilo (kg)',
            hintText: 'Örn: 72,5',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    final value = InputUtils.inRange(
      InputUtils.parseDecimal(result),
      20.0,
      350.0,
    );
    if (value == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçersiz değer. Kilo 20-350 kg arasında olmalı.'),
          ),
        );
      }
      return;
    }
    await provider.addWeight(value);
    // Profil ekranı ve BMI aynı güncel kiloyu göstersin.
    if (context.mounted) context.read<ProfileProvider>().loadProfile();
  }

  Widget _buildMedicationSection(
    BuildContext context,
    ChronicProvider provider,
  ) {
    return VcCard(
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'İlaç Hatırlatıcıları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () async {
                  final result = await showDialog<MedicationReminder>(
                    context: context,
                    builder: (_) => const MedicationDialog(),
                  );
                  if (result != null) {
                    // Eklemeden önce mevcut ilaçlarla etkileşimi denetle.
                    final checker = await DrugInteractionService().checker;
                    final warnings = checker.checkNew(
                      result.name,
                      provider.medications.map((m) => m.name),
                    );
                    if (warnings.isNotEmpty) {
                      if (!context.mounted) return;
                      final proceed = await _showInteractionDialog(
                        context,
                        result.name,
                        warnings,
                      );
                      if (proceed != true) return;
                    }
                    final requestExact = context.mounted
                        ? await _askExactAlarmPermission(context)
                        : false;
                    final scheduled = await provider.addMedication(
                      result,
                      requestExactPermission: requestExact,
                    );
                    if (!scheduled && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'İlaç kaydedildi ancak bildirim izni verilmedi.',
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          if (provider.medications.length > 1)
            _InteractionBanner(
              medications: provider.medications.map((m) => m.name).toList(),
            ),
          if (provider.medications.isNotEmpty) ...[
            const _ExactAlarmBanner(),
            AdherenceSummary(provider: provider),
            // Günde birden çok dozu olan ilacın her saati ayrı satırdır.
            for (final (index, medication) in provider.medications.indexed)
              for (final dose in medication.doses)
                MedicationRow(
                  provider: provider,
                  medication: medication,
                  dose: dose,
                  onDelete: () => provider.removeMedication(index),
                ),
          ] else
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Hatırlatıcı eklemek için + butonuna basın',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Android 12+ tam zamanlı alarm izni yoksa, sistem ayarlarına
  /// göndermeden önce nedenini açıklar. Yalnızca bir kez sorulur.
  Future<bool> _askExactAlarmPermission(BuildContext context) async {
    if (await NotificationService().canScheduleExactAlarms()) return false;
    final settings = HiveService().getSettingsBox();
    if (settings.get('exact_alarm_prompted') == true) return false;
    await settings.put('exact_alarm_prompted', true);
    if (!context.mounted) return false;
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.alarm, color: AppColors.primary),
        title: const Text('Tam zamanında hatırlatma'),
        content: const Text(
          'İlaç hatırlatmalarınızın dakikası dakikasına gelmesi için '
          '"Alarmlar ve hatırlatıcılar" izni gerekir. Sonraki ekranda '
          'VitaCoach için bu izni açabilirsiniz.\n\nİzin vermezseniz '
          'hatırlatmalar yine gelir ancak birkaç dakika gecikebilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İzin ver'),
          ),
        ],
      ),
    );
    return allow ?? false;
  }

  static Color severityColor(InteractionSeverity severity) {
    switch (severity) {
      case InteractionSeverity.high:
        return AppColors.danger;
      case InteractionSeverity.moderate:
        return AppColors.warning;
      case InteractionSeverity.low:
        return AppColors.accentChronic;
    }
  }

  Future<bool?> _showInteractionDialog(
    BuildContext context,
    String newMedication,
    List<InteractionWarning> warnings,
  ) {
    final spoken = warnings
        .map((w) => '${w.drugA} ile ${w.drugB}: ${w.message}')
        .join(' ');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            const Expanded(child: Text('Olası İlaç Etkileşimi')),
            SpeakButton(text: spoken, id: 'interaction-dialog'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${w.drugA} + ${w.drugB}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Önem: ${w.severity.label}',
                        style: TextStyle(
                          color: severityColor(w.severity),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(w.message),
                    ],
                  ),
                ),
              ),
              Text(
                'Bu uyarı sık görülen etkileşimleri kapsar, eksiksiz değildir. '
                'İlacı kullanmadan önce doktorunuza veya eczacınıza danışın.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yine de ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningReminders() {
    return VcCard(
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Kanser Tarama Hatırlatıcıları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildScreeningItem('Mamografi', '40 yaş üstü kadınlar, yılda bir'),
          _buildScreeningItem('Kolonoskopi', '50 yaş üstü, 10 yılda bir'),
          _buildScreeningItem('PSA Testi', '50 yaş üstü erkekler, yılda bir'),
          _buildScreeningItem('Pap Smear', '21-65 yaş kadınlar, 3 yılda bir'),
        ],
      ),
    );
  }

  Widget _buildScreeningItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
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
    );
  }
}

/// Kayıtlı ilaçlar arasında bilinen etkileşimleri gösteren kart.
class _InteractionBanner extends StatelessWidget {
  final List<String> medications;

  const _InteractionBanner({required this.medications});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DrugInteractionChecker>(
      future: DrugInteractionService().checker,
      builder: (context, snapshot) {
        final checker = snapshot.data;
        if (checker == null) return const SizedBox.shrink();
        final warnings = checker.checkAll(medications);
        if (warnings.isEmpty) return const SizedBox.shrink();
        final top = warnings.first.severity;
        final color = ChronicScreen.severityColor(top);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${warnings.length} olası ilaç etkileşimi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  SpeakButton(
                    id: 'interaction-banner',
                    color: color,
                    text: warnings
                        .map((w) => '${w.drugA} ile ${w.drugB}: ${w.message}')
                        .join(' '),
                  ),
                ],
              ),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${w.drugA} + ${w.drugB} '
                              '(${w.severity.label}): ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: w.message),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Doktorunuza veya eczacınıza danışmadan ilaç bırakmayın.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tam zamanlı alarm izni yoksa ilaç hatırlatmaları Android'de bir saate
/// kadar gecikebilir; kullanıcıyı bilgilendirip izin sayfasını açar.
class _ExactAlarmBanner extends StatefulWidget {
  const _ExactAlarmBanner();

  @override
  State<_ExactAlarmBanner> createState() => _ExactAlarmBannerState();
}

class _ExactAlarmBannerState extends State<_ExactAlarmBanner>
    with WidgetsBindingObserver {
  bool _canExact = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kullanıcı sistem sayfasından dönünce durumu yenile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final can = await NotificationService().canScheduleExactAlarms();
    if (!mounted || can == _canExact) return;
    setState(() => _canExact = can);
    // İzin yeni verildiyse hatırlatmaları tam zamanlı olarak yeniden kur
    // (kullanıcı Ayarlar'dan kapatmadıysa).
    final enabled =
        HiveService().getProfileBox().get('medication_reminder_enabled') !=
        false;
    if (can && enabled) {
      await context.read<ChronicProvider>().setMedicationRemindersEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_canExact) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hatırlatmalar tam zamanında değil; Android bir saate kadar '
              'geciktirebilir.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () =>
                NotificationService().requestExactAlarmPermission(),
            child: const Text('İzin ver'),
          ),
        ],
      ),
    );
  }
}
