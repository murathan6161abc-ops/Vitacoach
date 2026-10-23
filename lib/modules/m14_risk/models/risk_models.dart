import 'dart:math' as math;

/// Risk düzeyi.
enum RiskLevel { low, slightlyElevated, moderate, high, veryHigh }

extension RiskLevelLabel on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Düşük';
      case RiskLevel.slightlyElevated:
        return 'Hafif yüksek';
      case RiskLevel.moderate:
        return 'Orta';
      case RiskLevel.high:
        return 'Yüksek';
      case RiskLevel.veryHigh:
        return 'Çok yüksek';
    }
  }
}

/// Aile öyküsü (FINDRISC 8. soru).
enum FamilyDiabetesHistory { none, secondDegree, firstDegree }

/// FINDRISC — Finlandiya Diyabet Risk Skoru.
///
/// Kaynak: Lindström J, Tuomilehto J. The Diabetes Risk Score: a practical
/// tool to predict type 2 diabetes risk. Diabetes Care. 2003;26(3):725-31.
/// 8 sorudan oluşur, 0-26 puan; 10 yıllık Tip-2 diyabet riskini tahmin eder.
class FindriscInput {
  final int age;
  final double bmi;
  final double waistCm;
  final bool isMale;
  final bool activeDaily30Min;
  final bool eatsVegFruitDaily;
  final bool takesBpMedication;
  final bool hadHighBloodGlucose;
  final FamilyDiabetesHistory familyHistory;

  const FindriscInput({
    required this.age,
    required this.bmi,
    required this.waistCm,
    required this.isMale,
    required this.activeDaily30Min,
    required this.eatsVegFruitDaily,
    required this.takesBpMedication,
    required this.hadHighBloodGlucose,
    required this.familyHistory,
  });
}

class FindriscResult {
  final int score;
  final Map<String, int> breakdown;

  const FindriscResult(this.score, this.breakdown);

  RiskLevel get level {
    if (score < 7) return RiskLevel.low;
    if (score <= 11) return RiskLevel.slightlyElevated;
    if (score <= 14) return RiskLevel.moderate;
    if (score <= 20) return RiskLevel.high;
    return RiskLevel.veryHigh;
  }

  /// Orijinal çalışmadaki 10 yıllık tahmini risk.
  String get estimatedRisk {
    switch (level) {
      case RiskLevel.low:
        return '100 kişide yaklaşık 1';
      case RiskLevel.slightlyElevated:
        return '25 kişide yaklaşık 1';
      case RiskLevel.moderate:
        return '6 kişide yaklaşık 1';
      case RiskLevel.high:
        return '3 kişide yaklaşık 1';
      case RiskLevel.veryHigh:
        return '2 kişide yaklaşık 1';
    }
  }

  String get advice {
    switch (level) {
      case RiskLevel.low:
      case RiskLevel.slightlyElevated:
        return 'Sağlıklı beslenme ve düzenli hareketle riskinizi düşük tutabilirsiniz.';
      case RiskLevel.moderate:
        return 'Yaşam tarzı değişiklikleri önerilir. Aile hekiminizle açlık kan şekeri '
            'ölçümünü konuşabilirsiniz.';
      case RiskLevel.high:
      case RiskLevel.veryHigh:
        return 'Diyabet açısından değerlendirilmek için aile hekiminize başvurmanız '
            'önerilir (açlık kan şekeri / HbA1c).';
    }
  }
}

class FindriscCalculator {
  FindriscCalculator._();

  static FindriscResult calculate(FindriscInput i) {
    final parts = <String, int>{};

    parts['Yaş'] = i.age < 45
        ? 0
        : i.age <= 54
        ? 2
        : i.age <= 64
        ? 3
        : 4;

    parts['Vücut kitle indeksi'] = i.bmi < 25
        ? 0
        : i.bmi <= 30
        ? 1
        : 3;

    if (i.isMale) {
      parts['Bel çevresi'] = i.waistCm < 94
          ? 0
          : i.waistCm <= 102
          ? 3
          : 4;
    } else {
      parts['Bel çevresi'] = i.waistCm < 80
          ? 0
          : i.waistCm <= 88
          ? 3
          : 4;
    }

    parts['Fiziksel aktivite'] = i.activeDaily30Min ? 0 : 2;
    parts['Sebze/meyve tüketimi'] = i.eatsVegFruitDaily ? 0 : 1;
    parts['Tansiyon ilacı'] = i.takesBpMedication ? 2 : 0;
    parts['Yüksek kan şekeri öyküsü'] = i.hadHighBloodGlucose ? 5 : 0;
    parts['Ailede diyabet'] = switch (i.familyHistory) {
      FamilyDiabetesHistory.none => 0,
      FamilyDiabetesHistory.secondDegree => 3,
      FamilyDiabetesHistory.firstDegree => 5,
    };

    final total = parts.values.fold(0, (a, b) => a + b);
    return FindriscResult(total, parts);
  }
}

