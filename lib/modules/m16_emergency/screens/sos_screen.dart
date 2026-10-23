import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../m11_access/providers/access_provider.dart';
import '../models/emergency_info.dart';
import 'emergency_card_screen.dart';
import 'emergency_edit_screen.dart';

/// Acil durum ekranı. Arama ve SMS, cihazın kendi telefon/mesaj
/// uygulamasıyla ve kullanıcının onayıyla yapılır; uygulama kendi başına
/// arama yapmaz veya mesaj göndermez.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  EmergencyInfo _info = EmergencyInfo.load();
  String? _sendingTo;

  static const _instructions =
      '112 aradığınızda sakin olun. Adresinizi, ne olduğunu ve kaç kişinin '
      'etkilendiğini söyleyin. Görevli kapatana kadar telefonu kapatmayın. '
      'Bilinç kaybı ve nefes yoksa kalp masajına başlayın.';

  Future<void> _call(String number) async {
    final started = await AccessProvider().callNumber(number);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arama başlatılamadı. Lütfen $number numarasını elle arayın.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Konum izni yoksa ya da alınamazsa null döner; mesaj konumsuz gider.
  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (error) {
      debugPrint('Konum alınamadı: $error');
      return null;
    }
  }

  static String buildMessage(Position? position) {
    if (position == null) {
      return 'ACİL DURUM! Yardıma ihtiyacım var. Konumumu alamadım, lütfen '
          'beni hemen arayın. (VitaCoach)';
    }
    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);
    return 'ACİL DURUM! Yardıma ihtiyacım var. Konumum: '
        'https://maps.google.com/?q=$lat,$lng (VitaCoach)';
  }

  Future<void> _sendLocation(EmergencyContact contact) async {
    setState(() => _sendingTo = contact.phone);
    final position = await _currentPosition();
    final body = buildMessage(position);
    final uri = Uri.parse(
      'sms:${contact.dialable}?body=${Uri.encodeComponent(body)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _sendingTo = null);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj uygulaması açılamadı.')),
      );
    } else if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Konum alınamadı (izin veya GPS kapalı). Mesaj konumsuz hazırlandı.',
          ),
        ),
      );
    }
  }

  Future<void> _editContacts() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EmergencyEditScreen()),
    );
    if (changed == true && mounted) {
      setState(() => _info = EmergencyInfo.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acil Durum'),
        backgroundColor: const Color(0xFFC62828),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Semantics(
              button: true,
              label: '112 acil çağrı merkezini ara',
              child: GestureDetector(
                onTap: () => _call(AppConstants.emergencyNumber),
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD32F2F),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_in_talk, color: Colors.white, size: 48),
                      SizedBox(height: 6),
                      Text(
                        '112',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Acil Çağrı',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dokunduğunuzda telefon uygulaması 112 numarasıyla açılır.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          VcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Acil kişilerime konumumu gönder',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: _editContacts,
                      child: Text(_info.contacts.isEmpty ? 'Ekle' : 'Düzenle'),
                    ),
                  ],
                ),
                if (_info.contacts.isEmpty)
                  Text(
                    'Henüz acil kişi eklemediniz. Eklediğiniz kişilere tek '
                    'dokunuşla konumunuzu içeren bir SMS hazırlanır.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ..._info.contacts.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      child: Icon(Icons.person, color: AppColors.danger),
                    ),
                    title: Text(c.name),
                    subtitle: Text(c.relation.isEmpty ? c.phone : c.relation),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ara',
                          icon: Icon(Icons.call, color: AppColors.success),
                          onPressed: () => _call(c.dialable),
                        ),
                        _sendingTo == c.phone
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Konumlu mesaj',
                                icon: Icon(
                                  Icons.share_location,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => _sendLocation(c),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Konum yalnızca siz mesajı gönderdiğinizde, SMS uygulamanız '
                  'üzerinden paylaşılır.',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VcCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmergencyCardScreen()),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_information, color: AppColors.danger),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Acil Sağlık Kartımı Göster (QR)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VcCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(child: Text(_instructions)),
                const SpeakButton(text: _instructions, id: 'sos-instructions'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _call(AppConstants.poisonControl),
                  icon: const Icon(Icons.science),
                  label: const Text('Zehir Danışma 114'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
