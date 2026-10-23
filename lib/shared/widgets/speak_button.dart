import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/app_settings_service.dart';
import '../../services/tts_service.dart';

/// Önemli metinleri sesli okur. Yalnızca Ayarlar > Erişilebilirlik >
/// "Sesli okuma" açıksa görünür.
class SpeakButton extends StatelessWidget {
  final String text;
  final String id;
  final Color? color;

  const SpeakButton({
    super.key,
    required this.text,
    required this.id,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Ayar değişikliğini dinler; açık bir ekranda da anında görünür/gizlenir.
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsService().settings,
      builder: (context, settings, _) {
        if (!settings.ttsEnabled) return const SizedBox.shrink();
        return _button(context);
      },
    );
  }

  Widget _button(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: TtsService().speakingId,
      builder: (context, speaking, _) {
        final isSpeaking = speaking == id;
        return IconButton(
          tooltip: isSpeaking ? 'Okumayı durdur' : 'Sesli oku',
          icon: Icon(
            isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up,
            color: color ?? AppColors.primary,
          ),
          onPressed: () async {
            final ok = await TtsService().speak(text, id: id);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Türkçe ses paketi bulunamadı. Cihaz ayarlarından '
                    '"Metin okuma" için Türkçe dilini yükleyin.',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
