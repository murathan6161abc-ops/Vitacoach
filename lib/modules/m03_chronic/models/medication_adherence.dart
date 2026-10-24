import 'health_entry.dart';

/// Bir dozun kullanıcı tarafından işaretlenen durumu.
enum DoseStatus { taken, skipped }

/// Tek bir doz kaydı. Hive'da `dose_log` altında
/// `{ 'YYYY-MM-DD': { '<doz bildirim kimliği>': {status, at} } }` biçiminde
/// tutulur. Eski tek saatli ilacın kimliği göçte ilk dozuna geçtiği için
/// önceki kayıtlar olduğu gibi geçerlidir.
class DoseRecord {
  final DoseStatus status;
  final DateTime at;

  const DoseRecord({required this.status, required this.at});

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'at': at.toIso8601String(),
  };

  static DoseRecord? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final status = DoseStatus.values.where((s) => s.name == raw['status']);
    final at = DateTime.tryParse('${raw['at']}');
    if (status.isEmpty || at == null) return null;
    return DoseRecord(status: status.first, at: at);
  }
}

/// Doz kayıtlarını gün + doz kimliğine göre tutan değiştirilebilir yapı.
class DoseLog {
  final Map<String, Map<int, DoseRecord>> _days;

  DoseLog._(this._days);

  factory DoseLog.empty() => DoseLog._({});

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Bozuk girdileri atlayarak Hive'daki ham veriyi çözer.
  factory DoseLog.fromRaw(dynamic raw) {
    final days = <String, Map<int, DoseRecord>>{};
    if (raw is Map) {
      raw.forEach((day, meds) {
        if (meds is! Map) return;
        final parsed = <int, DoseRecord>{};
        meds.forEach((id, record) {
          final key = int.tryParse('$id');
          final value = DoseRecord.tryFromMap(record);
          if (key != null && value != null) parsed[key] = value;
        });
        if (parsed.isNotEmpty) days['$day'] = parsed;
      });
    }
    return DoseLog._(days);
  }

  Map<String, dynamic> toRaw() => {
    for (final day in _days.entries)
      day.key: {
        for (final med in day.value.entries) '${med.key}': med.value.toMap(),
      },
  };

  DoseRecord? get(DateTime day, int doseId) => _days[dayKey(day)]?[doseId];

  void set(DateTime day, int doseId, DoseRecord record) {
    (_days[dayKey(day)] ??= {})[doseId] = record;
  }

  void remove(DateTime day, int doseId) {
    final key = dayKey(day);
    _days[key]?.remove(doseId);
    if (_days[key]?.isEmpty ?? false) _days.remove(key);
  }

  /// Bu dozlardan herhangi biri için kaydedilmiş ilk gün (eski ilaçlarda
  /// başlangıç tarihi yok).
  DateTime? firstDayFor(Iterable<int> doseIds) {
    final ids = doseIds.toSet();
    final days =
        _days.entries
            .where((e) => e.value.keys.any(ids.contains))
            .map((e) => DateTime.tryParse(e.key))
            .whereType<DateTime>()
            .toList()
          ..sort();
    return days.isEmpty ? null : days.first;
  }

  /// [keepDays] günden eski kayıtları siler (Hive'ın şişmemesi için).
  void prune(DateTime now, {int keepDays = 90}) {
    final cutoff = dayKey(now.subtract(Duration(days: keepDays)));
    _days.removeWhere((key, _) => key.compareTo(cutoff) < 0);
  }
}

/// Bir dozun (ilaç + saat) dönem içindeki uyum istatistiği.
class DoseAdherence {
  final MedicationReminder medication;
  final MedicationDose dose;
  final int scheduled;
  final int taken;
  final int skipped;

  /// Alınan dozların planlanan saate göre ortalama gecikmesi (dakika).
  final double? averageDelayMinutes;
  final List<DateTime> missedDays;

  const DoseAdherence({
    required this.medication,
    required this.dose,
    required this.scheduled,
    required this.taken,
    required this.skipped,
    required this.averageDelayMinutes,
    required this.missedDays,
  });

  int get missed => scheduled - taken;
  double? get rate => scheduled == 0 ? null : taken / scheduled;
}

/// Kullanıcıya gösterilen, gerekçesi açıklanmış örüntü.
class AdherencePattern {
  final String message;
  final String suggestion;
  const AdherencePattern(this.message, this.suggestion);
}

class AdherenceReport {
  final int days;

  /// Günde birden çok dozu olan ilacın her saati ayrı satırdır.
  final List<DoseAdherence> perDose;
  final List<AdherencePattern> patterns;

  const AdherenceReport({
    required this.days,
    required this.perDose,
    required this.patterns,
  });

  int get scheduled => perDose.fold(0, (a, d) => a + d.scheduled);
  int get taken => perDose.fold(0, (a, d) => a + d.taken);

  /// 0-1 arası uyum oranı; planlanmış doz yoksa null.
  double? get rate => scheduled == 0 ? null : taken / scheduled;
  int? get percent => rate == null ? null : (rate! * 100).round();
}

/// Uyum tablosundaki bir hücrenin durumu.
enum DoseCellState { notScheduled, upcoming, taken, skipped, missed }

/// Doz kayıtlarından ilaç uyumunu ve örüntüleri hesaplar. Tamamen cihaz
/// içinde, açıklanabilir kurallarla çalışır.
class AdherenceCalculator {
  AdherenceCalculator._();

  /// Ortalama gecikme bu eşiği aşarsa hatırlatma saati için öneri yapılır.
  static const int lateThresholdMinutes = 60;

