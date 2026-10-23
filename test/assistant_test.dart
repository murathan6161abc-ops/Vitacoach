import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m03_chronic/services/drug_interaction_service.dart';
import 'package:vitacoach/modules/m20_assistant/services/assistant_engine.dart';
import 'package:vitacoach/modules/m20_assistant/services/assistant_loader.dart';

AssistantEngine engine({AssistantContext? context}) => AssistantLoader.fromJson(
  kbJson: File('assets/data/assistant_kb.json').readAsStringSync(),
  symptomsJson: File('assets/data/symptoms.json').readAsStringSync(),
  flagsJson: File('assets/data/emergency_flags.json').readAsStringSync(),
  context: context ?? const AssistantContext(),
);

final drugs = DrugInteractionChecker.fromJson(
  jsonDecode(File('assets/data/drug_interactions.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  group('Belirti değerlendirmesi', () {
    test('kalp krizi kombinasyonu anında acil', () {
      final r = engine().respond('Göğsüm sıkışıyor ve sol kolum ağrıyor');
      expect(r.urgent, isTrue);
      expect(r.actions.any((a) => a.value == '112'), isTrue);
      expect(r.text, contains('KALP KRİZİ'));
    });

    test('baş ağrısı: 3 soru sonrası düşük risk', () {
      final e = engine();
      expect(e.respond('Başım ağrıyor').text, contains('1/3'));
      expect(e.respond('Hayır').text, contains('2/3'));
      expect(e.respond('Hayır').text, contains('3/3'));
      final r = e.respond('Bugün başladı');
      expect(r.urgent, isFalse);
      expect(r.text, contains('düşük riskli'));
    });

    test('ani ve şiddetli başlangıç acile yönlendirir', () {
      final e = engine();
      e.respond('başım çok ağrıyor');
      final r = e.respond('Evet');
      expect(r.text, contains('2/3'));
      final last = e.respond('Hayır');
      expect(last.urgent, isTrue);
    });

    test('uzun süren belirti doktora yönlendirir', () {
      final e = engine();
      e.respond('öksürüğüm var');
      e.respond('hayır');
      e.respond('hayır');
      final r = e.respond('5 gündür');
      expect(r.text, contains('24 saat'));
    });

    test('akış sırasında konu değişirse yeni soru cevaplanır', () {
      final e = engine();
      e.respond('başım ağrıyor');
      final r = e.respond('İnme belirtileri neler?');
      expect(r.text, contains('YÜZ-KOL-KONUŞMA'));
    });
  });

  group('Kriz ve bilgi', () {
    test('intihar ifadesi 112 ile karşılanır', () {
      final r = engine().respond('artık yaşamak istemiyorum');
      expect(r.urgent, isTrue);
      expect(r.actions.first.value, '112');
    });

    test('zehirlenme 114', () {
      final r = engine().respond('çocuk çamaşır suyu yuttu');
      expect(r.actions.any((a) => a.value == '114'), isTrue);
    });

    test('bilgi soruları doğru karta eşleşir', () {
      final e = engine();
      expect(e.respond('Normal tansiyon kaç?').text, contains('120/80'));
      expect(e.respond('Ateş nasıl düşürülür?').text, contains('sıvı'));
      expect(e.respond('Kaç saat uyumalıyım?').text, contains('7-9'));
      expect(
        e.respond('Doğru tansiyon ölçümü nasıl yapılır?').text,
        contains('kalp hizasında'),
      );
      expect(e.respond('ilacımı almayı unuttum').text, contains('çift doz'));
      expect(e.respond('HRV nedir?').text, contains('değişkenliği'));
    });

    test('benzer kelimeler belirti sanılmaz', () {
      final e = engine();
      expect(e.detectSymptoms('başka bir sorum var'), isEmpty);
      expect(
        e.detectSymptoms('gözlerim ağrıyor').map((s) => s.id),
        contains('eye_pain'),
      );
      expect(
        e.detectSymptoms('belim çok ağrıyor').map((s) => s.id),
        contains('back_pain'),
      );
    });

    test('anlaşılmayan girdi önerilerle döner', () {
      final r = engine().respond('qwerty asdf');
      expect(r.quickReplies, isNotEmpty);
    });
  });

  group('Kişisel veri ve ilaçlar', () {
    final ctx = AssistantContext(
      name: 'Ayşe Demir',
      heightCm: 164,
      lastBp: BloodPressureEntry(
        systolic: 134,
        diastolic: 84,
        date: DateTime(2026, 9, 29, 8),
      ),
      lastWeight: HealthEntry(value: 76, date: DateTime(2026, 9, 29)),
      medications: [
        MedicationReminder(
          name: 'Coraspin',
          dosage: '100 mg',
          hour: 13,
          minute: 0,
        ),
      ],
      drugs: drugs,
    );

    test('tansiyonum nasıl', () {
      final r = engine(context: ctx).respond('Tansiyonum nasıl?');
      expect(r.text, contains('134/84'));
    });

    test('kilo ve BKİ', () {
      final r = engine(context: ctx).respond('kilom kaç');
      expect(r.text, contains('28,3'));
    });

    test('iki ilaç arasında etkileşim', () {
      final r = engine(
        context: ctx,
      ).respond('Coraspin ile Nurofen birlikte alınır mı?');
      expect(r.text, contains('etkileşim'));
      expect(r.text, contains('Mide kanaması'));
    });

    test('yeni ilaç kullanıcının ilaçlarıyla karşılaştırılır', () {
      final r = engine(context: ctx).respond('coumadin kullanabilir miyim');
      expect(r.urgent, isTrue); // varfarin + aspirin yüksek önem
    });

    test('selamlama adı kullanır', () {
      expect(engine(context: ctx).greeting().text, contains('Ayşe'));
    });
  });
}
