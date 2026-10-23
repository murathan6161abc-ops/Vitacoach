/// Acil durum kuralı (assets/data/emergency_flags.json). Tek başına düşük
/// riskli görünen belirtiler birlikte görüldüğünde acil olabilir (ör.
/// göğüs ağrısı + sol kolda ağrı). Belirti ekranı ve asistan aynı kuralları
/// aynı eşleştirmeyle kullanır; önceden iki ayrı kopya vardı.
class FlagRule {
  final String id;
  final String name;
  final List<String> symptoms;
  final int minMatch;
  final String message;
  final bool red;

  const FlagRule(
    this.id,
    this.name,
    this.symptoms,
    this.minMatch,
    this.message,
    this.red,
  );

  /// Kuraldaki belirtilerden en az [minMatch] tanesi seçili mi?
  bool matches(Set<String> selectedIds) =>
      symptoms.where(selectedIds.contains).length >= minMatch;

  static List<FlagRule> listFromJson(Map<String, dynamic> json) => [
    for (final group in const ['red_flags', 'yellow_flags'])
      for (final f in (json[group] as List? ?? const []))
        FlagRule(
          '${f['id']}',
          '${f['name']}',
          List<String>.from(f['symptoms'] ?? const []),
          (f['min_match'] as num?)?.toInt() ?? 1,
          '${f['message']}',
          group == 'red_flags',
        ),
  ];
}

enum TriageLevel { red, yellow, green }

class TriageResult {
  final TriageLevel level;

  /// Tetiklenen kombinasyon kuralı (varsa).
  final FlagRule? flag;

  const TriageResult(this.level, [this.flag]);
}

/// Seçili belirtilerin önceliği: kırmızı kural > kırmızı belirti > sarı
/// kural > sarı belirti > düşük risk. [severityById]: belirti kimliği ->
/// 'red' / 'yellow' / 'green'.
TriageResult assessSymptoms({
  required Map<String, String> severityById,
  required List<FlagRule> flags,
}) {
  final ids = severityById.keys.toSet();
  FlagRule? firstMatch({required bool red}) {
    for (final flag in flags) {
      if (flag.red == red && flag.matches(ids)) return flag;
    }
    return null;
  }

  final redFlag = firstMatch(red: true);
  if (redFlag != null) return TriageResult(TriageLevel.red, redFlag);
  if (severityById.values.contains('red')) {
    return const TriageResult(TriageLevel.red);
  }
  final yellowFlag = firstMatch(red: false);
  if (yellowFlag != null) return TriageResult(TriageLevel.yellow, yellowFlag);
  if (severityById.values.contains('yellow')) {
    return const TriageResult(TriageLevel.yellow);
  }
  return const TriageResult(TriageLevel.green);
}
