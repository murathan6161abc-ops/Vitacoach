class StepEntry {
  final int steps;
  final DateTime date;

  StepEntry({required this.steps, required this.date});

  double get kilometers => steps * 0.0007; // average stride ~70cm
  int get caloriesBurned => (steps * 0.04).toInt(); // ~0.04 kcal per step

  Map<String, dynamic> toMap() => {
    'steps': steps,
    'date': date.toIso8601String(),
  };

  factory StepEntry.fromMap(Map<dynamic, dynamic> map) =>
      StepEntry(steps: map['steps'], date: DateTime.parse(map['date']));
}

class Exercise {
  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final int caloriesPerHour;
  final String difficulty;
  final List<String> steps;
  final String muscleGroup;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.caloriesPerHour,
    required this.difficulty,
    this.steps = const [],
    this.muscleGroup = '',
  });
}

class WorkoutEntry {
  final String exerciseName;
  final int durationMinutes;
  final int caloriesBurned;
  final DateTime date;

  WorkoutEntry({
    required this.exerciseName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'exercise_name': exerciseName,
    'duration_minutes': durationMinutes,
    'calories_burned': caloriesBurned,
    'date': date.toIso8601String(),
  };

  factory WorkoutEntry.fromMap(Map<String, dynamic> map) => WorkoutEntry(
    exerciseName: map['exercise_name'],
    durationMinutes: map['duration_minutes'],
    caloriesBurned: map['calories_burned'],
    date: DateTime.parse(map['date']),
  );
}
