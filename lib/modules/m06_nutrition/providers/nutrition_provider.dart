import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/input_utils.dart';
import '../../../services/hive_service.dart';
import '../models/food_model.dart';

/// Beslenme günlüğünün (öğünler, su) tek kaynağı.
///
/// Bellekteki liste yalnızca önbellektir: her değişiklik Hive'daki güncel
/// değeri okuyup kopyası üzerinde yapılır. Önceden ekran kendi listesini
/// tutuyordu; bildirimden eklenen su ekranda görünmüyor ve sonraki
/// dokunuşla eziliyordu. Gece yarısı açık kalan ekran da aynı liste
/// nesnesini hem dünün hem bugünün anahtarına yazıp dünkü kaydı bellekte
/// bozuyordu.
class NutritionProvider extends ChangeNotifier {
  NutritionProvider({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _hiveService = HiveService();

  List<Map<String, dynamic>> _foodCategories = const [];
  List<Map<String, dynamic>> _todayMeals = const [];
  int _waterCount = 0;
  String _loadedDay = '';

  static String dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  String get _today => dayKey(_clock());

  /// Ham kategori verisi (assets/data/foods_tr.json).
  List<Map<String, dynamic>> get foodCategories => _foodCategories;

  Map<String, List<Food>> get foodsByCategory => {
    for (final category in _foodCategories)
      '${category['id']}': _parseFoods(category['foods']),
  };

  List<Food> get allFoods => [
    for (final category in _foodCategories) ..._parseFoods(category['foods']),
  ];

  List<Map<String, dynamic>> get todayMeals {
    _ensureToday();
    return _todayMeals;
  }

  int get waterCount {
    _ensureToday();
    return _waterCount;
  }

  bool get isDiabetic {
    final conditions = _hiveService.getProfileBox().get('conditions');
    return conditions is List && conditions.contains('Diyabet');
  }

  int get totalCalories => _sum('calories');
  int get totalProtein => _sum('protein');
  int get totalCarbs => _sum('carbs');
  int get totalFat => _sum('fat');

  int get waterMl => waterCount * AppConstants.waterGlassMl;
  double get waterProgress => waterMl / AppConstants.dailyWaterGoalMl;

  Future<void> init() async {
    // Günlük veri önce: yemek listesi yüklenmeden de ekranda görünsün.
    _loadToday();
    await _loadFoods();
  }

  Future<void> _loadFoods() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/foods_tr.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      _foodCategories = [
        for (final c in (data['categories'] as List? ?? const []))
          if (c is Map) Map<String, dynamic>.from(c),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Yemek verisi yükleme hatası: $e');
    }
  }

  /// Bildirimden eklenen su gibi dışarıdan yapılan değişiklikleri okur.
  void reloadToday() {
    _loadToday();
    notifyListeners();
  }

  void _ensureToday() {
    if (_loadedDay != _today) _loadToday();
  }

  void _loadToday() {
    final day = _today;
    _todayMeals = List.unmodifiable(_readMeals(day));
    _waterCount = _readWater(day);
    _loadedDay = day;
  }

  /// Hive'daki listenin elemanlarının kopyası; Hive'ın bellekte tuttuğu
  /// nesneyle hiçbir zaman aynı örnek değildir.
  List<Map<String, dynamic>> _readMeals(String day) {
    final raw = _hiveService.getNutritionBox().get('meals_$day');
    if (raw is! List) return [];
    return [
      for (final meal in raw)
        if (meal is Map) Map<String, dynamic>.from(meal),
    ];
  }

  int _readWater(String day) {
    final raw = _hiveService.getNutritionBox().get('water_$day');
    return raw is num ? raw.toInt() : 0;
  }

  Future<void> _writeMeals(String day, List<Map<String, dynamic>> meals) async {
    await _hiveService.getNutritionBox().put('meals_$day', meals);
    _todayMeals = List.unmodifiable(_readMeals(day));
    _loadedDay = day;
    notifyListeners();
  }

  Future<void> addMeal(Map<String, dynamic> food) async {
    final day = _today;
    final meals = _readMeals(day)
      ..add({
        ...food,
        'category': food['category'] ?? _categoryOf(food['name'] as String?),
      });
    await _writeMeals(day, meals);
  }

  /// Silinen öğünü döndürür (geçersiz sırada null).
  Future<Map<String, dynamic>?> removeMeal(int index) async {
    final day = _today;
    final meals = _readMeals(day);
    if (index < 0 || index >= meals.length) return null;
    final removed = meals.removeAt(index);
    await _writeMeals(day, meals);
    return removed;
  }

  Future<void> addWater() => _setWater(_readWater(_today) + 1);

  Future<void> removeWater() async {
    final current = _readWater(_today);
    if (current > 0) await _setWater(current - 1);
  }

  Future<void> _setWater(int glasses) async {
    final day = _today;
    await _hiveService.getNutritionBox().put('water_$day', glasses);
    _waterCount = glasses;
    if (_loadedDay != day) {
      _todayMeals = List.unmodifiable(_readMeals(day));
      _loadedDay = day;
    }
    notifyListeners();
  }

  String? _categoryOf(String? name) {
    if (name == null) return null;
    for (final category in _foodCategories) {
      for (final raw in (category['foods'] as List? ?? const [])) {
        if (raw is Map && raw['name'] == name) return '${category['id']}';
      }
    }
    return null;
  }

  int _sum(String field) => todayMeals.fold(
    0,
    (sum, meal) => sum + ((meal[field] as num?)?.toInt() ?? 0),
  );

  static List<Food> _parseFoods(dynamic raw) {
    final foods = <Food>[];
    for (final item in (raw as List? ?? const [])) {
      try {
        foods.add(Food.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {}
    }
    return foods;
  }

  /// Türkçe'ye duyarlı arama ("ızgara" -> "Izgara köfte", "cay" -> "Çay").
  List<Food> searchFoods(String query) {
    final q = InputUtils.normalizeForSearch(query);
    if (q.isEmpty) return [];
    return [
      for (final food in allFoods)
        if (InputUtils.normalizeForSearch(food.name).contains(q)) food,
    ];
  }
}
