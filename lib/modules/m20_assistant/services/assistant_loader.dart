import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../services/hive_service.dart';
import '../../m03_chronic/models/health_entry.dart';
import '../../m03_chronic/services/drug_interaction_service.dart';
import '../../m18_insights/services/insight_engine.dart';
import '../../m18_insights/services/insight_repository.dart';
import 'assistant_engine.dart';

/// Asistanın bilgi tabanını ve kullanıcının cihazdaki verilerini yükler.
class AssistantLoader {
  AssistantLoader._();

  /// JSON metinlerinden motoru kurar (testlerde doğrudan kullanılır).
  static AssistantEngine fromJson({
    required String kbJson,
    required String symptomsJson,
    required String flagsJson,
    AssistantContext context = const AssistantContext(),
  }) {
    final kb = (jsonDecode(kbJson)['entries'] as List)
        .map((e) => KbEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final symptoms = <SymptomDef>[
      for (final c in (jsonDecode(symptomsJson)['categories'] as List))
        for (final s in (c['symptoms'] as List))
          SymptomDef('${s['id']}', '${s['name']}', '${s['severity']}'),
    ];
    final flags = FlagRule.listFromJson(
      jsonDecode(flagsJson) as Map<String, dynamic>,
    );
    return AssistantEngine(
      kb: kb,
      symptoms: symptoms,
      flags: flags,
      context: context,
    );
  }

  static Future<AssistantEngine> load() async {
    final engine = fromJson(
      kbJson: await rootBundle.loadString('assets/data/assistant_kb.json'),
      symptomsJson: await rootBundle.loadString('assets/data/symptoms.json'),
      flagsJson: await rootBundle.loadString(
        'assets/data/emergency_flags.json',
      ),
    );
    engine.context = await loadContext();
    return engine;
  }

  static Future<AssistantContext> loadContext() async {
    final input = InsightRepository.load();
    final insights = InsightEngine.analyze(input);
    final hive = HiveService();
    final profile = hive.getProfileBox();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final water = hive.getNutritionBox().get('water_$today');
    final steps = hive.getFitnessBox().get('steps_$today');

    T? latest<T>(List<T> list, DateTime Function(T) date) {
      if (list.isEmpty) return null;
      return list.reduce((a, b) => date(a).isAfter(date(b)) ? a : b);
    }

    final medsRaw = hive.getMedicationBox().get('medications');
    final meds = <MedicationReminder>[];
    if (medsRaw is List) {
      for (final m in medsRaw) {
        if (m is! Map) continue;
        try {
          meds.add(MedicationReminder.fromMap(m));
        } catch (_) {}
      }
    }
    final recentSleep = input.sleep
        .where((s) => DateTime.now().difference(s.wakeTime).inDays < 7)
        .toList();

    DrugInteractionChecker? drugs;
    try {
      drugs = await DrugInteractionService().checker;
    } catch (_) {}

    return AssistantContext(
      name: profile.get('name') as String?,
      heightCm: (profile.get('height') as num?)?.toDouble(),
      lastBp: latest(input.pressures, (e) => e.date),
      lastSugar: latest(input.sugars, (e) => e.date),
      lastWeight: latest(input.weights, (e) => e.date),
      lastSleep: latest(input.sleep, (e) => e.wakeTime),
      sleepAvg7: recentSleep.isEmpty
          ? null
          : recentSleep.map((s) => s.hours).reduce((a, b) => a + b) /
                recentSleep.length,
      lastHeart: input.heart.isEmpty ? null : input.heart.first,
      adherence: input.adherence,
      medications: meds,
      insights: insights,
      waterGlassesToday: water is int ? water : 0,
      stepsToday: steps is int ? steps : 0,
      drugs: drugs,
    );
  }
}
