import '../../../services/hive_service.dart';

class EmergencyContact {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relation = '',
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };

  static EmergencyContact? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final name = '${raw['name'] ?? ''}'.trim();
    final phone = '${raw['phone'] ?? ''}'.trim();
    if (name.isEmpty || phone.isEmpty) return null;
    return EmergencyContact(
      name: name,
      phone: phone,
      relation: '${raw['relation'] ?? ''}'.trim(),
    );
  }

  /// Arama/SMS için yalnızca rakam ve baştaki + işareti.
  String get dialable {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  /// Türkiye ve uluslararası numaralar için basit doğrulama.
  static bool isValidPhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 && digits.length <= 15;
  }
}

/// Acil sağlık kartı ve acil kişiler. Yalnızca cihazda (şifreli Hive
/// kutusunda) saklanır.
class EmergencyInfo {
  static const bloodTypes = [
    'Bilinmiyor',
    '0 Rh+',
    '0 Rh-',
    'A Rh+',
    'A Rh-',
    'B Rh+',
    'B Rh-',
    'AB Rh+',
    'AB Rh-',
  ];

  final String bloodType;
  final String allergies;
  final String notes;
  final List<EmergencyContact> contacts;

  const EmergencyInfo({
    this.bloodType = 'Bilinmiyor',
    this.allergies = '',
    this.notes = '',
    this.contacts = const [],
  });

  bool get isFilled =>
      bloodType != 'Bilinmiyor' ||
      allergies.trim().isNotEmpty ||
      contacts.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'blood_type': bloodType,
    'allergies': allergies,
    'notes': notes,
    'contacts': contacts.map((c) => c.toMap()).toList(),
  };

  factory EmergencyInfo.fromMap(dynamic raw) {
    if (raw is! Map) return const EmergencyInfo();
    final blood = '${raw['blood_type'] ?? 'Bilinmiyor'}';
    return EmergencyInfo(
      bloodType: bloodTypes.contains(blood) ? blood : 'Bilinmiyor',
      allergies: '${raw['allergies'] ?? ''}',
      notes: '${raw['notes'] ?? ''}',
      contacts: (raw['contacts'] is List ? raw['contacts'] as List : const [])
          .map(EmergencyContact.tryFromMap)
          .whereType<EmergencyContact>()
          .toList(),
    );
  }

  EmergencyInfo copyWith({
    String? bloodType,
    String? allergies,
    String? notes,
    List<EmergencyContact>? contacts,
  }) {
    return EmergencyInfo(
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      notes: notes ?? this.notes,
      contacts: contacts ?? this.contacts,
    );
  }

  static const _key = 'emergency_info';

  static EmergencyInfo load() =>
      EmergencyInfo.fromMap(HiveService().getProfileBox().get(_key));

  Future<void> save() => HiveService().getProfileBox().put(_key, toMap());
}

/// QR koda yazılacak düz metin. Herhangi bir QR okuyucuyla internetsiz
/// okunabilir; hiçbir sunucuya bağlantı içermez.
class EmergencyCardText {
  EmergencyCardText._();

  static const int maxLength = 900;

  static String build({
    required String name,
    required DateTime? birthDate,
    required int age,
    required EmergencyInfo info,
    required List<String> conditions,
    required List<String> medications,
  }) {
    String two(int v) => v.toString().padLeft(2, '0');
    final lines = <String>[
      'ACİL SAĞLIK KARTI (VitaCoach)',
      if (name.trim().isNotEmpty) 'Ad: ${name.trim()}',
      if (birthDate != null)
        'Doğum: ${two(birthDate.day)}.${two(birthDate.month)}.${birthDate.year}'
            '${age > 0 ? ' ($age yaş)' : ''}',
      'Kan grubu: ${info.bloodType}',
      'Alerjiler: ${info.allergies.trim().isEmpty ? 'Bilinmiyor/yok' : info.allergies.trim()}',
      if (conditions.isNotEmpty) 'Kronik hastalıklar: ${conditions.join(', ')}',
      if (medications.isNotEmpty) 'İlaçlar: ${medications.join('; ')}',
      for (final c in info.contacts.take(3))
        'Acil kişi: ${c.name}${c.relation.isNotEmpty ? ' (${c.relation})' : ''} ${c.phone}',
      if (info.notes.trim().isNotEmpty) 'Not: ${info.notes.trim()}',
    ];
    final text = lines.join('\n');
    return text.length <= maxLength
        ? text
        : '${text.substring(0, maxLength - 1)}…';
  }
}
