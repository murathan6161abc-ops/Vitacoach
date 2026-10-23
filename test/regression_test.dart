// Analiz sırasında bulunan hataların tekrar etmemesi için regresyon testleri.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitacoach/modules/m03_chronic/models/health_entry.dart';
import 'package:vitacoach/modules/m04_maternal/models/maternal_model.dart';
import 'package:vitacoach/modules/m08_addiction/models/addiction_model.dart';

void main() {
  group('HealthEntry', () {
    test("profilden yazılan eski 'weight' anahtarını okur", () {
      final e = HealthEntry.fromMap({
        'weight': 78,
        'date': '2026-07-20T10:00:00.000',
      });
      expect(e.value, 78.0);
    });

    test('bozuk kayıtta çökmez', () {
      final e = HealthEntry.fromMap({'date': 'bozuk'});
      expect(e.value, 0);
    });
  });

  group('PregnancyProfile', () {
    test('dueDate kaydedilmemişse son adet tarihinden hesaplar', () {
      final p = PregnancyProfile(
        lastPeriodDate: DateTime.now().subtract(const Duration(days: 100)),
      );
      expect(p.daysRemaining, closeTo(180, 2));
    });
  });

  group('SmokingProfile', () {
    test('ileri tarihli bırakmada negatif değer üretmez', () {
      final p = SmokingProfile(
        quitDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(p.isScheduled, isTrue);
      expect(p.daysSinceQuit, 0);
      expect(p.moneySaved, 0);
      expect(p.cigarettesAvoided, 0);
      expect(p.daysUntilQuit, inInclusiveRange(5, 6));
    });

    test('geçmiş tarihte sayaç normal işler', () {
      final p = SmokingProfile(
        quitDate: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
        dailyCigarettes: 10,
        pricePerCigarette: 5,
      );
      expect(p.isScheduled, isFalse);
      expect(p.daysSinceQuit, 3);
      expect(p.moneySaved, 150);
    });
  });

  group('Veri dosyaları', () {
    test('acil durum kurallarındaki tüm belirtiler symptoms.json içinde var', () {
      final symptoms = json.decode(
        File('assets/data/symptoms.json').readAsStringSync(),
      );
      final ids = {
        for (final c in symptoms['categories'])
          for (final s in c['symptoms']) s['id'] as String,
      };
      final flags = json.decode(
        File('assets/data/emergency_flags.json').readAsStringSync(),
      );
      final referenced = <String>{
        for (final group in ['red_flags', 'yellow_flags'])
          for (final f in flags[group]) ...List<String>.from(f['symptoms']),
      };
      expect(referenced.difference(ids), isEmpty);
    });

    test('her yemekte beslenme ekranının kullandığı alanlar var', () {
      final foods = json.decode(
        File('assets/data/foods_tr.json').readAsStringSync(),
      );
      for (final c in foods['categories']) {
        for (final f in c['foods']) {
          expect(f['name'], isA<String>());
          expect(f['calories'], isA<num>());
          expect(f['gi'], isA<num>(), reason: '${f['name']} gi alanı eksik');
          expect(f['portion'], isA<String>());
        }
      }
    });

    test('çocuk aşı takvimi yaşa göre sıralı ve eksiksiz', () {
      final data = json.decode(
        File('assets/data/vaccine_schedule_tr.json').readAsStringSync(),
      );
      final vaccines = List<Map<String, dynamic>>.from(data['child_vaccines']);
      final ages = vaccines.map((v) => v['age_months'] as int).toList();
      expect(ages, [...ages]..sort());
      final ids = vaccines.map((v) => v['id']).toList();
      expect(ids.toSet().length, ids.length, reason: 'yinelenen aşı kimliği');
      // Sağlık Bakanlığı takviminde olup önceden eksik olan dozlar.
      expect(ids, containsAll(['varicella', 'dtap_ipv_48']));
    });

    test('acil durum mesajları koşulsuz ilaç önermez', () {
      final raw = File('assets/data/emergency_flags.json').readAsStringSync();
      expect(raw.contains('Aspirin çiğneyin.'), isFalse);
    });
  });
}
