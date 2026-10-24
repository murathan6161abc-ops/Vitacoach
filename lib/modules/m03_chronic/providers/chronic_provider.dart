import 'dart:async';

import 'package:flutter/material.dart';
import '../../../services/hive_service.dart';
import '../../../services/notification_service.dart';
import '../models/blood_sugar.dart';
import '../models/health_entry.dart';
import '../models/medication_adherence.dart';

class ChronicProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  List<HealthEntry> _bloodSugarEntries = [];
  List<BloodPressureEntry> _bloodPressureEntries = [];
  List<HealthEntry> _weightEntries = [];
  List<MedicationReminder> _medications = [];
  DoseLog _doseLog = DoseLog.empty();
  DateTime? _trackingSince;

  List<HealthEntry> get bloodSugarEntries => _bloodSugarEntries;
  List<BloodPressureEntry> get bloodPressureEntries => _bloodPressureEntries;
  List<HealthEntry> get weightEntries => _weightEntries;
  List<MedicationReminder> get medications => _medications;

  /// Etkin ilaçların her dozu ayrı satır olarak, saate göre sıralı.
  List<(MedicationReminder, MedicationDose)> get activeDoses => [
    for (final medication in _medications.where((m) => m.isActive))
      for (final dose in medication.doses) (medication, dose),
  ]..sort((a, b) => a.$2.minuteOfDay.compareTo(b.$2.minuteOfDay));

  /// Son 7 günün ilaç uyumu (cihaz içinde hesaplanır).
  AdherenceReport adherence({DateTime? now, int days = 7}) =>
      AdherenceCalculator.compute(
        medications: _medications,
        log: _doseLog,
        now: now ?? DateTime.now(),
        days: days,
        trackingSince: _trackingSince,
      );

  DoseCellState doseState(
    MedicationReminder medication,
    MedicationDose dose,
    DateTime day, {
    DateTime? now,
  }) => AdherenceCalculator.cellState(
    medication: medication,
    dose: dose,
    log: _doseLog,
    day: day,
    now: now ?? DateTime.now(),
    trackingSince: _trackingSince,
  );

  /// Dozun bugünkü kaydı (yoksa null).
  DoseRecord? todayDose(MedicationDose dose, {DateTime? now}) =>
      _doseLog.get(now ?? DateTime.now(), dose.notificationId);

  /// Dozun bugünkü vakti geldi mi?
  bool isDoseDue(MedicationDose dose, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return !dose.dueOn(t).isAfter(t);
  }

  // Last 7 days data
  List<HealthEntry> get bloodSugar7Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _bloodSugarEntries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  List<HealthEntry> get bloodSugar30Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _bloodSugarEntries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  /// Son ölçüm ile ondan önceki 30 gün içindeki ilk ölçüm arasındaki fark
  /// (kg). Karşılaştırılacak ikinci bir ölçüm yoksa null.
  double? get weightChange30Days {
    if (_weightEntries.length < 2) return null;
    final latest = _weightEntries.last;
    final cutoff = latest.date.subtract(const Duration(days: 30));
    final window = _weightEntries.where((e) => !e.date.isBefore(cutoff));
    if (window.length < 2) return null;
    return latest.value - window.first.value;
  }

  /// Hive'daki bir listeyi kayıt kayıt çözer. Eski/bozuk biçimli tek bir
  /// kayıt tüm modülü çökertmemeli; yalnızca kendisi atlanmalıdır.
  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<dynamic, dynamic>) fromMap,
  ) {
    if (raw is! List) return <T>[];
    final result = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(fromMap(item));
      } catch (error) {
        debugPrint('Sağlık kaydı okunamadı, atlandı: $error');
      }
    }
    return result;
  }

  void loadData() {
    final box = _hiveService.getHealthBox();

    // Blood sugar
    _bloodSugarEntries = _parseList(
      box.get('blood_sugar', defaultValue: <dynamic>[]),
      HealthEntry.fromMap,
    );

    // Blood pressure
    _bloodPressureEntries = _parseList(
      box.get('blood_pressure', defaultValue: <dynamic>[]),
      BloodPressureEntry.fromMap,
    );

    // Weight
    _weightEntries = _parseList(
      box.get('weight_history', defaultValue: <dynamic>[]),
      HealthEntry.fromMap,
    );

    // Medications
    final medData =
        _hiveService.getMedicationBox().get(
          'medications',
          defaultValue: <dynamic>[],
        ) ??
        [];
    final usedIds = <int>{};
    var needsMigration = false;
    _medications = [];
    for (var index = 0; index < medData.length; index++) {
      final raw = Map<dynamic, dynamic>.from(medData[index] as Map);
      // Eski tek saatli kayıt doz listesine taşınıp yeniden yazılır.
      if (MedicationReminder.isLegacyMap(raw)) needsMigration = true;
      final parsed = MedicationReminder.fromMap(raw);
      final medication = _withUniqueDoseIds(parsed, usedIds, salt: index);
      if (!identical(medication, parsed)) needsMigration = true;
      _medications.add(medication);
    }

    if (needsMigration) unawaited(_saveMedications());
    unawaited(_restoreMedicationNotifications());

    _doseLog = DoseLog.fromRaw(_hiveService.getMedicationBox().get('dose_log'));
    _trackingSince = trackingSinceOf(_hiveService.getMedicationBox());
    notifyListeners();
  }

  /// Uyum takibinin başladığı an (ilk açılışta kaydedilir). Takipten önce
  /// eklenmiş ilaçların eski dozları "kaçırılmış" sayılmasın diye.
  static DateTime trackingSinceOf(dynamic box) {
    final saved = DateTime.tryParse('${box.get('adherence_since') ?? ''}');
    if (saved != null) return saved;
    final now = DateTime.now();
    box.put('adherence_since', now.toIso8601String());
    return now;
  }

  /// Her dozun bildirim kimliği tüm ilaçlar arasında tekil olmalı: çakışan
  /// doza yeni kimlik verilir. Kimlik değişmediyse aynı nesne döner.
  static MedicationReminder _withUniqueDoseIds(
    MedicationReminder medication,
    Set<int> usedIds, {
    required int salt,
  }) {
    var changed = false;
    final doses = <MedicationDose>[];
    for (var dose in medication.doses) {
      while (!usedIds.add(dose.notificationId)) {
        dose = dose.copyWith(
          notificationId: MedicationReminder.createNotificationId(
            salt: salt + doses.length,
          ),
        );
        changed = true;
      }
      doses.add(dose);
    }
    return changed ? medication.copyWith(doses: doses) : medication;
  }

  /// Bildirimden gelen "Aldım" işlendikten sonra çağrılır.
  void reloadDoseLog() {
    _doseLog = DoseLog.fromRaw(_hiveService.getMedicationBox().get('dose_log'));
    notifyListeners();
  }

  /// Dozun bugünkü kaydını alındı/atlandı olarak işaretler; [status] null
  /// ise işaret kaldırılır.
  Future<void> markDose(
    MedicationDose dose,
    DoseStatus? status, {
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now();
    if (status == null) {
      _doseLog.remove(t, dose.notificationId);
    } else {
      _doseLog.set(t, dose.notificationId, DoseRecord(status: status, at: t));
      // Uygulamadan işaretlendiyse ertelenmiş hatırlatma artık gereksiz.
      // Beklenmeden çalışır; hata olursa yakalanmayan bir hataya dönüşmesin
      // (doz kaydı zaten yazıldı).
      unawaited(
        NotificationService()
            .cancelNotification(NotificationIds.snoozeFor(dose.notificationId))
            .catchError(
              (Object e) =>
                  debugPrint('Ertelenen hatırlatma iptal edilemedi: $e'),
            ),
      );
    }
    _doseLog.prune(t);
    await _hiveService.getMedicationBox().put('dose_log', _doseLog.toRaw());
    notifyListeners();
  }

  Future<void> addBloodSugar(
    double value, {
    String? note,
    SugarTiming? timing,
  }) async {
    final entry = HealthEntry(
      value: value,
      date: DateTime.now(),
      note: note,
      timing: timing?.name,
    );
    _bloodSugarEntries.add(entry);
    await _saveBloodSugar();
    notifyListeners();
  }

  // Yanlış girilen ölçümler önceden hiç silinemiyordu. Silinen kayıt
  // "Geri al" ile aynı tarihiyle geri konabilir.

  Future<void> removeBloodSugar(HealthEntry entry) async {
    if (!_bloodSugarEntries.remove(entry)) return;
    await _saveBloodSugar();
    notifyListeners();
  }

  Future<void> restoreBloodSugar(HealthEntry entry) async {
    _insertByDate(_bloodSugarEntries, entry, (e) => e.date);
    await _saveBloodSugar();
    notifyListeners();
  }

  Future<void> removeBloodPressure(BloodPressureEntry entry) async {
    if (!_bloodPressureEntries.remove(entry)) return;
    await _saveBloodPressure();
    notifyListeners();
  }

  Future<void> restoreBloodPressure(BloodPressureEntry entry) async {
    _insertByDate(_bloodPressureEntries, entry, (e) => e.date);
    await _saveBloodPressure();
    notifyListeners();
  }

  Future<void> removeWeight(HealthEntry entry) async {
    if (!_weightEntries.remove(entry)) return;
    await _saveWeights();
    notifyListeners();
  }

  Future<void> restoreWeight(HealthEntry entry) async {
    _insertByDate(_weightEntries, entry, (e) => e.date);
    await _saveWeights();
    notifyListeners();
  }

  static void _insertByDate<T>(
    List<T> list,
    T entry,
    DateTime Function(T) dateOf,
  ) {
    final index = list.indexWhere((e) => dateOf(e).isAfter(dateOf(entry)));
    list.insert(index < 0 ? list.length : index, entry);
  }

  Future<void> _saveBloodSugar() => _hiveService.getHealthBox().put(
    'blood_sugar',
    _bloodSugarEntries.map((e) => e.toMap()).toList(),
  );

  Future<void> _saveBloodPressure() => _hiveService.getHealthBox().put(
    'blood_pressure',
    _bloodPressureEntries.map((e) => e.toMap()).toList(),
  );

  /// Kilo geçmişini yazar ve profildeki güncel kiloyu en son ölçüme
  /// eşitler (BMI ve kalori hesapları aynı değeri kullansın).
  Future<void> _saveWeights() async {
    await _hiveService.getHealthBox().put(
      'weight_history',
      _weightEntries.map((e) => e.toMap()).toList(),
    );
    if (_weightEntries.isNotEmpty) {
      await _hiveService.getProfileBox().put(
        'weight',
        _weightEntries.last.value,
      );
    }
  }

  Future<void> addBloodPressure(
    double systolic,
    double diastolic, {
    String? note,
  }) async {
    final entry = BloodPressureEntry(
      systolic: systolic,
      diastolic: diastolic,
      date: DateTime.now(),
      note: note,
    );
    _bloodPressureEntries.add(entry);
    await _saveBloodPressure();
    notifyListeners();
  }

  /// Kilo geçmişinin tek yazıcısı. Profil düzenleme ve ilk kurulum da
  /// buradan geçer; profildeki güncel kilo da en son ölçüme eşitlenir ki
  /// BMI ve kalori hesapları trendle aynı değeri kullansın.
  Future<void> addWeight(double value, {DateTime? at}) async {
    final entry = HealthEntry(value: value, date: at ?? DateTime.now());
    _insertByDate(_weightEntries, entry, (e) => e.date);
    await _saveWeights();
    notifyListeners();
  }

  /// [requestExactPermission]: kullanıcı açıklamayı görüp onayladıysa
  /// sistem "Alarmlar ve hatırlatıcılar" sayfası açılır.
  Future<bool> addMedication(
    MedicationReminder medication, {
    bool requestExactPermission = false,
  }) async {
    final usedIds = {
      for (final m in _medications)
        for (final dose in m.doses) dose.notificationId,
    };
    medication = _withUniqueDoseIds(
      medication,
      usedIds,
      salt: _medications.length,
    );
    _medications.add(medication);
    await _saveMedications();
    await _hiveService.getProfileBox().put('medication_reminder_enabled', true);

    var notificationScheduled = true;
    if (medication.isActive) {
      final hasPermission = await NotificationService().requestPermissions();
      if (hasPermission) {
        await _scheduleMedication(
          medication,
          requestExactPermission: requestExactPermission,
        );
      } else {
        notificationScheduled = false;
      }
    }
    notifyListeners();
    return notificationScheduled;
  }

  /// Kayıtlı ilacın doz saatlerini değiştirir: saat ekler, çıkarır veya
  /// değiştirir. [doses] içinde bu ilaca ait kimliği taşıyan doz, kayıtlı
  /// dozun kendisidir ve kimliğiyle birlikte doz günlüğündeki geçmişini
  /// korur; diğerleri yeni saattir ve tekil yeni kimlik alır. Yalnızca
  /// kaldırılan, eklenen ve saati değişen dozların bildirimine dokunulur.
  /// Hatırlatmalar kurulamadıysa (izin yok, hata) false döner.
  ///
  /// Saati değişen doz kimliğini korur. Böylece bugün "Aldım" denmiş doz
  /// yeni saatinde yeniden "bekliyor" görünmez (aynı gün ikinci kez alınma
  /// riski) ve dozun geçmişi uyum tablosundan düşmez. Bedeli: değişiklikten
  /// önceki kayıtların gecikmesi yeni saate göre hesaplanır. Bu yalnızca
  /// "geç alıyorsunuz" önerisini etkiler ve o kayıtlar 7 günlük pencereden
  /// çıkınca kendiliğinden düzelir.
  Future<bool> updateMedicationDoses(
    int index,
    List<MedicationDose> doses, {
    DateTime? now,
  }) async {
    if (index < 0 || index >= _medications.length) return true;
    final previous = _medications[index];
    final previousById = {
      for (final dose in previous.doses) dose.notificationId: dose,
    };
    final incomingIds = {for (final dose in doses) dose.notificationId};
    final removed = [
      for (final dose in previous.doses)
        if (!incomingIds.contains(dose.notificationId)) dose,
    ];
    // Yeni saat başka bir dozun kimliğini alamaz; kaldırılan dozunkini de
    // alamaz ki onun geçmişi yeni saate geçmesin.
    final usedIds = {
      for (final (i, medication) in _medications.indexed)
        if (i != index)
          for (final dose in medication.doses) dose.notificationId,
      for (final dose in removed) dose.notificationId,
    };
    final unique = _withUniqueDoseIds(
      previous.copyWith(doses: doses),
      usedIds,
      salt: index,
    );
    final addedAt = now ?? DateTime.now();
    final medication = unique.copyWith(
      doses: [
        for (final dose in unique.doses)
          previousById.containsKey(dose.notificationId)
              ? dose
              : dose.copyWith(addedAt: addedAt),
      ],
    );
    _medications[index] = medication;
    await _saveMedications();
    notifyListeners();

    // Kalan dozlardan yalnızca saati değişenler yeniden kurulur; aynı
    // kimlikle kurulan bildirim eskisinin yerini alır.
    final changed = [
      for (final dose in medication.doses)
        if (previousById[dose.notificationId]?.minuteOfDay != dose.minuteOfDay)
          dose,
    ];
    try {
      for (final dose in removed) {
        await NotificationService().cancelMedicationDose(dose);
      }
      if (changed.isEmpty || !medication.isActive || !_remindersEnabled) {
        return true;
      }
      if (!await NotificationService().requestPermissions()) return false;
      for (final dose in changed) {
        await NotificationService().scheduleMedicationDose(medication, dose);
      }
      return true;
    } catch (error) {
      debugPrint('İlaç bildirimleri güncellenemedi: $error');
      return false;
    }
  }

  Future<void> removeMedication(int index) async {
    if (index >= 0 && index < _medications.length) {
      final medication = _medications.removeAt(index);
      await NotificationService().cancelMedicationReminders(medication);
      await _saveMedications();
      notifyListeners();
    }
  }

  Future<void> _saveMedications() async {
    await _hiveService.getMedicationBox().put(
      'medications',
      _medications.map((m) => m.toMap()).toList(),
    );
  }

  /// Ayarlardaki ilaç hatırlatıcıları açık mı? Ayar hiç kaydedilmediyse
  /// ilaç varken açık sayılır.
  bool get _remindersEnabled =>
      _hiveService.getProfileBox().get(
            'medication_reminder_enabled',
            defaultValue: _medications.isNotEmpty,
          )
          as bool;

  Future<void> _restoreMedicationNotifications() async {
    try {
      final enabled = _remindersEnabled;
      final pendingIds = await NotificationService().pendingNotificationIds();

      for (final medication in _medications) {
        if (!enabled || !medication.isActive) {
          await NotificationService().cancelMedicationReminders(medication);
          continue;
        }
        // Her doz ayrı bildirimdir; yalnızca kurulu olmayanlar kurulur.
        for (final dose in medication.doses) {
          if (pendingIds.contains(dose.notificationId)) continue;
          await NotificationService().scheduleMedicationDose(medication, dose);
        }
      }
    } catch (error) {
      debugPrint('İlaç bildirimleri geri yüklenemedi: $error');
    }
  }

  Future<bool> setMedicationRemindersEnabled(bool enabled) async {
    await _hiveService.getProfileBox().put(
      'medication_reminder_enabled',
      enabled,
    );

    if (!enabled) {
      await Future.wait(
        _medications.map(NotificationService().cancelMedicationReminders),
      );
      return true;
    }

    final hasPermission = await NotificationService().requestPermissions();
    if (!hasPermission) return false;

    for (final medication in _medications.where((item) => item.isActive)) {
      await _scheduleMedication(medication);
    }
    return true;
  }

  Future<void> _scheduleMedication(
    MedicationReminder medication, {
    bool requestExactPermission = false,
  }) {
    return NotificationService().scheduleMedicationReminder(
      medication,
      requestExactPermission: requestExactPermission,
    );
  }

  // Blood sugar status
  SugarAssessment assessSugar(HealthEntry entry) =>
      assessBloodSugar(entry.value, SugarTiming.parse(entry.timing));
}
