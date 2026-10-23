class Food {
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;
  final int gi; // glycemic index
  final String portion;

  Food({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.gi,
    required this.portion,
  });

  factory Food.fromJson(Map<String, dynamic> json) => Food(
    name: json['name'],
    calories: json['calories'],
    protein: json['protein'],
    carbs: json['carbs'],
    fat: json['fat'],
    fiber: json['fiber'] ?? 0,
    gi: json['gi'] ?? 0,
    portion: json['portion'],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'gi': gi,
    'portion': portion,
  };

  bool get isHighGI => gi > 55;
  bool get isMediumGI => gi > 40 && gi <= 55;
  bool get isLowGI => gi <= 40;
}

class FoodCategory {
  final String id;
  final String name;
  final List<Food> foods;

  FoodCategory({required this.id, required this.name, required this.foods});

  factory FoodCategory.fromJson(Map<String, dynamic> json) => FoodCategory(
    id: json['id'],
    name: json['name'],
    foods: (json['foods'] as List).map((f) => Food.fromJson(f)).toList(),
  );
}

class MealEntry {
  final Food food;
  final DateTime dateTime;
  final String mealType; // kahvalti, ogle, aksam, ara

  MealEntry({
    required this.food,
    required this.dateTime,
    this.mealType = 'ara',
  });

  Map<String, dynamic> toMap() => {
    ...food.toMap(),
    'date': dateTime.toIso8601String(),
    'meal_type': mealType,
  };

  factory MealEntry.fromMap(Map<String, dynamic> map) => MealEntry(
    food: Food(
      name: map['name'],
      calories: map['calories'],
      protein: map['protein'],
      carbs: map['carbs'],
      fat: map['fat'],
      fiber: map['fiber'] ?? 0,
      gi: map['gi'] ?? 0,
      portion: map['portion'] ?? '',
    ),
    dateTime: DateTime.parse(map['date']),
    mealType: map['meal_type'] ?? 'ara',
  );
}
