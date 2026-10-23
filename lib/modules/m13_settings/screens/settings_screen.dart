import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/app_state_service.dart';
import '../../../services/demo_data_service.dart';
import '../../../services/demo_mode.dart';
import '../widgets/backup_section.dart';
import '../../../services/tts_service.dart';
import '../../../services/hive_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/secure_storage_service.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../m03_chronic/providers/chronic_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hiveService = HiveService();
  bool _waterReminderEnabled = false;
  bool _medicationReminderEnabled = false;
  bool _exerciseReminderEnabled = false;
  bool _isUpdatingReminder = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = _hiveService.getProfileBox();
    final hasMedication = context
        .read<ChronicProvider>()
        .medications
        .isNotEmpty;
    if (!mounted) return;
    setState(() {
      _waterReminderEnabled =
          box.get('water_reminder_enabled', defaultValue: false) as bool;
      _medicationReminderEnabled =
          box.get('medication_reminder_enabled', defaultValue: hasMedication)
              as bool;
      _exerciseReminderEnabled =
          box.get('exercise_reminder_enabled', defaultValue: false) as bool;
    });
  }

  Future<void> _updateReminder(String key, bool value) async {
    if (_isUpdatingReminder) return;
    final chronicProvider = context.read<ChronicProvider>();
    setState(() => _isUpdatingReminder = true);

    var appliedValue = value;
    try {
      if (value && key != 'medication_reminder_enabled') {
        appliedValue = await NotificationService().requestPermissions();
      }

      if (appliedValue) {
        if (key == 'water_reminder_enabled') {
          await NotificationService().setWaterRemindersEnabled(true);
        } else if (key == 'exercise_reminder_enabled') {
          await NotificationService().setExerciseReminderEnabled(true);
        } else {
          appliedValue = await chronicProvider.setMedicationRemindersEnabled(
            true,
          );
        }
      } else {
        if (key == 'water_reminder_enabled') {
          await NotificationService().setWaterRemindersEnabled(false);
        } else if (key == 'exercise_reminder_enabled') {
          await NotificationService().setExerciseReminderEnabled(false);
        } else {
          await chronicProvider.setMedicationRemindersEnabled(false);
        }
      }
    } catch (_) {
      appliedValue = false;
    }

    if (!mounted) return;
    setState(() {
      if (key == 'water_reminder_enabled') {
        _waterReminderEnabled = appliedValue;
      } else if (key == 'medication_reminder_enabled') {
        _medicationReminderEnabled = appliedValue;
      } else {
        _exerciseReminderEnabled = appliedValue;
      }
      _isUpdatingReminder = false;
    });

    final profileBox = _hiveService.getProfileBox();
    await profileBox.put(key, appliedValue);
    await profileBox.put(
      'notifications_enabled',
      _waterReminderEnabled ||
          _medicationReminderEnabled ||
          _exerciseReminderEnabled,
    );

    if (value && !appliedValue && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bildirim izni verilmedi veya hatırlatıcı kurulamadı.'),
        ),
      );
    }
  }

  Future<void> _resetAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hesabı Sıfırla',
          style: TextStyle(color: AppColors.danger),
        ),
        content: const Text(
          'Tüm verileriniz kalıcı olarak silinecektir. Bu işlem geri alınamaz. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Evet, Sil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService().cancelAll();
      await SecureStorageService().clearUserSecrets();
      await HiveService().clearAllData();
      if (context.mounted) {
        context.go(AppConstants.routeOnboarding);
        AppStateService().restartProviders();
      }
    }
  }

  Future<void> _previewNotifications() async {
    final shown = await NotificationService().showPreview();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown
              ? 'Örnek bildirimler gönderildi; bildirim panelini açıp '
                    'görebilirsiniz.'
              : 'Bildirim izni verilmedi. Cihaz ayarlarından izin verin.',
        ),
      ),
    );
  }

  Future<void> _updateAppearance(AppSettings next) async {
    if (!next.ttsEnabled) await TtsService().stop();
    await AppSettingsService().update(next);
  }

  Future<void> _loadDemoData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jüri Demo Verisi'),
        content: const Text(
          'Uygulama 2 haftalık örnek verilerle doldurulacak (profil, tansiyon, '
          'kan şekeri, ilaçlar, uyku, ruh hali, adımlar, risk skorları, acil '
          'kart). Mevcut tüm yerel verileriniz SİLİNECEK. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Demo verisini yükle'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DemoDataService.load();
    if (!mounted) return;
    context.go(AppConstants.routeHome);
    AppStateService().restartProviders();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // Ayarlar değişince bu bölüm yeniden çizilmeli. Tema/yazı boyutu tüm
  // uygulamayı yeniden kurduğu için görünüyordu; ancak "Sesli okuma" yalnızca
  // kaydediliyor, anahtar ise eski değerde kalıyordu.
  Widget _buildAppearanceSection() {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsService().settings,
      builder: (context, settings, _) => _appearanceCard(settings),
    );
  }

  Widget _appearanceCard(AppSettings settings) {
    return VcCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tema',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Açık'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Koyu'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('Sistem'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (v) => _updateAppearance(
                      settings.copyWith(themeMode: v.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.format_size),
            title: const Text(
              'Büyük yazı',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Tüm metinleri %25 büyütür',
              style: TextStyle(fontSize: 12),
            ),
            value: settings.largeText,
            onChanged: (v) =>
                _updateAppearance(settings.copyWith(largeText: v)),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.contrast),
            title: const Text(
              'Yüksek kontrast',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Daha belirgin metin ve kenarlıklar',
              style: TextStyle(fontSize: 12),
            ),
            value: settings.highContrast,
            onChanged: (v) =>
                _updateAppearance(settings.copyWith(highContrast: v)),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over),
            title: const Text(
              'Sesli okuma',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Önemli metinlerin yanında "sesli oku" düğmesi gösterir '
              '(cihazın kendi ses motoru, internet gerekmez)',
              style: TextStyle(fontSize: 12),
            ),
            value: settings.ttsEnabled,
            onChanged: (v) =>
                _updateAppearance(settings.copyWith(ttsEnabled: v)),
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          _sectionTitle('Görünüm ve Erişilebilirlik'),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          Text(
            'Bildirim Tercihleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          VcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Su Hatırlatıcı',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Günlük su tüketim hedefinizi hatırlatır',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _waterReminderEnabled,
                  activeTrackColor: AppColors.secondary,
                  onChanged: _isUpdatingReminder
                      ? null
                      : (value) =>
                            _updateReminder('water_reminder_enabled', value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text(
                    'İlaç Hatırlatıcı',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Kayıtlı ilaçlarınızın saatlerini hatırlatır',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _medicationReminderEnabled,
                  activeTrackColor: AppColors.secondary,
                  onChanged: _isUpdatingReminder
                      ? null
                      : (value) => _updateReminder(
                          'medication_reminder_enabled',
                          value,
                        ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text(
                    'Egzersiz Hatırlatıcı',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Fiziksel aktivite hedeflerinizi hatırlatır',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _exerciseReminderEnabled,
                  activeTrackColor: AppColors.secondary,
                  onChanged: _isUpdatingReminder
                      ? null
                      : (value) =>
                            _updateReminder('exercise_reminder_enabled', value),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Bildirimleri önizle',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'İlaç, su ve hareket bildirimlerini şimdi gösterir',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _previewNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Gizlilik ve Veri'),
          VcCard(
            padding: EdgeInsets.zero,
            child: _navTile(
              icon: Icons.privacy_tip_outlined,
              color: AppColors.primary,
              title: 'Gizlilik ve veri kullanımı',
              subtitle: 'Verileriniz nerede, ne zaman internete bağlanılır',
              onTap: () => context.push(AppConstants.routePrivacy),
            ),
          ),
          const SizedBox(height: 8),
          const BackupSection(),
          const SizedBox(height: 24),
          _sectionTitle('Acil Durum ve Raporlar'),
          VcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _navTile(
                  icon: Icons.medical_information,
                  color: AppColors.danger,
                  title: 'Acil Sağlık Kartı ve Acil Kişiler',
                  subtitle: 'Kan grubu, alerjiler, QR kod',
                  onTap: () => context.push(AppConstants.routeEmergencyCard),
                ),
                const Divider(height: 1),
                _navTile(
                  icon: Icons.picture_as_pdf,
                  color: AppColors.primary,
                  title: 'Doktor İçin PDF Rapor',
                  subtitle: 'Son 30 günün ölçümleri, ilaçlar, risk skorları',
                  onTap: () => context.push(AppConstants.routeReport),
                ),
              ],
            ),
          ),
          if (DemoMode.isAvailable()) ...[
            const SizedBox(height: 24),
            _sectionTitle('Sunum'),
            VcCard(
              padding: EdgeInsets.zero,
              child: _navTile(
                icon: Icons.slideshow,
                color: AppColors.accentProgress,
                title: 'Jüri Demo Verisi Yükle',
                subtitle: 'Uygulamayı 2 haftalık örnek verilerle doldurur',
                onTap: _loadDemoData,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Hesap Yönetimi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          VcCard(
            borderColor: AppColors.danger.withValues(alpha: 0.3),
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: AppColors.danger),
              title: Text(
                'Hesabı Sıfırla',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Tüm yerel verileri ve bildirimleri siler.'),
              onTap: () => _resetAccount(context),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _onVersionTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${AppConstants.appName} ${AppConstants.appVersion}',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _versionTaps = 0;

  /// Sunum (jüri demo) bölümü yayın sürümünde gizlidir; sürüm yazısına
  /// arka arkaya dokunulunca açılır.
  Future<void> _onVersionTap() async {
    if (DemoMode.isAvailable()) return;
    _versionTaps++;
    if (_versionTaps < DemoMode.tapsToUnlock) return;
    await DemoMode.unlock();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sunum bölümü açıldı.')));
  }
}
