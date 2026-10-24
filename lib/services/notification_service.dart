import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/app_constants.dart';
import '../modules/m03_chronic/models/health_entry.dart';
import 'hive_service.dart';
import 'notification_actions.dart';
import 'notification_visuals.dart';

export 'notification_visuals.dart' show NotificationKind;

class NotificationIds {
  NotificationIds._();

  static const List<int> water = [1001, 1002, 1003];
  static const int exercise = 1101;
  static const int medicationStart = 10000;

  /// Ayarlar > "Bildirimleri önizle" için.
  static const List<int> preview = [901, 902, 903];

  /// Ertelenen ilaç bildirimi; günlük planlı bildirimin yerine geçmemesi
  /// için negatif kimlik kullanılır (ilaç kimlikleri hep pozitiftir).
  static int snoozeFor(int medicationId) => -1 - (medicationId % 1000000);
}

/// Bildirim eylem düğmesi kimlikleri.
class NotificationActionIds {
  NotificationActionIds._();

  static const String medicationTaken = 'med_taken';
  static const String medicationSnooze = 'med_snooze';
  static const String waterAdd = 'water_add';
}

/// Bildirimle birlikte taşınan, dokunulduğunda/eylemde kullanılan veri.
class NotificationPayload {
  final NotificationKind kind;
  final String? route;

  /// İlaç bildiriminde dozun bildirim kimliği. Eski tek saatli ilacın
  /// kimliği göçte ilk dozuna geçtiği için önceden kurulan bildirimler de
  /// doğru doza işlenir.
  final int? doseId;
  final String? name;
  final String? dosage;
  final int? hour;
  final int? minute;

  const NotificationPayload({
    required this.kind,
    this.route,
    this.doseId,
    this.name,
    this.dosage,
    this.hour,
    this.minute,
  });

