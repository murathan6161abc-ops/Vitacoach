class PregnancyProfile {
  final DateTime? lastPeriodDate;
  final DateTime? dueDate;

  PregnancyProfile({this.lastPeriodDate, this.dueDate});

  int get currentWeek {
    if (lastPeriodDate == null) return 0;
    final days = DateTime.now().difference(lastPeriodDate!).inDays;
    return (days / 7).floor();
  }

  int get currentDay {
    if (lastPeriodDate == null) return 0;
    return DateTime.now().difference(lastPeriodDate!).inDays % 7;
  }

  /// dueDate yalnızca bellekte set edilir, Hive'a ayrıca yazılmaz; uygulama
  /// yeniden açıldığında null olur. Bu durumda son adet tarihinden
  /// hesaplanan tahmini tarihe düşülür; aksi halde ekranda gebe olmayan
  /// veya erken haftadaki bir kullanıcıya bile yanlışlıkla
  /// "Doğum zamanı!" gösterilir.
  int get daysRemaining {
    final due = dueDate ?? (lastPeriodDate != null ? calculatedDueDate : null);
    if (due == null) return 0;
    return due.difference(DateTime.now()).inDays;
  }

  int get trimester {
    if (currentWeek <= 12) return 1;
    if (currentWeek <= 27) return 2;
    return 3;
  }

  DateTime get calculatedDueDate {
    if (lastPeriodDate == null) return DateTime.now();
    return lastPeriodDate!.add(const Duration(days: 280));
  }
}

class BabyGrowthEntry {
  final double weight; // kg
  final double height; // cm
  final double? headCircumference; // cm
  final DateTime date;
  final int ageMonths;

  BabyGrowthEntry({
    required this.weight,
    required this.height,
    this.headCircumference,
    required this.date,
    required this.ageMonths,
  });

  Map<String, dynamic> toMap() => {
    'weight': weight,
    'height': height,
    'head_circumference': headCircumference,
    'date': date.toIso8601String(),
    'age_months': ageMonths,
  };

  factory BabyGrowthEntry.fromMap(Map<dynamic, dynamic> map) => BabyGrowthEntry(
    weight: (map['weight'] as num).toDouble(),
    height: (map['height'] as num).toDouble(),
    headCircumference: (map['head_circumference'] as num?)?.toDouble(),
    date: DateTime.parse(map['date']),
    ageMonths: map['age_months'],
  );
}

class BreastfeedingEntry {
  final DateTime startTime;
  final int durationMinutes;
  final String side; // sol, sag, her iki

  BreastfeedingEntry({
    required this.startTime,
    required this.durationMinutes,
    required this.side,
  });

  Map<String, dynamic> toMap() => {
    'start_time': startTime.toIso8601String(),
    'duration_minutes': durationMinutes,
    'side': side,
  };

  factory BreastfeedingEntry.fromMap(Map<dynamic, dynamic> map) =>
      BreastfeedingEntry(
        startTime: DateTime.parse(map['start_time']),
        durationMinutes: map['duration_minutes'],
        side: map['side'],
      );
}
