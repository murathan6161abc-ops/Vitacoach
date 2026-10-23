import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Bildirim türleri: her birinin kendi kanalı, rengi ve simgesi vardır.
enum NotificationKind { medication, water, activity, general }

/// Bildirimlerde sağda görünen büyük, renkli simgeleri cihazda çizer.
/// Ayrı görsel dosyası gerekmez; simgeler uygulamanın Material ikonlarıdır.
class NotificationVisuals {
  NotificationVisuals._();

  static final Map<NotificationKind, Uint8List> _cache = {};

  static Color colorOf(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.medication:
        return const Color(0xFF2A7D4F);
      case NotificationKind.water:
        return const Color(0xFF1E88E5);
      case NotificationKind.activity:
        return const Color(0xFFF4511E);
      case NotificationKind.general:
        return const Color(0xFF00897B);
    }
  }

  static IconData iconOf(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.medication:
        return Icons.medication_rounded;
      case NotificationKind.water:
        return Icons.water_drop_rounded;
      case NotificationKind.activity:
        return Icons.directions_walk_rounded;
      case NotificationKind.general:
        return Icons.favorite_rounded;
    }
  }

  /// Degrade daire içinde beyaz simge (PNG). Çizilemezse null döner ve
  /// bildirim büyük simgesiz gösterilir.
  static Future<Uint8List?> largeIcon(NotificationKind kind) async {
    final cached = _cache[kind];
    if (cached != null) return cached;
    try {
      const size = 192.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const rect = Rect.fromLTWH(0, 0, size, size);
      final base = colorOf(kind);
      final hsl = HSLColor.fromColor(base);
      final light = hsl
          .withLightness((hsl.lightness + 0.12).clamp(0, 1))
          .toColor();
      final dark = hsl
          .withLightness((hsl.lightness - 0.10).clamp(0, 1))
          .toColor();
      canvas.drawCircle(
        rect.center,
        size / 2,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, dark],
          ).createShader(rect),
      );
      final icon = iconOf(kind);
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: size * 0.54,
            color: Colors.white,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        rect.center - Offset(painter.width / 2, painter.height / 2),
      );
      final image = await recorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      _cache[kind] = bytes;
      return bytes;
    } catch (error) {
      debugPrint('Bildirim simgesi çizilemedi: $error');
      return null;
    }
  }
}
