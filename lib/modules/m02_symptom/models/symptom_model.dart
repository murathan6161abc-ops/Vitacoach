class Symptom {
  final String id;
  final String name;
  final String severity; // green, yellow, red
  final List<String> related;

  Symptom({
    required this.id,
    required this.name,
    required this.severity,
    this.related = const [],
  });

  factory Symptom.fromJson(Map<String, dynamic> json) => Symptom(
    id: json['id'],
    name: json['name'],
    severity: json['severity'],
    related: List<String>.from(json['related'] ?? []),
  );
}

class SymptomCategory {
  final String id;
  final String name;
  final String icon;
  final List<Symptom> symptoms;

  SymptomCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.symptoms,
  });

  factory SymptomCategory.fromJson(Map<String, dynamic> json) =>
      SymptomCategory(
        id: json['id'],
        name: json['name'],
        icon: json['icon'],
        symptoms: (json['symptoms'] as List)
            .map((s) => Symptom.fromJson(s))
            .toList(),
      );
}

enum TriageLevel { green, yellow, red }

class TriageResult {
  final TriageLevel level;
  final String title;
  final String message;
  final bool isEmergency;

  TriageResult({
    required this.level,
    required this.title,
    required this.message,
    this.isEmergency = false,
  });
}
