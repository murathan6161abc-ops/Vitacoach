import '../../../services/hive_service.dart';
import '../services/ppg_processor.dart';

/// Kamera ile yapılan bir nabız/HRV ölçümü.
class HeartMeasurement {
  final DateTime date;
  final int bpm;
  final double rmssdMs;
  final StressLevel stress;
  final double quality;

  /// 'rest' (dinlenik) veya 'after_breathing' (nefes egzersizi sonrası).
  final String context;

  const HeartMeasurement({
    required this.date,
    required this.bpm,
    required this.rmssdMs,
    required this.stress,
    required this.quality,
    this.context = 'rest',
  });

  factory HeartMeasurement.fromResult(
    PpgResult result, {
    DateTime? at,
    String context = 'rest',
  }) => HeartMeasurement(
    date: at ?? DateTime.now(),
    bpm: result.bpm.round(),
    rmssdMs: double.parse(result.rmssdMs.toStringAsFixed(1)),
    stress: result.stress,
    quality: double.parse(result.quality.toStringAsFixed(2)),
    context: context,
  );

  bool get afterBreathing => context == 'after_breathing';

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'bpm': bpm,
    'rmssd': rmssdMs,
    'stress': stress.name,
    'quality': quality,
    'context': context,
  };

  static HeartMeasurement? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final date = DateTime.tryParse('${raw['date']}');
    final bpm = raw['bpm'];
    if (date == null || bpm is! num) return null;
    return HeartMeasurement(
      date: date,
      bpm: bpm.toInt(),
      rmssdMs: (raw['rmssd'] as num?)?.toDouble() ?? 0,
      stress: StressLevel.values.firstWhere(
        (s) => s.name == raw['stress'],
        orElse: () => StressLevel.moderate,
      ),
      quality: (raw['quality'] as num?)?.toDouble() ?? 0,
      context: raw['context'] as String? ?? 'rest',
    );
  }

  static const String storageKey = 'heart_log';

  /// En yeni başta.
  static List<HeartMeasurement> parseList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map(tryFromMap).whereType<HeartMeasurement>().toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<HeartMeasurement> loadAll() =>
      parseList(HiveService().getHealthBox().get(storageKey));

  static Future<void> save(HeartMeasurement m) async {
    final list = [m, ...loadAll()].take(100).toList();
    await HiveService().getHealthBox().put(
      storageKey,
      list.map((e) => e.toMap()).toList(),
    );
  }
}
