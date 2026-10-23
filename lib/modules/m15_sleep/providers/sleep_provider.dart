import 'package:flutter/material.dart';

import '../../../services/hive_service.dart';
import '../models/sleep_entry.dart';

class SleepProvider extends ChangeNotifier {
  static const _key = 'sleep_log';

  List<SleepEntry> _entries = [];

  List<SleepEntry> get entries => _entries;

  void loadData() {
    _entries = SleepEntry.parseList(HiveService().getHealthBox().get(_key));
    notifyListeners();
  }

  /// Aynı sabaha ait kayıt varsa üzerine yazar.
  Future<void> addEntry(SleepEntry entry) async {
    _entries.removeWhere((e) => e.dayKey == entry.dayKey);
    _entries.add(entry);
    _entries.sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
    await _save();
    notifyListeners();
  }

  Future<void> removeEntry(SleepEntry entry) async {
    _entries.remove(entry);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await HiveService().getHealthBox().put(
      _key,
      _entries.map((e) => e.toMap()).toList(),
    );
  }

  /// Bu sabahın ya da (henüz girilmediyse) dünün kaydı.
  SleepEntry? get lastNight {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final yesterday = now
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    for (final e in _entries) {
      if (e.dayKey == today || e.dayKey == yesterday) return e;
    }
    return null;
  }

  /// Son 7 günün (bugün dahil) saat cinsinden süreleri; kayıt yoksa 0.
  List<double> get last7DaysHours {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now
          .subtract(Duration(days: 6 - i))
          .toIso8601String()
          .substring(0, 10);
      final match = _entries.where((e) => e.dayKey == day);
      return match.isEmpty ? 0.0 : match.first.hours;
    });
  }

  double? get weeklyAverageHours {
    final values = last7DaysHours.where((h) => h > 0).toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
