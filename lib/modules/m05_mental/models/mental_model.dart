class MoodEntry {
  final int value; // 1-5
  final DateTime date;
  final String? note;

  MoodEntry({required this.value, required this.date, this.note});

  String get emoji {
    switch (value) {
      case 5:
        return '😊';
      case 4:
        return '🙂';
      case 3:
        return '😐';
      case 2:
        return '😔';
      case 1:
        return '😢';
      default:
        return '😐';
    }
  }

  String get label {
    switch (value) {
      case 5:
        return 'Harika';
      case 4:
        return 'İyi';
      case 3:
        return 'Normal';
      case 2:
        return 'Kötü';
      case 1:
        return 'Çok Kötü';
      default:
        return 'Normal';
    }
  }

  Map<String, dynamic> toMap() => {
    'value': value,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory MoodEntry.fromMap(Map<dynamic, dynamic> map) => MoodEntry(
    value: map['value'],
    date: DateTime.parse(map['date']),
    note: map['note'],
  );
}

class TestResult {
  final String testType; // PHQ9, GAD7
  final int score;
  final String severity;
  final DateTime date;

  TestResult({
    required this.testType,
    required this.score,
    required this.severity,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'test_type': testType,
    'score': score,
    'severity': severity,
    'date': date.toIso8601String(),
  };

  factory TestResult.fromMap(Map<dynamic, dynamic> map) => TestResult(
    testType: map['test_type'],
    score: map['score'],
    severity: map['severity'],
    date: DateTime.parse(map['date']),
  );
}

class PHQ9Scoring {
  static const List<String> questions = [
    'İşleri yapmaya karşı çok az ilgi veya zevk duyma',
    'Kendini kötü, depresif veya umutsuz hissetme',
    'Uykuya dalmada/sürdürmede güçlük veya çok uyuma',
    'Yorgun hissetme veya enerjisizlik',
    'İştahsızlık veya aşırı yeme',
    'Kendini başarısız hissetme veya aileni hayal kırıklığına uğrattığını düşünme',
    'Gazete okuma veya TV izleme gibi şeylere konsantre olamama',
    'Başkalarının fark edebileceği kadar yavaş hareket etme/konuşma veya tam tersi huzursuzluk',
    'Kendine zarar verme veya ölmüş olmayı isteme düşünceleri',
  ];

  static String severity(int score) {
    if (score <= 4) return 'Minimal';
    if (score <= 9) return 'Hafif';
    if (score <= 14) return 'Orta';
    if (score <= 19) return 'Orta-Şiddetli';
    return 'Şiddetli';
  }

  static bool needsReferral(int score) => score >= 10;
  static bool hasSuicidalIdeation(List<int> answers) =>
      answers.length > 8 && answers[8] >= 1;
}

class GAD7Scoring {
  static const List<String> questions = [
    'Gergin, endişeli veya sinirli hissetme',
    'Endişelenmeyi durduramama veya kontrol edememe',
    'Farklı şeyler hakkında çok fazla endişelenme',
    'Rahatlamada güçlük çekme',
    'Yerinde duramayacak kadar huzursuz olma',
    'Kolay sinirlenme veya huysuzlaşma',
    'Kötü bir şey olacakmış gibi korkma',
  ];

  static String severity(int score) {
    if (score <= 4) return 'Minimal';
    if (score <= 9) return 'Hafif';
    if (score <= 14) return 'Orta';
    return 'Şiddetli';
  }

  static bool needsReferral(int score) => score >= 10;
}

/// Ruh hali seçimine göre gösterilen destek mesajları. Tamamen cihaz
/// üzerinde çalışır; hiçbir veri dışarı gönderilmez.
class MoodSupportMessages {
  MoodSupportMessages._();

  static const Map<int, List<String>> _messages = {
    5: [
      'Harika hissetmen çok güzel! Bu enerjiyi sana iyi gelen bir şeyle taçlandır.',
      'Bugünün tadını çıkar. İyi hissettiren şeyleri not etmek, zor günlerde yol gösterir.',
      'Bu olumlu ruh halini sevdiğin biriyle paylaşmaya ne dersin?',
    ],
    4: [
      'İyi bir gün geçirmen sevindirici. Küçük bir yürüyüşle bu hissi pekiştirebilirsin.',
      'Kendine ayırdığın zamanın karşılığını alıyorsun, böyle devam!',
      'Bugün seni iyi hissettiren şey neydi? Onu hatırlamak değerli.',
    ],
    3: [
      'Normal bir gün de değerlidir. Kendine küçük bir mola vermeyi unutma.',
      'Birkaç derin nefes ve bir bardak su, günün geri kalanına iyi gelebilir.',
      'Bugün kendin için yapabileceğin küçük, keyifli bir şey seç.',
    ],
    2: [
      'Kötü hissetmen anlaşılır; her duygu geçicidir. Kendine nazik davran.',
      'Bir yakınınla konuşmak ya da kısa bir yürüyüş yükünü hafifletebilir.',
      'Bugün kendinden fazla şey bekleme; dinlenmek de bir ihtiyaçtır.',
    ],
    1: [
      'Zor bir gün geçirdiğini görüyorum. Yalnız değilsin; güvendiğin biriyle konuşmayı dene.',
      'Bu duygular geçecek. Kendine zarar verme düşüncen varsa hemen 112\'yi ara.',
      'Nefesine odaklan: 4 saniye al, 7 saniye tut, 8 saniyede ver. Birkaç kez tekrarla.',
    ],
  };

  /// Aynı gün içinde tutarlı, günden güne değişen bir mesaj seçer.
  static String forMood(int value, {DateTime? date}) {
    final list = _messages[value.clamp(1, 5)]!;
    final day = date ?? DateTime.now();
    final index = (day.year * 372 + day.month * 31 + day.day) % list.length;
    return list[index];
  }
}
