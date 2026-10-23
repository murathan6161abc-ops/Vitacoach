import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m19_heart/services/ppg_processor.dart';

/// Gerçekçi sentetik PPG: atım zamanlarında darbe, solunumla değişen
/// atım aralığı, yavaş kayma ve gürültü; 30 fps, [seconds] saniye.
List<PpgSample> synthetic({
  required double bpm,
  double seconds = 30,
  double fps = 30,
  double rsaMs = 40,
  double noise = 0.15,
  int seed = 1,
}) {
  final rnd = math.Random(seed);
  final baseIbi = 60000 / bpm;
  final beats = <double>[];
  var t = 300.0;
  while (t < seconds * 1000) {
    beats.add(t);
    // Solunumsal sinüs aritmisi (~0,25 Hz)
    t += baseIbi + rsaMs * math.sin(2 * math.pi * 0.25 * t / 1000);
  }
  final samples = <PpgSample>[];
  final n = (seconds * fps).round();
  for (var i = 0; i < n; i++) {
    final ms =
        i * 1000 / fps + rnd.nextDouble() * 4; // kare zamanlama titremesi
    var v = 150 + 8 * math.sin(2 * math.pi * 0.05 * ms / 1000); // kayma
    for (final b in beats) {
      final d = (ms - b) / 90;
      if (d.abs() < 4) v -= 3 * math.exp(-d * d); // atımda parlaklık düşer
    }
    v += (rnd.nextDouble() - 0.5) * 2 * noise;
    samples.add(PpgSample(ms.round(), v));
  }
  return samples;
}

void main() {
  group('PPG nabız ölçümü', () {
    for (final bpm in [55.0, 72.0, 95.0, 130.0]) {
      test('${bpm.toInt()} atım/dk doğru bulunur', () {
        final r = PpgProcessor.analyze(synthetic(bpm: bpm))!;
        expect(r.bpm, closeTo(bpm, 2.5));
        expect(r.reliable, isTrue);
      });
    }

    test('solunum aritmisi HRV olarak yakalanır, düz ritimde düşük kalır', () {
      final variable = PpgProcessor.analyze(synthetic(bpm: 65, rsaMs: 60))!;
      final flat = PpgProcessor.analyze(
        synthetic(bpm: 65, rsaMs: 0, noise: 0.05),
      )!;
      expect(variable.rmssdMs, greaterThan(flat.rmssdMs));
      expect(variable.rmssdMs, greaterThan(15));
      expect(flat.rmssdMs, lessThan(15));
    });

    test('kısa veya düz sinyalde sonuç üretmez', () {
      expect(PpgProcessor.analyze(synthetic(bpm: 70, seconds: 5)), isNull);
      final flat = [for (var i = 0; i < 600; i++) PpgSample(i * 33, 120)];
      expect(PpgProcessor.analyze(flat), isNull);
    });

    test('stres düzeyi RMSSD eşiklerine göre', () {
      PpgResult r(double rmssd) => PpgResult(
        bpm: 70,
        rmssdMs: rmssd,
        sdnnMs: 30,
        beats: 30,
        quality: 1,
        ibisMs: const [],
      );
      expect(r(55).stress, StressLevel.low);
      expect(r(30).stress, StressLevel.moderate);
      expect(r(12).stress, StressLevel.high);
    });
  });

  group('Kare analizi', () {
    test('düzgün kırmızı kare parmak olarak algılanır', () {
      const w = 64, h = 48;
      final y = Uint8List(w * h)..fillRange(0, w * h, 160);
      final v = Uint8List((w ~/ 2) * (h ~/ 2))
        ..fillRange(0, (w ~/ 2) * (h ~/ 2), 190);
      final s = FrameStats.fromYuv(
        y: y,
        width: w,
        height: h,
        yRowStride: w,
        v: v,
        vRowStride: w ~/ 2,
      );
      expect(s.fingerDetected, isTrue);
    });

    test('desenli (parmaksız) kare algılanmaz', () {
      const w = 64, h = 48;
      final y = Uint8List.fromList([
        for (var i = 0; i < w * h; i++) (i * 37) % 256,
      ]);
      final s = FrameStats.fromYuv(y: y, width: w, height: h, yRowStride: w);
      expect(s.fingerDetected, isFalse);
    });
  });
}
