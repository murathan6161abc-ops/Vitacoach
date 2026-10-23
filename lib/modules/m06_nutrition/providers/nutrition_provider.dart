import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/input_utils.dart';
import '../../../services/hive_service.dart';
import '../models/food_model.dart';

class NutritionProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  List<FoodCategory> _foodCategories = [];
  List<MealEntry> _todayMeals = [];
  int _waterCount = 0;
  bool _isDiabetic = false;

  List<FoodCategory> get foodCategories => _foodCategories;
  List<MealEntry> get todayMeals => _todayMeals;
  int get waterCount => _waterCount;
  bool get isDiabetic => _isDiabetic;

  int get totalCalories =>
      _todayMeals.fold(0, (sum, m) => sum + m.food.calories);
  int get totalProtein => _todayMeals.fold(0, (sum, m) => sum + m.food.protein);
  int get totalCarbs => _todayMeals.fold(0, (sum, m) => sum + m.food.carbs);
  int get totalFat => _todayMeals.fold(0, (sum, m) => sum + m.food.fat);
  int get totalFiber => _todayMeals.fold(0, (sum, m) => sum + m.food.fiber);

  int get waterMl => _waterCount * AppConstants.waterGlassMl;
  double get waterProgress => waterMl / AppConstants.dailyWaterGoalMl;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> init() async {
    await _loadFoods();
    _loadTodayData();
    _checkDiabetic();
  }

  Future<void> _loadFoods() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/foods_tr.json',
      );
      final data = json.decode(jsonString);
      _foodCategories = (data['categories'] as List)
          .map((c) => FoodCategory.fromJson(c))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Yemek verisi yükleme hatası: $e');
    }
  }

  /// Bildirimden eklenen su gibi dışarıdan yapılan değişiklikleri okur.
  void reloadToday() => _loadTodayData();

  void _loadTodayData() {
    final box = _hiveService.getNutritionBox();
    final meals = box.get('meals_$_today', defaultValue: <dynamic>[]);
    _waterCount = box.get('water_$_today', defaultValue: 0) ?? 0;

    _todayMeals = [];
    if (meals != null) {
      for (final m in meals) {
        try {
          _todayMeals.add(MealEntry.fromMap(Map<String, dynamic>.from(m)));
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  void _checkDiabetic() {
    final conditions =
        _hiveService.getProfileBox().get(
          'conditions',
          defaultValue: <dynamic>[],
        ) ??
        [];
    _isDiabetic = conditions.contains('Diyabet');
  }

  Future<void> addMeal(Food food, {String mealType = 'ara'}) async {
    final entry = MealEntry(
      food: food,
      dateTime: DateTime.now(),
      mealType: mealType,
    );
    _todayMeals.add(entry);

    final box = _hiveService.getNutritionBox();
    await box.put('meals_$_today', _todayMeals.map((m) => m.toMap()).toList());
    notifyListeners();
  }

  Future<void> removeMeal(int index) async {
    if (index >= 0 && index < _todayMeals.length) {
      _todayMeals.removeAt(index);
      final box = _hiveService.getNutritionBox();
      await box.put(
        'meals_$_today',
        _todayMeals.map((m) => m.toMap()).toList(),
      );
      notifyListeners();
    }
  }

  Future<void> addWater() async {
    _waterCount++;
    final box = _hiveService.getNutritionBox();
    await box.put('water_$_today', _waterCount);
    notifyListeners();
  }

  Future<void> removeWater() async {
    if (_waterCount > 0) {
      _waterCount--;
      final box = _hiveService.getNutritionBox();
      await box.put('water_$_today', _waterCount);
      notifyListeners();
    }
  }

  /// Türkçe'ye duyarlı arama ("ızgara" -> "Izgara köfte", "cay" -> "Çay").
  List<Food> searchFoods(String query) {
    final q = InputUtils.normalizeForSearch(query);
    if (q.isEmpty) return [];
    final results = <Food>[];
    for (final category in _foodCategories) {
      for (final food in category.foods) {
        if (InputUtils.normalizeForSearch(food.name).contains(q)) {
          results.add(food);
        }
      }
    }
    return results;
  }
}
