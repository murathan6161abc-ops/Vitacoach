class HealthEntry {
  final double value;
  final DateTime date;
  final String? note;

  /// Kan şekeri ölçüm zamanı (bkz. SugarTiming); eski kayıtlarda yoktur.
  final String? timing;

  HealthEntry({
    required this.value,
    required this.date,
    this.note,
    this.timing,
  });

  Map<String, dynamic> toMap() => {
    'value': value,
    'date': date.toIso8601String(),
    'note': note,
    if (timing != null) 'timing': timing,
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
      timing: map['timing'] as String?,
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

  /// Büyük tansiyon 180 veya üstü ya da küçük tansiyon 120 veya üstü:
  /// hipertansif kriz olabilir. Önceden yalnızca "Evre 2" deniyordu.
  bool get isCrisis => systolic >= 180 || diastolic >= 120;

  /// 90/60 altı düşük tansiyon sayılır (yüksek tansiyon kategorileri önce
  /// değerlendirilir: 150/55 düşük değil, Evre 2'dir).
  bool get isLow => systolic < 90 || diastolic < 60;

  String get category {
    if (isCrisis) return 'Hipertansif kriz';
    if (systolic >= 140 || diastolic >= 90) return 'Evre 2 Hipertansiyon';
    if (systolic >= 130 || diastolic >= 80) return 'Evre 1 Hipertansiyon';
    if (isLow) return 'Düşük tansiyon';
    if (systolic >= 120) return 'Yüksek Normal';
    return 'Normal';
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

/// İlacın günlük doz saatlerinden biri. Her dozun kendi kalıcı bildirim
/// kimliği vardır: günlük bildirim, "Aldım" eylemi ve doz günlüğü dozu bu
/// kimlikle tanır.
class MedicationDose {
  final int notificationId;
  final int hour;
  final int minute;

  /// Doz ilaca sonradan (saatler düzenlenirken) eklendiyse eklendiği an;
  /// uyum bu dozu bu andan itibaren sayar. İlaçla birlikte eklenen dozlarda
  /// yoktur (null).
  final DateTime? addedAt;

  MedicationDose({
    int? notificationId,
    required this.hour,
    required this.minute,
    this.addedAt,
  }) : notificationId =
           notificationId ?? MedicationReminder.createNotificationId();

  int get minuteOfDay => hour * 60 + minute;

  String get timeDisplay =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Dozun [day] günündeki vakti.
  DateTime dueOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  Map<String, dynamic> toMap() => {
    'notification_id': notificationId,
    'hour': hour,
    'minute': minute,
    if (addedAt != null) 'added_at': addedAt!.toIso8601String(),
  };

  MedicationDose copyWith({
    int? notificationId,
    int? hour,
    int? minute,
    DateTime? addedAt,
  }) => MedicationDose(
    notificationId: notificationId ?? this.notificationId,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    addedAt: addedAt ?? this.addedAt,
  );
}

class MedicationReminder {
  final String name;
  final String dosage;

  /// Günlük doz saatleri; saate göre sıralı, en az bir doz.
  final List<MedicationDose> doses;
  final bool isActive;

  /// İlacın eklendiği an; uyum skoru bu tarihten itibaren hesaplanır.
  /// Eski kayıtlarda yoktur (null).
  final DateTime? createdAt;

  MedicationReminder({
    required this.name,
    required this.dosage,
    required List<MedicationDose> doses,
    this.isActive = true,
    this.createdAt,
  }) : doses = _sorted(doses);

  static List<MedicationDose> _sorted(List<MedicationDose> doses) {
    if (doses.isEmpty) {
      throw ArgumentError.value(doses, 'doses', 'En az bir doz saati gerekir');
    }
    return List.unmodifiable(
      [...doses]..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay)),
    );
  }

  static int createNotificationId({int salt = 0}) {
    final value = DateTime.now().microsecondsSinceEpoch + salt;
    return NotificationIdsRange.start +
        (value % NotificationIdsRange.availableCount);
  }

  static int _legacyNotificationId(
    Map<dynamic, dynamic> medication,
    Map<dynamic, dynamic> dose,
  ) {
    final source =
        '${medication['name'] ?? ''}|${medication['dosage'] ?? ''}|'
        '${dose['hour'] ?? 0}|${dose['minute'] ?? 0}';
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return NotificationIdsRange.start +
        (hash % NotificationIdsRange.availableCount);
  }

  /// "08:00, 20:00"
  String get timesDisplay => doses.map((d) => d.timeDisplay).join(', ');

  /// Kayıt eski sürümün tek saatli biçiminde mi (doz listesi yok)?
  static bool isLegacyMap(Map<dynamic, dynamic> map) {
    final doses = map['doses'];
    return doses is! List || doses.isEmpty;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'dosage': dosage,
    'doses': [for (final dose in doses) dose.toMap()],
    // Tek saatli eski sürümler de okuyabilsin diye ilk dozun kimliği ve
    // saati üst düzeyde tekrarlanır; bu sürüm yalnızca 'doses' listesini okur.
    'notification_id': doses.first.notificationId,
    'hour': doses.first.hour,
    'minute': doses.first.minute,
    'is_active': isActive,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  /// Eski tek saatli kayıt, üst düzeydeki saat ve bildirim kimliğiyle tek
  /// doza dönüşür; doz günlüğündeki eski kayıtlar böylece bu doza ait kalır.
  factory MedicationReminder.fromMap(Map<dynamic, dynamic> map) {
    final doseMaps = isLegacyMap(map)
        ? [map]
        : (map['doses'] as List).whereType<Map<dynamic, dynamic>>();
    return MedicationReminder(
      name: map['name'],
      dosage: map['dosage'] ?? '',
      doses: [
        for (final dose in doseMaps)
          MedicationDose(
            notificationId:
                (dose['notification_id'] as num?)?.toInt() ??
                _legacyNotificationId(map, dose),
            hour: (dose['hour'] as num).toInt(),
            minute: (dose['minute'] as num).toInt(),
            addedAt: DateTime.tryParse('${dose['added_at'] ?? ''}'),
          ),
      ],
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
    );
  }

  MedicationReminder copyWith({List<MedicationDose>? doses, bool? isActive}) {
    return MedicationReminder(
      name: name,
      dosage: dosage,
      doses: doses ?? this.doses,
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
