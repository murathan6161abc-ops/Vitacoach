import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/hive_service.dart';

class InfectiousProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  List<dynamic> _childVaccines = [];
  List<dynamic> _adultVaccines = [];
  Set<String> _completedVaccines = {};

  List<dynamic> get childVaccines => _childVaccines;
  List<dynamic> get adultVaccines => _adultVaccines;
  Set<String> get completedVaccines => _completedVaccines;

  int get totalChildVaccines => _childVaccines.length;
  int get completedChildVaccines =>
      _childVaccines.where((v) => _completedVaccines.contains(v['id'])).length;
  double get childProgress =>
      totalChildVaccines > 0 ? completedChildVaccines / totalChildVaccines : 0;

  Future<void> loadData() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/vaccine_schedule_tr.json',
      );
      final data = json.decode(jsonString);
      final box = _hiveService.getVaccineBox();
      final completed =
          box.get('completed_vaccines', defaultValue: <dynamic>[]) ?? [];

      _childVaccines = data['child_vaccines'];
      _adultVaccines = data['adult_vaccines'];
      _completedVaccines = Set<String>.from(completed);
      notifyListeners();
    } catch (e) {
      debugPrint('Aşı verisi yükleme hatası: $e');
    }
  }

  Future<void> toggleVaccine(String id) async {
    if (_completedVaccines.contains(id)) {
      _completedVaccines.remove(id);
    } else {
      _completedVaccines.add(id);
    }
    final box = _hiveService.getVaccineBox();
    await box.put('completed_vaccines', _completedVaccines.toList());
    notifyListeners();
  }

  bool isCompleted(String id) => _completedVaccines.contains(id);

  // Get upcoming vaccines based on child's age in months
  List<dynamic> getUpcomingVaccines(int childAgeMonths) {
    return _childVaccines.where((v) {
      final vaccineAge = v['age_months'] as int;
      return vaccineAge >= childAgeMonths &&
          !_completedVaccines.contains(v['id']);
    }).toList();
  }
}
