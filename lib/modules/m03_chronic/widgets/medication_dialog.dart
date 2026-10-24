import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/health_entry.dart';

class MedicationDialog extends StatefulWidget {
  const MedicationDialog({super.key});

  @override
  State<MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<MedicationDialog> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();

  /// Günlük doz saatleri; sıralı, tekrarsız ve en az bir tane.
  List<TimeOfDay> _times = const [TimeOfDay(hour: 8, minute: 0)];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  static const _minutesPerDay = 24 * 60;

  static int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Yeni saat önerisi: saatler arasındaki en uzun boşluğun ortası (08:00
  /// için 20:00; 08:00 ve 20:00 için 14:00). Var olan saatle çakışmaz.
  TimeOfDay _suggestNextTime() {
    final minutes = [for (final t in _times) _minutesOf(t)];
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

  /// Aynı saat iki kez eklenmez; saatler sıralı tutulur.
  void _setTimes(Iterable<TimeOfDay> times) {
    final unique = {for (final t in times) _minutesOf(t): t};
    setState(() {
      _times = [
        for (final minutes in unique.keys.toList()..sort()) unique[minutes]!,
      ];
    });
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _suggestNextTime(),
    );
    if (time != null) _setTimes([..._times, time]);
  }

  Future<void> _changeTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (time != null) _setTimes([..._times]..[index] = time);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İlaç Hatırlatıcı Ekle'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),
          Text(
            _times.length == 1 ? 'Doz saati' : 'Günde ${_times.length} doz',
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
              for (final (index, time) in _times.indexed)
                InputChip(
                  avatar: Icon(
                    Icons.access_time,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(_format(time)),
                  onPressed: () => _changeTime(index),
                  // İlacın en az bir doz saati olmalı.
                  onDeleted: _times.length > 1
                      ? () => _setTimes([..._times]..removeAt(index))
                      : null,
                  deleteButtonTooltipMessage: '${_format(time)} saatini kaldır',
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
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            final medication = MedicationReminder(
              name: name,
              dosage: _dosageController.text.trim(),
              doses: [
                for (final time in _times)
                  MedicationDose(hour: time.hour, minute: time.minute),
              ],
              createdAt: DateTime.now(),
            );
            Navigator.pop(context, medication);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
