import '../../../core/constants/app_constants.dart';
import '../../../core/utils/input_utils.dart';
import '../../m02_symptom/services/triage.dart';
import '../../m03_chronic/models/health_entry.dart';
import '../../m03_chronic/models/medication_adherence.dart';
import '../../m03_chronic/services/drug_interaction_service.dart';
import '../../m15_sleep/models/sleep_entry.dart';
import '../../m18_insights/services/insight_engine.dart';
import '../../m19_heart/models/heart_measurement.dart';
import '../../m19_heart/services/ppg_processor.dart';

export '../../m02_symptom/services/triage.dart' show FlagRule;

enum AssistantActionType { call, route }

class AssistantAction {
  final String label;
  final AssistantActionType type;
  final String value;
  const AssistantAction.call(this.label, this.value)
    : type = AssistantActionType.call;
  const AssistantAction.route(this.label, this.value)
    : type = AssistantActionType.route;
}

class AssistantReply {
  final String text;
  final List<String> quickReplies;
  final List<AssistantAction> actions;
  final bool urgent;

  const AssistantReply(
    this.text, {
    this.quickReplies = const [],
    this.actions = const [],
    this.urgent = false,
  });
}

/// Bilgi tabanı girdisi (assets/data/assistant_kb.json).
class KbEntry {
  final String id;
  final List<String> keywords;
  final String answer;
  final String? route;

  KbEntry(this.id, List<String> keywords, this.answer, this.route)
    : keywords = keywords.map(InputUtils.normalizeForSearch).toList();

  factory KbEntry.fromJson(Map<String, dynamic> j) => KbEntry(
    '${j['id']}',
    List<String>.from(j['keywords'] ?? const []),
    '${j['answer']}',
    j['route'] as String?,
  );
}

/// Belirti kataloğu girdisi (symptoms.json).
class SymptomDef {
  final String id;
  final String name;
  final String severity;
  const SymptomDef(this.id, this.name, this.severity);
}

/// Kullanıcının cihazdaki verilerinden bir anlık görüntü.
class AssistantContext {
  final String? name;
  final double? heightCm;
  final BloodPressureEntry? lastBp;
  final HealthEntry? lastSugar;
  final HealthEntry? lastWeight;
  final SleepEntry? lastSleep;
  final double? sleepAvg7;
  final HeartMeasurement? lastHeart;
  final AdherenceReport? adherence;
  final List<MedicationReminder> medications;
  final List<HealthInsight> insights;
  final int waterGlassesToday;
  final int stepsToday;
  final DrugInteractionChecker? drugs;

  const AssistantContext({
    this.name,
    this.heightCm,
    this.lastBp,
    this.lastSugar,
    this.lastWeight,
    this.lastSleep,
    this.sleepAvg7,
    this.lastHeart,
    this.adherence,
    this.medications = const [],
    this.insights = const [],
    this.waterGlassesToday = 0,
    this.stepsToday = 0,
    this.drugs,
  });
}

enum _FlowStep { none, sudden, redSigns, duration }

/// Kural tabanlı, tamamen çevrimdışı sağlık asistanı. Yapay zekâ servisi
/// kullanmaz: anahtar kelime/kök eşleştirme, karar ağacı ve kullanıcının
/// kendi verileriyle cevap üretir. Tanı koymaz.
class AssistantEngine {
  final List<KbEntry> kb;
  final List<SymptomDef> symptoms;
  final List<FlagRule> flags;
  AssistantContext context;

  AssistantEngine({
    required this.kb,
    required this.symptoms,
    required this.flags,
    required this.context,
  });

  static const List<String> defaultSuggestions = [
    'Genel durumum nasıl?',
    'Tansiyonum nasıl?',
    'Başım ağrıyor',
    'İlaç uyumum',
    'Normal tansiyon kaç?',
  ];

  // --- Çok adımlı belirti değerlendirmesi durumu
  _FlowStep _step = _FlowStep.none;
  final List<SymptomDef> _flowSymptoms = [];
  bool _sudden = false;
  bool _redSigns = false;

