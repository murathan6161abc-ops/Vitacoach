class HealthEntry {
  final double value;
  final DateTime date;
  final String? note;

  HealthEntry({required this.value, required this.date, this.note});

  Map<String, dynamic> toMap() => {
    'value': value,
    'date': date.toIso8601String(),
    'note': note,
  };

  /// Eski/uyumsuz kayıtlarda değer 'value' yerine 'weight' anahtarıyla
  /// yazılmış olabilir (bkz. ProfileProvider geçmişi); ikisini de kabul
  /// ederek tek bir bozuk kayıt yüzünden tüm listenin okunamamasını önler.
  factory HealthEntry.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['value'] ?? map['weight'];
    return HealthEntry(
      value: raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0,
      date: DateTime.tryParse('${map['date']}') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}

class BloodPressureEntry {
  final double systolic;
  final double diastolic;
  final DateTime date;
  final String? note;

  BloodPressureEntry({
    required this.systolic,
    required this.diastolic,
    required this.date,
    this.note,
  });

  String get display => '${systolic.toInt()}/${diastolic.toInt()} mmHg';

  String get category {
    if (systolic < 120 && diastolic < 80) return 'Normal';
    if (systolic < 130 && diastolic < 80) return 'Yüksek Normal';
    if (systolic < 140 && diastolic < 90) return 'Evre 1 Hipertansiyon';
    if (systolic >= 140 || diastolic >= 90) return 'Evre 2 Hipertansiyon';
    return 'Bilinmiyor';
  }

  Map<String, dynamic> toMap() => {
    'systolic': systolic,
    'diastolic': diastolic,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory BloodPressureEntry.fromMap(Map<dynamic, dynamic> map) =>
      BloodPressureEntry(
        systolic: (map['systolic'] as num?)?.toDouble() ?? 0,
        diastolic: (map['diastolic'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse('${map['date']}') ?? DateTime.now(),
        note: map['note'] as String?,
      );
}

class MedicationReminder {
  final int notificationId;
  final String name;
  final String dosage;
  final int hour;
  final int minute;
  final bool isActive;

  /// İlacın eklendiği an; uyum skoru bu tarihten itibaren hesaplanır.
  /// Eski kayıtlarda yoktur (null).
  final DateTime? createdAt;

  MedicationReminder({
    int? notificationId,
    required this.name,
    required this.dosage,
    required this.hour,
    required this.minute,
    this.isActive = true,
    this.createdAt,
  }) : notificationId = notificationId ?? createNotificationId();

  static int createNotificationId({int salt = 0}) {
    final value = DateTime.now().microsecondsSinceEpoch + salt;
    return NotificationIdsRange.start +
        (value % NotificationIdsRange.availableCount);
  }

  static int _legacyNotificationId(Map<dynamic, dynamic> map) {
    final source =
        '${map['name'] ?? ''}|${map['dosage'] ?? ''}|'
        '${map['hour'] ?? 0}|${map['minute'] ?? 0}';
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return NotificationIdsRange.start +
        (hash % NotificationIdsRange.availableCount);
  }

  String get timeDisplay =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'notification_id': notificationId,
    'name': name,
    'dosage': dosage,
    'hour': hour,
    'minute': minute,
    'is_active': isActive,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  factory MedicationReminder.fromMap(Map<dynamic, dynamic> map) =>
      MedicationReminder(
        notificationId:
            (map['notification_id'] as num?)?.toInt() ??
            _legacyNotificationId(map),
        name: map['name'],
        dosage: map['dosage'] ?? '',
        hour: map['hour'],
        minute: map['minute'],
        isActive: map['is_active'] ?? true,
        createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
      );

  MedicationReminder copyWith({int? notificationId, bool? isActive}) {
    return MedicationReminder(
      notificationId: notificationId ?? this.notificationId,
      name: name,
      dosage: dosage,
      hour: hour,
      minute: minute,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

class NotificationIdsRange {
  NotificationIdsRange._();

  static const int start = 10000;
  static const int availableCount = 2000000000;
}
