import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/hive_service.dart';
import '../models/symptom_model.dart';

class SymptomProvider extends ChangeNotifier {
  List<SymptomCategory> _categories = [];
  final List<Symptom> _selectedSymptoms = [];
  TriageResult? _triageResult;

  List<SymptomCategory> get categories => _categories;
  List<Symptom> get selectedSymptoms => _selectedSymptoms;
  TriageResult? get triageResult => _triageResult;

  Future<void> loadSymptoms() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/symptoms.json',
      );
      final data = json.decode(jsonString);
      _categories = (data['categories'] as List)
          .map((c) => SymptomCategory.fromJson(c))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Semptom yükleme hatası: $e');
    }
  }

  void toggleSymptom(Symptom symptom) {
    final exists = _selectedSymptoms.any((s) => s.id == symptom.id);
    if (exists) {
      _selectedSymptoms.removeWhere((s) => s.id == symptom.id);
    } else {
      _selectedSymptoms.add(symptom);
    }
    _triageResult = null;
    notifyListeners();
  }

  bool isSelected(Symptom symptom) =>
      _selectedSymptoms.any((s) => s.id == symptom.id);

  void performTriage() {
    if (_selectedSymptoms.isEmpty) return;

    final hasRed = _selectedSymptoms.any((s) => s.severity == 'red');
    final hasYellow = _selectedSymptoms.any((s) => s.severity == 'yellow');

    if (hasRed) {
      _triageResult = TriageResult(
        level: TriageLevel.red,
        title: 'ACİL DURUM',
        message:
            'Seçtiğiniz belirtiler acil müdahale gerektirebilir. Hemen 112\'yi arayın!',
        isEmergency: true,
      );
    } else if (hasYellow) {
      _triageResult = TriageResult(
        level: TriageLevel.yellow,
        title: 'DİKKAT',
        message:
            'Belirtileriniz tıbbi değerlendirme gerektirebilir. 24 saat içinde doktora başvurmanız önerilir.',
      );
    } else {
      _triageResult = TriageResult(
        level: TriageLevel.green,
        title: 'DÜŞÜK RİSK',
        message:
            'Belirtileriniz şu an için düşük riskli görünüyor. Şikayetleriniz artarsa doktora başvurun.',
      );
    }

    // Save to history
    _saveToHistory();
    notifyListeners();
  }

  void _saveToHistory() {
    final box = HiveService().getHealthBox();
    List<dynamic> history =
        box.get('symptom_history', defaultValue: <dynamic>[]) ?? [];
    history.add({
      'symptoms': _selectedSymptoms.map((s) => s.name).toList(),
      'triage': _triageResult?.level.name,
      'date': DateTime.now().toIso8601String(),
    });
    box.put('symptom_history', history);
  }

  void clear() {
    _selectedSymptoms.clear();
    _triageResult = null;
    notifyListeners();
  }
}
