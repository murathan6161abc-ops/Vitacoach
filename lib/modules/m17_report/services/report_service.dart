import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../services/hive_service.dart';
import '../../m01_profile/models/user_profile.dart';
import '../../m03_chronic/models/medication_adherence.dart';
import '../../m18_insights/services/insight_engine.dart';
import '../../m18_insights/services/insight_repository.dart';
import '../../m19_heart/models/heart_measurement.dart';
import '../../m03_chronic/models/health_entry.dart';
import '../../m03_chronic/services/drug_interaction_service.dart';
import '../../m15_sleep/models/sleep_entry.dart';
import '../../m16_emergency/models/emergency_info.dart';

/// Rapora girecek tüm veriler (yalnızca cihazdaki kayıtlardan).
class ReportData {
  final UserProfile profile;
  final EmergencyInfo emergency;
  final List<MedicationReminder> medications;
  final List<InteractionWarning> interactions;
  final List<BloodPressureEntry> pressures;
  final List<HealthEntry> sugars;
  final List<HealthEntry> weights;
  final List<SleepEntry> sleep;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> risks;
  final double? moodAverage14;
  final int moodDays14;
  final double stepAverage7;
  final AdherenceReport? adherence;
  final List<HeartMeasurement> heart;
  final List<HealthInsight> insights;
  final DateTime generatedAt;
  final int periodDays;

  ReportData({
    required this.profile,
    required this.emergency,
    required this.medications,
    required this.interactions,
    required this.pressures,
    required this.sugars,
    required this.weights,
    required this.sleep,
    required this.tests,
    required this.risks,
    required this.moodAverage14,
    required this.moodDays14,
    required this.stepAverage7,
    this.adherence,
    this.heart = const [],
    this.insights = const [],
    required this.generatedAt,
    this.periodDays = 30,
  });

