# VitaCoach Gizlilik ve Veri Kullanımı

Son güncelleme: 24 Ekim 2026

Bu metin uygulamadaki Ayarlar > Gizlilik ve Veri ekranıyla aynıdır.

## Verileriniz nerede saklanır?

- Girdiğiniz profil ve sağlık bilgileri (ölçümler, ilaçlar, ruh hali, uyku, adımlar vb.) yalnızca bu telefonda saklanır.
- Veriler, cihazın güvenli kasasında (Android Keystore / iOS Keychain) tutulan 256 bitlik bir anahtarla şifrelenir.
- VitaCoach'un sunucusu, kullanıcı hesabı, reklamı veya kullanım analitiği yoktur.

## Uygulama ne zaman internete bağlanır?

- Yalnızca hava kalitesini sorguladığınızda: yaklaşık konumunuz (yaklaşık 10 km'ye yuvarlanmış koordinat) Open-Meteo hava kalitesi servisine gönderilir.
- Bunun dışında hiçbir veri telefondan gönderilmez. Android'de adım geçmişi, Google Play hizmetlerinin cihaz içinde kalan Kayıt API'sinden okunur.

## Sizin başlattığınız paylaşımlar

- Acil durum (SOS) mesajı konumunuzla birlikte, telefonunuzun mesaj uygulamasıyla sizin seçtiğiniz kişiye gönderilir.
- PDF rapor ve yedek dosyası yalnızca siz paylaştığınızda, sizin seçtiğiniz uygulama veya kişiyle paylaşılır. Yedek dosyası belirlediğiniz parolayla şifrelenir.

## İzinler ve nedenleri

- Bildirimler: ilaç, su ve hareket hatırlatıcıları.
- Fiziksel aktivite / Hareket ve Fitness: adım sayımı.
- Kamera: parmakla nabız ölçümü. Görüntü kaydedilmez, telefonda işlenir.
- Konum: yalnızca acil durum mesajı ve hava kalitesi için, siz istediğinizde.
- Alarmlar ve hatırlatıcılar (Android): ilaç hatırlatıcılarının tam zamanında gelmesi için.

## Verilerinizi silme ve taşıma

- Ayarlar > Hesabı Sıfırla tüm yerel verileri ve bildirimleri siler; uygulamayı kaldırmak da verileri siler.
- Telefon değiştirirken veri kaybetmemek için Ayarlar > Veri Yedekleme bölümünden şifreli yedek alın.

## Tıbbi uyarı

- VitaCoach tanı veya tedavi aracı değildir; bilgiler genel bilgilendirme amaçlıdır. Acil durumda 112'yi arayın.

## İletişim

- Sorular ve öneriler için: github.com/murathan6161abc-ops/Vitacoach/issues
