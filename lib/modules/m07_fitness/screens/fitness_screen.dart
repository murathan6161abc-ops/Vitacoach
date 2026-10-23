import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../../shared/widgets/vc_button.dart';
import '../providers/fitness_provider.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  bool _trackingStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_trackingStarted) return;
    _trackingStarted = true;
    unawaited(context.read<FitnessProvider>().startStepTracking());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fitness'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Adımlar'),
              Tab(text: 'Egzersiz'),
              Tab(text: 'Geçmiş'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStepsTab(context),
            _buildExerciseTab(context),
            _buildHistoryTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsTab(BuildContext context) {
    return Consumer<FitnessProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            children: [
              VcCard(
                child: Column(
                  children: [
                    Text(
                      'Bugünkü Adımlar',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: CircularProgressIndicator(
                            value: provider.todayProgress.clamp(0.0, 1.0),
                            strokeWidth: 14,
                            backgroundColor: AppColors.primaryContainer,
                            color: AppColors.accentFitness,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${provider.todaySteps}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentFitness,
                              ),
                            ),
                            Text(
                              '/ ${AppConstants.dailyStepGoal}',
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statChip(
                          '${provider.todayKm.toStringAsFixed(1)} km',
                          Icons.straighten,
                        ),
                        _statChip(
                          '${provider.todayCalories} kcal',
                          Icons.local_fire_department,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    VcButton(
                      text: 'Adım Ekle',
                      onPressed: () => _addStepsDialog(context, provider),
                      icon: Icons.directions_walk,
                      color: AppColors.accentFitness,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              VcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Haftalık Aktivite',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ort: ${provider.weeklyAvgSteps.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: AppConstants.dailyStepGoal.toDouble() * 1.2,
                          barGroups: provider.weeklySteps.asMap().entries.map((
                            e,
                          ) {
                            final isToday = e.key == 6;
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value.toDouble(),
                                  color: isToday
                                      ? AppColors.accentFitness
                                      : AppColors.accentFitness.withValues(
                                          alpha: 0.5,
                                        ),
                                  width: 22,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const days = [
                                    'Pzt',
                                    'Sal',
                                    'Çar',
                                    'Per',
                                    'Cum',
                                    'Cmt',
                                    'Paz',
                                  ];
                                  final now = DateTime.now();
                                  final day = now.subtract(
                                    Duration(days: 6 - value.toInt()),
                                  );
                                  return Text(
                                    days[day.weekday - 1],
                                    style: const TextStyle(fontSize: 11),
                                  );
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: AppConstants.dailyStepGoal
                                .toDouble(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _addStepsDialog(
    BuildContext context,
    FitnessProvider provider,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adım Ekle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Adım sayısı',
            hintText: 'Örn: 5000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;
    final steps = InputUtils.inRange(InputUtils.parseInt(result), 1, 100000);
    if (steps == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adım sayısı 1-100.000 arasında olmalı.'),
          ),
        );
      }
      return;
    }
    await provider.addSteps(steps);
  }

  Widget _buildExerciseTab(BuildContext context) {
    final exercises = FitnessProvider.exercises;
    final categories = exercises.map((e) => e.category).toSet().toList();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: categories.map((category) {
        final categoryExercises = exercises
            .where((e) => e.category == category)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...categoryExercises.map((exercise) {
              return VcCard(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentFitness.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppColors.accentFitness,
                    ),
                  ),
                  title: Text(
                    exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${exercise.durationMinutes} dk • ${exercise.caloriesPerHour} kcal/sa • ${exercise.muscleGroup}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: AppColors.accentFitness,
                      size: 32,
                    ),
                    onPressed: () => _startExercise(
                      context,
                      exercise.name,
                      exercise.durationMinutes,
                      exercise.caloriesPerHour,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _startExercise(
    BuildContext context,
    String name,
    int defaultDuration,
    int caloriesPerHour,
  ) async {
    final controller = TextEditingController(text: defaultDuration.toString());
    final durationStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hedef Süre (dakika)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Başla'),
          ),
        ],
      ),
    );

    if (durationStr != null && durationStr.isNotEmpty && context.mounted) {
      // 0 veya negatif hedef, sayaçta 0/0 = NaN ilerleme değeri üretiyordu.
      final targetMinutes =
          InputUtils.inRange(InputUtils.parseInt(durationStr), 1, 180) ??
          defaultDuration;

      // Show Countdown Timer
      final completedMinutes = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            _CountdownTimerDialog(name: name, targetMinutes: targetMinutes),
      );

      if (completedMinutes == 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('1 dakikadan kısa süren egzersiz kaydedilmedi.'),
          ),
        );
      }
      if (completedMinutes != null && completedMinutes > 0 && context.mounted) {
        await context.read<FitnessProvider>().addWorkout(
          name,
          completedMinutes,
          caloriesPerHour,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name - $completedMinutes dk tamamlandı ve kaydedildi!',
            ),
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Consumer<FitnessProvider>(
      builder: (context, provider, _) {
        if (provider.workoutHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: AppColors.textHint),
                SizedBox(height: 16),
                Text(
                  'Henüz egzersiz kaydı yok',
                  style: TextStyle(color: AppColors.textHint),
                ),
                Text(
                  'Egzersiz sekmesinden başlayın!',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          itemCount: provider.workoutHistory.length,
          itemBuilder: (context, index) {
            final workout = provider.workoutHistory[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  Icons.fitness_center,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(workout.exerciseName),
              subtitle: Text(
                '${workout.durationMinutes} dk • ${workout.caloriesBurned} kcal',
              ),
              trailing: Builder(
                builder: (context) {
                  final months = [
                    'Oca',
                    'Şub',
                    'Mar',
                    'Nis',
                    'May',
                    'Haz',
                    'Tem',
                    'Ağu',
                    'Eyl',
                    'Eki',
                    'Kas',
                    'Ara',
                  ];
                  return Text(
                    '${workout.date.day} ${months[workout.date.month - 1]}',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _CountdownTimerDialog extends StatefulWidget {
  final String name;
  final int targetMinutes;

  const _CountdownTimerDialog({
    required this.name,
    required this.targetMinutes,
  });

  @override
  State<_CountdownTimerDialog> createState() => _CountdownTimerDialogState();
}

class _CountdownTimerDialogState extends State<_CountdownTimerDialog> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.targetMinutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        Navigator.pop(context, widget.targetMinutes);
      }
    });
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = 1 - (_remainingSeconds / (widget.targetMinutes * 60));

    return AlertDialog(
      title: Text('${widget.name} Egzersizi', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: AppColors.primaryContainer,
                  color: AppColors.accentFitness,
                ),
              ),
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentFitness,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 48,
                color: _isRunning ? AppColors.warning : AppColors.success,
                icon: Icon(
                  _isRunning
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
                onPressed: _toggleTimer,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Gerçekte geçen süreyi say. Önceden kalan dakika üzerinden
            // hesaplanıyor ve en az 1 dakikaya yuvarlanıyordu; "Bitir"e
            // hemen basmak bile 1 dakikalık (kalorili) sahte bir antrenman
            // kaydediyordu. 1 dakikadan kısa süre kaydedilmez.
            _timer?.cancel();
            final elapsedSeconds =
                widget.targetMinutes * 60 - _remainingSeconds;
            Navigator.pop(context, elapsedSeconds ~/ 60);
          },
          child: Text('Bitir', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