  /// Belirti kökleri: kullanıcı cümlesindeki kelimelerin başlangıcıyla
  /// eşleşir ("başım ağrıyor" → "bas agr").
  static const Map<String, List<String>> symptomStems = {
    'headache': ['bas agr', 'basim agr', 'kafa agr', 'migren'],
    'dizziness': ['bas don', 'basim don', 'sersem'],
    'vision_blur': ['bulanik gor', 'gorme bulan', 'gozum bulan', 'cift gor'],
    'facial_droop': [
      'yuz kay',
      'yuzum kay',
      'yuz sark',
      'agiz kay',
      'yuzde kay',
    ],
    'eye_pain': ['goz agr', 'gozum agr', 'gozlerim agr'],
    'ear_pain': ['kulak agr', 'kulagim agr'],
    'chest_pain': [
      'gogus agr',
      'gogsum agr',
      'gogus sikis',
      'gogsum sikis',
      'gogsumde agr',
      'gogus bask',
    ],
    'arm_pain_left': ['sol kol'],
    'palpitation': ['carpint', 'kalbim hizli', 'kalbim carp', 'kalp carp'],
    'shortness_breath': [
      'nefes darl',
      'nefes alamiyorum',
      'nefesim daral',
      'nefes almakta zorl',
      'soluk alamiyorum',
    ],
    'cough': ['oksur'],
    'wheezing': ['hirilt'],
    'abdominal_pain': ['karin agr', 'karnim agr', 'mide agr', 'midem agr'],
    'nausea': ['bulant', 'midem bulan'],
    'vomiting': ['kusm', 'kustum', 'kusuyor'],
    'diarrhea': ['ishal'],
    'constipation': ['kabiz'],
    'blood_stool': ['diskida kan', 'kakada kan', 'makattan kan', 'kanli diski'],
    'back_pain': ['bel agr', 'belim agr', 'sirt agr', 'sirtim agr'],
    'joint_pain': ['eklem', 'dizim agr', 'diz agr'],
    'muscle_pain': ['kas agr', 'kaslarim agr', 'vucudum agr'],
    'swelling': ['sislik', 'sisti', 'sismis', 'odem'],
    'leg_numbness': ['bacak uyus', 'bacagim uyus'],
    'arm_weakness': [
      'kol gucsuz',
      'kolum gucsuz',
      'kolumu kaldiramiyorum',
      'kolumda gucsuz',
    ],
    'fever': ['ates', 'atesim'],
    'fatigue': ['yorgun', 'halsiz', 'bitkin'],
    'weight_loss': ['kilo kayb', 'istemeden kilo'],
    'appetite_loss': ['istahsiz', 'istah kayb', 'istahim yok'],
    'night_sweats': ['gece terle'],
    'rash': ['dokunt', 'kurdesen'],
    'speech_difficulty': [
      'konusma guc',
      'konusamiyor',
      'konusmam bozul',
      'dilim dolas',
    ],
    'confusion': ['bilinc bulan', 'bilincim', 'kafa karis'],
    'seizure': ['nobet', 'kasilma', 'sara'],
    'fainting': ['bayil', 'bayg'],
    'tingling': ['karincal'],
    'painful_urination': [
      'idrar yaparken yan',
      'idrarda yanma',
      'idrar yanm',
      'cis yaparken yan',
    ],
    'frequent_urination': ['sik idrar', 'sik tuvalet', 'sik cis'],
    'blood_urine': ['idrarda kan', 'kanli idrar'],
    'dark_urine': ['koyu idrar', 'idrarim koyu'],
    'itching': ['kasint'],
    'redness': ['kizarik'],
    'bruising': ['morar', 'morluk'],
    'wound_not_healing': ['iyilesmeyen yara', 'kapanmayan yara'],
  };

  static const List<String> _crisisStems = [
    'intihar',
    'kendimi oldur',
    'olmek istiyorum',
    'yasamak istemiyorum',
    'kendime zarar',
    'canima kiy',
  ];
  static const List<String> _poisonStems = [
    'zehirlen',
    'yanlislikla ictim',
    'cocuk yuttu',
    'ilac yuttu',
    'fazla ilac ictim',
    'camasir suyu',
    'yuttu',
  ];

