import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/vc_button.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../../modules/m11_access/providers/access_provider.dart';
import '../services/triage.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({super.key});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  List<dynamic> _categories = [];
  final List<Map<String, dynamic>> _selectedSymptoms = [];
  Map<String, dynamic>? _triageResult;

  // Sonuç kartı kategori listesinin altında çizilir; değerlendirmeden
  // sonra ekran oraya kaydırılmazsa kullanıcı (acil durumda bile) sonucu
  // görmeyebilir.
  final GlobalKey _resultKey = GlobalKey();

  // emergency_flags.json'daki kombinasyon kuralları (bkz. FlagRule).
  List<FlagRule> _flags = const [];

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
    _loadEmergencyFlags();
  }

  Future<void> _loadSymptoms() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/symptoms.json',
      );
      final data = json.decode(jsonString);
      if (!mounted) return;
      setState(() => _categories = data['categories']);
    } catch (e) {
      debugPrint('Semptom yükleme hatası: $e');
    }
  }

  Future<void> _loadEmergencyFlags() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/emergency_flags.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _flags = FlagRule.listFromJson(data));
    } catch (e) {
      debugPrint('Acil durum kuralları yüklenemedi: $e');
    }
  }

  void _toggleSymptom(Map<String, dynamic> symptom) {
    setState(() {
      final exists = _selectedSymptoms.any((s) => s['id'] == symptom['id']);
      if (exists) {
        _selectedSymptoms.removeWhere((s) => s['id'] == symptom['id']);
      } else {
        _selectedSymptoms.add(symptom);
      }
      _triageResult = null;
    });
  }

  void _performTriage() {
    if (_selectedSymptoms.isEmpty) return;

    // Kombinasyon kuralları tek tek belirtilerin önem derecesinden daha
    // önceliklidir (bkz. assessSymptoms).
    final result = assessSymptoms(
      severityById: {
        for (final s in _selectedSymptoms) '${s['id']}': '${s['severity']}',
      },
      flags: _flags,
    );
    final flag = result.flag;

    setState(() {
      _triageResult = switch (result.level) {
        TriageLevel.red => {
          'level': 'red',
          'title': 'ACİL DURUM',
          'message':
              flag?.message ??
              'Seçtiğiniz belirtiler acil müdahale gerektirebilir. Hemen 112\'yi arayın!',
          'flagName': flag?.name,
          'color': AppColors.danger,
        },
        TriageLevel.yellow => {
          'level': 'yellow',
          'title': 'DİKKAT',
          'message':
              flag?.message ??
              'Belirtileriniz tıbbi değerlendirme gerektirebilir. 24 saat içinde doktora başvurmanız önerilir.',
          'flagName': flag?.name,
          'color': AppColors.warning,
        },
        TriageLevel.green => {
          'level': 'green',
          'title': 'DÜŞÜK RİSK',
          'message':
              'Belirtileriniz şu an için düşük riskli görünüyor. Şikayetleriniz artarsa doktora başvurun.',
          'color': AppColors.success,
        },
      };
    });

    _saveTriageToHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultContext = _resultKey.currentContext;
      if (resultContext == null || !resultContext.mounted) return;
      Scrollable.ensureVisible(
        resultContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  /// Değerlendirme sonucunu geçmişe kaydeder. Önceden bu ekran hiçbir
  /// zaman 'symptom_history' yazmıyordu; bu yüzden geçmiş sekmesi hep
  /// boştu.
  void _saveTriageToHistory() {
    if (_triageResult == null) return;
    try {
      final box = HiveService().getHealthBox();
      final history = List<dynamic>.from(
        box.get('symptom_history', defaultValue: <dynamic>[]) ?? [],
      );
      history.add({
        'symptoms': _selectedSymptoms.map((s) => s['name']).toList(),
        'triage': _triageResult!['level'],
        'flag': _triageResult!['flagName'],
        'date': DateTime.now().toIso8601String(),
      });
      box.put('symptom_history', history);
    } catch (e) {
      debugPrint('Belirti geçmişi kaydedilemedi: $e');
    }
  }

  /// 112'yi arar; arama başlatılamazsa kullanıcıya bildirir (sessiz
  /// başarısızlık acil durumda tehlikelidir).
  Future<void> _callEmergency() async {
    final started = await AccessProvider().callNumber('112');
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arama başlatılamadı. Lütfen 112\'yi elle arayın.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belirti Sorgulama')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Belirtilerinizi seçin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._categories.map((cat) => _buildCategory(cat)),
                  if (_triageResult != null) ...[
                    const SizedBox(height: 16),
                    KeyedSubtree(key: _resultKey, child: _buildTriageResult()),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildCategory(Map<String, dynamic> category) {
    return ExpansionTile(
      title: Text(
        category['name'],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (category['symptoms'] as List).map((symptom) {
            final selected = _selectedSymptoms.any(
              (s) => s['id'] == symptom['id'],
            );
            final severityColor = symptom['severity'] == 'red'
                ? AppColors.danger
                : symptom['severity'] == 'yellow'
                ? AppColors.warning
                : AppColors.success;
            return FilterChip(
              label: Text(symptom['name']),
              selected: selected,
              selectedColor: severityColor.withValues(alpha: 0.2),
              checkmarkColor: severityColor,
              onSelected: (_) => _toggleSymptom(symptom),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTriageResult() {
    final color = _triageResult!['color'] as Color;
    return VcCard(
      borderColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _triageResult!['level'] == 'red' ? Icons.emergency : Icons.info,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _triageResult!['title'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              SpeakButton(
                id: 'triage',
                color: color,
                text:
                    '${_triageResult!['title']}. ${_triageResult!['flagName'] ?? ''}. ${_triageResult!['message']}',
              ),
            ],
          ),
          if (_triageResult!['flagName'] != null) ...[
            const SizedBox(height: 4),
            Text(
              _triageResult!['flagName'],
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
          const SizedBox(height: 8),
          Text(_triageResult!['message']),
          if (_triageResult!['level'] == 'red') ...[
            const SizedBox(height: 12),
            VcButton(
              text: '112\'yi Ara',
              onPressed: _callEmergency,
              color: AppColors.danger,
              icon: Icons.phone,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: VcButton(
              text: 'Değerlendir (${_selectedSymptoms.length})',
              onPressed: _performTriage,
            ),
          ),
        ],
      ),
    );
  }
}
