import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Rezonans nefesi: 4 sn al, 6 sn ver (dakikada 6 nefes). Kalp hızı
/// değişkenliğini artırdığı ve stresi azalttığı gösterilmiş basit bir
/// yöntemdir. Tamamlanınca true döner.
Future<bool?> showBreathingExercise(BuildContext context, {int seconds = 60}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BreathingExerciseScreen(totalSeconds: seconds),
    ),
  );
}

class BreathingExerciseScreen extends StatefulWidget {
  final int totalSeconds;
  const BreathingExerciseScreen({super.key, this.totalSeconds = 60});

  @override
  State<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with SingleTickerProviderStateMixin {
  static const int _inhaleMs = 4000;
  static const int _exhaleMs = 6000;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _inhaleMs + _exhaleMs),
  )..repeat();
  late final Timer _timer;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _elapsed++);
      if (_elapsed >= widget.totalSeconds) {
        t.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.totalSeconds - _elapsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Nefes Egzersizi')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '4 saniye burnunuzdan alın, 6 saniye ağzınızdan yavaşça verin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final ms = _controller.value * (_inhaleMs + _exhaleMs);
                      final inhaling = ms < _inhaleMs;
                      final t = inhaling
                          ? ms / _inhaleMs
                          : 1 - (ms - _inhaleMs) / _exhaleMs;
                      final eased = Curves.easeInOut.transform(t.clamp(0, 1));
                      final size = 140 + 120 * eased;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: Center(
                              child: Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.35),
                                      AppColors.primary.withValues(alpha: 0.85),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            inhaling ? 'Nefes al' : 'Nefes ver',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Text(
                'Kalan: $remaining sn',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _elapsed / widget.totalSeconds),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Bitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
