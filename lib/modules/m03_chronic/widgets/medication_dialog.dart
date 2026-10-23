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
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İlaç Hatırlatıcı Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.access_time, color: AppColors.primary),
            title: Text('Saat: ${_selectedTime.format(context)}'),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) {
                setState(() => _selectedTime = time);
              }
            },
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
              hour: _selectedTime.hour,
              minute: _selectedTime.minute,
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
