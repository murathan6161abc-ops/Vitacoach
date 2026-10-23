import 'dart:math' as math;
import 'dart:typed_data';

/// Kameradan elde edilen tek bir parlaklık örneği.
class PpgSample {
  final int tMs;
  final double value;
  const PpgSample(this.tMs, this.value);
}

enum StressLevel { low, moderate, high }

extension StressLevelLabel on StressLevel {
  String get label => switch (this) {
    StressLevel.low => 'Düşük',
    StressLevel.moderate => 'Orta',
    StressLevel.high => 'Yüksek',
  };
}

class PpgResult {
  final double bpm;

  /// Ardışık atım aralıkları farklarının karekök ortalaması (ms). Kısa
  /// süreli kalp hızı değişkenliği (HRV) göstergesi.
  final double rmssdMs;
  final double sdnnMs;
  final int beats;

  /// 0-1: geçerli atım aralıklarının oranı ve düzenliliği.
  final double quality;
  final List<double> ibisMs;

  const PpgResult({
    required this.bpm,
    required this.rmssdMs,
    required this.sdnnMs,
    required this.beats,
    required this.quality,
    required this.ibisMs,
  });

  /// RMSSD'ye dayalı kaba stres tahmini. Kısa ölçümde HRV gürültülüdür;
  /// yalnızca eğilim göstergesi olarak kullanılmalıdır.
  StressLevel get stress {
    if (rmssdMs >= 40) return StressLevel.low;
    if (rmssdMs >= 20) return StressLevel.moderate;
    return StressLevel.high;
  }

  bool get reliable => quality >= 0.6 && beats >= 8;
}

/// Fotopletismografi (PPG): parmak flaş ve kamerayı kapattığında her kalp
/// atımında kan hacmi değişir ve görüntü parlaklığı hafifçe dalgalanır.
/// Bu sınıf o dalgalanmadan atımları bulur. Tamamen cihaz içinde çalışır.
class PpgProcessor {
  PpgProcessor._();

  static const double minBpm = 40;
  static const double maxBpm = 180;

  /// [samples] zaman sıralı olmalıdır. Yetersiz/gürültülü sinyalde null.
  static PpgResult? analyze(List<PpgSample> samples) {
    if (samples.length < 60) return null;
    final durationMs = samples.last.tMs - samples.first.tMs;
    if (durationMs < 8000) return null;
    final fps = (samples.length - 1) * 1000 / durationMs;
    if (fps < 10) return null;

    final raw = samples.map((s) => s.value).toList();
    // 1) Yavaş değişimi (pozlama, parmak basıncı) çıkar: ~1 sn hareketli ortalama.
    final trend = _movingAverage(raw, (fps * 1.0).round().clamp(3, 999));
    final detrended = [for (var i = 0; i < raw.length; i++) raw[i] - trend[i]];
    // 2) Yüksek frekanslı gürültüyü yumuşat: ~0,15 sn.
    final smooth = _movingAverage(detrended, (fps * 0.15).round().clamp(1, 99));
    // Kan hacmi arttığında ışık emilir, parlaklık düşer: tepe = çukur.
    final signal = [for (final v in smooth) -v];

    final std = _std(signal);
    if (std == 0) return null;
    final minGap = (fps * 60 / maxBpm).floor().clamp(1, 999);
    final peaks = <double>[]; // alt-örnek hassasiyetinde zaman (ms)
    var lastPeak = -minGap;
    for (var i = 1; i < signal.length - 1; i++) {
      final v = signal[i];
      if (v <= 0.3 * std) continue;
      if (v < signal[i - 1] || v < signal[i + 1]) continue;
      // Pencere içindeki en yüksek nokta mı?
      final lo = math.max(0, i - minGap),
          hi = math.min(signal.length - 1, i + minGap);
      var isMax = true;
      for (var j = lo; j <= hi; j++) {
        if (signal[j] > v) {
          isMax = false;
          break;
        }
      }
      if (!isMax || i - lastPeak < minGap) continue;
      lastPeak = i;
      // Parabolik ara değerleme: 30 fps'lik ~33 ms çözünürlüğü iyileştirir.
      final a = signal[i - 1], b = signal[i], c = signal[i + 1];
      final denom = a - 2 * b + c;
      final offset = denom == 0
          ? 0.0
          : (0.5 * (a - c) / denom).clamp(-0.5, 0.5);
      final t0 = samples[i].tMs.toDouble();
      final dt = (samples[i + 1].tMs - samples[i - 1].tMs) / 2;
      peaks.add(t0 + offset * dt);
    }
    if (peaks.length < 5) return null;

    final ibis = [
      for (var i = 1; i < peaks.length; i++) peaks[i] - peaks[i - 1],
    ].where((ibi) => ibi >= 60000 / maxBpm && ibi <= 60000 / minBpm).toList();
    if (ibis.length < 4) return null;
    final med = median(ibis);
    // Median'dan %25'ten fazla sapan aralıklar (kaçırılan/fazladan atım) atılır.
    final valid = <double>[];
    final validMask = <bool>[];
    for (final ibi in ibis) {
      final ok = (ibi - med).abs() <= 0.25 * med;
      validMask.add(ok);
      if (ok) valid.add(ibi);
    }
    if (valid.length < 4) return null;

    final meanIbi = valid.reduce((a, b) => a + b) / valid.length;
    final diffs = <double>[];
    for (var i = 1; i < ibis.length; i++) {
      if (validMask[i] && validMask[i - 1]) diffs.add(ibis[i] - ibis[i - 1]);
    }
    final rmssd = diffs.isEmpty
        ? 0.0
        : math.sqrt(
            diffs.map((d) => d * d).reduce((a, b) => a + b) / diffs.length,
          );
    final sdnn = _std(valid);
    final validRatio = valid.length / ibis.length;
    final cv = sdnn / meanIbi;
    // Düzenli ritimde CV düşüktür; çok yüksek CV genelde hareket/gürültüdür.
    final regularity = (1 - ((cv - 0.10).clamp(0.0, 0.25) / 0.25));
    final quality = (validRatio * 0.7 + regularity * 0.3).clamp(0.0, 1.0);

    return PpgResult(
      bpm: 60000 / meanIbi,
      rmssdMs: rmssd,
      sdnnMs: sdnn,
      beats: valid.length + 1,
      quality: quality,
      ibisMs: valid,
    );
  }

