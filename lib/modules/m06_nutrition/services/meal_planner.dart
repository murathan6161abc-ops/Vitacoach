import '../models/food_model.dart';

/// Planlanan tek bir öğün.
class PlannedMeal {
  final String title;
  final String mealType; // kahvalti, ogle, aksam, ara
  final int targetCalories;
  final List<Food> items;

  const PlannedMeal({
    required this.title,
    required this.mealType,
    required this.targetCalories,
    required this.items,
  });

  int get calories => items.fold(0, (sum, f) => sum + f.calories);
  int get protein => items.fold(0, (sum, f) => sum + f.protein);
  int get carbs => items.fold(0, (sum, f) => sum + f.carbs);
  int get fat => items.fold(0, (sum, f) => sum + f.fat);
}

/// Günlük öğün planı.
class MealPlan {
  final int targetCalories;
  final List<PlannedMeal> meals;
  final bool diabeticFriendly;

  const MealPlan({
    required this.targetCalories,
    required this.meals,
    required this.diabeticFriendly,
  });

  int get calories => meals.fold(0, (sum, m) => sum + m.calories);
}

/// Cihaz üzerinde çalışan, kural tabanlı öğün planlayıcı.
///
/// Hiçbir ağ çağrısı yapmaz. Günlük kalori hedefi Harris-Benedict bazal
/// metabolizma hızından, hafif aktivite katsayısıyla (x1.375) türetilir;
/// "Kilo ver" hedefinde 500 kcal açık uygulanır. Diyabet varsa glisemik
/// indeksi 55'in üzerindeki yiyecekler plandan çıkarılır.
class MealPlanner {
  MealPlanner._();

  /// Sağlıklı bir günlük planda yer almaması gereken yiyecekler.
  static const Set<String> _excluded = {
    'Baklava',
    'Kola',
    'Çay (2 şekerli)',
    'Açma',
    'Poğaça (peynirli)',
    'Sucuk (ızgara)',
    'İskender kebap',
    'Hünkar beğendi',
  };

  static const double _activityFactor = 1.375;

  /// Profil bilgisinden günlük kalori hedefi hesaplar.
  static int dailyTarget({
    required double bmr,
    required bool wantsToLoseWeight,
    required bool isMale,
    bool hasProfileData = true,
  }) {
    if (!hasProfileData || bmr <= 0) return 2000;
    var target = bmr * _activityFactor;
    if (wantsToLoseWeight) target -= 500;
    final floor = isMale ? 1500.0 : 1200.0;
    if (target < floor) target = floor;
    // 50 kcal'a yuvarla, okunaklı olsun.
    return (target / 50).round() * 50;
  }

