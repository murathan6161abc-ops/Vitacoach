import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m02_symptom/services/triage.dart';

final _flags = FlagRule.listFromJson(
  json.decode(File('assets/data/emergency_flags.json').readAsStringSync())
      as Map<String, dynamic>,
);

final Map<String, String> _severity = {
  for (final c
      in (json.decode(File('assets/data/symptoms.json').readAsStringSync())
              as Map<String, dynamic>)['categories']
          as List)
    for (final s in c['symptoms'] as List) '${s['id']}': '${s['severity']}',
};

TriageResult _assess(List<String> ids) => assessSymptoms(
  severityById: {for (final id in ids) id: _severity[id]!},
  flags: _flags,
);

void main() {
  test('göğüs ağrısı + sol kolda ağrı kalp krizi kuralıyla acil', () {
    final r = _assess(['chest_pain', 'arm_pain_left']);
    expect(r.level, TriageLevel.red);
    expect(r.flag?.id, 'heart_attack');
  });

  test('tek başına düşük riskli iki belirti birlikte sarı olabilir', () {
    // Öksürük ve kas ağrısı tek tek yeşil; birlikte enfeksiyon belirtisi.
    final r = _assess(['cough', 'muscle_pain']);
    expect(r.level, TriageLevel.yellow);
    expect(r.flag?.id, 'infection_signs');
  });

  test('kırmızı belirti, kural tetiklenmese de acil', () {
    final r = _assess(['headache', 'fainting']);
    expect(r.level, TriageLevel.red);
  });

  test('kırmızı kural sarı kuraldan önce gelir', () {
    final r = _assess(['fever', 'cough', 'chest_pain', 'shortness_breath']);
    expect(r.level, TriageLevel.red);
    expect(r.flag?.red, isTrue);
  });

  test('yalnızca düşük riskli belirti yeşil kalır', () {
    expect(_assess(['diarrhea']).level, TriageLevel.green);
  });
}
