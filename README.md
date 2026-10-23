# VitaCoach

[![CI](https://github.com/murathan6161abc-ops/Vitacoach/actions/workflows/ci.yml/badge.svg)](https://github.com/murathan6161abc-ops/Vitacoach/actions/workflows/ci.yml)

VitaCoach, tamamen telefonda çalışan Türkçe bir kişisel sağlık koçudur. Sunucusu,
hesabı, reklamı ve kullanım analitiği yoktur; veriler cihazda şifreli tutulur.

> VitaCoach tanı veya tedavi aracı değildir. Acil durumda 112 aranmalıdır.

## Özellikler

- **Bugün paneli:** vakti gelen ilaçlar ("Aldım"), su ve adım tek bakışta.
- **Kronik hastalık takibi:** kan şekeri (açlık / tokluk / rastgele), tansiyon,
  kilo; ölçümler silinebilir ve geri alınabilir. Tehlikeli değerlerde
  (hipertansif kriz, hipoglisemi, çok yüksek şeker) anında yönlendirme.
- **İlaçlar:** hatırlatıcılar, bildirimden "Aldım" / "10 dk sonra", ilaç uyumu
  ve yerel ilaç etkileşimi denetimi.
- **Belirti değerlendirmesi** ve kural tabanlı sağlık asistanı (aynı acil durum
  kurallarını kullanır).
- **Risk hesapları:** FINDRISC (diyabet) ve Framingham (kalp-damar).
- Beslenme ve öğün planı, adım sayar (cihazın kendi adım kaydından), uyku,
  ruh sağlığı (PHQ-9, GAD-7), gebelik ve bebek, aşı takvimi, hava kalitesi,
  kamerayla nabız ölçümü, SOS, doktor için PDF rapor.
- **Şifreli yedekleme:** tüm veriler parolalı bir dosyaya yedeklenip başka
  telefonda geri yüklenebilir.

## Gizlilik ve güvenlik

Ayrıntılar: [PRIVACY.md](PRIVACY.md) (uygulamadaki Ayarlar > Gizlilik ve Veri
ekranıyla aynı metin).

- Sağlık ve profil verileri, cihazın güvenli kasasında (Android Keystore /
  iOS Keychain) tutulan 256 bitlik anahtarla şifrelenmiş Hive kutularında
  saklanır. Android yedeği ve açık metin HTTP trafiği kapalıdır.
- Uygulama yalnızca hava kalitesi sorgusunda internete çıkar: yaklaşık konum
  (0,1 dereceye, yaklaşık 10 km'ye yuvarlanmış) Open-Meteo'ya gönderilir.
  Yazı tipi uygulamayla birlikte gelir; çalışma anında indirilmez.
- Yedek dosyası PBKDF2-HMAC-SHA256 (310 000 tur) ile türetilen anahtarla
  AES-256-GCM kullanılarak şifrelenir; parola unutulursa açılamaz.
- Android'de adım geçmişi Google Play hizmetlerinin cihaz içi Kayıt API'sinden,
  iOS'ta CoreMotion'dan okunur.

## Geliştirme

Gereksinimler: Flutter 3.41 (stable), Android SDK; iOS için Xcode ve CocoaPods.

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

CI (`.github/workflows/ci.yml`) her push ve PR'da biçim denetimi, analiz,
testler ve debug APK derlemesi çalıştırır.

Widget testleri `test/helpers/memory_hive.dart` ile bellek içi Hive kutuları
kullanır. Jüri sunumu için "Jüri Demo Verisi Yükle" geliştirme derlemesinde
Ayarlar'da görünür; yayın sürümünde Ayarlar'ın altındaki sürüm yazısına 7 kez
dokununca açılır (tüm gerçek verileri siler).

### iOS notları

- En düşük iOS sürümü 15.0'dır (güncel Xcode daha eskisini derlemez).
- `pod install` çalıştırırken UTF-8 yerel ayarı gerekir:
  `LANG=en_US.UTF-8 pod install`.
- Proje iCloud ile eşitlenen bir klasördeyse (ör. Masaüstü) `codesign`
  "resource fork, Finder information, or similar detritus not allowed" hatası
  verir. Projeyi eşitlenmeyen bir klasöre taşıyın ya da derlemeden önce
  `xattr -rc build.nosync` çalıştırın.

## Release APK

Release derlemesi için aşağıdaki iki dosya birlikte gereklidir:

- `android/app/vitacoach-release.jks`
- `android/key.properties`

Bu dosyalar Git tarafından yok sayılır. Güvenli ve erişimi kısıtlı bir konumda
birlikte yedeklenmelidir; kaybedilmeleri halinde aynı uygulamaya güncelleme
yayımlanamaz.

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Üretilen APK: `build/app/outputs/flutter-apk/app-release.apk`.
