/// Kullanıcı girdisi ve Türkçe metin işlemleri için ortak yardımcılar.
///
/// Türkçe klavyeler ondalık ayırıcı olarak virgül üretir ("72,5");
/// `double.tryParse` bunu reddeder ve değer sessizce kaybolur. Ayrıca
/// Dart'ın `toLowerCase()` fonksiyonu Türkçe'ye duyarlı değildir
/// ("I" -> "i" olur, "ı" değil), bu yüzden "ızgara" araması "Izgara"yı
/// bulamaz.
class InputUtils {
  InputUtils._();

  /// "72,5", " 72.5 ", "1.250,5" gibi girdileri güvenle double'a çevirir.
  /// Geçersizse null döner.
  static double? parseDecimal(String? input) {
    if (input == null) return null;
    var text = input.trim().replaceAll(' ', '');
    if (text.isEmpty) return null;

    final hasComma = text.contains(',');
    final hasDot = text.contains('.');
    if (hasComma && hasDot) {
      // Son görülen ayırıcı ondalık ayırıcıdır; diğeri binlik ayırıcı.
      if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
        text = text.replaceAll('.', '').replaceAll(',', '.');
      } else {
        text = text.replaceAll(',', '');
      }
    } else if (hasComma) {
      text = text.replaceAll(',', '.');
    }

    final value = double.tryParse(text);
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }

  /// Tam sayı girdisi; "15,0" gibi değerleri de kabul eder.
  static int? parseInt(String? input) {
    final value = parseDecimal(input);
    if (value == null) return null;
    return value.round();
  }

  /// [value] null değilse ve [min, max] aralığındaysa döndürür.
  static T? inRange<T extends num>(T? value, T min, T max) {
    if (value == null || value < min || value > max) return null;
    return value;
  }

  /// Arama için Türkçe'ye duyarlı normalleştirme: küçük harfe çevirir ve
  /// Türkçe karakterleri ASCII karşılıklarına katlar. Böylece "ızgara",
  /// "izgara" ve "IZGARA" aynı sonucu verir; "cay" araması "Çay"ı bulur.
  /// Türkçe büyük harf: "i" → "İ", "ı" → "I". Dart'ın toUpperCase'i
  /// yerel ayardan bağımsızdır ve "Şüphesi"ni "ŞÜPHESI" yapar.
  static String upperTr(String input) =>
      input.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  static String normalizeForSearch(String input) {
    const map = {
      'İ': 'i',
      'I': 'i',
      'ı': 'i',
      'i̇': 'i',
      'Ş': 's',
      'ş': 's',
      'Ğ': 'g',
      'ğ': 'g',
      'Ü': 'u',
      'ü': 'u',
      'Ö': 'o',
      'ö': 'o',
      'Ç': 'c',
      'ç': 'c',
      'Â': 'a',
      'â': 'a',
      'Î': 'i',
      'î': 'i',
      'Û': 'u',
      'û': 'u',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      // Birleşik nokta (U+0307) "i̇" artığını at.
      if (rune == 0x0307) continue;
      buffer.write(map[char] ?? char.toLowerCase());
    }
    return buffer.toString().trim();
  }
}