  static double median(List<double> values) {
    final sorted = [...values]..sort();
    final n = sorted.length;
    if (n == 0) return 0;
    return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }

  static List<double> _movingAverage(List<double> x, int window) {
    final half = window ~/ 2;
    final prefix = List<double>.filled(x.length + 1, 0);
    for (var i = 0; i < x.length; i++) {
      prefix[i + 1] = prefix[i] + x[i];
    }
    return [
      for (var i = 0; i < x.length; i++)
        () {
          final lo = math.max(0, i - half),
              hi = math.min(x.length, i + half + 1);
          return (prefix[hi] - prefix[lo]) / (hi - lo);
        }(),
    ];
  }

  static double _std(List<double> x) {
    if (x.length < 2) return 0;
    final mean = x.reduce((a, b) => a + b) / x.length;
    final v =
        x.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b) /
        (x.length - 1);
    return math.sqrt(v);
  }
}

/// Kamera karesinden parlaklık ve "parmak kamerada mı?" bilgisini çıkarır.
class FrameStats {
  final double brightness;
  final double redness;
  final double uniformity;

  const FrameStats(this.brightness, this.redness, this.uniformity);

  /// Parmak flaşı ve lensi kapattığında görüntü kırmızı, oldukça düzgün
  /// (az desenli) ve orta parlaklıktadır.
  bool get fingerDetected =>
      brightness > 40 && brightness < 250 && uniformity < 28 && redness > 0.55;

  /// YUV420: Y düzlemi parlaklık, V (Cr) düzlemi kırmızılık verir.
  /// Performans için merkezdeki bölgeden seyrek örnekleme yapılır.
  static FrameStats fromYuv({
    required Uint8List y,
    required int width,
    required int height,
    required int yRowStride,
    Uint8List? v,
    int vRowStride = 0,
    int vPixelStride = 1,
  }) {
    final x0 = width ~/ 4, x1 = width * 3 ~/ 4;
    final y0 = height ~/ 4, y1 = height * 3 ~/ 4;
    var sum = 0.0, sumSq = 0.0, n = 0;
    var vSum = 0.0, vn = 0;
    for (var row = y0; row < y1; row += 6) {
      for (var col = x0; col < x1; col += 6) {
        final idx = row * yRowStride + col;
        if (idx >= y.length) continue;
        final p = y[idx].toDouble();
        sum += p;
        sumSq += p * p;
        n++;
        if (v != null) {
          final vi = (row ~/ 2) * vRowStride + (col ~/ 2) * vPixelStride;
          if (vi < v.length) {
            vSum += v[vi];
            vn++;
          }
        }
      }
    }
    if (n == 0) return const FrameStats(0, 0, 255);
    final mean = sum / n;
    final std = math.sqrt(math.max(0, sumSq / n - mean * mean));
    // Cr > 128 kırmızıya kayma demektir; 0-1'e ölçekle.
    final redness = vn == 0 ? 1.0 : ((vSum / vn - 128) / 40).clamp(0.0, 1.0);
    return FrameStats(mean, redness, std);
  }

  /// iOS BGRA8888 karesi.
  static FrameStats fromBgra({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
  }) {
    final x0 = width ~/ 4, x1 = width * 3 ~/ 4;
    final y0 = height ~/ 4, y1 = height * 3 ~/ 4;
    var sum = 0.0, sumSq = 0.0, n = 0, redDominant = 0;
    for (var row = y0; row < y1; row += 6) {
      for (var col = x0; col < x1; col += 6) {
        final i = row * rowStride + col * 4;
        if (i + 2 >= bytes.length) continue;
        final b = bytes[i], g = bytes[i + 1], r = bytes[i + 2];
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        sum += lum;
        sumSq += lum * lum;
        n++;
        if (r > g * 1.4 && r > b * 1.4) redDominant++;
      }
    }
    if (n == 0) return const FrameStats(0, 0, 255);
    final mean = sum / n;
    final std = math.sqrt(math.max(0, sumSq / n - mean * mean));
    return FrameStats(mean, redDominant / n, std);
  }
}
