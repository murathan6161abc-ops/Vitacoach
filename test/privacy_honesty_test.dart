import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/core/theme/app_theme.dart';
import 'package:vitacoach/services/demo_mode.dart';

import 'helpers/memory_hive.dart';

void main() {
  test('tema uygulamaya gömülü yazı tipini kullanır', () {
    final theme = AppTheme.build(dark: false, highContrast: false);
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, AppTheme.fontFamily);
    // Yazı tipi dosyası pubspec'te tanımlı ve gerçekten pakette.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: ${AppTheme.fontFamily}'));
    expect(pubspec, isNot(contains('google_fonts')));
    expect(File('assets/fonts/Roboto-Regular.ttf').existsSync(), isTrue);
  });

  test('kullanıcıya görünen metinlerde yapay zekâ iddiası yok', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (RegExp(r'[Yy]apay [Zz]ek[aâ] [Dd]estekli').hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  group('jüri demo düğmesi', () {
    setUp(openMemoryBoxes);
    tearDown(closeMemoryBoxes);

    test('yayın sürümünde kilidi açılana kadar gizli', () async {
      expect(DemoMode.isAvailable(releaseMode: true), isFalse);
      expect(DemoMode.isAvailable(releaseMode: false), isTrue);
      await DemoMode.unlock();
      expect(DemoMode.isAvailable(releaseMode: true), isTrue);
    });
  });
}
