import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/utils/input_utils.dart';

enum InteractionSeverity { low, moderate, high }

extension InteractionSeverityLabel on InteractionSeverity {
  String get label {
    switch (this) {
      case InteractionSeverity.low:
        return 'Düşük';
      case InteractionSeverity.moderate:
        return 'Orta';
      case InteractionSeverity.high:
        return 'Yüksek';
    }
  }
}

class InteractionWarning {
  final String drugA;
  final String drugB;
  final InteractionSeverity severity;
  final String message;

  const InteractionWarning({
    required this.drugA,
    required this.drugB,
    required this.severity,
    required this.message,
  });
}

class _DrugGroup {
  final String id;
  final String name;
  final bool duplicateWarning;
  final List<List<String>> aliasTokens;

  _DrugGroup(this.id, this.name, this.duplicateWarning, this.aliasTokens);
}

/// Yerel veri tabanıyla ilaç etkileşimi denetimi (internet gerekmez).
///
/// İlaç adları gruplara (ör. "NSAİİ ağrı kesici") eşlenir; marka ve etken
/// madde adlarının ikisi de tanınır. Aynı ada sahip kayıtlar (örn. sabah ve
/// akşam iki ayrı hatırlatıcı) birbiriyle karşılaştırılmaz.
class DrugInteractionChecker {
  final List<_DrugGroup> _groups;
  final Map<String, ({InteractionSeverity severity, String message})> _rules;

  DrugInteractionChecker._(this._groups, this._rules);

  factory DrugInteractionChecker.fromJson(Map<String, dynamic> json) {
    final groups = <_DrugGroup>[];
    for (final raw in (json['groups'] as List? ?? const [])) {
      final g = Map<String, dynamic>.from(raw as Map);
      groups.add(
        _DrugGroup(
          '${g['id']}',
          '${g['name']}',
          g['duplicate_warning'] == true,
          List<String>.from(
            g['aliases'] ?? const [],
          ).map((a) => _tokens(a)).where((t) => t.isNotEmpty).toList(),
        ),
      );
    }
    final rules = <String, ({InteractionSeverity severity, String message})>{};
    for (final raw in (json['interactions'] as List? ?? const [])) {
      final r = Map<String, dynamic>.from(raw as Map);
      final severity = InteractionSeverity.values.firstWhere(
        (s) => s.name == r['severity'],
        orElse: () => InteractionSeverity.moderate,
      );
      rules[_pairKey('${r['a']}', '${r['b']}')] = (
        severity: severity,
        message: '${r['message']}',
      );
    }
    return DrugInteractionChecker._(groups, rules);
  }

  static List<String> _tokens(String text) => InputUtils.normalizeForSearch(
    text,
  ).split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toList();

  static String _pairKey(String a, String b) =>
      a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

  static bool _containsAlias(List<String> nameTokens, List<String> alias) {
    if (alias.length == 1) {
      final a = alias.first;
      // Uzun adlarda ek almış yazımları da yakala ("sertralinli" vb.).
      return nameTokens.any(
        (t) => t == a || (a.length >= 6 && t.startsWith(a)),
      );
    }
    for (var i = 0; i + alias.length <= nameTokens.length; i++) {
      var match = true;
      for (var j = 0; j < alias.length; j++) {
        if (nameTokens[i + j] != alias[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  /// İlacın ait olduğu grupların kimlikleri.
  Set<String> groupsFor(String medicationName) {
    final tokens = _tokens(medicationName);
    return {
      for (final g in _groups)
        if (g.aliasTokens.any((a) => _containsAlias(tokens, a))) g.id,
    };
  }

  /// Serbest metinde geçen ilaç adları (grup başına bir tane). Asistanın
  /// "X ile Y birlikte alınır mı?" sorularını anlaması için.
  List<String> mentionsIn(String text) {
    final tokens = _tokens(text);
    final found = <String>{};
    for (final g in _groups) {
      for (final alias in g.aliasTokens) {
        if (_containsAlias(tokens, alias)) {
          final name = alias.join(' ');
          found.add(InputUtils.upperTr(name[0]) + name.substring(1));
          break;
        }
      }
    }
    return found.toList();
  }

  String groupName(String id) => _groups.firstWhere((g) => g.id == id).name;

  /// İki ilaç arasındaki uyarılar.
  List<InteractionWarning> checkPair(String a, String b) {
    if (InputUtils.normalizeForSearch(a) == InputUtils.normalizeForSearch(b)) {
      return const [];
    }
    final ga = groupsFor(a);
    final gb = groupsFor(b);
    final warnings = <InteractionWarning>[];
    final seen = <String>{};
    for (final x in ga) {
      for (final y in gb) {
        if (x == y) {
          final group = _groups.firstWhere((g) => g.id == x);
          if (group.duplicateWarning && seen.add('dup|$x')) {
            warnings.add(
              InteractionWarning(
                drugA: a,
                drugB: b,
                severity: InteractionSeverity.moderate,
                message:
                    'İkisi de aynı ilaç grubunda (${group.name}). Birlikte '
                    'kullanmak yan etki riskini artırır; doktorunuza danışın.',
              ),
            );
          }
          continue;
        }
        final key = _pairKey(x, y);
        final rule = _rules[key];
        if (rule != null && seen.add(key)) {
          warnings.add(
            InteractionWarning(
              drugA: a,
              drugB: b,
              severity: rule.severity,
              message: rule.message,
            ),
          );
        }
      }
    }
    return warnings;
  }

  /// Yeni ilacın mevcut listeyle etkileşimleri.
  List<InteractionWarning> checkNew(String newMed, Iterable<String> existing) {
    return [for (final e in existing) ...checkPair(newMed, e)]
      ..sort((x, y) => y.severity.index.compareTo(x.severity.index));
  }

  /// Listedeki tüm ilaç çiftlerinin etkileşimleri.
  List<InteractionWarning> checkAll(List<String> medications) {
    final names = <String>[];
    for (final m in medications) {
      final n = InputUtils.normalizeForSearch(m);
      if (!names.any((x) => InputUtils.normalizeForSearch(x) == n)) {
        names.add(m);
      }
    }
    final warnings = <InteractionWarning>[];
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        warnings.addAll(checkPair(names[i], names[j]));
      }
    }
    warnings.sort((x, y) => y.severity.index.compareTo(x.severity.index));
    return warnings;
  }
}

class DrugInteractionService {
  static final DrugInteractionService _instance =
      DrugInteractionService._internal();
  factory DrugInteractionService() => _instance;
  DrugInteractionService._internal();

  DrugInteractionChecker? _checker;

  Future<DrugInteractionChecker> get checker async {
    return _checker ??= DrugInteractionChecker.fromJson(
      json.decode(
            await rootBundle.loadString('assets/data/drug_interactions.json'),
          )
          as Map<String, dynamic>,
    );
  }
}
