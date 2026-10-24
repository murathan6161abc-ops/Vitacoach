import '../../../core/constants/app_constants.dart';
import '../../m03_chronic/models/blood_sugar.dart';
import '../../m03_chronic/models/health_entry.dart';
import '../../m03_chronic/models/medication_adherence.dart';
import '../../m15_sleep/models/sleep_entry.dart';
import '../../m19_heart/models/heart_measurement.dart';
import '../../m19_heart/services/ppg_processor.dart';
import 'trend_math.dart';

enum InsightSeverity { alert, warning, info, positive }

extension InsightSeverityLabel on InsightSeverity {
  String get label => switch (this) {
    InsightSeverity.alert => 'Acil',
    InsightSeverity.warning => 'Dikkat',
    InsightSeverity.info => 'Bilgi',
    InsightSeverity.positive => 'Olumlu',
  };
}

/// Açıklanabilir bir sağlık bulgusu: ne bulundu, neden, hangi yöntemle.
class HealthInsight {
  final String id;
  final InsightSeverity severity;
  final String category;
  final String title;
  final String message;
  final String? suggestion;

  /// "Neden bu sonuç?" altında gösterilen sayısal kanıtlar.
  final List<String> evidence;
  final String method;
  final String? route;

  const HealthInsight({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.message,
    required this.evidence,
    required this.method,
    this.suggestion,
    this.route,
  });
}

/// Analizin girdileri; uygulamada Hive'dan, testte doğrudan oluşturulur.
class InsightInput {
  final DateTime now;
  final List<BloodPressureEntry> pressures;
  final List<HealthEntry> sugars;
  final List<HealthEntry> weights;
  final List<SleepEntry> sleep;
  final Map<String, int> moodByDay;
  final Map<String, int> stepsByDay;
  final AdherenceReport? adherence;
  final List<HeartMeasurement> heart;
  final List<String> goals;

  const InsightInput({
    required this.now,
    this.pressures = const [],
    this.sugars = const [],
    this.weights = const [],
    this.sleep = const [],
    this.moodByDay = const {},
    this.stepsByDay = const {},
    this.adherence,
    this.heart = const [],
    this.goals = const [],
  });
}

/// Kural + istatistik tabanlı, tamamen cihaz içinde çalışan analiz motoru.
class InsightEngine {
  InsightEngine._();

  static const String _regression =
      'Doğrusal regresyon (en küçük kareler); eğilim, R² ≥ 0,3 ve haftalık '
      'değişim eşiği aşıldığında raporlanır.';
  static const String _robustZ =
      'Değiştirilmiş z-skoru (Iglewicz & Hoaglin, 1993): son ölçüm, önceki '
      'ölçümlerin ortanca ve ortanca mutlak sapmasıyla karşılaştırılır; '
      '|z| ≥ 3,5 olağandışı kabul edilir.';
  static const String _groups =
      'Grup ortalamaları karşılaştırması ve Pearson korelasyonu. İlişki '
      'nedensellik göstermez.';

