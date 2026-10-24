import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/health_entry.dart';
import '../models/medication_adherence.dart';
import '../providers/chronic_provider.dart';

Color adherenceColor(int percent) {
  if (percent >= 80) return AppColors.success;
  if (percent >= 50) return AppColors.warning;
  return AppColors.danger;
}

/// İlaç kartının üstündeki "Haftalık ilaç uyumu" özeti.
class AdherenceSummary extends StatelessWidget {
  final ChronicProvider provider;

  const AdherenceSummary({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final report = provider.adherence();
    final percent = report.percent;
    if (percent == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Dozlarınızı "Aldım" ile işaretledikçe haftalık uyum skorunuz '
          'burada görünecek.',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      );
    }
    final color = adherenceColor(percent);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showAdherenceDetails(context, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Haftalık ilaç uyumu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '%$percent',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: report.rate,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${report.taken}/${report.scheduled} doz alındı'
              '${report.patterns.isEmpty ? '' : ' · ${report.patterns.length} öneri'}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// İlacın tek bir dozunun satırı: bugünkü durum ve "Aldım" düğmesi. Günde
/// birden çok dozu olan ilacın her saati ayrı satırdır.
class MedicationRow extends StatelessWidget {
  final ChronicProvider provider;
  final MedicationReminder medication;
  final MedicationDose dose;
  final VoidCallback onEditTimes;
  final VoidCallback onDelete;

  const MedicationRow({
    super.key,
    required this.provider,
    required this.medication,
    required this.dose,
    required this.onEditTimes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final record = provider.todayDose(dose);
    final due = provider.isDoseDue(dose);
    final dosage = medication.dosage.trim();

    String status;
    Color statusColor;
    if (record?.status == DoseStatus.taken) {
      final t = record!.at;
      status =
          'Bugün alındı · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      statusColor = AppColors.success;
    } else if (record?.status == DoseStatus.skipped) {
      status = 'Bugün atlandı';
      statusColor = AppColors.warning;
    } else if (due) {
      status = 'Bugünkü doz bekliyor';
      statusColor = AppColors.danger;
    } else {
      status = 'Bugün ${dose.timeDisplay}';
      statusColor = AppColors.textHint;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
            child: Icon(Icons.medication, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${dosage.isEmpty ? '' : '$dosage · '}${dose.timeDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (record == null)
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => provider.markDose(dose, DoseStatus.taken),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Aldım'),
            )
          else
            Icon(
              record.status == DoseStatus.taken
                  ? Icons.check_circle
                  : Icons.remove_circle_outline,
              color: statusColor,
            ),
          PopupMenuButton<String>(
            tooltip: 'Diğer',
            onSelected: (value) {
              switch (value) {
                case 'skip':
                  provider.markDose(dose, DoseStatus.skipped);
                case 'undo':
                  provider.markDose(dose, null);
                case 'edit':
                  onEditTimes();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              if (record == null)
                const PopupMenuItem(
                  value: 'skip',
                  child: Text('Bugün atladım'),
                ),
              if (record != null)
                const PopupMenuItem(
                  value: 'undo',
                  child: Text('İşareti kaldır'),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Saatleri düzenle'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  medication.doses.length > 1
                      ? 'İlacı sil (tüm saatler)'
                      : 'İlacı sil',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showAdherenceDetails(
  BuildContext context,
  ChronicProvider provider,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _AdherenceDetails(provider: provider, controller: controller),
    ),
  );
}

class _AdherenceDetails extends StatelessWidget {
  final ChronicProvider provider;
  final ScrollController controller;

  const _AdherenceDetails({required this.provider, required this.controller});

  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final report = provider.adherence(now: now);
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    ];
    final percent = report.percent;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          'İlaç Uyumu (son 7 gün)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (percent != null)
          Text(
            '%$percent · ${report.taken}/${report.scheduled} doz alındı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: adherenceColor(percent),
            ),
          ),
        const SizedBox(height: 16),
        // Gün × ilaç tablosu
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(40),
            columnWidths: const {0: IntrinsicColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  for (final d in days)
                    Center(
                      child: Text(
                        _days[d.weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              // Günde birden çok dozu olan ilacın her saati ayrı satırdır.
              for (final med in provider.medications.where((m) => m.isActive))
                for (final dose in med.doses)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                          top: 8,
                          bottom: 8,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            '${med.name}\n${dose.timeDisplay}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      for (final d in days)
                        Center(
                          child: _Cell(
                            provider.doseState(med, dose, d, now: now),
                          ),
                        ),
                    ],
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: const [
            _Legend(DoseCellState.taken, 'Alındı'),
            _Legend(DoseCellState.missed, 'Kaçırıldı'),
            _Legend(DoseCellState.skipped, 'Atlandı'),
            _Legend(DoseCellState.upcoming, 'Saati gelmedi'),
          ],
        ),
        if (report.patterns.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Fark edilen örüntüler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in report.patterns)
            Card(
              elevation: 0,
              color: AppColors.warning.withValues(alpha: 0.08),
              child: ListTile(
                leading: Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.warning,
                ),
                title: Text(p.message),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(p.suggestion),
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'Nasıl hesaplanır? Uyum = alınan doz ÷ planlanan doz. Saati henüz '
          'gelmemiş dozlar ve ilaç ya da saat eklenmeden önceki dozlar '
          'sayılmaz. '
          'Örüntüler, kaçırılan dozların gün ve saatlerine bakılarak cihazınızda '
          'çıkarılır.',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }
}

Color _cellColor(DoseCellState state) {
  switch (state) {
    case DoseCellState.taken:
      return AppColors.success;
    case DoseCellState.missed:
      return AppColors.danger;
    case DoseCellState.skipped:
      return AppColors.warning;
    case DoseCellState.upcoming:
    case DoseCellState.notScheduled:
      return AppColors.textHint;
  }
}

class _Cell extends StatelessWidget {
  final DoseCellState state;
  const _Cell(this.state);

  @override
  Widget build(BuildContext context) {
    if (state == DoseCellState.notScheduled) {
      return Text('–', style: TextStyle(color: AppColors.textHint));
    }
    final color = _cellColor(state);
    final icon = switch (state) {
      DoseCellState.taken => Icons.check,
      DoseCellState.missed => Icons.close,
      DoseCellState.skipped => Icons.remove,
      _ => null,
    };
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == DoseCellState.upcoming
            ? Colors.transparent
            : color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
      ),
      child: icon == null ? null : Icon(icon, size: 16, color: color),
    );
  }
}

class _Legend extends StatelessWidget {
  final DoseCellState state;
  final String label;
  const _Legend(this.state, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(scale: 0.7, child: _Cell(state)),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