  static List<T> _parse<T>(dynamic raw, T Function(Map<dynamic, dynamic>) f) {
    if (raw is! List) return <T>[];
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(f(item));
      } catch (_) {}
    }
    return out;
  }

  static Future<ReportData> collect({int periodDays = 30}) async {
    final hive = HiveService();
    final profileBox = hive.getProfileBox();
    final healthBox = hive.getHealthBox();
    final now = DateTime.now();
    final since = now.subtract(Duration(days: periodDays));

    final profile = UserProfile.fromMap({
      'name': profileBox.get('name'),
      'birth_date': profileBox.get('birth_date'),
      'gender': profileBox.get('gender'),
      'height': profileBox.get('height'),
      'weight': profileBox.get('weight'),
      'conditions': profileBox.get('conditions'),
      'goals': profileBox.get('goals'),
    });

    final medications = _parse(
      hive.getMedicationBox().get('medications'),
      MedicationReminder.fromMap,
    );
    final checker = await DrugInteractionService().checker;
    final interactions = checker.checkAll(
      medications.map((m) => m.name).toList(),
    );

    bool recent(DateTime d) => d.isAfter(since);
    final pressures =
        _parse(
            healthBox.get('blood_pressure'),
            BloodPressureEntry.fromMap,
          ).where((e) => recent(e.date)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final sugars =
        _parse(
            healthBox.get('blood_sugar'),
            HealthEntry.fromMap,
          ).where((e) => recent(e.date)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final weights =
        _parse(
            healthBox.get('weight_history'),
            HealthEntry.fromMap,
          ).where((e) => recent(e.date)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final sleep = SleepEntry.parseList(healthBox.get('sleep_log'))
        .where((e) => e.wakeTime.isAfter(now.subtract(const Duration(days: 7))))
        .toList();

    final moodBox = hive.getMoodBox();
    var moodSum = 0.0;
    var moodDays = 0;
    for (var i = 0; i < 14; i++) {
      final key = now
          .subtract(Duration(days: i))
          .toIso8601String()
          .substring(0, 10);
      final raw = moodBox.get(key);
      final value = raw is int
          ? raw
          : (raw is Map ? (raw['value'] as num?)?.toInt() : null);
      if (value != null) {
        moodSum += value;
        moodDays++;
      }
    }
    final tests =
        (moodBox.get('test_history') is List
                ? moodBox.get('test_history') as List
                : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
          ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    final risks =
        (healthBox.get('risk_history') is List
                ? healthBox.get('risk_history') as List
                : const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
          ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    final fitnessBox = hive.getFitnessBox();
    var steps = 0;
    for (var i = 0; i < 7; i++) {
      final key = now
          .subtract(Duration(days: i))
          .toIso8601String()
          .substring(0, 10);
      steps += (fitnessBox.get('steps_$key') as num?)?.toInt() ?? 0;
    }

    final insightInput = InsightRepository.load(now: now);

    return ReportData(
      adherence: insightInput.adherence,
      heart: insightInput.heart.where((h) => recent(h.date)).toList(),
      insights: InsightEngine.analyze(insightInput),
      profile: profile,
      emergency: EmergencyInfo.load(),
      medications: medications,
      interactions: interactions,
      pressures: pressures,
      sugars: sugars,
      weights: weights,
      sleep: sleep,
      tests: tests,
      risks: risks,
      moodAverage14: moodDays == 0 ? null : moodSum / moodDays,
      moodDays14: moodDays,
      stepAverage7: steps / 7,
      generatedAt: now,
      periodDays: periodDays,
    );
  }
}

/// Doktora gösterilebilecek PDF raporu üretir. Tamamen cihazda çalışır.
class ReportService {
  ReportService._();

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
  static String _dm(DateTime d) => '${_two(d.day)}.${_two(d.month)}';
  static String _num(num v, [int digits = 0]) =>
      v.toStringAsFixed(digits).replaceAll('.', ',');

  static Future<Uint8List> generate(ReportData data) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final doc = pw.Document(
      title: 'VitaCoach Sağlık Raporu',
      author: 'VitaCoach',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    const green = PdfColor.fromInt(0xFF2A7D4F);

    pw.Widget heading(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: green, width: 1.2)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: green,
        ),
      ),
    );

    pw.Widget muted(String text) => pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
    );

    pw.Widget table(List<String> headers, List<List<String>> rows) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      );
    }

    pw.Widget chart({
      required List<DateTime> dates,
      required List<List<double>> series,
      required List<String> legends,
      required List<PdfColor> colors,
    }) {
      if (dates.length < 2) return pw.SizedBox();
      final all = series.expand((s) => s).toList();
      final lo = (all.reduce(math.min) / 10).floor() * 10 - 10;
      final hi = (all.reduce(math.max) / 10).ceil() * 10 + 10;
      final step = math.max(10, ((hi - lo) / 4 / 10).ceil() * 10);
      final ticks = <int>[for (var v = lo; v <= hi; v += step) v];
      // X ekseninde en fazla 8 etiket göster.
      final every = (dates.length / 8).ceil();
      final labels = [
        for (var i = 0; i < dates.length; i++)
          i % every == 0 ? _dm(dates[i]) : '',
      ];
      return pw.SizedBox(
        height: 150,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis.fromStrings(
              labels,
              marginStart: 20,
              marginEnd: 20,
              textStyle: const pw.TextStyle(fontSize: 7),
            ),
            yAxis: pw.FixedAxis<int>(
              ticks,
              divisions: true,
              textStyle: const pw.TextStyle(fontSize: 7),
            ),
          ),
          datasets: [
            for (var s = 0; s < series.length; s++)
              pw.LineDataSet(
                legend: legends[s],
                color: colors[s],
                pointSize: 2,
                lineWidth: 1.5,
                data: [
                  for (var i = 0; i < series[s].length; i++)
                    pw.PointChartValue(i.toDouble(), series[s][i]),
                ],
              ),
          ],
        ),
      );
    }

    final p = data.profile;
    final conditions = p.conditions.where((c) => c != 'Yok').toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 42),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'VitaCoach Sağlık Raporu',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: green,
              ),
            ),
            pw.Text(
              'Oluşturma: ${date(data.generatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            muted(
              'Bu rapor kullanıcının kendi girdiği verilerden oluşturulmuştur; '
              'tanı amacı taşımaz.',
            ),
            muted('Sayfa ${context.pageNumber}/${context.pagesCount}'),
          ],
        ),
        build: (context) => [
          heading('Kişisel Bilgiler'),
          table(
            ['Bilgi', 'Değer', 'Bilgi', 'Değer'],
            [
              [
                'Ad',
                p.name.isEmpty ? '-' : p.name,
                'Yaş',
                p.age > 0 ? '${p.age}' : '-',
              ],
              [
                'Cinsiyet',
                p.gender.isEmpty ? '-' : p.gender,
                'Kan grubu',
                data.emergency.bloodType,
              ],
              [
                'Boy / Kilo',
                p.height > 0 && p.weight > 0
                    ? '${_num(p.height)} cm / ${_num(p.weight, 1)} kg'
                    : '-',
                'BMI',
                p.bmi > 0 ? '${_num(p.bmi, 1)} (${p.bmiCategory})' : '-',
              ],
              [
                'Kronik hastalık',
                conditions.isEmpty ? '-' : conditions.join(', '),
                'Alerji',
                data.emergency.allergies.trim().isEmpty
                    ? '-'
                    : data.emergency.allergies.trim(),
              ],
            ],
          ),

          heading('Kullandığı İlaçlar'),
          if (data.medications.isEmpty)
            muted('Kayıtlı ilaç yok.')
          else
            table(
              ['İlaç', 'Doz', 'Saat', 'Hatırlatıcı'],
              data.medications
                  .map(
                    (m) => [
                      m.name,
                      m.dosage.isEmpty ? '-' : m.dosage,
                      m.timeDisplay,
                      m.isActive ? 'Açık' : 'Kapalı',
                    ],
                  )
                  .toList(),
            ),
          if (data.interactions.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red300, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Olası ilaç etkileşimleri (uygulama tarafından saptanan)',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.red800,
                    ),
                  ),
                  ...data.interactions.map(
                    (w) => pw.Text(
                      '• ${w.drugA} + ${w.drugB} (${w.severity.label}): ${w.message}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (data.adherence?.percent != null) ...[
            pw.SizedBox(height: 6),
            muted(
              'İlaç uyumu (son ${data.adherence!.days} gün, "Aldım" kayıtlarına göre): '
              '%${data.adherence!.percent} (${data.adherence!.taken}/${data.adherence!.scheduled} doz)'
              '${data.adherence!.patterns.isEmpty ? '' : ' • ${data.adherence!.patterns.first.message}'}',
            ),
          ],

          heading('Tansiyon (son ${data.periodDays} gün)'),
          if (data.pressures.isEmpty)
            muted('Bu dönemde tansiyon kaydı yok.')
          else ...[
            muted(
              '${data.pressures.length} ölçüm • Ortalama '
              '${_num(data.pressures.map((e) => e.systolic).reduce((a, b) => a + b) / data.pressures.length)}/'
              '${_num(data.pressures.map((e) => e.diastolic).reduce((a, b) => a + b) / data.pressures.length)} mmHg',
            ),
            pw.SizedBox(height: 4),
            chart(
              dates: data.pressures.map((e) => e.date).toList(),
              series: [
                data.pressures.map((e) => e.systolic).toList(),
                data.pressures.map((e) => e.diastolic).toList(),
              ],
              legends: ['Sistolik', 'Diastolik'],
              colors: [PdfColors.red, PdfColors.blue],
            ),
            pw.SizedBox(height: 4),
            table(
              ['Tarih', 'Saat', 'Tansiyon', 'Sınıflandırma'],
              data.pressures.reversed
                  .take(12)
                  .map(
                    (e) => [
                      date(e.date),
                      '${_two(e.date.hour)}:${_two(e.date.minute)}',
                      e.display,
                      e.category,
                    ],
                  )
                  .toList(),
            ),
          ],

          heading('Kan Şekeri (son ${data.periodDays} gün)'),
          if (data.sugars.isEmpty)
            muted('Bu dönemde kan şekeri kaydı yok.')
          else ...[
            muted(
              '${data.sugars.length} ölçüm • Ortalama '
              '${_num(data.sugars.map((e) => e.value).reduce((a, b) => a + b) / data.sugars.length)} mg/dL • '
              'En düşük ${_num(data.sugars.map((e) => e.value).reduce(math.min))} • '
              'En yüksek ${_num(data.sugars.map((e) => e.value).reduce(math.max))}',
            ),
            pw.SizedBox(height: 4),
            chart(
              dates: data.sugars.map((e) => e.date).toList(),
              series: [data.sugars.map((e) => e.value).toList()],
              legends: ['Kan şekeri (mg/dL)'],
              colors: [PdfColors.orange],
            ),
          ],

          if (data.weights.isNotEmpty) ...[
            heading('Kilo (son ${data.periodDays} gün)'),
            muted(
              'İlk: ${_num(data.weights.first.value, 1)} kg (${date(data.weights.first.date)}) • '
              'Son: ${_num(data.weights.last.value, 1)} kg (${date(data.weights.last.date)})',
            ),
          ],

          heading('Yaşam Tarzı Özeti'),
          table(
            ['Gösterge', 'Değer'],
            [
              ['Günlük adım (7 gün ort.)', _num(data.stepAverage7)],
              [
                'Uyku (7 gün ort.)',
                data.sleep.isEmpty
                    ? 'Kayıt yok'
                    : '${_num(data.sleep.map((e) => e.hours).reduce((a, b) => a + b) / data.sleep.length, 1)} saat (${data.sleep.length} gece)',
              ],
              if (data.heart.isNotEmpty)
                [
                  'Son nabız (kamera, dinlenik)',
                  () {
                    final rest = data.heart.where((h) => !h.afterBreathing);
                    final h = rest.isEmpty ? data.heart.first : rest.first;
                    return '${h.bpm} atım/dk • HRV ${_num(h.rmssdMs)} ms (${_dm(h.date)})';
                  }(),
                ],
              [
                'Ruh hali (14 gün ort., 1-5)',
                data.moodAverage14 == null
                    ? 'Kayıt yok'
                    : '${_num(data.moodAverage14!, 1)} (${data.moodDays14} gün)',
              ],
            ],
          ),

          if (data.tests.isNotEmpty) ...[
            heading('Ruh Sağlığı Tarama Testleri'),
            table(
              ['Tarih', 'Test', 'Puan', 'Değerlendirme'],
              data.tests.take(6).map((t) {
                final d = DateTime.tryParse('${t['date']}');
                return [
                  d == null ? '-' : date(d),
                  '${t['test_type']}',
                  '${t['score']}',
                  '${t['severity']}',
                ];
              }).toList(),
            ),
          ],

          if (data.risks.isNotEmpty) ...[
            heading('Risk Skorları'),
            table(
              ['Tarih', 'Model', 'Sonuç', 'Düzey'],
              _latestPerType(data.risks).map((r) {
                final d = DateTime.tryParse('${r['date']}');
                final isFramingham = r['type'] == 'Framingham';
                return [
                  d == null ? '-' : date(d),
                  isFramingham ? 'Framingham KVH (10 yıl)' : 'FINDRISC diyabet',
                  isFramingham
                      ? '%${_num(r['score'] as num, 1)}'
                      : '${r['score']} / 26',
                  '${r['level']}',
                ];
              }).toList(),
            ),
          ],

          if (data.insights.isNotEmpty) ...[
            heading('Otomatik Analiz Bulguları'),
            muted(
              'Cihaz içi istatistiksel analiz (regresyon, sağlam z-skoru, korelasyon); '
              'tanı amacı taşımaz.',
            ),
            pw.SizedBox(height: 4),
            ...data.insights
                .take(7)
                .map(
                  (i) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        style: const pw.TextStyle(fontSize: 9),
                        children: [
                          pw.TextSpan(
                            text: '[${i.severity.label}] ${i.title}: ',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: switch (i.severity) {
                                InsightSeverity.alert => PdfColors.red800,
                                InsightSeverity.warning => PdfColors.orange800,
                                InsightSeverity.info => PdfColors.blue800,
                                InsightSeverity.positive => PdfColors.green800,
                              },
                            ),
                          ),
                          pw.TextSpan(text: i.message),
                        ],
                      ),
                    ),
                  ),
                ),
          ],

          pw.SizedBox(height: 6),
          muted(AppConstants.medicalDisclaimer.replaceAll('⚠️ ', '')),
        ],
      ),
    );
    return doc.save();
  }

  static List<Map<String, dynamic>> _latestPerType(
    List<Map<String, dynamic>> risks,
  ) {
    final seen = <String>{};
    return [
      for (final r in risks)
        if (seen.add('${r['type']}')) r,
    ];
  }
}