  static String _norm(String s) => InputUtils.normalizeForSearch(s)
      .replaceAll(RegExp(r"[^a-z0-9 ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// "bas agr" kökü: cümlede bir kelime "bas", sonraki 3 kelimeden biri
  /// "agr" ile başlıyorsa eşleşir ("başım çok ağrıyor" de yakalanır).
  static bool _hasStem(List<String> words, String stem) {
    final parts = stem.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (!_firstPartMatches(words[i], parts.first, multi: parts.length > 1)) {
        continue;
      }
      var pos = i;
      var ok = true;
      for (var j = 1; j < parts.length; j++) {
        var next = -1;
        for (var k = pos + 1; k < words.length && k <= pos + 3; k++) {
          if (words[k].startsWith(parts[j])) {
            next = k;
            break;
          }
        }
        if (next < 0) {
          ok = false;
          break;
        }
        pos = next;
      }
      if (ok) return true;
    }
    return false;
  }

  /// Kısa kökler ("bas", "goz", "kas") yalnızca iyelik/çoğul ekleriyle
  /// eşleşir; "başka" veya "kasım" gibi kelimeler belirti sanılmaz.
  static final RegExp _shortSuffix = RegExp(
    r'^(|i|u|im|um|in|un|imda|umda|imde|umde|ler|lar|lerim|larim|leri|lari)$',
  );

  static bool _firstPartMatches(
    String word,
    String part, {
    required bool multi,
  }) {
    if (!word.startsWith(part)) return false;
    if (!multi || part.length > 3) return true;
    return _shortSuffix.hasMatch(word.substring(part.length));
  }

  List<SymptomDef> detectSymptoms(String text) {
    final words = _norm(text).split(' ');
    final found = <SymptomDef>[];
    for (final s in symptoms) {
      final stems = symptomStems[s.id] ?? [_norm(s.name)];
      if (stems.any((st) => _hasStem(words, st))) found.add(s);
    }
    return found;
  }

  AssistantReply greeting() {
    final name = context.name?.split(' ').first;
    return AssistantReply(
      'Merhaba${name == null || name.isEmpty ? '' : ' $name'}! Ben VitaCoach sağlık '
      'asistanıyım. Belirtilerinizi değerlendirebilir, ölçümlerinizi yorumlayabilir, '
      'ilaç etkileşimlerini kontrol edebilir ve sağlık sorularınızı yanıtlayabilirim. '
      'Tüm cevaplar telefonunuzda hazırlanır; tanı koymam.',
      quickReplies: defaultSuggestions,
    );
  }

  AssistantReply respond(String input) {
    final text = _norm(input);
    if (text.isEmpty) {
      return const AssistantReply(
        'Size nasıl yardımcı olabilirim?',
        quickReplies: defaultSuggestions,
      );
    }
    final words = text.split(' ');

    // 1) Kriz ifadeleri her şeyden önce gelir.
    if (_crisisStems.any((s) => _hasStem(words, s))) {
      _resetFlow();
      return const AssistantReply(
        'Bunu paylaştığınız için teşekkür ederim; yalnız değilsiniz. Kendinize zarar '
        "verme düşünceniz varsa lütfen hemen 112'yi arayın veya güvendiğiniz birine "
        'şimdi ulaşın. Bu duygular geçicidir ve yardım almak işe yarar.',
        urgent: true,
        actions: [
          AssistantAction.call('112 Acil Çağrı', '112'),
          AssistantAction.route(
            'Ruh sağlığı desteği',
            AppConstants.routeMental,
          ),
        ],
      );
    }
    if (_poisonStems.any((s) => _hasStem(words, s))) {
      _resetFlow();
      return const AssistantReply(
        "Zehirlenme şüphesinde Ulusal Zehir Danışma Merkezi'ni (114) arayın. "
        'Kusturmaya çalışmayın, ürünün kutusunu yanınızda tutun. Bilinç kaybı, '
        "nöbet veya nefes sıkıntısı varsa 112'yi arayın.",
        urgent: true,
        actions: [
          AssistantAction.call('114 Zehir Danışma', '114'),
          AssistantAction.call('112 Acil Çağrı', '112'),
        ],
      );
    }

    // 2) Süren belirti değerlendirmesinin cevabı
    if (_step != _FlowStep.none) {
      final reply = _continueFlow(text, words);
      if (reply != null) return reply;
      _resetFlow(); // konu değişti
    }

    final kbHit = _bestKb(words, text);
    final info = _isInfoQuestion(words);

    // 3) Belirti anlatımı ("başım ağrıyor"). "Ateş nasıl düşürülür?" gibi
    // bilgi soruları ise bilgi tabanından cevaplanır.
    final found = detectSymptoms(text);
    if (found.isNotEmpty && !(info && kbHit != null)) return _startFlow(found);

    // 4) İlaç etkileşimi
    final interaction = _interaction(input, words);
    if (interaction != null) return interaction;

    // 5) Kişisel veri soruları ve bilgi tabanı
    final data = _dataAnswer(words, text);
    if (info && kbHit != null) return _kbReply(kbHit);
    if (data != null) return data;
    if (kbHit != null) return _kbReply(kbHit);

    // 6) Sohbet
    if (_any(words, ['merhaba', 'selam', 'gunaydin', 'iyi aksam', 'iyi gun'])) {
      return greeting();
    }
    if (_any(words, ['baska bir sorum', 'bir sorum var', 'soru sorabilir'])) {
      return const AssistantReply(
        'Tabii, sorunuzu yazın.',
        quickReplies: defaultSuggestions,
      );
    }
    if (_any(words, ['tesekkur', 'sagol', 'sag ol', 'eyvallah'])) {
      return const AssistantReply(
        'Rica ederim, sağlıklı günler dilerim!',
        quickReplies: defaultSuggestions,
      );
    }
    if (_any(words, [
      'sen kimsin',
      'yapay zeka',
      'chatgpt',
      'robot mu',
      'neler yapabilir',
      'ne yapabilir',
      'yardim',
    ])) {
      return const AssistantReply(
        'Ben VitaCoach\'un kural tabanlı sağlık asistanıyım. İnternete veya bir yapay '
        'zekâ servisine bağlanmam; cevaplarımı bilimsel kaynaklara dayalı bir bilgi '
        'tabanından, karar ağaçlarından ve sizin telefonunuzdaki verilerden hazırlarım. '
        'Şunları deneyebilirsiniz:',
        quickReplies: [
          'Genel durumum nasıl?',
          'Göğsüm sıkışıyor',
          'Coraspin ile Nurofen birlikte alınır mı?',
          'Uykum nasıl?',
          'İnme belirtileri neler?',
        ],
      );
    }

    return const AssistantReply(
      'Bunu tam anlayamadım. Belirtinizi kısa bir cümleyle yazabilir (ör. "başım '
      'ağrıyor") veya aşağıdakilerden birini seçebilirsiniz.',
      quickReplies: defaultSuggestions,
    );
  }

  // ------------------------------------------------------------------ yardımcılar
  static bool _any(List<String> words, List<String> stems) =>
      stems.any((s) => _hasStem(words, s));

  static bool _isInfoQuestion(List<String> words) => _any(words, [
    'nedir',
    'normal',
    'olmali',
    'belirtileri',
    'belirtisi',
    'nasil yapilir',
    'ne yapmali',
    'ne yapmaliyim',
    'kac saat',
    'ne kadar',
    'kac bardak',
    'neler',
    'nasil dusur',
    'nasil gecer',
    'ne iyi gelir',
    'nasil olcul',
  ]);

  KbEntry? _bestKb(List<String> words, String text) {
    KbEntry? best;
    var bestScore = 0;
    for (final e in kb) {
      var score = 0;
      for (final k in e.keywords) {
        final match = k.contains(' ')
            ? text.contains(k)
            : words.any((w) => w.startsWith(k));
        if (match) score += k.contains(' ') ? 3 : 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }

  AssistantReply _kbReply(KbEntry e) => AssistantReply(
    e.answer,
    actions: [
      if (e.route != null) AssistantAction.route('İlgili bölüme git', e.route!),
    ],
    quickReplies: const ['Genel durumum nasıl?', 'Başka bir sorum var'],
  );

  // ------------------------------------------------------------------ belirti akışı
  void _resetFlow() {
    _step = _FlowStep.none;
    _flowSymptoms.clear();
    _sudden = false;
    _redSigns = false;
  }

  List<FlagRule> _matchingFlags(Set<String> ids, {required bool red}) => [
    for (final f in flags)
      if (f.red == red && f.matches(ids)) f,
  ];

  AssistantReply _startFlow(List<SymptomDef> found) {
    _resetFlow();
    final ids = found.map((s) => s.id).toSet();
    final names = found.map((s) => s.name.toLowerCase()).join(', ');
    final redFlag = _matchingFlags(ids, red: true);
    final redSymptom = found.where((s) => s.severity == 'red').toList();
    if (redFlag.isNotEmpty || redSymptom.isNotEmpty) {
      final flag = redFlag.isEmpty ? null : redFlag.first;
      return AssistantReply(
        '${(flag == null ? null : InputUtils.upperTr(flag.name)) ?? 'ACİL DEĞERLENDİRME GEREKİR'}: $names. '
        '${flag?.message ?? "Bu belirti acil değerlendirme gerektirebilir. Hemen 112'yi arayın."} '
        'Beklemeyin ve araç kullanmayın.',
        urgent: true,
        actions: const [
          AssistantAction.call('112 Acil Çağrı', '112'),
          AssistantAction.route('Acil durum ekranı', AppConstants.routeSos),
        ],
      );
    }
    _flowSymptoms.addAll(found);
    _step = _FlowStep.sudden;
    return AssistantReply(
      'Anladığım kadarıyla: $names. Durumu değerlendirmek için 3 kısa soru soracağım.\n\n'
      '1/3 — Belirtiler aniden ve hayatınızda yaşadığınız en şiddetli şekilde mi başladı?',
      quickReplies: const ['Evet', 'Hayır'],
    );
  }

  static bool? _yesNo(List<String> words) {
    if (_any(words, ['evet', 'var', 'oldu', 'aynen', 'dogru', 'maalesef'])) {
      return true;
    }
    if (_any(words, ['hayir', 'yok', 'olmadi', 'degil'])) return false;
    return null;
  }

  AssistantReply? _continueFlow(String text, List<String> words) {
    switch (_step) {
      case _FlowStep.sudden:
        final yn = _yesNo(words);
        if (yn == null) return null;
        _sudden = yn;
        _step = _FlowStep.redSigns;
        return const AssistantReply(
          '2/3 — Bunlardan biri eşlik ediyor mu: bilinç bulanıklığı, konuşma bozukluğu, '
          'yüzde kayma, kolda güçsüzlük, göğüs ağrısı veya nefes darlığı?',
          quickReplies: ['Evet', 'Hayır'],
        );
      case _FlowStep.redSigns:
        final yn = _yesNo(words);
        if (yn == null) return null;
        _redSigns = yn;
        if (_sudden || _redSigns) return _finishFlow(days: 0);
        _step = _FlowStep.duration;
        return const AssistantReply(
          '3/3 — Ne zamandır sürüyor?',
          quickReplies: ['Bugün başladı', '1-3 gündür', '3 günden fazla'],
        );
      case _FlowStep.duration:
        final numbers = RegExp(
          r'\d+',
        ).allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
        int? days;
        if (_any(words, ['bugun', 'az once', 'simdi', 'sabah', 'saat'])) {
          days = 0;
        }
        if (_any(words, ['fazla', 'hafta', 'ay', 'uzun'])) days = 4;
        if (days == null && numbers.isNotEmpty) {
          days = numbers.reduce((a, b) => a > b ? a : b);
        }
        if (days == null && _any(words, ['dun', 'gun'])) days = 2;
        if (days == null) return null;
        return _finishFlow(days: days);
      case _FlowStep.none:
        return null;
    }
  }

  AssistantReply _finishFlow({required int days}) {
    final ids = _flowSymptoms.map((s) => s.id).toSet();
    final names = _flowSymptoms.map((s) => s.name.toLowerCase()).join(', ');
    final urgent = _sudden || _redSigns;
    final yellowFlags = _matchingFlags(ids, red: false);
    final yellow =
        yellowFlags.isNotEmpty ||
        _flowSymptoms.any((s) => s.severity == 'yellow') ||
        days > 3;
    _resetFlow();

    if (urgent) {
      return AssistantReply(
        'Belirtilerin ani ve çok şiddetli başlaması veya eşlik eden uyarı belirtileri '
        "($names) acil değerlendirme gerektirir. Lütfen hemen 112'yi arayın.",
        urgent: true,
        actions: const [
          AssistantAction.call('112 Acil Çağrı', '112'),
          AssistantAction.route('Acil durum ekranı', AppConstants.routeSos),
        ],
      );
    }
    if (yellow) {
      final flag = yellowFlags.isEmpty ? null : yellowFlags.first;
      return AssistantReply(
        '${flag == null ? '' : '${flag.name}: ${flag.message} '}'
        '${days > 3 ? '3 günden uzun süren belirtiler ($names) bir hekim tarafından '
                  'değerlendirilmelidir. ' : ''}'
        '24 saat içinde aile hekiminize veya bir sağlık kuruluşuna başvurmanızı öneririm. '
        'Belirtiler ağırlaşırsa beklemeden acile gidin.',
        actions: const [
          AssistantAction.route(
            'Randevu ve yakın tesisler',
            AppConstants.routeAccess,
          ),
          AssistantAction.route('Belirti ekranı', AppConstants.routeSymptom),
        ],
        quickReplies: const ['Ateş nasıl düşürülür?', 'Genel durumum nasıl?'],
      );
    }
    return AssistantReply(
      'Anlattıklarınız ($names) şu an için düşük riskli görünüyor. Dinlenin, bol sıvı '
      'alın ve belirtileri takip edin. Ateş, şiddetli ağrı veya yeni bir belirti eklenirse '
      'ya da 3 günden uzun sürerse doktorunuza başvurun.',
      quickReplies: const ['Genel durumum nasıl?', 'Başka bir sorum var'],
    );
  }

  // ------------------------------------------------------------------ ilaç etkileşimi
  AssistantReply? _interaction(String raw, List<String> words) {
    final checker = context.drugs;
    if (checker == null) return null;
    final mentioned = checker.mentionsIn(raw);
    final asks = _any(words, [
      'etkiles',
      'birlikte',
      'beraber',
      'ayni anda',
      'ile alin',
      'kullanabilir',
    ]);
    if (mentioned.length >= 2) {
      final warnings = <InteractionWarning>[];
      for (var i = 0; i < mentioned.length; i++) {
        for (var j = i + 1; j < mentioned.length; j++) {
          warnings.addAll(checker.checkPair(mentioned[i], mentioned[j]));
        }
      }
      return _interactionReply(mentioned.join(' + '), warnings);
    }
    if (mentioned.length == 1 && asks && context.medications.isNotEmpty) {
      final warnings = checker.checkNew(
        mentioned.first,
        context.medications.map((m) => m.name),
      );
      return _interactionReply(
        '${mentioned.first} ve kullandığınız ilaçlar',
        warnings,
      );
    }
    if (mentioned.length == 1 && asks) {
      return AssistantReply(
        '${mentioned.first} için hangi ilaçla birlikte kullanımı merak ediyorsunuz? '
        'İki ilacın adını birlikte yazabilirsiniz.',
      );
    }
    return null;
  }

  AssistantReply _interactionReply(
    String subject,
    List<InteractionWarning> warnings,
  ) {
    if (warnings.isEmpty) {
      return AssistantReply(
        '$subject için veri tabanımda bilinen sık bir etkileşim bulunmuyor. Bu, hiçbir '
        'etkileşim olmadığı anlamına gelmez; ilaçları birlikte kullanmadan önce eczacınıza '
        'danışın.',
        actions: const [
          AssistantAction.route('İlaçlarım', AppConstants.routeChronic),
        ],
      );
    }
    final lines = warnings
        .map(
          (w) =>
              '• ${w.drugA} + ${w.drugB} (${w.severity.label}): ${w.message}',
        )
        .join('\n');
    final high = warnings.any((w) => w.severity == InteractionSeverity.high);
    return AssistantReply(
      '$subject için ${warnings.length} olası etkileşim buldum:\n$lines\n\n'
      'İlaçlarınızı kendiniz bırakmayın veya değiştirmeyin; doktorunuza ya da '
      'eczacınıza danışın.',
      urgent: high,
      actions: const [
        AssistantAction.route('İlaçlarım', AppConstants.routeChronic),
      ],
    );
  }

  // ------------------------------------------------------------------ kişisel veri
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  String _insightLine(String id) {
    for (final i in context.insights) {
      if (i.id.startsWith(id)) return '\n\n${i.title}: ${i.message}';
    }
    return '';
  }

  AssistantReply? _dataAnswer(List<String> words, String text) {
    final c = context;
    if (_any(words, ['genel durum', 'nasilim', 'durumum', 'ozet', 'analiz'])) {
      if (c.insights.isEmpty) {
        return const AssistantReply(
          'Henüz yorumlayabileceğim kadar veri yok. Birkaç gün tansiyon, şeker, uyku ve '
          'ruh hali kaydı girdikçe size kişisel eğilimlerinizi anlatabilirim.',
          actions: [
            AssistantAction.route('Ölçüm ekle', AppConstants.routeChronic),
          ],
        );
      }
      final top = c.insights
          .take(3)
          .map((i) => '• ${i.title}: ${i.message}')
          .join('\n');
      return AssistantReply(
        'Verilerinizde öne çıkanlar:\n$top',
        actions: const [
          AssistantAction.route('Tüm analiz', AppConstants.routeInsights),
        ],
        quickReplies: const [
          'Tansiyonum nasıl?',
          'Uykum nasıl?',
          'İlaç uyumum',
        ],
      );
    }
    if (_any(words, [
      'tansiyonum',
      'kan basincim',
      'tansiyon deger',
      'tansiyon durum',
      'tansiyon olcumlerim',
    ])) {
      final bp = c.lastBp;
      if (bp == null) {
        return const AssistantReply(
          'Henüz tansiyon ölçümünüz yok. Kronik Hastalık ekranından ekleyebilirsiniz.',
          actions: [
            AssistantAction.route('Tansiyon ekle', AppConstants.routeChronic),
          ],
        );
      }
      return AssistantReply(
        'Son tansiyon ölçümünüz ${_date(bp.date)} tarihinde ${bp.display} '
        '(${bp.category}).${_insightLine('bp_')}',
        actions: const [
          AssistantAction.route('Tansiyon geçmişi', AppConstants.routeChronic),
        ],
        quickReplies: const [
          'Normal tansiyon kaç?',
          'Doğru tansiyon ölçümü nasıl yapılır?',
        ],
      );
    }
    if (_any(words, ['sekerim', 'seker deger', 'seker olcum', 'glikozum']) &&
        !text.contains('dustu')) {
      final s = c.lastSugar;
      if (s == null) {
        return const AssistantReply(
          'Henüz kan şekeri ölçümünüz yok.',
          actions: [
            AssistantAction.route('Şeker ekle', AppConstants.routeChronic),
          ],
        );
      }
      return AssistantReply(
        'Son kan şekeri ölçümünüz ${_date(s.date)} tarihinde ${s.value.round()} mg/dL.'
        '${_insightLine('sugar_')}',
        actions: const [
          AssistantAction.route('Şeker geçmişi', AppConstants.routeChronic),
        ],
        quickReplies: const ['Normal şeker kaç olmalı?'],
      );
    }
    if (_any(words, [
      'kilom',
      'agirligim',
      'bmi',
      'kilo durum',
      'vucut kitle indeksim',
    ])) {
      final w = c.lastWeight;
      if (w == null) return null;
      final h = c.heightCm;
      final bmi = h == null || h <= 0
          ? null
          : w.value / ((h / 100) * (h / 100));
      final cat = bmi == null
          ? ''
          : bmi < 18.5
          ? 'zayıf'
          : bmi < 25
          ? 'normal'
          : bmi < 30
          ? 'fazla kilolu'
          : 'obez';
      return AssistantReply(
        'Son kilonuz ${w.value.toStringAsFixed(1).replaceAll('.', ',')} kg'
        '${bmi == null ? '' : ', vücut kitle indeksiniz ${bmi.toStringAsFixed(1).replaceAll('.', ',')} ($cat)'}.'
        '${_insightLine('weight_')}',
        actions: const [
          AssistantAction.route('Profil', AppConstants.routeProfile),
        ],
      );
    }
    if (_any(words, ['uyku', 'uykum', 'uyudum', 'uyuyabil'])) {
      final s = c.lastSleep;
      if (s == null) {
        return const AssistantReply(
          'Henüz uyku kaydınız yok.',
          actions: [
            AssistantAction.route('Uyku ekle', AppConstants.routeSleep),
          ],
        );
      }
      final avg = c.sleepAvg7;
      return AssistantReply(
        'Son uykunuz ${s.durationLabel} (${_date(s.wakeTime)}).'
        '${avg == null ? '' : ' Son 7 gecenin ortalaması ${avg.toStringAsFixed(1).replaceAll('.', ',')} saat; önerilen 7-9 saat.'}'
        '${_insightLine('sleep_')}',
        actions: const [
          AssistantAction.route('Uyku takibi', AppConstants.routeSleep),
        ],
        quickReplies: const ['Kaç saat uyumalıyım?'],
      );
    }
    if (_any(words, ['nabiz', 'nabzim', 'stres', 'hrv', 'kalp atis'])) {
      final h = c.lastHeart;
      if (h == null) {
        return const AssistantReply(
          'Henüz nabız ölçümünüz yok. Telefonunuzun kamerasıyla 30 saniyede nabzınızı '
          've stres göstergenizi (HRV) ölçebilirsiniz.',
          actions: [
            AssistantAction.route('Nabız ölç', AppConstants.routeHeart),
          ],
        );
      }
      return AssistantReply(
        'Son ölçümünüz (${_date(h.date)}): nabız ${h.bpm} atım/dk, HRV ${h.rmssdMs.round()} ms, '
        'stres göstergesi ${h.stress.label.toLowerCase()}.${_insightLine('hrv_')}',
        actions: const [
          AssistantAction.route('Yeniden ölç', AppConstants.routeHeart),
        ],
        quickReplies: const ['HRV nedir?', 'Normal nabız kaç?'],
      );
    }
    if (_any(words, ['ilac uyum', 'uyumum', 'ilaclarimi dogru', 'dozlarimi'])) {
      final a = c.adherence;
      if (a == null || a.percent == null) {
        return const AssistantReply(
          'İlaç uyumunuzu hesaplamak için dozlarınızı "Aldım" ile işaretlemeniz gerekiyor.',
          actions: [
            AssistantAction.route('İlaçlarım', AppConstants.routeChronic),
          ],
        );
      }
      final pattern = a.patterns.isEmpty
          ? ''
          : '\n\n${a.patterns.first.message} ${a.patterns.first.suggestion}';
      return AssistantReply(
        'Son ${a.days} günde ${a.taken}/${a.scheduled} dozu aldınız: uyumunuz %${a.percent}.'
        '${a.percent! >= 80 ? ' Harika gidiyorsunuz!' : ' Hedef en az %80.'}$pattern',
        actions: const [
          AssistantAction.route('İlaçlarım', AppConstants.routeChronic),
        ],
      );
    }
    if (_any(words, ['ilaclarim', 'ilac listem', 'hangi ilac', 'ilaclarimi'])) {
      if (c.medications.isEmpty) {
        return const AssistantReply(
          'Kayıtlı ilacınız yok.',
          actions: [
            AssistantAction.route('İlaç ekle', AppConstants.routeChronic),
          ],
        );
      }
      final list = c.medications
          .map((m) => '• ${m.name} ${m.dosage} — ${m.timeDisplay}')
          .join('\n');
      return AssistantReply(
        'Kayıtlı ilaçlarınız:\n$list',
        actions: const [
          AssistantAction.route('İlaçlarım', AppConstants.routeChronic),
        ],
        quickReplies: const ['İlaç uyumum', 'İlacımı almayı unuttum'],
      );
    }
    if (_any(words, ['suyum', 'su ic', 'kac bardak ictim', 'bugun su'])) {
      return AssistantReply(
        'Bugün ${c.waterGlassesToday} bardak (${c.waterGlassesToday * AppConstants.waterGlassMl} ml) '
        'su içtiniz; hedef ${AppConstants.dailyWaterGoalMl} ml.',
        actions: const [
          AssistantAction.route('Su ekle', AppConstants.routeNutrition),
        ],
      );
    }
    if (_any(words, ['adim', 'adimim'])) {
      return AssistantReply(
        'Bugün ${c.stepsToday} adım attınız; günlük hedef ${AppConstants.dailyStepGoal}.',
        actions: const [
          AssistantAction.route('Fitness', AppConstants.routeFitness),
        ],
      );
    }
    if (_any(words, ['rapor', 'pdf'])) {
      return const AssistantReply(
        'Doktorunuza götürebileceğiniz, son 30 günün ölçümlerini, ilaçlarınızı ve risk '
        'skorlarınızı içeren PDF raporu hazırlayabilirim.',
        actions: [
          AssistantAction.route('PDF rapor oluştur', AppConstants.routeReport),
        ],
      );
    }
    if (_any(words, ['acil kart', 'kan grub', 'qr'])) {
      return const AssistantReply(
        'Kan grubunuz, alerjileriniz ve acil kişileriniz Acil Sağlık Kartı\'nda; sağlık '
        'personeli QR kodu okutarak bilgilere ulaşabilir.',
        actions: [
          AssistantAction.route(
            'Acil sağlık kartı',
            AppConstants.routeEmergencyCard,
          ),
        ],
      );
    }
    return null;
  }
}
