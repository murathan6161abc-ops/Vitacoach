import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/health_entry.dart';

/// Yeni ilaç ekleme ya da kayıtlı ilacın doz saatlerini düzenleme penceresi.
class MedicationDialog extends StatefulWidget {
  /// Saatleri düzenlenecek kayıtlı ilaç; yoksa yeni ilaç eklenir.
  final MedicationReminder? initial;

  const MedicationDialog({super.key, this.initial});

  @override
  State<MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<MedicationDialog> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();

  /// Günlük dozlar; saate göre sıralı, saatleri tekrarsız ve en az bir tane.
  /// Düzenlemede kayıtlı dozlar kimlikleriyle gelir: saati değiştirilen doz
  /// kimliğini korur, eklenen saat yeni kimlik alır.
  late List<MedicationDose> _doses =
      widget.initial?.doses ?? [MedicationDose(hour: 8, minute: 0)];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  static const _minutesPerDay = 24 * 60;

  /// Yeni saat önerisi: saatler arasındaki en uzun boşluğun ortası (08:00
  /// için 20:00; 08:00 ve 20:00 için 14:00). Var olan saatle çakışmaz.
  TimeOfDay _suggestNextTime() {
    final minutes = [for (final d in _doses) d.minuteOfDay];
    var start = minutes.first, longest = 0;
    for (var i = 0; i < minutes.length; i++) {
      final next = i + 1 < minutes.length
          ? minutes[i + 1]
          : minutes.first + _minutesPerDay;
      if (next - minutes[i] > longest) {
        longest = next - minutes[i];
        start = minutes[i];
      }
    }
    final suggested = (start + longest ~/ 2) % _minutesPerDay;
    return TimeOfDay(hour: suggested ~/ 60, minute: suggested % 60);
  }

  static bool _hasTime(Iterable<MedicationDose> doses, TimeOfDay time) =>
      doses.any((d) => d.hour == time.hour && d.minute == time.minute);

  /// Dozlar saate göre sıralı tutulur.
  void _setDoses(List<MedicationDose> doses) {
    setState(() {
      _doses = doses..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    });
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _suggestNextTime(),
    );
    // Aynı saat iki kez eklenmez.
    if (time == null || _hasTime(_doses, time)) return;
    _setDoses([
      ..._doses,
      MedicationDose(hour: time.hour, minute: time.minute),
    ]);
  }

  /// Saati değişen doz kimliğini korur; başka bir dozun saatine alınırsa o
  /// dozla birleşir.
  Future<void> _changeTime(int index) async {
    final dose = _doses[index];
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: dose.hour, minute: dose.minute),
    );
    if (time == null) return;
    final others = [..._doses]..removeAt(index);
    _setDoses([
      ...others,
      if (!_hasTime(others, time))
        dose.copyWith(hour: time.hour, minute: time.minute),
    ]);
  }

  void _save() {
    final initial = widget.initial;
    if (initial != null) {
      Navigator.pop(context, initial.copyWith(doses: _doses));
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final medication = MedicationReminder(
      name: name,
      dosage: _dosageController.text.trim(),
      doses: _doses,
      createdAt: DateTime.now(),
    );
    Navigator.pop(context, medication);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return AlertDialog(
      title: Text(
        initial == null ? 'İlaç Hatırlatıcı Ekle' : 'Saatleri Düzenle',
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (initial == null) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'İlaç adı',
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Doz (örn: 1 tablet)',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
          ] else
            // Düzenlemede yalnızca saatler değişir; ad ve doz bilgi içindir.
            Row(
              children: [
                Icon(Icons.medication, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        initial.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (initial.dosage.trim().isNotEmpty)
                        Text(
                          initial.dosage.trim(),
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
          const SizedBox(height: 16),
          Text(
            _doses.length == 1 ? 'Doz saati' : 'Günde ${_doses.length} doz',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Her saat ayrı bir hatırlatma ve ayrı "Aldım" satırı olur.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, dose) in _doses.indexed)
                InputChip(
                  avatar: Icon(
                    Icons.access_time,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(dose.timeDisplay),
                  onPressed: () => _changeTime(index),
                  // İlacın en az bir doz saati olmalı.
                  onDeleted: _doses.length > 1
                      ? () => _setDoses([..._doses]..removeAt(index))
                      : null,
                  deleteButtonTooltipMessage:
                      '${dose.timeDisplay} saatini kaldır',
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Saat ekle'),
                onPressed: _addTime,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(initial == null ? 'Kaydet' : 'Güncelle'),
        ),
      ],
    );
  }
}
