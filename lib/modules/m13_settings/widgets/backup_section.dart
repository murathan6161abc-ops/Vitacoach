import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/app_state_service.dart';
import '../../../services/backup_service.dart';
import '../../../services/hive_service.dart';
import '../../../services/notification_service.dart';
import '../../../shared/widgets/vc_card.dart';

/// Ayarlar > Veri Yedekleme: parolayla şifrelenmiş yedek alma ve geri
/// yükleme. Telefon değişince veya uygulama silinince sağlık geçmişini
/// korumanın tek yolu budur.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final password = await _askNewPassword();
    if (password == null || !mounted) return;
    final shareOrigin = _shareOrigin();
    setState(() => _busy = true);
    try {
      final backup = await BackupService().export(password);
      final dir = await getTemporaryDirectory();
      final day = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/vitacoach-yedek-$day.json');
      await file.writeAsString(backup, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'VitaCoach şifreli yedek',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (e) {
      debugPrint('Yedek oluşturulamadı: $e');
      _snack('Yedek oluşturulamadı.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// iPad'de paylaşım penceresinin konumu.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Yedek dosyasını seçin',
    );
    if (picked == null || !mounted) return;
    final String backup;
    try {
      backup = utf8.decode(await picked.readAsBytes());
    } catch (_) {
      _snack('Dosya okunamadı.');
      return;
    }
    final password = await _askPassword();
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final created = await BackupService().restore(backup, password);
      await _applyRestoredData();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Yedek geri yüklendi'),
          content: Text(
            created == null
                ? 'Verileriniz yedekteki haliyle geri yüklendi.'
                : 'Verileriniz ${created.day}.${created.month}.${created.year} '
                      'tarihli yedekteki haliyle geri yüklendi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go(AppConstants.routeHome);
      AppStateService().restartProviders();
    } on BackupException catch (e) {
      _snack(e.message);
    } catch (e) {
      debugPrint('Yedek geri yüklenemedi: $e');
      _snack('Yedek geri yüklenemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Görünüm tercihleri ve hatırlatıcılar geri yüklenen veriye uyarlanır.
  /// İlaç hatırlatıcıları ChronicProvider yeniden kurulunca planlanır.
  Future<void> _applyRestoredData() async {
    AppSettingsService().load();
    final profile = HiveService().getProfileBox();
    try {
      final notifications = NotificationService();
      await notifications.cancelAll();
      await notifications.setWaterRemindersEnabled(
        profile.get('water_reminder_enabled') == true,
      );
      await notifications.setExerciseReminderEnabled(
        profile.get('exercise_reminder_enabled') == true,
      );
    } catch (e) {
      debugPrint('Hatırlatıcılar yeniden kurulamadı: $e');
    }
  }

  Future<String?> _askNewPassword() {
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Şifreli yedek al'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yedek bu parolayla şifrelenir. Parolayı unutursanız yedek '
                  'açılamaz; kimse kurtaramaz.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: first,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Parola'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: second,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Parola (tekrar)',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (first.text.length < BackupService.minPasswordLength) {
                  setDialogState(
                    () => error =
                        'Parola en az ${BackupService.minPasswordLength} '
                        'karakter olmalı.',
                  );
                } else if (first.text != second.text) {
                  setDialogState(() => error = 'Parolalar aynı değil.');
                } else {
                  Navigator.pop(ctx, first.text);
                }
              },
              child: const Text('Yedeği oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedekten geri yükle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bu telefondaki tüm VitaCoach verileri yedektekiyle '
              'değiştirilecek.',
              style: TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Yedek parolası'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VcCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          ListTile(
            leading: Icon(Icons.backup, color: AppColors.primary),
            title: const Text(
              'Şifreli yedek al',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Tüm verileri parolalı bir dosyaya kaydedip paylaşın',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_busy,
            onTap: _export,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.settings_backup_restore,
              color: AppColors.secondary,
            ),
            title: const Text(
              'Yedekten geri yükle',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Başka telefondan veya yeniden kurulumdan sonra',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_busy,
            onTap: _restore,
          ),
        ],
      ),
    );
  }
}
