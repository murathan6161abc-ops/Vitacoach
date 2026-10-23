# VitaCoach

VitaCoach; profil, belirti triyajı, kronik hastalık ölçümleri, ilaç
hatırlatıcıları, ruh sağlığı testleri, beslenme, fitness, aşı ve ilerleme
takibi sunan bir Flutter sağlık koçu uygulamasıdır.

> VitaCoach tanı veya tedavi aracı değildir. Acil durumda 112 aranmalıdır.

## Güvenlik

- Sağlık ve profil verileri, cihazın güvenli kasasında tutulan 256 bit anahtar
  ile şifrelenmiş Hive kutularında saklanır.
- Gemini ve IQAir API anahtarları Android Keystore / iOS Keychain üzerinden
  güvenli depoda tutulur; kaynak koda anahtar eklenmemelidir.
- AI özellikleri, kullanıcı sağlık verisi paylaşım izni vermeden çalışmaz.
- Android yedekleme ve açık metin HTTP trafiği kapalıdır.
- Hesap sıfırlama; yerel verileri, bildirimleri ve kullanıcı API anahtarlarını
  temizler.

İstemci içindeki bir API anahtarı, güvenli depoda olsa bile sunucu tarafındaki
bir sır kadar güçlü korunamaz. Üretim dağıtımında kimlik doğrulamalı bir backend
proxy kullanılması önerilir.

## Geliştirme

Gereksinimler: Flutter SDK ve Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
```

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
