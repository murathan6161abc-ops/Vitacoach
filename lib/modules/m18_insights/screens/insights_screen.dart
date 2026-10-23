import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils/input_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../services/insight_engine.dart';
import '../services/insight_repository.dart';
import '../services/trend_math.dart';

Color insightColor(InsightSeverity s) => switch (s) {
  InsightSeverity.alert => AppColors.danger,
  InsightSeverity.warning => AppColors.warning,
  InsightSeverity.info => AppColors.accentChronic,
  InsightSeverity.positive => AppColors.success,
};

IconData insightIcon(InsightSeverity s) => switch (s) {
  InsightSeverity.alert => Icons.emergency,
  InsightSeverity.warning => Icons.warning_amber_rounded,
  InsightSeverity.info => Icons.insights,
  InsightSeverity.positive => Icons.thumb_up_alt_outlined,
};

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late InsightInput _input;
  late List<HealthInsight> _insights;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _input = InsightRepository.load();
    _insights = InsightEngine.analyze(_input);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akıllı Sağlık Analizi')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          children: [
            _header(),
            const SizedBox(height: 16),
            if (_bpChartData() != null) ...[
              _BpTrendCard(data: _bpChartData()!),
              const SizedBox(height: 16),
            ],
            if (_insights.isEmpty)
              _empty()
            else
              for (final insight in _insights) ...[
                _InsightCard(insight: insight),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            Text(
              'Bu analiz tanı koymaz; kendi girdiğiniz verilerdeki eğilimleri '
              'gösterir. ${AppConstants.medicalDisclaimer}',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    int count(InsightSeverity s) =>
        _insights.where((i) => i.severity == s).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        gradient: const LinearGradient(
          colors: [Color(0xFF2EA067), Color(0xFF18688C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cihazınızda çalışan analiz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Son 30 günlük ölçümleriniz istatistiksel yöntemlerle incelendi. '
            'Verileriniz telefonunuzdan çıkmaz.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in InsightSeverity.values)
                if (count(s) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${count(s)} ${s.label.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return VcCard(
      child: Column(
        children: [
          Icon(Icons.query_stats, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            'Analiz için biraz daha veri gerekiyor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '• En az 5 gün tansiyon veya şeker ölçümü\n'
            '• Uyku ve ruh hali kayıtları (ilişki analizi için ~1 hafta)\n'
            '• İlaç dozlarını "Aldım" ile işaretleme\n'
            '• Kamerayla nabız ölçümü',
          ),
        ],
      ),
    );
  }

  _BpChartData? _bpChartData() {
    final list =
        _input.pressures
            .where(
              (p) =>
                  _input.now.difference(p.date).inDays <= 14 && p.systolic > 0,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 5) return null;
    final t0 = list.first.date;
    double x(DateTime d) => d.difference(t0).inMinutes / (60 * 24);
    final points = [for (final p in list) FlSpot(x(p.date), p.systolic)];
    final fit = TrendMath.fit(
      [for (final s in points) s.x],
      [for (final s in points) s.y],
    );
    if (fit == null) return null;
    return _BpChartData(points, fit, x(_input.now));
  }
}

class _BpChartData {
  final List<FlSpot> points;
  final LinearFit fit;
  final double nowX;
  _BpChartData(this.points, this.fit, this.nowX);
}

class _BpTrendCard extends StatelessWidget {
  final _BpChartData data;
  const _BpTrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fit = data.fit;
    final endX = data.nowX + 7;
    final ys = [
      ...data.points.map((p) => p.y),
      fit.predict(0),
      fit.predict(endX),
      140,
    ];
    final minY = ((ys.reduce((a, b) => a < b ? a : b) - 5) / 10).floor() * 10.0;
    final maxY = ((ys.reduce((a, b) => a > b ? a : b) + 5) / 10).ceil() * 10.0;
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Büyük tansiyon: eğilim ve 7 günlük tahmin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Noktalar: ölçümler · düz çizgi: regresyon · kesikli: tahmin · kırmızı: 140 mmHg',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: endX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.textHint.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 140,
                      color: AppColors.danger.withValues(alpha: 0.6),
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 7,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) {
                        final label = (v - data.nowX).abs() < 0.6
                            ? 'bugün'
                            : v > data.nowX
                            ? '+7 gün'
                            : '${(data.nowX - v).round()} gün önce';
                        return SideTitleWidget(
                          meta: meta,
                          // Kenardaki "+7 gün" etiketi kırpılmasın.
                          fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 10,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${v.toInt()}',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.points,
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.accentChronic,
                        strokeWidth: 0,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(0, fit.predict(0)),
                      FlSpot(data.nowX, fit.predict(data.nowX)),
                    ],
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(data.nowX, fit.predict(data.nowX)),
                      FlSpot(endX, fit.predict(endX)),
                    ],
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dashArray: [6, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Eğim: ${TrendMath.signed(fit.slope * 7)} mmHg/hafta · '
            'R² = ${TrendMath.fmt(fit.r2, 2)} · 7 gün sonra ≈ ${fit.predict(endX).round()} mmHg',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final HealthInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = insightColor(insight.severity);
    final route = insight.route;
    return VcCard(
      borderColor: color.withValues(alpha: 0.5),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(
                    insightIcon(insight.severity),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        InputUtils.upperTr(
                          '${insight.category} · ${insight.severity.label}',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SpeakButton(
                  id: 'insight-${insight.id}',
                  text:
                      '${insight.title}. ${insight.message} ${insight.suggestion ?? ''}',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(insight.message),
          ),
          if (insight.suggestion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      insight.suggestion!,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(
                'Neden bu sonuç?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                for (final e in insight.evidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e', style: const TextStyle(fontSize: 13)),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Yöntem: ${insight.method}',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
                if (route != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.push(route),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('İlgili ekrana git'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
