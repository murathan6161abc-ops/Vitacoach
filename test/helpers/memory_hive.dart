import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:vitacoach/core/constants/app_constants.dart';

const _boxNames = [
  AppConstants.hiveProfileBox,
  AppConstants.hiveHealthBox,
  AppConstants.hiveNutritionBox,
  AppConstants.hiveMoodBox,
  AppConstants.hiveSettingsBox,
  AppConstants.hiveMedicationBox,
  AppConstants.hiveAddictionBox,
  AppConstants.hiveVaccineBox,
  AppConstants.hiveFitnessBox,
  AppConstants.hiveBadgeBox,
];

/// Uygulamanın tüm kutularını bellekte, boş olarak açar.
///
/// Dosya tabanlı kutuların gerçek disk G/Ç'si testWidgets'ın sahte
/// zamanında tamamlanmaz; bellek kutuları ise HiveService'in kullandığı
/// adlarla aynı şekilde erişilir.
Future<void> openMemoryBoxes() async {
  for (final name in _boxNames) {
    if (Hive.isBoxOpen(name)) {
      await Hive.box<dynamic>(name).clear();
    } else {
      await Hive.openBox<dynamic>(name, bytes: Uint8List(0));
    }
  }
}

Future<void> closeMemoryBoxes() => Hive.close();
