import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../modules/m03_chronic/models/health_entry.dart';
import '../../modules/m03_chronic/models/medication_adherence.dart';
import '../../modules/m03_chronic/providers/chronic_provider.dart';
import '../../modules/m06_nutrition/providers/nutrition_provider.dart';
import '../../modules/m07_fitness/providers/fitness_provider.dart';
import 'vc_card.dart';

/// Ana sayfadaki "Bugün" paneli: bugünkü ilaç dozları, su ve adım. Ana
/// sayfa önceden yalnızca bir modül ızgarasıydı; günün yapılacakları için
/// her seferinde ilgili modüle girmek gerekiyordu.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  static int get _waterGoalGlasses =>
      AppConstants.dailyWaterGoalMl ~/ AppConstants.waterGlassMl;

  /// 5230 -> "5.230"
  static String thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final chronic = context.watch<ChronicProvider>();
    final nutrition = context.watch<NutritionProvider>();
    final fitness = context.watch<FitnessProvider>();
    final meds = chronic.medications.where((m) => m.isActive).toList()
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );

    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugün',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          for (final med in meds) _MedicationRow(medication: med),
          if (meds.isNotEmpty) const Divider(),
          Row(
            children: [
              Icon(Icons.water_drop, color: AppColors.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Su: ${nutrition.waterCount}/$_waterGoalGlasses bardak',
                ),
              ),
              IconButton(
                tooltip: 'Bir bardak su ekle',
                icon: Icon(Icons.add_circle, color: AppColors.secondary),
                onPressed: nutrition.addWater,
              ),
            ],
          ),
          InkWell(
            onTap: () => context.push(AppConstants.routeFitness),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.directions_walk, color: AppColors.accentFitness),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Adım: ${thousands(fitness.todaySteps)} / '
                      '${thousands(AppConstants.dailyStepGoal)}',
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final MedicationReminder medication;

  const _MedicationRow({required this.medication});

  @override
  Widget build(BuildContext context) {
    final chronic = context.read<ChronicProvider>();
    final dose = chronic.todayDose(medication);
    final Widget status;
    if (dose?.status == DoseStatus.taken) {
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 4),
          Text('Alındı', style: TextStyle(color: AppColors.success)),
        ],
      );
    } else if (dose?.status == DoseStatus.skipped) {
      status = Text('Atlandı', style: TextStyle(color: AppColors.textHint));
    } else if (chronic.isDoseDue(medication)) {
      status = FilledButton.tonal(
        onPressed: () => chronic.markDose(medication, DoseStatus.taken),
        child: const Text('Aldım'),
      );
    } else {
      status = Text(
        medication.timeDisplay,
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.medication, color: AppColors.accentChronic),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${medication.name} · ${medication.timeDisplay}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          status,
        ],
      ),
    );
  }
}