  String encode() => jsonEncode({
    'k': kind.name,
    if (route != null) 'r': route,
    if (doseId != null) 'id': doseId,
    if (name != null) 'n': name,
    if (dosage != null) 'd': dosage,
    if (hour != null) 'h': hour,
    if (minute != null) 'm': minute,
  });

  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final kind = NotificationKind.values.firstWhere(
        (k) => k.name == map['k'],
        orElse: () => NotificationKind.general,
      );
      return NotificationPayload(
        kind: kind,
        route: map['r'] as String?,
        doseId: (map['id'] as num?)?.toInt(),
        name: map['n'] as String?,
        dosage: map['d'] as String?,
        hour: (map['h'] as num?)?.toInt(),
        minute: (map['m'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Bildirimde gösterilecek metinler.
class NotificationContent {
  final NotificationKind kind;
  final String title;
  final String body;

  /// Başlık satırında uygulama adının yanında görünen kısa etiket.
  final String summary;
  final NotificationPayload payload;

  const NotificationContent({
    required this.kind,
    required this.title,
    required this.body,
    required this.summary,
    required this.payload,
  });

  /// İlacın tek bir dozunun bildirimi; "Aldım" ve "10 dk sonra" dozu
  /// bildirim verisindeki kimlik ve saatten tanır.
  factory NotificationContent.medication(
    MedicationReminder med,
    MedicationDose dose, {
    bool snoozed = false,
  }) {
    final dosage = med.dosage.trim();
    return NotificationContent(
      kind: NotificationKind.medication,
      title: snoozed ? 'Hatırlatma: ${med.name}' : 'İlaç zamanı: ${med.name}',
      body:
          '${dosage.isEmpty ? '' : '$dosage · '}${dose.timeDisplay} dozu. '
          'Aldıysanız "Aldım"a dokunun; ilaç uyumunuza işlenir.',
      summary: 'İlaç hatırlatıcısı',
      payload: NotificationPayload(
        kind: NotificationKind.medication,
        route: AppConstants.routeChronic,
        doseId: dose.notificationId,
        name: med.name,
        dosage: dosage,
        hour: dose.hour,
        minute: dose.minute,
      ),
    );
  }

  /// Günün üç su hatırlatması; her biri farklı ve bilgilendirici.
  static const List<(String, String)> _waterTexts = [
    (
      'Su molası',
      'Güne iyi başlamak için bir bardak su için. Günlük hedefiniz 2,5 litre '
          '(10 bardak).',
    ),
    (
      'Öğleden sonra su hatırlatması',
      'Öğleden sonraki yorgunluk ve baş ağrısı çoğu zaman susuzluktandır. '
          'Bir bardak su için.',
    ),
    (
      'Günün su hedefi',
      'Günü tamamlamadan su hedefinize ne kadar yaklaştığınıza bakın; bir '
          'bardak daha için.',
    ),
  ];

  factory NotificationContent.water(int index) {
    final text = _waterTexts[index % _waterTexts.length];
    return NotificationContent(
      kind: NotificationKind.water,
      title: text.$1,
      body: text.$2,
      summary: 'Su hatırlatıcısı',
      payload: const NotificationPayload(
        kind: NotificationKind.water,
        route: AppConstants.routeNutrition,
      ),
    );
  }

  factory NotificationContent.activity() => const NotificationContent(
    kind: NotificationKind.activity,
    title: 'Hareket zamanı',
    body:
        'Günlük 10.000 adım hedefiniz için 20 dakikalık tempolu bir yürüyüş '
        'iyi bir başlangıç. Adımlarınızı uygulamadan takip edin.',
    summary: 'Hareket hatırlatıcısı',
    payload: NotificationPayload(
      kind: NotificationKind.activity,
      route: AppConstants.routeFitness,
    ),
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _exactAlarmPermissionGranted = false;
  bool _initialized = false;

  /// Uygulama bir bildirime dokunularak açıldıysa gidilecek ekran.
  String? _launchRoute;

  static const String _smallIcon = 'ic_stat_vitacoach';
  static const String _medicationCategory = 'vc_medication';
  static const String _waterCategory = 'vc_water';

  /// Bildirim görünümü sürümü. Değişince eski planlı bildirimler yeni
  /// tasarımla yeniden kurulur.
  static const int _styleVersion = 2;
  static const List<String> _legacyChannels = [
    'vitacoach_daily',
    'vitacoach_general',
  ];

  static const Map<NotificationKind, AndroidNotificationChannel> _channels = {
    NotificationKind.medication: AndroidNotificationChannel(
      'vc_medication',
      'İlaç hatırlatıcıları',
      description: 'İlaç saatleriniz geldiğinde "Aldım" düğmeli hatırlatma',
      importance: Importance.high,
    ),
    NotificationKind.water: AndroidNotificationChannel(
      'vc_water',
      'Su hatırlatıcıları',
      description: 'Gün içinde su içmeyi hatırlatır',
    ),
    NotificationKind.activity: AndroidNotificationChannel(
      'vc_activity',
      'Hareket hatırlatıcıları',
      description: 'Günlük hareket hedefinizi hatırlatır',
    ),
    NotificationKind.general: AndroidNotificationChannel(
      'vc_general',
      'Genel bildirimler',
      description: 'VitaCoach sağlık bildirimleri',
    ),
  };

  InitializationSettings get _initSettings => InitializationSettings(
    android: const AndroidInitializationSettings(_smallIcon),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _medicationCategory,
          actions: [
            DarwinNotificationAction.plain(
              NotificationActionIds.medicationTaken,
              'Aldım',
            ),
            DarwinNotificationAction.plain(
              NotificationActionIds.medicationSnooze,
              '10 dk sonra',
            ),
          ],
        ),
        DarwinNotificationCategory(
          _waterCategory,
          actions: [
            DarwinNotificationAction.plain(
              NotificationActionIds.waterAdd,
              '+1 bardak içtim',
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> init() async {
    await _initTimeZone();
    await _plugin.initialize(
      settings: _initSettings,
      onDidReceiveNotificationResponse:
          NotificationActions.onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    _initialized = true;
    await _createChannels();
    // İzin daha önce verildiyse hatırlatmalar tam zamanında kurulsun.
    await canScheduleExactAlarms();

    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final response = launch!.notificationResponse;
        if (response != null &&
            (response.actionId == null || response.actionId!.isEmpty)) {
          _launchRoute = NotificationPayload.decode(response.payload)?.route;
        }
      }
    } catch (error) {
      debugPrint('Bildirim açılış bilgisi okunamadı: $error');
    }

    await _migrateStyleIfNeeded();
  }

  /// Arka plan eylemi (ör. "10 dk sonra") için hafif başlatma. Ana
  /// isolate'teki geri çağrıları korumak için aynı işleyicilerle kurulur.
  Future<void> initForBackground() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: _initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    _initialized = true;
  }

  /// Bir kez okunur: açılış ekranı yönlendirme yaptıktan sonra kullanılır.
  String? takeLaunchRoute() {
    final route = _launchRoute;
    _launchRoute = null;
    return route;
  }

  Future<void> _initTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      debugPrint('Timezone hatası: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;
    for (final channel in _channels.values) {
      await android.createNotificationChannel(channel);
    }
  }

  /// Önceki sürümün tek tip, simgesi bozuk bildirimlerini yeni tasarımla
  /// değiştirir. İlaç bildirimleri ChronicProvider açılışta eksik olanları
  /// yeniden kurduğu için burada yalnızca iptal edilir.
  Future<void> _migrateStyleIfNeeded() async {
    try {
      final settings = HiveService().getSettingsBox();
      final version = settings.get(
        'notification_style_version',
        defaultValue: 1,
      );
      if (version is int && version >= _styleVersion) return;

      await _plugin.cancelAll();
      final android = _android;
      if (android != null) {
        for (final id in _legacyChannels) {
          await android.deleteNotificationChannel(channelId: id);
        }
      }
      final profile = HiveService().getProfileBox();
      if (profile.get('water_reminder_enabled') == true) {
        await setWaterRemindersEnabled(true);
      }
      if (profile.get('exercise_reminder_enabled') == true) {
        await setExerciseReminderEnabled(true);
      }
      await settings.put('notification_style_version', _styleVersion);
    } catch (error) {
      debugPrint('Bildirim geçişi yapılamadı: $error');
    }
  }

  /// Android 12+ "Alarmlar ve hatırlatıcılar" izni (tam zamanlı bildirim).
  Future<bool> canScheduleExactAlarms() async {
    try {
      final android = _android;
      if (android == null) return true;
      _exactAlarmPermissionGranted =
          await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      _exactAlarmPermissionGranted = false;
    }
    return _exactAlarmPermissionGranted;
  }

  /// Sistem "Alarmlar ve hatırlatıcılar" sayfasını açar.
  Future<void> requestExactAlarmPermission() async {
    try {
      _exactAlarmPermissionGranted =
          await _android?.requestExactAlarmsPermission() ?? true;
    } catch (error) {
      debugPrint('Tam zamanlı alarm izni istenemedi: $error');
    }
  }

  Future<bool> requestPermissions() async {
    var isGranted = true;
    final android = _android;
    if (android != null) {
      final result = await android.requestNotificationsPermission();
      if (result != null) isGranted = result;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (result != null) isGranted = result;
    }
    return isGranted;
  }

  List<AndroidNotificationAction>? _androidActions(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.medication:
        return const [
          AndroidNotificationAction(
            NotificationActionIds.medicationTaken,
            'Aldım',
            titleColor: Color(0xFF2A7D4F),
          ),
          AndroidNotificationAction(
            NotificationActionIds.medicationSnooze,
            '10 dk sonra',
          ),
        ];
      case NotificationKind.water:
        return const [
          AndroidNotificationAction(
            NotificationActionIds.waterAdd,
            '+1 bardak içtim',
            titleColor: Color(0xFF1E88E5),
          ),
        ];
      case NotificationKind.activity:
      case NotificationKind.general:
        return null;
    }
  }

  NotificationDetails _details(
    NotificationContent content, {
    Uint8List? largeIcon,
  }) {
    final kind = content.kind;
    final channel = _channels[kind]!;
    final isMedication = kind == NotificationKind.medication;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: isMedication ? Priority.high : Priority.defaultPriority,
        icon: _smallIcon,
        color: NotificationVisuals.colorOf(kind),
        largeIcon: largeIcon == null ? null : ByteArrayAndroidBitmap(largeIcon),
        styleInformation: BigTextStyleInformation(
          content.body,
          contentTitle: content.title,
          summaryText: content.summary,
        ),
        subText: content.summary,
        ticker: content.title,
        category: AndroidNotificationCategory.reminder,
        // İlaç adı sağlık verisidir: kilitli ekranda içerik gizlenir.
        visibility: isMedication
            ? NotificationVisibility.private
            : NotificationVisibility.public,
        actions: _androidActions(kind),
      ),
      iOS: DarwinNotificationDetails(
        subtitle: content.summary,
        threadIdentifier: kind.name,
        categoryIdentifier: switch (kind) {
          NotificationKind.medication => _medicationCategory,
          NotificationKind.water => _waterCategory,
          _ => null,
        },
      ),
    );
  }

  Future<NotificationDetails> _detailsWithIcon(NotificationContent c) async =>
      _details(c, largeIcon: await NotificationVisuals.largeIcon(c.kind));

  Future<void> showContent(int id, NotificationContent content) async {
    await _plugin.show(
      id: id,
      title: content.title,
      body: content.body,
      notificationDetails: await _detailsWithIcon(content),
      payload: content.payload.encode(),
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return showContent(
      id,
      NotificationContent(
        kind: NotificationKind.general,
        title: title,
        body: body,
        summary: 'VitaCoach',
        payload:
            NotificationPayload.decode(payload) ??
            const NotificationPayload(kind: NotificationKind.general),
      ),
    );
  }

  /// Her doz saati, kimliği dozun kimliği olan ayrı bir günlük bildirimdir.
  Future<void> scheduleMedicationReminder(
    MedicationReminder medication, {
    bool requestExactPermission = false,
  }) async {
    for (final (index, dose) in medication.doses.indexed) {
      await scheduleMedicationDose(
        medication,
        dose,
        // Sistem izin sayfası ilaç başına bir kez açılır.
        requestExactPermission: requestExactPermission && index == 0,
      );
    }
  }

  Future<void> scheduleMedicationDose(
    MedicationReminder medication,
    MedicationDose dose, {
    bool requestExactPermission = false,
  }) {
    return scheduleDailyContent(
      id: dose.notificationId,
      content: NotificationContent.medication(medication, dose),
      hour: dose.hour,
      minute: dose.minute,
      requestExactPermission: requestExactPermission,
    );
  }

  /// İlacın tüm doz bildirimlerini ve ertelenmiş hatırlatmalarını kaldırır.
  Future<void> cancelMedicationReminders(MedicationReminder medication) async {
    for (final dose in medication.doses) {
      await cancelNotification(dose.notificationId);
      await cancelNotification(NotificationIds.snoozeFor(dose.notificationId));
    }
  }

  Future<void> scheduleDailyContent({
    required int id,
    required NotificationContent content,
    required int hour,
    required int minute,
    bool requestExactPermission = false,
  }) async {
    final details = await _detailsWithIcon(content);
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (requestExactPermission) {
      final android = _android;
      if (android != null) {
        _exactAlarmPermissionGranted =
            await android.requestExactAlarmsPermission() ?? false;
      }
    }

    await _scheduleWithFallback(
      id: id,
      content: content,
      scheduledDate: scheduledDate,
      details: details,
      daily: true,
    );
  }

  /// Ertelenen ilaç hatırlatması (10 dakika sonra, tek seferlik). Aynı dozun
  /// kimliğini ve saatini taşır; "Aldım"ı yine o doza işlenir.
  Future<void> snoozeMedication(
    NotificationPayload payload, {
    Duration delay = const Duration(minutes: 10),
  }) async {
    final id = payload.doseId;
    if (id == null || payload.name == null) return;
    final dose = MedicationDose(
      notificationId: id,
      hour: payload.hour ?? 0,
      minute: payload.minute ?? 0,
    );
    final med = MedicationReminder(
      name: payload.name!,
      dosage: payload.dosage ?? '',
      doses: [dose],
    );
    final content = NotificationContent.medication(med, dose, snoozed: true);
    // Arka plan motorunda görsel çizimi desteklenmeyebilir; simgesiz göster.
    await _scheduleWithFallback(
      id: NotificationIds.snoozeFor(id),
      content: content,
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(delay),
      details: _details(content),
      daily: false,
    );
  }

  Future<void> _scheduleWithFallback({
    required int id,
    required NotificationContent content,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required bool daily,
  }) async {
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: id,
      title: content.title,
      body: content.body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: mode,
      matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      payload: content.payload.encode(),
    );

    final mode = _exactAlarmPermissionGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await schedule(mode);
    } on PlatformException {
      if (mode != AndroidScheduleMode.exactAllowWhileIdle) rethrow;
      _exactAlarmPermissionGranted = false;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  Future<Set<int>> pendingNotificationIds() async {
    final requests = await _plugin.pendingNotificationRequests();
    return requests.map((request) => request.id).toSet();
  }

  Future<void> setWaterRemindersEnabled(bool enabled) async {
    if (!enabled) {
      await Future.wait(NotificationIds.water.map(cancelNotification));
      return;
    }

    const times = [(10, 0), (14, 0), (18, 0)];
    for (var index = 0; index < NotificationIds.water.length; index++) {
      final time = times[index];
      await scheduleDailyContent(
        id: NotificationIds.water[index],
        content: NotificationContent.water(index),
        hour: time.$1,
        minute: time.$2,
      );
    }
  }

  Future<void> setExerciseReminderEnabled(bool enabled) async {
    if (!enabled) {
      await cancelNotification(NotificationIds.exercise);
      return;
    }
    await scheduleDailyContent(
      id: NotificationIds.exercise,
      content: NotificationContent.activity(),
      hour: 19,
      minute: 0,
    );
  }

  /// Ayarlar ekranından: üç bildirim türünü hemen göstererek tasarımı
  /// ve eylem düğmelerini denemeyi sağlar.
  Future<bool> showPreview({MedicationReminder? medication}) async {
    try {
      return await _showPreview(medication: medication);
    } catch (error) {
      debugPrint('Bildirim önizlemesi gösterilemedi: $error');
      return false;
    }
  }

  Future<bool> _showPreview({MedicationReminder? medication}) async {
    final granted = await requestPermissions();
    if (!granted) return false;
    final med =
        medication ??
        MedicationReminder(
          name: 'Örnek ilaç',
          dosage: '1 tablet',
          doses: [
            MedicationDose(
              notificationId: 999999,
              hour: TimeOfDay.now().hour,
              minute: TimeOfDay.now().minute,
            ),
          ],
        );
    await showContent(
      NotificationIds.preview[0],
      NotificationContent.medication(med, med.doses.first),
    );
    await showContent(NotificationIds.preview[1], NotificationContent.water(1));
    await showContent(
      NotificationIds.preview[2],
      NotificationContent.activity(),
    );
    return true;
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
