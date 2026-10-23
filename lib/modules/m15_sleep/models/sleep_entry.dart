/// Bir gecelik uyku kaydı. Gün anahtarı uyanılan günün tarihidir.
class SleepEntry {
  final DateTime bedTime;
  final DateTime wakeTime;
  final int quality; // 1 (çok kötü) - 5 (çok iyi)

  SleepEntry({
    required this.bedTime,
    required this.wakeTime,
    required this.quality,
  });

  /// Yatış ve kalkış saatinden kayıt oluşturur. Kalkış saati yatıştan önce
  /// görünüyorsa (23:30 -> 07:00) ertesi güne aittir.
  factory SleepEntry.fromTimes({
    required DateTime wakeDate,
    required int bedHour,
    required int bedMinute,
    required int wakeHour,
    required int wakeMinute,
    required int quality,
  }) {
    final wake = DateTime(
      wakeDate.year,
      wakeDate.month,
      wakeDate.day,
      wakeHour,
      wakeMinute,
    );
    var bed = DateTime(
      wakeDate.year,
      wakeDate.month,
      wakeDate.day,
      bedHour,
      bedMinute,
    );
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    return SleepEntry(bedTime: bed, wakeTime: wake, quality: quality);
  }

  Duration get duration => wakeTime.difference(bedTime);
  double get hours => duration.inMinutes / 60;

  String get dayKey => wakeTime.toIso8601String().substring(0, 10);

  String get durationLabel {
    final h = duration.inMinutes ~/ 60;
    final m = duration.inMinutes % 60;
    return m == 0 ? '$h sa' : '$h sa $m dk';
  }

  Map<String, dynamic> toMap() => {
    'bed': bedTime.toIso8601String(),
    'wake': wakeTime.toIso8601String(),
    'quality': quality,
  };

  static SleepEntry? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final bed = DateTime.tryParse('${raw['bed']}');
    final wake = DateTime.tryParse('${raw['wake']}');
    final quality = (raw['quality'] as num?)?.toInt() ?? 3;
    if (bed == null || wake == null || !bed.isBefore(wake)) return null;
    return SleepEntry(
      bedTime: bed,
      wakeTime: wake,
      quality: quality.clamp(1, 5),
    );
  }

  static List<SleepEntry> parseList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map(tryFromMap).whereType<SleepEntry>().toList()
      ..sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
  }
}

/// Uyku puanı (0-10). Yetişkinler için önerilen süre 7-9 saattir
/// (National Sleep Foundation, 2015). Kullanıcının kalite değerlendirmesi
/// puanı en fazla ±1 değiştirir.
class SleepScore {
  SleepScore._();

  static double compute(SleepEntry entry) {
    final h = entry.hours;
    double base;
    if (h >= 7 && h <= 9) {
      base = 9;
    } else if ((h >= 6 && h < 7) || (h > 9 && h <= 10)) {
      base = 6.5;
    } else if ((h >= 5 && h < 6) || (h > 10 && h <= 11)) {
      base = 4;
    } else {
      base = 2;
    }
    final adjusted = base + (entry.quality - 3) * 0.5;
    return adjusted.clamp(0, 10).toDouble();
  }

  static String assessment(SleepEntry entry) {
    final h = entry.hours;
    if (h < 6) return 'Yetersiz uyku';
    if (h < 7) return 'Önerilenin biraz altında';
    if (h <= 9) return 'Önerilen aralıkta';
    return 'Önerilenden uzun';
  }
}
