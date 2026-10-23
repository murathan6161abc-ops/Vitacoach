/// Kan şekeri ölçüm zamanı. Aynı değer açlıkta yüksek, yemekten sonra
/// normal olabilir; önceden her ölçüm açlık sayılıyordu ve tokluktaki
/// normal bir 140 mg/dL "çok yüksek" görünüyordu.
enum SugarTiming {
  fasting('Açlık'),
  postMeal('Tokluk (yemekten 2 saat sonra)'),
  random('Rastgele');

  final String label;
  const SugarTiming(this.label);

  static SugarTiming? parse(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

enum SugarLevel { severeLow, low, normal, elevated, high, veryHigh }

class SugarAssessment {
  final SugarLevel level;
  final String label;

  const SugarAssessment(this.level, this.label);

  bool get isLow => level == SugarLevel.low || level == SugarLevel.severeLow;
}

/// mg/dL değerini ölçüm zamanına göre değerlendirir. Tanı koymaz; zamanı
/// bilinmeyen eski kayıtlar açlık sayılır (önceki davranış).
SugarAssessment assessBloodSugar(double mgdl, SugarTiming? timing) {
  if (mgdl < 54) {
    return const SugarAssessment(
      SugarLevel.severeLow,
      'Ciddi düşük (hipoglisemi)',
    );
  }
  if (mgdl < 70) {
    return const SugarAssessment(SugarLevel.low, 'Düşük (hipoglisemi)');
  }
  if (mgdl >= 300) {
    return const SugarAssessment(
      SugarLevel.veryHigh,
      'Çok yüksek; doktorunuza hemen ulaşın',
    );
  }
  switch (timing ?? SugarTiming.fasting) {
    case SugarTiming.fasting:
      if (mgdl < 100) {
        return const SugarAssessment(SugarLevel.normal, 'Açlıkta normal');
      }
      if (mgdl < 126) {
        return const SugarAssessment(
          SugarLevel.elevated,
          'Açlıkta sınırda yüksek',
        );
      }
      return const SugarAssessment(SugarLevel.high, 'Açlıkta yüksek');
    case SugarTiming.postMeal:
      if (mgdl < 140) {
        return const SugarAssessment(SugarLevel.normal, 'Toklukta normal');
      }
      if (mgdl < 200) {
        return const SugarAssessment(SugarLevel.elevated, 'Toklukta yüksek');
      }
      return const SugarAssessment(SugarLevel.high, 'Toklukta çok yüksek');
    case SugarTiming.random:
      if (mgdl < 140) {
        return const SugarAssessment(SugarLevel.normal, 'Normal aralık');
      }
      if (mgdl < 200) {
        return const SugarAssessment(SugarLevel.elevated, 'Yüksek aralık');
      }
      return const SugarAssessment(
        SugarLevel.high,
        'Yüksek; hekiminize danışın',
      );
  }
}
