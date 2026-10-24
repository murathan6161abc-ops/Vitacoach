import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modules/m03_chronic/models/health_entry.dart';
import '../modules/m03_chronic/models/medication_adherence.dart';
import 'hive_service.dart';
import 'notification_service.dart';

/// Bildirimdeki bir eylem (ör. "Aldım"). Arka planda kuyruğa yazılır,
/// uygulama öne gelince ana isolate'te veritabanına işlenir.
class PendingNotificationAction {
  final String action;

  /// İlaç eylemlerinde dozun bildirim kimliği.
  final int? doseId;
  final int? hour;
  final int? minute;
  final DateTime at;

  const PendingNotificationAction({
    required this.action,
    required this.at,
    this.doseId,
    this.hour,
    this.minute,
  });

  Map<String, dynamic> toJson() => {
    'a': action,
    't': at.toIso8601String(),
    if (doseId != null) 'id': doseId,
    if (hour != null) 'h': hour,
    if (minute != null) 'm': minute,
  };

  static PendingNotificationAction? fromJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse('${map['t']}');
      if (at == null || map['a'] is! String) return null;
      return PendingNotificationAction(
        action: map['a'] as String,
        at: at,
        doseId: (map['id'] as num?)?.toInt(),
        hour: (map['h'] as num?)?.toInt(),
        minute: (map['m'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Dozun ait olduğu gün. Gece yarısından sonra işaretlenen akşam dozu
  /// (ör. 23:00 dozu 00:30'da "Aldım") önceki güne yazılır.
  DateTime get doseDay {
    final day = DateTime(at.year, at.month, at.day);
    if (hour == null) return day;
    final pressedMinutes = at.hour * 60 + at.minute;
    final dueMinutes = hour! * 60 + (minute ?? 0);
    if (dueMinutes - pressedMinutes > 12 * 60) {
      return day.subtract(const Duration(days: 1));
    }
    return day;
  }
}

/// Hive tek isolate içindir; arka plan motoru ona dokunmaz. Eylemler
/// SharedPreferences üzerinden kuyruğa alınır.
class NotificationActionQueue {
  NotificationActionQueue._();

  static const String _key = 'vc_pending_notification_actions';

  static Future<void> enqueue(PendingNotificationAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.add(jsonEncode(action.toJson()));
    await prefs.setStringList(_key, list);
  }

  static Future<List<PendingNotificationAction>> drain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = prefs.getStringList(_key) ?? const <String>[];
    if (list.isEmpty) return const [];
    await prefs.remove(_key);
    return list
        .map(PendingNotificationAction.fromJson)
        .whereType<PendingNotificationAction>()
        .toList();
  }
}

/// Uygulama kapalıyken veya arka plandayken eylem düğmelerine basıldığında
/// eklenti tarafından ayrı bir motorda çağrılır.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await NotificationActions.handleAction(response, background: true);
  } catch (error) {
    debugPrint('Bildirim eylemi işlenemedi: $error');
  }
}

class NotificationActions {
  NotificationActions._();

  /// Veriler değiştiğinde ekranların yenilenmesi için (app.dart bağlar).
  static VoidCallback? onDataChanged;

  /// Bildirim gövdesine dokunulduğunda gidilecek ekran (app.dart bağlar).
  static void Function(String route)? onOpenRoute;

  /// Ana isolate: bildirime veya (iOS'ta) eylem düğmesine dokunuldu.
  static Future<void> onForegroundResponse(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) {
      final route = NotificationPayload.decode(response.payload)?.route;
      if (route != null) onOpenRoute?.call(route);
      return;
    }
    await handleAction(response, background: false);
    await applyPending();
  }

  static Future<void> handleAction(
    NotificationResponse response, {
    required bool background,
  }) async {
    final payload = NotificationPayload.decode(response.payload);
    final now = DateTime.now();
    switch (response.actionId) {
      case NotificationActionIds.medicationTaken:
        await NotificationActionQueue.enqueue(
          PendingNotificationAction(
            action: NotificationActionIds.medicationTaken,
            at: now,
            doseId: payload?.doseId,
            hour: payload?.hour,
            minute: payload?.minute,
          ),
        );
      case NotificationActionIds.waterAdd:
        await NotificationActionQueue.enqueue(
          PendingNotificationAction(
            action: NotificationActionIds.waterAdd,
            at: now,
          ),
        );
      case NotificationActionIds.medicationSnooze:
        if (payload == null) return;
        if (background) await NotificationService().initForBackground();
        await NotificationService().snoozeMedication(payload);
    }
  }

  /// Kuyruktaki eylemleri Hive'a işler. Yalnızca ana isolate'te çağrılır
  /// (açılışta ve uygulama öne geldiğinde).
  static Future<int> applyPending() async {
    final actions = await NotificationActionQueue.drain();
    if (actions.isEmpty) return 0;
    final hive = HiveService();
    final medBox = hive.getMedicationBox();
    final log = DoseLog.fromRaw(medBox.get('dose_log'));
    // Silinmiş ilaçlara veya önizleme bildirimine ait eylemler yok sayılır.
    final knownIds = <int>{
      for (final m in (medBox.get('medications') as List? ?? const []))
        if (m is Map) ..._doseIdsOf(m),
    };
    var doseChanged = false;

    for (final action in actions) {
      switch (action.action) {
        case NotificationActionIds.medicationTaken:
          final id = action.doseId;
          if (id == null || !knownIds.contains(id)) continue;
          final day = action.doseDay;
          if (log.get(day, id)?.status == DoseStatus.taken) continue;
          log.set(day, id, DoseRecord(status: DoseStatus.taken, at: action.at));
          doseChanged = true;
        case NotificationActionIds.waterAdd:
          final box = hive.getNutritionBox();
          final key = 'water_${DoseLog.dayKey(action.at)}';
          final current = box.get(key, defaultValue: 0);
          await box.put(key, (current is int ? current : 0) + 1);
      }
    }
    if (doseChanged) await medBox.put('dose_log', log.toRaw());
    onDataChanged?.call();
    return actions.length;
  }

  /// Kayıtlı ilacın doz kimlikleri; eski tek saatli kayıtta ilacın kimliği.
  static Iterable<int> _doseIdsOf(Map<dynamic, dynamic> raw) {
    try {
      final medication = MedicationReminder.fromMap(raw);
      return medication.doses.map((dose) => dose.notificationId);
    } catch (_) {
      return const [];
    }
  }
}
