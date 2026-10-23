import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../m01_profile/providers/profile_provider.dart';
import '../../m03_chronic/providers/chronic_provider.dart';
import '../../m11_access/providers/access_provider.dart';
import '../models/emergency_info.dart';
import 'emergency_edit_screen.dart';

/// Sağlık personeline gösterilebilecek acil sağlık kartı ve QR kodu.
class EmergencyCardScreen extends StatefulWidget {
  const EmergencyCardScreen({super.key});

  @override
  State<EmergencyCardScreen> createState() => _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends State<EmergencyCardScreen> {
  EmergencyInfo _info = EmergencyInfo.load();

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EmergencyEditScreen()),
    );
    if (changed == true && mounted) {
      setState(() => _info = EmergencyInfo.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final medications = context
        .watch<ChronicProvider>()
        .medications
        .map((m) => m.dosage.trim().isEmpty ? m.name : '${m.name} ${m.dosage}')
        .toList();
    final conditions = profile.conditions.where((c) => c != 'Yok').toList();
    final cardText = EmergencyCardText.build(
      name: profile.name,
      birthDate: profile.birthDate,
      age: profile.age,
      info: _info,
      conditions: conditions,
      medications: medications,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acil Sağlık Kartı'),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit),
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(AppConstants.radiusLG),
            ),
            child: Row(
              children: [
                const Icon(Icons.medical_information, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name.isEmpty ? 'Adsız kullanıcı' : profile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        profile.age > 0 ? '${profile.age} yaş' : 'Yaş bilinmiyor',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text('Kan grubu', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      _info.bloodType == 'Bilinmiyor' ? '?' : _info.bloodType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_info.isFilled) ...[
            const SizedBox(height: 12),
            VcCard(
              borderColor: AppColors.warning,
              onTap: _edit,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kan grubu, alerji ve acil kişi bilgilerinizi eklemek '
                      'için dokunun.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _section(
            Icons.warning_amber,
            'Alerjiler',
            _info.allergies.trim().isEmpty
                ? 'Belirtilmedi'
                : _info.allergies.trim(),
            highlight: _info.allergies.trim().isNotEmpty,
          ),
          _section(
            Icons.monitor_heart,
            'Kronik hastalıklar',
            conditions.isEmpty ? 'Belirtilmedi' : conditions.join(', '),
          ),
          _section(
            Icons.medication,
            'Kullandığı ilaçlar',
            medications.isEmpty ? 'Kayıtlı ilaç yok' : medications.join('\n'),
          ),
          if (_info.notes.trim().isNotEmpty)
            _section(Icons.notes, 'Notlar', _info.notes.trim()),
          VcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acil Kişiler',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_info.contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Acil kişi eklenmedi.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ..._info.contacts.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name),
                    subtitle: Text(
                      [c.phone, if (c.relation.isNotEmpty) c.relation].join(' • '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Ara',
                      icon: Icon(Icons.call, color: AppColors.success),
                      onPressed: () => AccessProvider().callNumber(c.dialable),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VcCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sağlık personeli için QR',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SpeakButton(text: cardText, id: 'emergency-card'),
                  ],
                ),
                const SizedBox(height: 12),
                // QR kodlar okuyucular için koyu temada da beyaz zemin ister.
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: cardText,
                    size: 220,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'QR kod bu cihazda oluşturulur ve düz metin içerir; herhangi '
                  'bir kamera uygulamasıyla internetsiz okunabilir. Hiçbir '
                  'sunucuya gönderilmez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    IconData icon,
    String title,
    String body, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VcCard(
        borderColor: highlight ? AppColors.danger.withValues(alpha: 0.4) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: highlight ? AppColors.danger : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