  static AdherenceReport compute({
    required List<MedicationReminder> medications,
    required DoseLog log,
    required DateTime now,
    int days = 7,
    DateTime? trackingSince,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final stats = <DoseAdherence>[];

    for (final med in medications.where((m) => m.isActive)) {
      final medicationStart = _startMoment(med, log, trackingSince, now);
      for (final dose in med.doses) {
        final start = _doseStart(dose, medicationStart);
        var scheduled = 0, taken = 0, skipped = 0;
        final delays = <double>[];
        final missedDays = <DateTime>[];

        for (var i = days - 1; i >= 0; i--) {
          final day = today.subtract(Duration(days: i));
          final due = dose.dueOn(day);
          final record = log.get(day, dose.notificationId);
          // İlaç eklenmeden / takip başlamadan önceki dozlar sayılmaz.
          if (record == null && due.isBefore(start)) continue;
          // Bugünün henüz vakti gelmemiş ve işaretlenmemiş dozu sayılmaz.
          if (record == null && due.isAfter(now)) continue;
          scheduled++;
          if (record?.status == DoseStatus.taken) {
            taken++;
            delays.add(record!.at.difference(due).inMinutes.toDouble());
          } else {
            if (record?.status == DoseStatus.skipped) skipped++;
            missedDays.add(day);
          }
        }

        stats.add(
          DoseAdherence(
            medication: med,
            dose: dose,
            scheduled: scheduled,
            taken: taken,
            skipped: skipped,
            averageDelayMinutes: delays.isEmpty
                ? null
                : delays.reduce((a, b) => a + b) / delays.length,
            missedDays: missedDays,
          ),
        );
      }
    }

    return AdherenceReport(
      days: days,
      perDose: stats,
      patterns: _patterns(stats),
    );
  }

  /// Belirli bir gün için dozun durumu (tablo gösterimi için); [compute]
  /// ile aynı kuralları kullanır.
  static DoseCellState cellState({
    required MedicationReminder medication,
    required MedicationDose dose,
    required DoseLog log,
    required DateTime day,
    required DateTime now,
    DateTime? trackingSince,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d.isAfter(today)) return DoseCellState.notScheduled;
    final record = log.get(d, dose.notificationId);
    if (record?.status == DoseStatus.taken) return DoseCellState.taken;
    if (record?.status == DoseStatus.skipped) return DoseCellState.skipped;
    final due = dose.dueOn(d);
    final start = _doseStart(
      dose,
      _startMoment(medication, log, trackingSince, now),
    );
    if (due.isBefore(start)) return DoseCellState.notScheduled;
    return due.isAfter(now) ? DoseCellState.upcoming : DoseCellState.missed;
  }

  /// İlaca sonradan eklenen doz, eklendiği andan önce kaçırılmış sayılmaz.
  static DateTime _doseStart(MedicationDose dose, DateTime medicationStart) {
    final addedAt = dose.addedAt;
    return addedAt != null && addedAt.isAfter(medicationStart)
        ? addedAt
        : medicationStart;
  }

  /// Uyum sayımının başladığı an: ilacın eklendiği an; yoksa (eski
  /// kayıtlar) ilk doz kaydının günü, o da yoksa takibin başladığı an.
  static DateTime _startMoment(
    MedicationReminder med,
    DoseLog log,
    DateTime? trackingSince,
    DateTime now,
  ) {
    if (med.createdAt != null) return med.createdAt!;
    final first = log.firstDayFor(med.doses.map((d) => d.notificationId));
    if (first != null) return DateTime(first.year, first.month, first.day);
    return trackingSince ?? now;
  }

  static List<AdherencePattern> _patterns(List<DoseAdherence> stats) {
    final patterns = <AdherencePattern>[];
    for (final s in stats) {
      final name = s.medication.name;
      final time = s.dose.timeDisplay;
      if (s.scheduled >= 3 && s.missed >= 2) {
        patterns.add(
          AdherencePattern(
            '$name ($time) dozunu son ${s.scheduled} dozun ${s.missed} tanesinde kaçırdınız.',
            _missSuggestion(s),
          ),
        );
      }
      final delay = s.averageDelayMinutes;
      if (delay != null && s.taken >= 3 && delay >= lateThresholdMinutes) {
        final suggested = _shift(s.dose, delay);
        patterns.add(
          AdherencePattern(
            '$name ($time) dozunu ortalama ${delay.round()} dakika geç '
                'alıyorsunuz.',
            'Hatırlatma saatini $suggested olarak güncellemeyi düşünebilirsiniz '
                '(ilacın saatini değiştirmeden önce doktorunuza danışın).',
          ),
        );
      }
    }
    return patterns;
  }

  static String _missSuggestion(DoseAdherence s) {
    final weekendMisses = s.missedDays
        .where(
          (d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday,
        )
        .length;
    if (s.missed >= 2 && weekendMisses * 2 >= s.missed + 1) {
      return 'Kaçırılan dozların çoğu hafta sonuna denk geliyor; hafta sonu '
          'rutininize uygun bir hatırlatma belirleyin.';
    }
    if (s.dose.hour >= 19) {
      return 'Akşam dozlarında ilacı akşam yemeği gibi sabit bir alışkanlığa '
          'bağlamak (ör. masaya koymak) unutmayı azaltır.';
    }
    return "Bildirimdeki 'Aldım' düğmesini kullanmak takibi kolaylaştırır.";
  }

  static String _shift(MedicationDose dose, double delayMinutes) {
    final rounded = (delayMinutes / 15).round() * 15;
    final total = (dose.minuteOfDay + rounded) % (24 * 60);
    final h = (total ~/ 60).toString().padLeft(2, '0');
    final m = (total % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