/// Framingham genel kardiyovasküler hastalık riski — laboratuvar
/// gerektirmeyen (BMI tabanlı) model.
///
/// Kaynak: D'Agostino RB Sr, et al. General cardiovascular risk profile for
/// use in primary care: the Framingham Heart Study. Circulation.
/// 2008;117(6):743-53. 30-74 yaş aralığında, 10 yıllık KVH olayı riskini
/// verir.
class FraminghamInput {
  final int age;
  final bool isMale;
  final double bmi;
  final double systolicBp;
  final bool bpTreated;
  final bool smoker;
  final bool diabetic;

  const FraminghamInput({
    required this.age,
    required this.isMale,
    required this.bmi,
    required this.systolicBp,
    required this.bpTreated,
    required this.smoker,
    required this.diabetic,
  });
}

class FraminghamResult {
  /// 0-1 arası 10 yıllık risk.
  final double risk;

  /// Aynı riske sahip, risk faktörleri ideal düzeydeki bir kişinin yaşı.
  final int vascularAge;

  const FraminghamResult(this.risk, this.vascularAge);

  double get percent => risk * 100;

  RiskLevel get level {
    if (percent < 10) return RiskLevel.low;
    if (percent < 20) return RiskLevel.moderate;
    return RiskLevel.high;
  }

  String get advice {
    switch (level) {
      case RiskLevel.low:
      case RiskLevel.slightlyElevated:
        return 'Riskiniz düşük. Sigara kullanmamak, hareketli yaşam ve düzenli '
            'tansiyon takibiyle koruyabilirsiniz.';
      case RiskLevel.moderate:
        return 'Orta risk. Kolesterol ölçümü dahil ayrıntılı değerlendirme için '
            'aile hekiminize başvurmanız önerilir.';
      case RiskLevel.high:
      case RiskLevel.veryHigh:
        return 'Yüksek risk. Bir hekim tarafından değerlendirilmeniz önerilir; '
            'tansiyon, kolesterol ve sigara kontrolü öncelikli olmalıdır.';
    }
  }
}

class FraminghamCalculator {
  FraminghamCalculator._();

  static const int minAge = 30;
  static const int maxAge = 74;

  // Katsayılar: D'Agostino 2008, Tablo 2 (BMI tabanlı model).
  static const _male = _Coefficients(
    age: 3.11296,
    bmi: 0.79277,
    sbpUntreated: 1.85508,
    sbpTreated: 1.92672,
    smoker: 0.70953,
    diabetes: 0.53160,
    baselineSurvival: 0.88431,
    meanSum: 23.9388,
  );
  static const _female = _Coefficients(
    age: 2.72107,
    bmi: 0.51125,
    sbpUntreated: 2.81291,
    sbpTreated: 2.88267,
    smoker: 0.61868,
    diabetes: 0.77763,
    baselineSurvival: 0.94833,
    meanSum: 26.0145,
  );

  static bool isAgeSupported(int age) => age >= minAge && age <= maxAge;

  static FraminghamResult calculate(FraminghamInput i) {
    final c = i.isMale ? _male : _female;
    final sum = _sum(
      c,
      age: i.age.toDouble(),
      bmi: i.bmi,
      sbp: i.systolicBp,
      treated: i.bpTreated,
      smoker: i.smoker,
      diabetic: i.diabetic,
    );
    final risk = _risk(c, sum);

    // Damar yaşı: ideal faktörlerle (BMI 22.5, tedavisiz SKB 125, sigara ve
    // diyabet yok) aynı toplamı veren yaş.
    final optimalRest = c.bmi * math.log(22.5) + c.sbpUntreated * math.log(125);
    final vascularAge = math.exp((sum - optimalRest) / c.age);

    return FraminghamResult(
      risk.clamp(0.0, 0.99),
      vascularAge.isFinite ? vascularAge.round().clamp(20, 100) : i.age,
    );
  }

  static double _sum(
    _Coefficients c, {
    required double age,
    required double bmi,
    required double sbp,
    required bool treated,
    required bool smoker,
    required bool diabetic,
  }) {
    return c.age * math.log(age) +
        c.bmi * math.log(bmi) +
        (treated ? c.sbpTreated : c.sbpUntreated) * math.log(sbp) +
        (smoker ? c.smoker : 0) +
        (diabetic ? c.diabetes : 0);
  }

  static double _risk(_Coefficients c, double sum) {
    return 1 -
        math.pow(c.baselineSurvival, math.exp(sum - c.meanSum)).toDouble();
  }
}

class _Coefficients {
  final double age;
  final double bmi;
  final double sbpUntreated;
  final double sbpTreated;
  final double smoker;
  final double diabetes;
  final double baselineSurvival;
  final double meanSum;

  const _Coefficients({
    required this.age,
    required this.bmi,
    required this.sbpUntreated,
    required this.sbpTreated,
    required this.smoker,
    required this.diabetes,
    required this.baselineSurvival,
    required this.meanSum,
  });
}
