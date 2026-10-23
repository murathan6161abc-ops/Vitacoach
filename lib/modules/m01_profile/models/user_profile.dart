class UserProfile {
  final String name;
  final DateTime? birthDate;
  final String gender;
  final double height;
  final double weight;
  final List<String> conditions;
  final List<String> goals;
  final bool notificationsEnabled;

  UserProfile({
    this.name = '',
    this.birthDate,
    this.gender = '',
    this.height = 0,
    this.weight = 0,
    this.conditions = const [],
    this.goals = const [],
    this.notificationsEnabled = true,
  });

  double get bmi {
    if (height <= 0 || weight <= 0) return 0;
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  String get bmiCategory {
    if (bmi == 0) return '';
    if (bmi < 18.5) return 'Zayıf';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Fazla Kilolu';
    return 'Obez';
  }

  int get age {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  double get dailyCalorieNeed {
    if (height <= 0 || weight <= 0 || age <= 0) return 2000;
    // Harris-Benedict formula
    if (gender == 'Erkek') {
      return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }
  }

  bool get hasDiabetes => conditions.contains('Diyabet');
  bool get hasHypertension => conditions.contains('Hipertansiyon');
  bool get hasAsthma => conditions.contains('Astım');
  bool get hasHeartDisease => conditions.contains('Kalp Hastalığı');
  bool get wantsToQuitSmoking => goals.contains('Sigara bırak');
  bool get wantsToLoseWeight => goals.contains('Kilo ver');

  Map<String, dynamic> toMap() => {
    'name': name,
    'birth_date': birthDate?.toIso8601String(),
    'gender': gender,
    'height': height,
    'weight': weight,
    'conditions': conditions,
    'goals': goals,
    'notifications_enabled': notificationsEnabled,
  };

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
    name: map['name'] ?? '',
    birthDate: map['birth_date'] != null
        ? DateTime.tryParse(map['birth_date'])
        : null,
    gender: map['gender'] ?? '',
    height: (map['height'] as num?)?.toDouble() ?? 0,
    weight: (map['weight'] as num?)?.toDouble() ?? 0,
    conditions: List<String>.from(map['conditions'] ?? []),
    goals: List<String>.from(map['goals'] ?? []),
    notificationsEnabled: map['notifications_enabled'] ?? true,
  );
}