  static MealPlan generate({
    required Map<String, List<Food>> foodsByCategory,
    required int targetCalories,
    required bool diabetic,
    int seed = 0,
  }) {
    bool allowed(Food f) =>
        !_excluded.contains(f.name) && (!diabetic || !f.isHighGI);

    List<Food> pool(List<String> categories, {Set<String>? only}) {
      final result = <Food>[];
      for (final c in categories) {
        for (final f in foodsByCategory[c] ?? const <Food>[]) {
          if (!allowed(f)) continue;
          if (only != null && !only.contains(f.name)) continue;
          result.add(f);
        }
      }
      return result;
    }

    final breakfastProtein = pool(
      ['breakfast', 'dairy'],
      only: {
        'Yumurta (haşlanmış)',
        'Menemen',
        'Beyaz peynir',
        'Kaşar peyniri',
      },
    );
    final breads = pool(
      ['grains'],
      only: {'Tam buğday ekmeği', 'Beyaz ekmek', 'Simit'},
    );
    final breakfastSides = pool(
      ['breakfast', 'fruits'],
      only: {'Zeytin', 'Bal', 'Tahin-pekmez', 'Çilek', 'Portakal', 'Elma'},
    );
    final breakfastDrinks = pool(
      ['beverages', 'dairy'],
      only: {'Çay (şekersiz)', 'Süt (tam yağlı)', 'Türk kahvesi'},
    );
    final soups = pool(['soups']);
    final mains = pool(['meat', 'vegetables'])
      ..removeWhere((f) => f.name == 'Çoban salata');
    final sides = pool(
      ['grains'],
      only: {'Bulgur pilavı', 'Pilav', 'Tam buğday ekmeği', 'Makarna'},
    );
    final salads = pool(
      ['vegetables', 'dairy'],
      only: {'Çoban salata', 'Cacık', 'Yoğurt', 'Ayran'},
    );
    final snacks = pool(
      ['fruits', 'snacks', 'dairy'],
      only: {
        'Elma',
        'Portakal',
        'Muz',
        'Çilek',
        'Kayısı',
        'Ceviz',
        'Badem',
        'Kuru kayısı',
        'Yoğurt',
      },
    );
    final fillers = pool(
      ['grains', 'dairy', 'fruits'],
      only: {'Tam buğday ekmeği', 'Yoğurt', 'Elma', 'Çilek'},
    );

    Food? pick(List<Food> list, int salt) {
      if (list.isEmpty) return null;
      return list[(seed * 7 + salt * 13).abs() % list.length];
    }

    /// Hedefe en yakın ana yemeği seçer; çeşitlilik için en yakın üç
    /// adaydan tohuma göre birini alır.
    Food? pickClosest(List<Food> list, int remaining, int salt) {
      if (list.isEmpty) return null;
      final sorted = [...list]
        ..sort(
          (a, b) => (a.calories - remaining).abs().compareTo(
            (b.calories - remaining).abs(),
          ),
        );
      final top = sorted.take(3).toList();
      return top[(seed + salt).abs() % top.length];
    }

    PlannedMeal build({
      required String title,
      required String type,
      required double share,
      required List<Food?> Function(int target) compose,
    }) {
      final target = (targetCalories * share).round();
      final items = compose(target).whereType<Food>().toList();
      var total = items.fold(0, (s, f) => s + f.calories);
      // Hedefin altında kaldıysa küçük eklerle tamamla (±%10 bandı).
      var guard = 0;
      while (total < target * 0.9 && fillers.isNotEmpty && guard < 4) {
        final filler = fillers[(seed + guard) % fillers.length];
        if (total + filler.calories > target * 1.1) break;
        items.add(filler);
        total += filler.calories;
        guard++;
      }
      return PlannedMeal(
        title: title,
        mealType: type,
        targetCalories: target,
        items: items,
      );
    }

    final meals = <PlannedMeal>[
      build(
        title: 'Kahvaltı',
        type: 'kahvalti',
        share: 0.25,
        compose: (_) => [
          pick(breakfastProtein, 1),
          pick(breads, 2),
          pick(breakfastSides, 3),
          pick(breakfastDrinks, 4),
        ],
      ),
      build(
        title: 'Öğle Yemeği',
        type: 'ogle',
        share: 0.35,
        compose: (target) {
          final soup = pick(soups, 5);
          final side = pick(sides, 6);
          final salad = pick(salads, 7);
          final fixed = [soup, side, salad].whereType<Food>().fold(
            0,
            (s, f) => s + f.calories,
          );
          return [soup, pickClosest(mains, target - fixed, 8), side, salad];
        },
      ),
      build(
        title: 'Akşam Yemeği',
        type: 'aksam',
        share: 0.30,
        compose: (target) {
          final salad = pick(salads, 9);
          final side = pick(sides, 10);
          final fixed = [salad, side].whereType<Food>().fold(
            0,
            (s, f) => s + f.calories,
          );
          return [pickClosest(mains, target - fixed, 11), side, salad];
        },
      ),
      build(
        title: 'Ara Öğün',
        type: 'ara',
        share: 0.10,
        compose: (_) => [pick(snacks, 12)],
      ),
    ];

    return MealPlan(
      targetCalories: targetCalories,
      meals: meals,
      diabeticFriendly: diabetic,
    );
  }
}
