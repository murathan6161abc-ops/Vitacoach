import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m07_fitness/providers/fitness_provider.dart';
import 'package:vitacoach/modules/m07_fitness/services/step_history.dart';
import 'package:vitacoach/services/hive_service.dart';

import 'helpers/memory_hive.dart';

class _FakeStepHistory extends StepHistory {
  Map<String, int>? totals;
  _FakeStepHistory(this.totals);

  @override
  Future<Map<String, int>?> dailyTotals({int days = 7}) async => totals;
}

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  final today = _day(DateTime.now());
  final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));

  test('uygulama akşam ilk kez açılsa da sabahki adımlar sayılır', () async {
    // Sensör son okuması dünden: gün değişince fark sıfırlanıyor ve sabah
    // atılan adımlar hiç sayılmıyordu.
    await HiveService().getFitnessBox().putAll({
      'last_device_steps': 12000,
      'last_device_steps_date': yesterday,
    });
    final provider = FitnessProvider(
      stepHistory: _FakeStepHistory({today: 6200, yesterday: 9100}),
    )..loadData();

    await provider.syncDeviceHistory();

    expect(provider.todaySteps, 6200);
    expect(provider.weeklySteps.last, 6200);
    expect(provider.weeklySteps[5], 9100);
    expect(HiveService().getFitnessBox().get('steps_$today'), 6200);
  });

  test('elle eklenen adımlar cihaz senkronunda kaybolmaz', () async {
    final provider = FitnessProvider(
      stepHistory: _FakeStepHistory({today: 6000}),
    )..loadData();
    await provider.addSteps(500);

    await provider.syncDeviceHistory();

    expect(provider.todaySteps, 6500);
  });

  test('cihaz kaydı daha düşükse daha önce sayılan adımlar korunur', () async {
    // Eski sürüm yalnızca toplamı tutuyordu.
    await HiveService().getFitnessBox().put('steps_$today', 4000);
    final provider = FitnessProvider(
      stepHistory: _FakeStepHistory({today: 1000}),
    )..loadData();

    await provider.syncDeviceHistory();

    expect(provider.todaySteps, 4000);
  });

  test(
    'sensörün gün içi artışı cihaz adımına eklenir, elle girilen korunur',
    () async {
      await HiveService().getFitnessBox().putAll({
        'last_device_steps': 1000,
        'last_device_steps_date': today,
      });
      final provider = FitnessProvider(stepHistory: _FakeStepHistory(null))
        ..loadData();
      await provider.addSteps(200);

      await provider.handleDeviceStepCount(1300);

      expect(provider.todaySteps, 500);
      expect(HiveService().getFitnessBox().get('device_steps_$today'), 300);
    },
  );

  test('cihaz kaydı yoksa hiçbir şey değişmez', () async {
    await HiveService().getFitnessBox().put('steps_$today', 2500);
    final provider = FitnessProvider(stepHistory: _FakeStepHistory(null))
      ..loadData();

    await provider.syncDeviceHistory();

    expect(provider.todaySteps, 2500);
  });
}
