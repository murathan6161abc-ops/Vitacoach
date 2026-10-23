import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/vc_card.dart';

/// Gizlilik ve veri kullanımı. Depodaki PRIVACY.md ile aynı içeriktir
/// (mağaza gizlilik politikası bağlantısı); biri değişirse diğeri de
/// güncellenmelidir (bkz. test/privacy_honesty_test.dart).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<(String, List<String>)> sections = [
    (
      'Verileriniz nerede saklanır?',
      [
        'Girdiğiniz profil ve sağlık bilgileri (ölçümler, ilaçlar, ruh hali, '
            'uyku, adımlar vb.) yalnızca bu telefonda saklanır.',
        'Veriler, cihazın güvenli kasasında (Android Keystore / iOS Keychain) '
            'tutulan 256 bitlik bir anahtarla şifrelenir.',
        "VitaCoach'un sunucusu, kullanıcı hesabı, reklamı veya kullanım "
            'analitiği yoktur.',
      ],
    ),
    (
      'Uygulama ne zaman internete bağlanır?',
      [
        'Yalnızca hava kalitesini sorguladığınızda: yaklaşık konumunuz '
            "(yaklaşık 10 km'ye yuvarlanmış koordinat) Open-Meteo hava "
            'kalitesi servisine gönderilir.',
        'Bunun dışında hiçbir veri telefondan gönderilmez. Android\'de adım '
            'geçmişi, Google Play hizmetlerinin cihaz içinde kalan Kayıt '
            "API'sinden okunur.",
      ],
    ),
    (
      'Sizin başlattığınız paylaşımlar',
      [
        'Acil durum (SOS) mesajı konumunuzla birlikte, telefonunuzun mesaj '
            'uygulamasıyla sizin seçtiğiniz kişiye gönderilir.',
        'PDF rapor ve yedek dosyası yalnızca siz paylaştığınızda, sizin '
            'seçtiğiniz uygulama veya kişiyle paylaşılır. Yedek dosyası '
            'belirlediğiniz parolayla şifrelenir.',
      ],
    ),
    (
      'İzinler ve nedenleri',
      [
        'Bildirimler: ilaç, su ve hareket hatırlatıcıları.',
        'Fiziksel aktivite / Hareket ve Fitness: adım sayımı.',
        'Kamera: parmakla nabız ölçümü. Görüntü kaydedilmez, telefonda '
            'işlenir.',
        'Konum: yalnızca acil durum mesajı ve hava kalitesi için, siz '
            'istediğinizde.',
        "Alarmlar ve hatırlatıcılar (Android): ilaç hatırlatıcılarının tam "
            'zamanında gelmesi için.',
      ],
    ),
    (
      'Verilerinizi silme ve taşıma',
      [
        'Ayarlar > Hesabı Sıfırla tüm yerel verileri ve bildirimleri siler; '
            'uygulamayı kaldırmak da verileri siler.',
        'Telefon değiştirirken veri kaybetmemek için Ayarlar > Veri '
            'Yedekleme bölümünden şifreli yedek alın.',
      ],
    ),
    (
      'Tıbbi uyarı',
      [
        'VitaCoach tanı veya tedavi aracı değildir; bilgiler genel '
            "bilgilendirme amaçlıdır. Acil durumda 112'yi arayın.",
      ],
    ),
    (
      'İletişim',
      [
        'Sorular ve öneriler için: '
            'github.com/murathan6161abc-ops/Vitacoach/issues',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve Veri')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          for (final (title, paragraphs) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    for (final paragraph in paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          paragraph,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
