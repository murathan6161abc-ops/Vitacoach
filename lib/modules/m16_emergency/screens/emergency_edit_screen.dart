import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/vc_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../models/emergency_info.dart';

/// Acil sağlık kartı ve acil kişileri düzenleme ekranı.
class EmergencyEditScreen extends StatefulWidget {
  const EmergencyEditScreen({super.key});

  @override
  State<EmergencyEditScreen> createState() => _EmergencyEditScreenState();
}

class _EmergencyEditScreenState extends State<EmergencyEditScreen> {
  late EmergencyInfo _info;
  late final TextEditingController _allergies;
  late final TextEditingController _notes;
  late String _bloodType;
  late List<EmergencyContact> _contacts;

  @override
  void initState() {
    super.initState();
    _info = EmergencyInfo.load();
    _allergies = TextEditingController(text: _info.allergies);
    _notes = TextEditingController(text: _info.notes);
    _bloodType = _info.bloodType;
    _contacts = [..._info.contacts];
  }

  @override
  void dispose() {
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _info
        .copyWith(
          bloodType: _bloodType,
          allergies: _allergies.text.trim(),
          notes: _notes.text.trim(),
          contacts: _contacts,
        )
        .save();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _editContact({int? index}) async {
    final existing = index == null ? null : _contacts[index];
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final relation = TextEditingController(text: existing?.relation ?? '');
    String? error;

    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Acil Kişi Ekle' : 'Acil Kişiyi Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    hintText: '05xx xxx xx xx',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relation,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Yakınlık (isteğe bağlı)',
                    hintText: 'Eş, anne, komşu…',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  setDialogState(() => error = 'Ad girin.');
                  return;
                }
                if (!EmergencyContact.isValidPhone(phone.text)) {
                  setDialogState(
                    () => error = 'Geçerli bir telefon numarası girin.',
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  EmergencyContact(
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    relation: relation.text.trim(),
                  ),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      if (index == null) {
        _contacts.add(result);
      } else {
        _contacts[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acil Bilgilerim')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          VcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sağlık Bilgileri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _bloodType,
                  decoration: const InputDecoration(labelText: 'Kan grubu'),
                  items: EmergencyInfo.bloodTypes
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _bloodType = v ?? _bloodType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _allergies,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Alerjiler',
                    hintText: 'Örn: Penisilin, fıstık',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Diğer notlar',
                    hintText: 'Örn: Kalp pili var, organ bağışçısıyım',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kronik hastalıklar ve ilaçlar profilinizden ve ilaç '
                  'hatırlatıcılarınızdan otomatik eklenir.',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Acil Kişiler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_contacts.length < 3)
                      TextButton.icon(
                        onPressed: () => _editContact(),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Ekle'),
                      ),
                  ],
                ),
                if (_contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'SOS ekranından konum gönderebilmek için en az bir acil '
                      'kişi ekleyin (en fazla 3).',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ..._contacts.asMap().entries.map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: AppColors.danger),
                    ),
                    title: Text(e.value.name),
                    subtitle: Text(
                      [
                        e.value.phone,
                        if (e.value.relation.isNotEmpty) e.value.relation,
                      ].join(' • '),
                    ),
                    onTap: () => _editContact(index: e.key),
                    trailing: IconButton(
                      tooltip: 'Sil',
                      icon: Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () =>
                          setState(() => _contacts.removeAt(e.key)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          VcButton(text: 'Kaydet', icon: Icons.save, onPressed: _save),
        ],
      ),
    );
  }
}
