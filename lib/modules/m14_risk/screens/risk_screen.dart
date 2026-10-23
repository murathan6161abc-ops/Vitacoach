import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../m01_profile/providers/profile_provider.dart';
import '../../m03_chronic/providers/chronic_provider.dart';
import '../models/risk_models.dart';

/// Laboratuvar sonucu gerektirmeyen, bilimsel olarak doğrulanmış risk
/// skorları. Tüm hesaplar cihaz üzerinde yapılır.
class RiskScreen extends StatefulWidget {
  const RiskScreen({super.key});

  @override
  State<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends State<RiskScreen> {
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _sbpCtrl = TextEditingController();

  bool _isMale = true;
  bool _active = true;
  bool _vegFruit = true;
  bool _bpMedication = false;
  bool _highGlucose = false;
  FamilyDiabetesHistory _family = FamilyDiabetesHistory.none;
  bool _smoker = false;
  bool _diabetic = false;

  FindriscResult? _findrisc;
  FraminghamResult? _framingham;
  String? _framinghamNote;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final profile = context.read<ProfileProvider>().profile;
    if (profile.age > 0) _ageCtrl.text = '${profile.age}';
    if (profile.height > 0) _heightCtrl.text = _fmt(profile.height);
    if (profile.weight > 0) _weightCtrl.text = _fmt(profile.weight);
    _isMale = profile.gender != 'Kadın';
    _bpMedication = profile.hasHypertension;
    _diabetic = profile.hasDiabetes;

    final pressures = context.read<ChronicProvider>().bloodPressureEntries;
    if (pressures.isNotEmpty) {
      _sbpCtrl.text = _fmt(pressures.last.systolic);
    }
    final sugars = context.read<ChronicProvider>().bloodSugarEntries;
    _highGlucose = profile.hasDiabetes || sugars.any((e) => e.value >= 126);
  }

