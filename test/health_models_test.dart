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
        name: 'Test ilacı',
        dosage: '1 tablet',
        doses: [MedicationDose(notificationId: 123456, hour: 8, minute: 30)],
      );

      final restored = MedicationReminder.fromMap(medication.toMap());

      expect(restored.doses.single.notificationId, 123456);
      expect(restored.timesDisplay, '08:30');
      expect(restored.name, medication.name);
    });

    test('eski tek saatli kayıt, kimliğini koruyan tek doz olur', () {
      final medication = MedicationReminder.fromMap({
        'notification_id': 45678,
        'name': 'Delix',
        'dosage': '5 mg',
        'hour': 9,
        'minute': 15,
        'is_active': false,
        'created_at': '2026-09-01T10:00:00.000',
      });

      expect(medication.doses.single.notificationId, 45678);
      expect(medication.doses.single.timeDisplay, '09:15');
      expect(medication.isActive, isFalse);
      expect(medication.createdAt, DateTime(2026, 9, 1, 10));
    });

    test('doz saatleri sıralanır ve kimlikleriyle saklanır', () {
      final medication = MedicationReminder(
        name: 'Metformin',
        dosage: '500 mg',
        doses: [
          MedicationDose(notificationId: 20002, hour: 20, minute: 0),
          MedicationDose(notificationId: 20001, hour: 8, minute: 0),
        ],
      );

      final map = medication.toMap();
      // Tek saatli eski sürümler kaydı ilk dozuyla okuyabilir.
      expect(
        (map['notification_id'], map['hour'], map['minute']),
        (20001, 8, 0),
      );

      final restored = MedicationReminder.fromMap(map);
      expect(restored.timesDisplay, '08:00, 20:00');
      expect(restored.doses.map((d) => d.notificationId), [20001, 20002]);
    });

    test('assigns a stable id to legacy records', () {
      final legacy = <String, dynamic>{
        'name': 'Eski kayıt',
        'dosage': '5 mg',
        'hour': 9,
        'minute': 0,
        'is_active': true,
      };

      final first = MedicationReminder.fromMap(legacy).doses.single;
      final second = MedicationReminder.fromMap(legacy).doses.single;

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
