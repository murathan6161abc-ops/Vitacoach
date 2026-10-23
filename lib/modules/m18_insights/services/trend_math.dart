import 'dart:math' as math;

/// En küçük kareler doğrusal regresyon sonucu: y = intercept + slope * x.
class LinearFit {
  final double slope;
  final double intercept;

  /// Belirlilik katsayısı (0-1): doğrunun veriyi ne kadar açıkladığı.
  final double r2;
  final int n;

  const LinearFit(this.slope, this.intercept, this.r2, this.n);

  double predict(double x) => intercept + slope * x;
}

/// Cihaz içi, açıklanabilir istatistik yöntemleri.
class TrendMath {
  TrendMath._();

  static LinearFit? fit(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n < 3 || ys.length != n) return null;
    final mx = mean(xs), my = mean(ys);
    var sxx = 0.0, sxy = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (xs[i] - mx) * (xs[i] - mx);
      sxy += (xs[i] - mx) * (ys[i] - my);
      syy += (ys[i] - my) * (ys[i] - my);
    }
    if (sxx == 0) return null;
    final slope = sxy / sxx;
    final intercept = my - slope * mx;
    final r2 = syy == 0 ? 0.0 : (sxy * sxy) / (sxx * syy);
    return LinearFit(slope, intercept, r2, n);
  }

  static double mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  static double median(List<double> v) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  /// Değiştirilmiş z-skoru (Iglewicz & Hoaglin, 1993): ortanca ve ortanca
  /// mutlak sapmaya dayanır; tek bir uç değerden etkilenmez. |z| > 3,5
  /// genellikle aykırı değer kabul edilir.
  static double? modifiedZ(double x, List<double> reference) {
    if (reference.length < 5) return null;
    final med = median(reference);
    final mad = median([for (final r in reference) (r - med).abs()]);
    if (mad == 0) {
      // Değerler neredeyse aynıysa ortalama mutlak sapmaya geri dön.
      final meanAbs = mean([for (final r in reference) (r - med).abs()]);
      if (meanAbs == 0) return null;
      return (x - med) / (1.253314 * meanAbs);
    }
    return 0.6745 * (x - med) / mad;
  }

  /// Pearson korelasyon katsayısı (-1..1).
  static double? pearson(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n < 4 || ys.length != n) return null;
    final mx = mean(xs), my = mean(ys);
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (xs[i] - mx) * (ys[i] - my);
      sxx += (xs[i] - mx) * (xs[i] - mx);
      syy += (ys[i] - my) * (ys[i] - my);
    }
    if (sxx == 0 || syy == 0) return null;
    return sxy / math.sqrt(sxx * syy);
  }

  /// Türkçe ondalık gösterim (virgül).
  static String fmt(double v, [int digits = 1]) =>
      v.toStringAsFixed(digits).replaceAll('.', ',');

  static String signed(double v, [int digits = 1]) =>
      '${v > 0 ? '+' : v < 0 ? '−' : ''}${fmt(v.abs(), digits)}';
}