  @override
  void dispose() {
    for (final c in [_ageCtrl, _heightCtrl, _weightCtrl, _waistCtrl, _sbpCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  double? get _bmi {
    final h = InputUtils.inRange(
      InputUtils.parseDecimal(_heightCtrl.text),
      100.0,
      250.0,
    );
    final w = InputUtils.inRange(
      InputUtils.parseDecimal(_weightCtrl.text),
      30.0,
      300.0,
    );
    if (h == null || w == null) return null;
    return w / ((h / 100) * (h / 100));
  }

  int? get _age =>
      InputUtils.inRange(InputUtils.parseInt(_ageCtrl.text), 18, 110);

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveResult(String type, num score, String level) async {
    final box = HiveService().getHealthBox();
    final history = List<dynamic>.from(box.get('risk_history') ?? const []);
    history.add({
      'type': type,
      'score': score,
      'level': level,
      'date': DateTime.now().toIso8601String(),
    });
    await box.put('risk_history', history);
  }

  void _calculateFindrisc() {
    final age = _age;
    final bmi = _bmi;
    final waist = InputUtils.inRange(
      InputUtils.parseDecimal(_waistCtrl.text),
      40.0,
      200.0,
    );
    if (age == null) return _showError('Yaş 18-110 arasında olmalı.');
    if (bmi == null) return _showError('Geçerli boy ve kilo girin.');
    if (waist == null) return _showError('Bel çevresi 40-200 cm olmalı.');

    final result = FindriscCalculator.calculate(
      FindriscInput(
        age: age,
        bmi: bmi,
        waistCm: waist,
        isMale: _isMale,
        activeDaily30Min: _active,
        eatsVegFruitDaily: _vegFruit,
        takesBpMedication: _bpMedication,
        hadHighBloodGlucose: _highGlucose,
        familyHistory: _family,
      ),
    );
    setState(() => _findrisc = result);
    _saveResult('FINDRISC', result.score, result.level.label);
  }

  void _calculateFramingham() {
    final age = _age;
    final bmi = _bmi;
    final sbp = InputUtils.inRange(
      InputUtils.parseDecimal(_sbpCtrl.text),
      80.0,
      250.0,
    );
    if (age == null) return _showError('Yaş 18-110 arasında olmalı.');
    if (bmi == null) return _showError('Geçerli boy ve kilo girin.');
    if (sbp == null) {
      return _showError('Büyük tansiyon (sistolik) 80-250 mmHg olmalı.');
    }
    if (!FraminghamCalculator.isAgeSupported(age)) {
      setState(() {
        _framingham = null;
        _framinghamNote =
            'Bu model 30-74 yaş arası için geliştirilmiştir; yaşınız bu aralıkta '
            'olmadığından güvenilir bir sonuç verilemez.';
      });
      return;
    }
    final result = FraminghamCalculator.calculate(
      FraminghamInput(
        age: age,
        isMale: _isMale,
        bmi: bmi.clamp(15.0, 50.0),
        systolicBp: sbp,
        bpTreated: _bpMedication,
        smoker: _smoker,
        diabetic: _diabetic,
      ),
    );
    setState(() {
      _framingham = result;
      _framinghamNote = null;
    });
    _saveResult(
      'Framingham',
      double.parse(result.percent.toStringAsFixed(1)),
      result.level.label,
    );
  }

  Color _levelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.slightlyElevated:
        return AppColors.primaryLight;
      case RiskLevel.moderate:
        return AppColors.warning;
      case RiskLevel.high:
      case RiskLevel.veryHigh:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Risk Analizi'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Diyabet Riski'),
              Tab(text: 'Kalp-Damar Riski'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildFindriscTab(), _buildFraminghamTab()],
        ),
      ),
    );
  }

  Widget _commonFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _numberField(_ageCtrl, 'Yaş', decimal: false)),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Erkek')),
                  ButtonSegment(value: false, label: Text('Kadın')),
                ],
                selected: {_isMale},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _isMale = v.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _numberField(_heightCtrl, 'Boy (cm)')),
            const SizedBox(width: 12),
            Expanded(child: _numberField(_weightCtrl, 'Kilo (kg)')),
          ],
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  Widget _buildFindriscTab() {
    final profileDiabetic = context.read<ProfileProvider>().profile.hasDiabetes;
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        _infoCard(
          'Finlandiya Diyabet Risk Skoru (FINDRISC)',
          'Önümüzdeki 10 yılda Tip-2 diyabet gelişme olasılığını, kan tahlili '
              'gerektirmeden 8 soruyla tahmin eder.\n'
              'Kaynak: Lindström & Tuomilehto, Diabetes Care 2003.',
        ),
        if (profileDiabetic) ...[
          const SizedBox(height: 12),
          VcCard(
            borderColor: AppColors.warning.withValues(alpha: 0.4),
            child: Text(
              'Profilinizde diyabet kayıtlı. Bu skor henüz diyabet tanısı '
              'almamış kişiler içindir; sonucu bilgi amaçlı değerlendirin.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 12),
        VcCard(
          child: Column(
            children: [
              _commonFields(),
              const SizedBox(height: 12),
              _numberField(_waistCtrl, 'Bel çevresi (cm, göbek hizası)'),
              const SizedBox(height: 4),
              _switch(
                'Günde en az 30 dakika fiziksel aktivite yapıyorum',
                _active,
                (v) => _active = v,
              ),
              _switch(
                'Her gün sebze veya meyve yiyorum',
                _vegFruit,
                (v) => _vegFruit = v,
              ),
              _switch(
                'Düzenli tansiyon ilacı kullanıyorum / kullandım',
                _bpMedication,
                (v) => _bpMedication = v,
              ),
              _switch(
                'Daha önce kan şekerim yüksek bulundu',
                _highGlucose,
                (v) => _highGlucose = v,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ailede diyabet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _familyChip('Yok', FamilyDiabetesHistory.none),
                  _familyChip(
                    'Büyükanne/baba, amca, teyze, kuzen',
                    FamilyDiabetesHistory.secondDegree,
                  ),
                  _familyChip(
                    'Anne, baba, kardeş, çocuk',
                    FamilyDiabetesHistory.firstDegree,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: VcButton(
                  text: 'Riski Hesapla',
                  icon: Icons.calculate,
                  onPressed: _calculateFindrisc,
                ),
              ),
            ],
          ),
        ),
        if (_findrisc != null) ...[
          const SizedBox(height: 16),
          _findriscResultCard(_findrisc!),
        ],
        const SizedBox(height: 16),
        _disclaimer(),
      ],
    );
  }

  Widget _familyChip(String label, FamilyDiabetesHistory value) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _family == value,
      onSelected: (_) => setState(() => _family = value),
    );
  }

  Widget _findriscResultCard(FindriscResult r) {
    final color = _levelColor(r.level);
    final summary =
        'Diyabet risk puanınız 26 üzerinden ${r.score}. Risk düzeyi: '
        '${r.level.label}. On yıl içinde tip 2 diyabet görülme olasılığı '
        '${r.estimatedRisk}. ${r.advice}';
    return VcCard(
      borderColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${r.score}',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(' / 26', style: TextStyle(color: AppColors.textHint)),
              const Spacer(),
              _levelBadge(r.level.label, color),
              SpeakButton(text: summary, id: 'findrisc'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '10 yıllık tahmini risk: ${r.estimatedRisk}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(r.advice),
          const Divider(height: 24),
          ...r.breakdown.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    '+${e.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: e.value > 0 ? color : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFraminghamTab() {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        _infoCard(
          'Framingham Kalp-Damar Risk Skoru',
          '10 yıl içinde kalp krizi, inme veya kalp yetmezliği gibi bir '
              'kardiyovasküler olay yaşama olasılığını kolesterol tahlili '
              'gerektirmeyen BMI tabanlı modelle tahmin eder (30-74 yaş).\n'
              'Kaynak: D\'Agostino ve ark., Circulation 2008.',
        ),
        const SizedBox(height: 12),
        VcCard(
          child: Column(
            children: [
              _commonFields(),
              const SizedBox(height: 12),
              _numberField(_sbpCtrl, 'Büyük tansiyon (sistolik, mmHg)'),
              const SizedBox(height: 4),
              _switch(
                'Tansiyon ilacı kullanıyorum',
                _bpMedication,
                (v) => _bpMedication = v,
              ),
              _switch('Sigara kullanıyorum', _smoker, (v) => _smoker = v),
              _switch('Diyabet tanısı var', _diabetic, (v) => _diabetic = v),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: VcButton(
                  text: 'Riski Hesapla',
                  icon: Icons.calculate,
                  color: AppColors.accentRisk,
                  onPressed: _calculateFramingham,
                ),
              ),
            ],
          ),
        ),
        if (_framinghamNote != null) ...[
          const SizedBox(height: 16),
          VcCard(
            borderColor: AppColors.warning,
            child: Text(_framinghamNote!),
          ),
        ],
        if (_framingham != null) ...[
          const SizedBox(height: 16),
          _framinghamResultCard(_framingham!),
        ],
        const SizedBox(height: 16),
        _disclaimer(),
      ],
    );
  }

  Widget _framinghamResultCard(FraminghamResult r) {
    final color = _levelColor(r.level);
    final percent = r.percent.toStringAsFixed(1).replaceAll('.', ',');
    final age = _age ?? 0;
    final vascular = r.vascularAge >= 100 ? '100+' : '${r.vascularAge}';
    final summary =
        'On yıllık kalp damar hastalığı riskiniz yüzde $percent. Risk düzeyi: '
        '${r.level.label}. Tahmini damar yaşınız $vascular. ${r.advice}';
    return VcCard(
      borderColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              _levelBadge(r.level.label, color),
              SpeakButton(text: summary, id: 'framingham'),
            ],
          ),
          Text(
            '10 yıllık kardiyovasküler olay riski',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.favorite, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tahmini damar yaşınız: $vascular'
                  '${age > 0 ? ' (gerçek yaşınız $age)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.advice),
        ],
      ),
    );
  }

  Widget _levelBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoCard(String title, String body) {
    return VcCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: AppColors.accentRisk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _disclaimer() {
    return Text(
      'Bu hesaplamalar tarama amaçlıdır, tanı koymaz. '
      '${AppConstants.medicalDisclaimer}',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.textHint),
    );
  }
}
