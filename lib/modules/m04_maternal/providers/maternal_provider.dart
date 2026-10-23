import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/hive_service.dart';
import '../models/maternal_model.dart';

class MaternalProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  PregnancyProfile _pregnancyProfile = PregnancyProfile();
  List<dynamic> _weeks = [];
  Map<String, dynamic> _preeclampsiaRules = {};
  List<BabyGrowthEntry> _babyGrowth = [];
  List<BreastfeedingEntry> _breastfeedingLog = [];

  PregnancyProfile get pregnancyProfile => _pregnancyProfile;
  List<dynamic> get weeks => _weeks;
  Map<String, dynamic> get preeclampsiaRules => _preeclampsiaRules;
  List<BabyGrowthEntry> get babyGrowth => _babyGrowth;
  List<BreastfeedingEntry> get breastfeedingLog => _breastfeedingLog;

  /// pregnancy_weeks.json her haftayı içermez (ör. 13'ten sonra 16, 20, 24
  /// gibi atlamalı ilerler). Tam eşleşme aranırsa aradaki haftalarda içerik
  /// tamamen kaybolur; bu yüzden mevcut haftayı geçmeyen en yakın kayda
  /// düşülür.
  Map<String, dynamic>? get currentWeekData {
    final week = _pregnancyProfile.currentWeek;
    if (week <= 0 || _weeks.isEmpty) return null;

    Map<String, dynamic>? best;
    var bestWeek = -1;
    for (final raw in _weeks) {
      if (raw is! Map) continue;
      final w = Map<String, dynamic>.from(raw);
      final wNum = w['week'];
      if (wNum is! int || wNum > week) continue;
      if (wNum > bestWeek) {
        bestWeek = wNum;
        best = w;
      }
    }
    return best;
  }

  Future<void> init() async {
    await _loadWeeksData();
    _loadProfile();
    _loadBabyGrowth();
    _loadBreastfeedingLog();
  }

  Future<void> _loadWeeksData() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/pregnancy_weeks.json',
      );
      final data = json.decode(jsonString);
      _weeks = data['weeks'];
      _preeclampsiaRules = data['preeclampsia_rules'];
      notifyListeners();
    } catch (e) {
      debugPrint('Gebelik verisi yükleme hatası: $e');
    }
  }

  void _loadProfile() {
    final box = _hiveService.getHealthBox();
    final lpdStr = box.get('last_period_date');
    _pregnancyProfile = PregnancyProfile(
      lastPeriodDate: lpdStr != null ? DateTime.tryParse(lpdStr) : null,
    );
  }

  void _loadBabyGrowth() {
    final box = _hiveService.getHealthBox();
    final data = box.get('baby_growth', defaultValue: <dynamic>[]) ?? [];
    _babyGrowth = data
        .map<BabyGrowthEntry>((e) => BabyGrowthEntry.fromMap(e))
        .toList();
  }

  void _loadBreastfeedingLog() {
    final box = _hiveService.getHealthBox();
    final data = box.get('breastfeeding_log', defaultValue: <dynamic>[]) ?? [];
    _breastfeedingLog = data
        .map<BreastfeedingEntry>((e) => BreastfeedingEntry.fromMap(e))
        .toList();
    _breastfeedingLog.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> setLastPeriodDate(DateTime date) async {
    _pregnancyProfile = PregnancyProfile(
      lastPeriodDate: date,
      dueDate: date.add(const Duration(days: 280)),
    );
    final box = _hiveService.getHealthBox();
    await box.put('last_period_date', date.toIso8601String());
    notifyListeners();
  }

  /// Gebelik takibini sonlandırır (yanlış tarih, doğum sonrası vb.).
  /// Önceden son adet tarihi bir kez girildikten sonra değiştirilemiyordu.
  Future<void> clearPregnancy() async {
    _pregnancyProfile = PregnancyProfile();
    await _hiveService.getHealthBox().delete('last_period_date');
    notifyListeners();
  }

  /// Hafta rehberinde "Şu an" rozetinin gösterileceği hafta: veride tam
  /// eşleşme yoksa [currentWeekData] ile aynı en yakın kayıt.
  int? get currentGuideWeek => currentWeekData?['week'] as int?;

  Future<void> addBabyGrowth(BabyGrowthEntry entry) async {
    _babyGrowth.add(entry);
    final box = _hiveService.getHealthBox();
    await box.put('baby_growth', _babyGrowth.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> addBreastfeeding(BreastfeedingEntry entry) async {
    _breastfeedingLog.insert(0, entry);
    final box = _hiveService.getHealthBox();
    await box.put(
      'breastfeeding_log',
      _breastfeedingLog.map((e) => e.toMap()).toList(),
    );
    notifyListeners();
  }

  // Preeclampsia risk check
  bool checkPreeclampsiaRisk(List<String> symptoms) {
    final warningSignsRaw = _preeclampsiaRules['warning_signs'];
    if (warningSignsRaw == null) return false;
    final warningSigns = List<String>.from(warningSignsRaw);
    return symptoms.any((s) => warningSigns.contains(s));
  }

  // Today's breastfeeding summary
  int get todayFeedingCount {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _breastfeedingLog
        .where((e) => e.startTime.toIso8601String().substring(0, 10) == today)
        .length;
  }

  int get todayFeedingMinutes {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _breastfeedingLog
        .where((e) => e.startTime.toIso8601String().substring(0, 10) == today)
        .fold(0, (sum, e) => sum + e.durationMinutes);
  }
}
