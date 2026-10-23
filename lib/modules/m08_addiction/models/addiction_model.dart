class SmokingProfile {
  final DateTime? quitDate;
  final int dailyCigarettes;
  final double pricePerCigarette;

  SmokingProfile({
    this.quitDate,
    this.dailyCigarettes = 20,
    this.pricePerCigarette = 1.5,
  });

  /// Bırakma tarihi ileri bir güne planlanmışsa henüz başlamamıştır.
  /// Önceden fark negatif çıkıyor ve ekranda "-3 Gün", "-150 ₺" gibi
  /// değerler görünüyordu.
  bool get isScheduled => quitDate != null && quitDate!.isAfter(DateTime.now());

  int get daysUntilQuit {
    if (!isScheduled) return 0;
    return quitDate!.difference(DateTime.now()).inHours ~/ 24 + 1;
  }

  Duration get timeSinceQuit {
    if (quitDate == null || isScheduled) return Duration.zero;
    return DateTime.now().difference(quitDate!);
  }

  int get daysSinceQuit => timeSinceQuit.inDays;
  int get hoursSinceQuit => timeSinceQuit.inHours;
  int get minutesSinceQuit => timeSinceQuit.inMinutes;

  double get moneySaved => daysSinceQuit * dailyCigarettes * pricePerCigarette;
  int get cigarettesAvoided => daysSinceQuit * dailyCigarettes;
  double get lifeDaysGained =>
      daysSinceQuit * dailyCigarettes * 11 / (24 * 60); // 11 min per cigarette

  bool get hasQuit => quitDate != null;
}

class HealthMilestone {
  final String time;
  final String benefit;
  final int hoursRequired;
  final bool achieved;

  HealthMilestone({
    required this.time,
    required this.benefit,
    required this.hoursRequired,
    required this.achieved,
  });
}

class AddictionBadge {
  final String name;
  final String description;
  final int daysRequired;
  final bool earned;

  AddictionBadge({
    required this.name,
    required this.description,
    required this.daysRequired,
    required this.earned,
  });

  static List<AddictionBadge> getBadges(int daysSinceQuit) => [
    AddictionBadge(
      name: 'İlk Adım',
      description: '1 gün sigarasız',
      daysRequired: 1,
      earned: daysSinceQuit >= 1,
    ),
    AddictionBadge(
      name: 'Bir Hafta',
      description: '7 gün sigarasız',
      daysRequired: 7,
      earned: daysSinceQuit >= 7,
    ),
    AddictionBadge(
      name: 'İki Hafta',
      description: '14 gün sigarasız',
      daysRequired: 14,
      earned: daysSinceQuit >= 14,
    ),
    AddictionBadge(
      name: 'Bir Ay',
      description: '30 gün sigarasız',
      daysRequired: 30,
      earned: daysSinceQuit >= 30,
    ),
    AddictionBadge(
      name: 'Üç Ay',
      description: '90 gün sigarasız',
      daysRequired: 90,
      earned: daysSinceQuit >= 90,
    ),
    AddictionBadge(
      name: 'Altı Ay',
      description: '180 gün sigarasız',
      daysRequired: 180,
      earned: daysSinceQuit >= 180,
    ),
    AddictionBadge(
      name: 'Bir Yıl',
      description: '365 gün sigarasız',
      daysRequired: 365,
      earned: daysSinceQuit >= 365,
    ),
  ];
}
