import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m05_mental/models/mental_model.dart';

void main() {
  group('BloodPressureEntry', () {
    BloodPressureEntry entry(double systolic, double diastolic) {
      return BloodPressureEntry(
        systolic: systolic,
        diastolic: diastolic,
        date: DateTime(2026),
      );
    }

    test('does not downgrade isolated high systolic pressure', () {
      expect(entry(150, 70).category, 'Evre 2 Hipertansiyon');
    });

    test('classifies stage boundaries consistently', () {
      expect(entry(119, 79).category, 'Normal');
      expect(entry(125, 75).category, 'Yüksek Normal');
      expect(entry(135, 85).category, 'Evre 1 Hipertansiyon');
      expect(entry(139, 95).category, 'Evre 2 Hipertansiyon');
    });
  });

  group('MedicationReminder', () {
    test('keeps its notification id through persistence', () {
      final medication = MedicationReminder(
        notificationId: 123456,
        name: 'Test ilacı',
        dosage: '1 tablet',
        hour: 8,
        minute: 30,
      );

      final restored = MedicationReminder.fromMap(medication.toMap());

      expect(restored.notificationId, 123456);
      expect(restored.timeDisplay, '08:30');
      expect(restored.name, medication.name);
    });

    test('assigns a stable id to legacy records', () {
      final legacy = <String, dynamic>{
        'name': 'Eski kayıt',
        'dosage': '5 mg',
        'hour': 9,
        'minute': 0,
        'is_active': true,
      };

      final first = MedicationReminder.fromMap(legacy);
      final second = MedicationReminder.fromMap(legacy);

      expect(first.notificationId, second.notificationId);
      expect(first.notificationId, greaterThanOrEqualTo(10000));
    });
  });

  group('Mental health scoring', () {
    test('PHQ-9 flags item 9 and referral threshold', () {
      expect(
        PHQ9Scoring.hasSuicidalIdeation([0, 0, 0, 0, 0, 0, 0, 0, 1]),
        isTrue,
      );
      expect(PHQ9Scoring.needsReferral(10), isTrue);
      expect(PHQ9Scoring.severity(20), 'Şiddetli');
    });

    test('GAD-7 severity boundaries are correct', () {
      expect(GAD7Scoring.severity(4), 'Minimal');
      expect(GAD7Scoring.severity(5), 'Hafif');
      expect(GAD7Scoring.severity(10), 'Orta');
      expect(GAD7Scoring.severity(15), 'Şiddetli');
    });
  });
}