  static List<HealthInsight> analyze(InsightInput input) {
    final out = <HealthInsight>[
      ..._bloodPressure(input),
      ..._sugar(input),
      ..._weight(input),
      ..._sleepMood(input),
      ..._stepsMood(input),
      ..._adherence(input),
      ..._heart(input),
    ];
    out.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return out;
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  /// Çok büyük z değerleri (ör. neredeyse sabit geçmiş) anlamlı değildir.
  static String _z(double z) => z.abs() > 20
      ? (z > 0 ? 'z > 20' : 'z < −20')
      : 'z = ${TrendMath.fmt(z, 1)}';

  static double _days(DateTime from, DateTime to) =>
      to.difference(from).inMinutes / (60 * 24);

  // ---------------------------------------------------------------- Tansiyon
  static List<HealthInsight> _bloodPressure(InsightInput input) {
    final list =
        input.pressures
            .where(
              (p) =>
                  input.now.difference(p.date).inDays <= 30 && p.systolic > 0,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (list.isEmpty) return const [];
    final out = <HealthInsight>[];
    final last = list.last;
    final recent = input.now.difference(last.date).inDays <= 3;

    if (recent && (last.systolic >= 180 || last.diastolic >= 120)) {
      out.add(
        HealthInsight(
          id: 'bp_crisis',
          severity: InsightSeverity.alert,
          category: 'Tansiyon',
          title: 'Tansiyon kriz aralığında',
          message:
              'Son ölçümünüz ${last.display}. Şiddetli baş ağrısı, göğüs ağrısı, '
              'nefes darlığı, görme bozukluğu veya konuşma güçlüğü varsa hemen '
              "112'yi arayın.",
          suggestion:
              'Belirti yoksa 5 dakika oturarak dinlenip tekrar ölçün ve aynı gün '
              'doktorunuza ulaşın.',
          evidence: ['Son ölçüm: ${_d(last.date)} — ${last.display}'],
          method: 'Klinik eşik: ≥180/120 mmHg (hipertansif kriz).',
          route: AppConstants.routeSos,
        ),
      );
    } else if (recent && last.systolic < 90) {
      out.add(
        HealthInsight(
          id: 'bp_low',
          severity: InsightSeverity.warning,
          category: 'Tansiyon',
          title: 'Tansiyon düşük',
          message:
              'Son ölçümünüz ${last.display}; büyük tansiyon 90 mmHg altında.',
          suggestion:
              'Baş dönmesi, bayılma hissi varsa oturun/uzanın, sıvı alın ve '
              'tansiyon ilacı kullanıyorsanız doktorunuza danışın.',
          evidence: ['Son ölçüm: ${_d(last.date)} — ${last.display}'],
          method: 'Klinik eşik: büyük tansiyon < 90 mmHg.',
          route: AppConstants.routeChronic,
        ),
      );
    }

    // Eğilim ve tahmin (son 14 gün)
    final window = list
        .where((p) => input.now.difference(p.date).inDays <= 14)
        .toList();
    if (window.length >= 5 && _days(window.first.date, window.last.date) >= 4) {
      final t0 = window.first.date;
      final xs = [for (final p in window) _days(t0, p.date)];
      final fit = TrendMath.fit(xs, [for (final p in window) p.systolic]);
      if (fit != null) {
        final weekly = fit.slope * 7;
        final meanSys = TrendMath.mean([for (final p in window) p.systolic]);
        final meanDia = TrendMath.mean([for (final p in window) p.diastolic]);
        final evidence = [
          '${window.length} ölçüm, ${_d(window.first.date)}–${_d(window.last.date)}',
          'Eğim: ${TrendMath.signed(fit.slope, 2)} mmHg/gün · R² = ${TrendMath.fmt(fit.r2, 2)}',
          'Ortalama: ${meanSys.round()}/${meanDia.round()} mmHg',
        ];
        if (fit.r2 >= 0.3 && weekly >= 3) {
          final nowX = _days(t0, input.now);
          final fittedNow = fit.predict(nowX);
          final forecast = fit.predict(nowX + 7);
          var message =
              'Son 14 günde büyük tansiyonunuz haftada ortalama '
              '${TrendMath.signed(weekly)} mmHg artıyor. 7 gün sonrası tahmini: '
              '${forecast.round()} mmHg.';
          if (fittedNow < 140 && fit.slope > 0) {
            final daysTo140 = (140 - fittedNow) / fit.slope;
            if (daysTo140 <= 14) {
              message +=
                  ' Bu eğilim sürerse yaklaşık ${daysTo140.ceil()} gün içinde '
                  '140 mmHg eşiğini aşabilir.';
            }
          }
          final adherence = input.adherence?.percent;
          out.add(
            HealthInsight(
              id: 'bp_rising',
              severity: InsightSeverity.warning,
              category: 'Tansiyon',
              title: 'Tansiyon yükseliş eğiliminde',
              message: message,
              suggestion:
                  'Tuzu azaltın, ölçümleri her gün aynı saatte yapın; artış '
                  'sürerse doktorunuza danışın.'
                  '${adherence != null && adherence < 80 ? ' İlaç uyumunuz %$adherence; dozları düzenli almak tansiyonu doğrudan etkiler.' : ''}',
              evidence: [
                ...evidence,
                '7 günlük tahmin: ${forecast.round()} mmHg',
              ],
              method: _regression,
              route: AppConstants.routeChronic,
            ),
          );
        } else if (fit.r2 >= 0.3 && weekly <= -3) {
          out.add(
            HealthInsight(
              id: 'bp_falling',
              severity: InsightSeverity.positive,
              category: 'Tansiyon',
              title: 'Tansiyonunuz düşüş eğiliminde',
              message:
                  'Son 14 günde büyük tansiyonunuz haftada ortalama '
                  '${TrendMath.signed(weekly)} mmHg azaldı. Tedaviniz ve yaşam '
                  'tarzı değişiklikleriniz işe yarıyor görünüyor.',
              evidence: evidence,
              method: _regression,
              route: AppConstants.routeChronic,
            ),
          );
        } else if (meanSys >= 135 || meanDia >= 85) {
          out.add(
            HealthInsight(
              id: 'bp_home_high',
              severity: InsightSeverity.info,
              category: 'Tansiyon',
              title: 'Ev ölçümü ortalamanız hedefin üzerinde',
              message:
                  'Son 14 günün ortalaması ${meanSys.round()}/${meanDia.round()} '
                  'mmHg. Evde ölçülen tansiyon için hedef genellikle 135/85 '
                  "mmHg'nin altıdır.",
              suggestion: 'Bu ortalamayı doktor kontrolünüzde paylaşın.',
              evidence: evidence,
              method: 'Ev ölçümü eşiği: ≥135/85 mmHg (ESH kılavuzu).',
              route: AppConstants.routeChronic,
            ),
          );
        }
      }
    }

    // Olağandışı son ölçüm
    if (recent && list.length >= 8) {
      final reference = [
        for (final p in list.sublist(0, list.length - 1)) p.systolic,
      ];
      final z = TrendMath.modifiedZ(last.systolic, reference);
      if (z != null && z.abs() >= 3.5 && !out.any((i) => i.id == 'bp_crisis')) {
        final med = TrendMath.median(reference);
        out.add(
          HealthInsight(
            id: 'bp_anomaly',
            severity: InsightSeverity.warning,
            category: 'Tansiyon',
            title: 'Olağandışı tansiyon ölçümü',
            message:
                'Son ölçümünüz (${last.display}) kişisel normalinizden belirgin '
                '${z > 0 ? 'yüksek' : 'düşük'} (sizin için tipik değer ≈ '
                '${med.round()} mmHg).',
            suggestion:
                'Ölçüm hatası olabilir: 5 dakika dinlenip, kol kalp hizasında '
                'olacak şekilde tekrar ölçün.',
            evidence: [
              'Karşılaştırılan ölçüm sayısı: ${reference.length}',
              'Ortanca: ${med.round()} mmHg · ${_z(z)}',
            ],
            method: _robustZ,
            route: AppConstants.routeChronic,
          ),
        );
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- Şeker
  static List<HealthInsight> _sugar(InsightInput input) {
    final list =
        input.sugars
            .where(
              (s) => input.now.difference(s.date).inDays <= 30 && s.value > 0,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (list.isEmpty) return const [];
    final out = <HealthInsight>[];
    final last = list.last;
    final recent = input.now.difference(last.date).inDays <= 3;
    final v = last.value.round();

    if (recent && last.value < 70) {
      out.add(
        HealthInsight(
          id: 'sugar_low',
          severity: InsightSeverity.alert,
          category: 'Kan şekeri',
          title: 'Kan şekeri düşük (hipoglisemi)',
          message:
              'Son ölçümünüz $v mg/dL. Bilinç bulanıklığı veya bayılma varsa '
              "112'yi arayın.",
          suggestion:
              '15-15 kuralı: 15 g hızlı şeker alın (yarım bardak meyve suyu), '
              '15 dakika sonra tekrar ölçün.',
          evidence: ['Son ölçüm: ${_d(last.date)} — $v mg/dL'],
          method: 'Klinik eşik: < 70 mg/dL (ADA).',
          route: AppConstants.routeChronic,
        ),
      );
    } else if (recent && last.value >= 250) {
      out.add(
        HealthInsight(
          id: 'sugar_very_high',
          severity: InsightSeverity.alert,
          category: 'Kan şekeri',
          title: 'Kan şekeri çok yüksek',
          message:
              'Son ölçümünüz $v mg/dL. Kusma, karın ağrısı, nefeste aseton kokusu '
              "veya bilinç değişikliği varsa 112'yi arayın.",
          suggestion: 'Bol su için ve aynı gün doktorunuza ulaşın.',
          evidence: ['Son ölçüm: ${_d(last.date)} — $v mg/dL'],
          method: 'Klinik eşik: ≥ 250 mg/dL.',
          route: AppConstants.routeChronic,
        ),
      );
    }

    if (recent && list.length >= 7) {
      final reference = [
        for (final s in list.sublist(0, list.length - 1)) s.value,
      ];
      final z = TrendMath.modifiedZ(last.value, reference);
      if (z != null && z.abs() >= 3.5 && out.isEmpty) {
        final med = TrendMath.median(reference);
        out.add(
          HealthInsight(
            id: 'sugar_anomaly',
            severity: InsightSeverity.warning,
            category: 'Kan şekeri',
            title: 'Olağandışı kan şekeri ölçümü',
            message:
                '${_d(last.date)} tarihli ölçümünüz ($v mg/dL) kişisel normalinizin '
                '(≈ ${med.round()} mg/dL) belirgin ${z > 0 ? 'üzerinde' : 'altında'}.',
            suggestion:
                'Öncesinde ne yediğinizi, ilacınızı ve ölçümün açlıkta yapılıp '
                'yapılmadığını kontrol edin; tekrarlarsa doktorunuza danışın.',
            evidence: [
              'Karşılaştırılan ölçüm sayısı: ${reference.length}',
              'Ortanca: ${med.round()} mg/dL · ${_z(z)}',
            ],
            method: _robustZ,
            route: AppConstants.routeChronic,
          ),
        );
      }
    }

    // Ortalama açlık eşikleriyle karşılaştırılır; tokluk ve rastgele
    // ölçümler dahil edilirse normal tokluk değerleri yanlışlıkla
    // "açlık şekeri yüksek" uyarısı üretir. Zamanı bilinmeyen eski
    // kayıtlar açlık sayılır.
    final window = list
        .where(
          (s) =>
              input.now.difference(s.date).inDays <= 14 &&
              (s.timing == null || s.timing == SugarTiming.fasting.name),
        )
        .toList();
    if (window.length >= 3) {
      final avg = TrendMath.mean([for (final s in window) s.value]);
      final evidence = [
        '${window.length} ölçüm (son 14 gün)',
        'Ortalama: ${avg.round()} mg/dL',
      ];
      if (avg >= 126) {
        out.add(
          HealthInsight(
            id: 'sugar_avg_diabetes',
            severity: InsightSeverity.warning,
            category: 'Kan şekeri',
            title: 'Açlık şekeri ortalaması yüksek',
            message:
                'Son 14 günün ortalaması ${avg.round()} mg/dL; açlık ölçümünde '
                '126 mg/dL ve üzeri diyabet aralığıdır.',
            suggestion: 'HbA1c testi için doktorunuza başvurun.',
            evidence: evidence,
            method: 'ADA ölçütü: açlık kan şekeri ≥ 126 mg/dL.',
            route: AppConstants.routeRisk,
          ),
        );
      } else if (avg >= 100) {
        out.add(
          HealthInsight(
            id: 'sugar_avg_prediabetes',
            severity: InsightSeverity.info,
            category: 'Kan şekeri',
            title: 'Açlık şekeri prediyabet aralığında',
            message:
                'Son 14 günün ortalaması ${avg.round()} mg/dL (100-125 mg/dL). '
                'Bu aralık, yaşam tarzı değişiklikleriyle geri döndürülebilir.',
            suggestion:
                'Haftada 150 dakika yürüyüş ve %5-7 kilo kaybı diyabet riskini '
                'yaklaşık %58 azaltır (DPP çalışması). Risk Analizi ekranından '
                'FINDRISC skorunuzu hesaplayabilirsiniz.',
            evidence: evidence,
            method: 'ADA ölçütü: açlık kan şekeri 100-125 mg/dL.',
            route: AppConstants.routeRisk,
          ),
        );
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- Kilo
  static List<HealthInsight> _weight(InsightInput input) {
    final list =
        input.weights
            .where(
              (w) => input.now.difference(w.date).inDays <= 45 && w.value > 0,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 2) return const [];
    final first = list.first, last = list.last;
    final days = _days(first.date, last.date);
    if (days < 14) return const [];
    final change = last.value - first.value;
    final pct = change / first.value * 100;
    final perWeek = change / days * 7;
    final wantsLoss = input.goals.any(
      (g) => g.toLowerCase().contains('kilo ver'),
    );
    final evidence = [
      '${_d(first.date)}: ${TrendMath.fmt(first.value)} kg → '
          '${_d(last.date)}: ${TrendMath.fmt(last.value)} kg',
      'Değişim: ${TrendMath.signed(change)} kg (${TrendMath.signed(pct)}%) · '
          'haftalık ${TrendMath.signed(perWeek, 2)} kg',
    ];
    const method =
        'Dönem başı ve sonu karşılaştırması; sağlıklı kilo kaybı hızı haftada '
        '0,5-1 kg kabul edilir.';

    if (pct <= -5 && !wantsLoss) {
      return [
        HealthInsight(
          id: 'weight_unintended_loss',
          severity: InsightSeverity.warning,
          category: 'Kilo',
          title: 'Belirgin kilo kaybı',
          message:
              '${days.round()} günde vücut ağırlığınızın %${TrendMath.fmt(-pct)} '
              'kadarını kaybettiniz ve kilo verme hedefiniz yok.',
          suggestion:
              'İstemsiz kilo kaybı bir sağlık sorununun işareti olabilir; '
              'doktorunuza danışın.',
          evidence: evidence,
          method: method,
          route: AppConstants.routeProfile,
        ),
      ];
    }
    if (wantsLoss && change < 0) {
      final tooFast = perWeek < -1;
      return [
        HealthInsight(
          id: 'weight_goal',
          severity: tooFast ? InsightSeverity.info : InsightSeverity.positive,
          category: 'Kilo',
          title: tooFast ? 'Kilo kaybınız hızlı' : 'Kilo hedefiniz yolunda',
          message: tooFast
              ? 'Haftada ${TrendMath.fmt(-perWeek)} kg veriyorsunuz; bu önerilen '
                    'hızdan fazla ve kas kaybına yol açabilir.'
              : '${days.round()} günde ${TrendMath.fmt(-change)} kg verdiniz '
                    '(haftada ${TrendMath.fmt(-perWeek, 2)} kg). Sağlıklı ve '
                    'sürdürülebilir bir hız.',
          evidence: evidence,
          method: method,
          route: AppConstants.routeProfile,
        ),
      ];
    }
    if (pct >= 3) {
      return [
        HealthInsight(
          id: 'weight_gain',
          severity: InsightSeverity.info,
          category: 'Kilo',
          title: 'Kilo artışı',
          message:
              '${days.round()} günde ${TrendMath.fmt(change)} kg aldınız '
              '(%${TrendMath.fmt(pct)}).',
          suggestion:
              'Ani kilo artışı ile birlikte bacaklarda şişlik veya nefes darlığı '
              'varsa doktorunuza danışın.',
          evidence: evidence,
          method: method,
          route: AppConstants.routeProfile,
        ),
      ];
    }
    return const [];
  }

  // ---------------------------------------------------------------- Uyku ↔ ruh hali
  static List<HealthInsight> _sleepMood(InsightInput input) {
    final out = <HealthInsight>[];
    final lastWeek = input.sleep
        .where((s) => input.now.difference(s.wakeTime).inDays < 7)
        .toList();
    if (lastWeek.length >= 4) {
      final avg = TrendMath.mean([for (final s in lastWeek) s.hours]);
      if (avg < 6) {
        out.add(
          HealthInsight(
            id: 'sleep_short',
            severity: InsightSeverity.warning,
            category: 'Uyku',
            title: 'Uyku süreniz kısa',
            message:
                'Son ${lastWeek.length} gecenin ortalaması ${TrendMath.fmt(avg)} '
                'saat. Yetişkinler için önerilen süre 7-9 saattir.',
            suggestion:
                'Yatış saatinizi 15 dakika erkene çekerek başlayın; yatmadan 1 '
                'saat önce ekranı bırakın.',
            evidence: [
              'Ortalama: ${TrendMath.fmt(avg)} saat (${lastWeek.length} gece)',
            ],
            method: 'NSF önerisi: yetişkinler için 7-9 saat.',
            route: AppConstants.routeSleep,
          ),
        );
      }
    }

    final pairs = <(double, double)>[];
    for (final s in input.sleep) {
      final mood = input.moodByDay[s.dayKey];
      if (mood != null && input.now.difference(s.wakeTime).inDays <= 30) {
        pairs.add((s.hours, mood.toDouble()));
      }
    }
    final short = [
      for (final p in pairs)
        if (p.$1 < 7) p.$2,
    ];
    final enough = [
      for (final p in pairs)
        if (p.$1 >= 7) p.$2,
    ];
    if (pairs.length >= 6 && short.length >= 3 && enough.length >= 3) {
      final diff = TrendMath.mean(enough) - TrendMath.mean(short);
      final r = TrendMath.pearson(
        [for (final p in pairs) p.$1],
        [for (final p in pairs) p.$2],
      );
      if (diff >= 0.5) {
        out.add(
          HealthInsight(
            id: 'sleep_mood',
            severity: InsightSeverity.info,
            category: 'Uyku ve ruh hali',
            title: 'Uykunuz ruh halinizi etkiliyor',
            message:
                '7 saatten az uyuduğunuz günlerde ruh haliniz ortalama '
                '${TrendMath.fmt(diff)} puan (5 üzerinden) daha düşük.',
            suggestion:
                'Düzenli uyku, sizin verilerinizde ruh halinizi iyileştiren en '
                'belirgin etken görünüyor.',
            evidence: [
              '<7 saat: ${short.length} gün, ortalama ruh hali ${TrendMath.fmt(TrendMath.mean(short))}',
              '≥7 saat: ${enough.length} gün, ortalama ruh hali ${TrendMath.fmt(TrendMath.mean(enough))}',
              if (r != null)
                'Korelasyon (uyku süresi ↔ ruh hali): r = ${TrendMath.fmt(r, 2)}',
            ],
            method: _groups,
            route: AppConstants.routeSleep,
          ),
        );
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- Adım ↔ ruh hali
  static List<HealthInsight> _stepsMood(InsightInput input) {
    final pairs = <(double, double)>[];
    input.stepsByDay.forEach((day, steps) {
      final mood = input.moodByDay[day];
      final date = DateTime.tryParse(day);
      if (mood != null &&
          date != null &&
          input.now.difference(date).inDays <= 30) {
        pairs.add((steps.toDouble(), mood.toDouble()));
      }
    });
    final active = [
      for (final p in pairs)
        if (p.$1 >= 7000) p.$2,
    ];
    final passive = [
      for (final p in pairs)
        if (p.$1 < 7000) p.$2,
    ];
    if (pairs.length < 5 || active.length < 2 || passive.length < 2) {
      return const [];
    }
    final diff = TrendMath.mean(active) - TrendMath.mean(passive);
    if (diff < 0.5) return const [];
    final r = TrendMath.pearson(
      [for (final p in pairs) p.$1],
      [for (final p in pairs) p.$2],
    );
    return [
      HealthInsight(
        id: 'steps_mood',
        severity: InsightSeverity.info,
        category: 'Hareket ve ruh hali',
        title: 'Yürüdüğünüz günler daha iyi hissediyorsunuz',
        message:
            '7.000 adımı geçtiğiniz günlerde ruh haliniz ortalama '
            '${TrendMath.fmt(diff)} puan daha yüksek.',
        suggestion:
            'Kötü hissettiğiniz günlerde 15 dakikalık kısa bir yürüyüş deneyin.',
        evidence: [
          '≥7.000 adım: ${active.length} gün, ruh hali ${TrendMath.fmt(TrendMath.mean(active))}',
          '<7.000 adım: ${passive.length} gün, ruh hali ${TrendMath.fmt(TrendMath.mean(passive))}',
          if (r != null)
            'Korelasyon (adım ↔ ruh hali): r = ${TrendMath.fmt(r, 2)}',
        ],
        method: _groups,
        route: AppConstants.routeFitness,
      ),
    ];
  }

  // ---------------------------------------------------------------- İlaç uyumu
  static List<HealthInsight> _adherence(InsightInput input) {
    final report = input.adherence;
    final percent = report?.percent;
    if (report == null || percent == null || report.scheduled < 5) {
      return const [];
    }
    final evidence = [
      'Son ${report.days} gün: ${report.taken}/${report.scheduled} doz alındı',
      for (final d in report.perDose)
        if (d.scheduled > 0)
          '${d.medication.name} ${d.dose.timeDisplay}: '
              '${d.taken}/${d.scheduled}',
    ];
    const method =
        'Uyum = alınan doz ÷ planlanan doz. Örüntüler kaçırılan dozların gün ve '
        'saatlerinden çıkarılır.';
    if (percent < 80) {
      final pattern = report.patterns.isEmpty ? null : report.patterns.first;
      return [
        HealthInsight(
          id: 'adherence_low',
          severity: InsightSeverity.warning,
          category: 'İlaç',
          title: 'İlaç uyumunuz %$percent',
          message:
              '${pattern?.message ?? 'Son bir haftada dozların bir kısmı kaçırıldı.'} '
              'Etkili tedavi için hedef en az %80 uyumdur.',
          suggestion:
              pattern?.suggestion ??
              "Bildirimdeki 'Aldım' düğmesini kullanmak takibi kolaylaştırır.",
          evidence: evidence,
          method: method,
          route: AppConstants.routeChronic,
        ),
      ];
    }
    return [
      HealthInsight(
        id: report.patterns.isEmpty ? 'adherence_good' : 'adherence_pattern',
        severity: report.patterns.isEmpty
            ? InsightSeverity.positive
            : InsightSeverity.info,
        category: 'İlaç',
        title: report.patterns.isEmpty
            ? 'İlaç uyumunuz çok iyi (%$percent)'
            : 'İlaç uyumu %$percent — bir örüntü var',
        message: report.patterns.isEmpty
            ? 'Son ${report.days} günde dozlarınızı düzenli aldınız.'
            : report.patterns.first.message,
        suggestion: report.patterns.isEmpty
            ? null
            : report.patterns.first.suggestion,
        evidence: evidence,
        method: method,
        route: AppConstants.routeChronic,
      ),
    ];
  }

  // ---------------------------------------------------------------- Nabız / HRV
  static List<HealthInsight> _heart(InsightInput input) {
    final recent = input.heart
        .where((m) => input.now.difference(m.date).inDays <= 14)
        .toList(); // en yeni başta
    if (recent.isEmpty) return const [];
    final out = <HealthInsight>[];
    final rest = recent.where((m) => !m.afterBreathing).toList();
    if (rest.isNotEmpty) {
      final last = rest.first;
      if (last.bpm > 100 || last.bpm < 50) {
        out.add(
          HealthInsight(
            id: 'hr_range',
            severity: InsightSeverity.info,
            category: 'Nabız',
            title: last.bpm > 100
                ? 'Dinlenik nabız yüksek'
                : 'Dinlenik nabız düşük',
            message:
                'Son kamera ölçümünüz ${last.bpm} atım/dk (normal dinlenik aralık '
                '60-100).',
            suggestion:
                '5 dakika dinlenip tekrar ölçün; tekrarlarsa veya çarpıntı, baş '
                'dönmesi eşlik ederse doktorunuza danışın.',
            evidence: ['${_d(last.date)} — ${last.bpm} atım/dk'],
            method: 'Kamera ile fotopletismografi (PPG).',
            route: AppConstants.routeHeart,
          ),
        );
      }
      final lastThree = rest.take(3).toList();
      final highCount = lastThree
          .where((m) => m.stress == StressLevel.high)
          .length;
      if (lastThree.length >= 2 && highCount >= 2) {
        out.add(
          HealthInsight(
            id: 'hrv_stress',
            severity: InsightSeverity.info,
            category: 'Stres',
            title: 'Stres göstergeleriniz yüksek',
            message:
                'Son ${lastThree.length} ölçümün $highCount tanesinde kalp hızı '
                'değişkenliğiniz düşüktü.',
            suggestion:
                'Günde 1-2 kez 1 dakikalık rezonans nefesi (4 sn al, 6 sn ver) '
                'deneyin ve ardından tekrar ölçün.',
            evidence: [
              for (final m in lastThree)
                '${_d(m.date)}: HRV ${m.rmssdMs.round()} ms (${m.stress.label})',
            ],
            method:
                'RMSSD (ardışık atım aralığı farklarının karekök ortalaması); <20 ms yüksek stres göstergesi.',
            route: AppConstants.routeHeart,
          ),
        );
      }
    }
    // Nefes egzersizinin etkisi
    for (var i = 0; i < recent.length - 1; i++) {
      final after = recent[i], before = recent[i + 1];
      if (after.afterBreathing &&
          !before.afterBreathing &&
          after.date.difference(before.date).inMinutes <= 30 &&
          after.rmssdMs - before.rmssdMs >= 5) {
        out.add(
          HealthInsight(
            id: 'breathing_effect',
            severity: InsightSeverity.positive,
            category: 'Stres',
            title: 'Nefes egzersizi size iyi geliyor',
            message:
                '1 dakikalık nefes egzersizinden sonra kalp hızı değişkenliğiniz '
                '${before.rmssdMs.round()} → ${after.rmssdMs.round()} ms yükseldi.',
            evidence: [
              'Önce: ${before.bpm} atım/dk, HRV ${before.rmssdMs.round()} ms',
              'Sonra: ${after.bpm} atım/dk, HRV ${after.rmssdMs.round()} ms',
            ],
            method:
                'Aynı oturumda (≤30 dk) ölçüm öncesi/sonrası karşılaştırması.',
            route: AppConstants.routeHeart,
          ),
        );
        break;
      }
    }
    return out;
  }
}
