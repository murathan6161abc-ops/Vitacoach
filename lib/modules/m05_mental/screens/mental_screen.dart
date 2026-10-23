// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../../shared/widgets/vc_button.dart';
import '../../../modules/m11_access/providers/access_provider.dart';
import '../models/mental_model.dart';
import '../providers/mental_provider.dart';

class MentalScreen extends StatefulWidget {
  const MentalScreen({super.key});

  @override
  State<MentalScreen> createState() => _MentalScreenState();
}

class _MentalScreenState extends State<MentalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _cbtExercises = [];

  // Uzunluklar model içindeki soru listelerinden türetilir.
  final List<int> _phq9Scores = List.filled(PHQ9Scoring.questions.length, -1);
  final List<int> _gad7Scores = List.filled(GAD7Scoring.questions.length, -1);

  String? _selectedMoodEmoji;
  String? _moodMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCbtExercises();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCbtExercises() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/cbt_exercises.json',
      );
      final data = json.decode(jsonString);
      if (!mounted) return;
      setState(() => _cbtExercises = data['exercises']);
    } catch (e) {
      debugPrint('CBT yükleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruh Sağlığı'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Mood'),
            Tab(text: 'PHQ-9'),
            Tab(text: 'GAD-7'),
            Tab(text: 'CBT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMoodTab(),
          _buildPHQ9Tab(),
          _buildGAD7Tab(),
          _buildCBTTab(),
        ],
      ),
    );
  }

  Widget _buildMoodTab() {
    final moods = [
      {'emoji': '😊', 'label': 'Harika', 'value': 5},
      {'emoji': '🙂', 'label': 'İyi', 'value': 4},
      {'emoji': '😐', 'label': 'Normal', 'value': 3},
      {'emoji': '😔', 'label': 'Kötü', 'value': 2},
      {'emoji': '😢', 'label': 'Çok Kötü', 'value': 1},
    ];

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugün nasıl hissediyorsunuz?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: moods.map((mood) {
              return GestureDetector(
                onTap: () async {
                  await context.read<MentalProvider>().saveMood(
                    mood['value'] as int,
                  );

                  if (!mounted) return;
                  setState(() {
                    _selectedMoodEmoji = mood['emoji'] as String;
                    _moodMessage = MoodSupportMessages.forMood(
                      mood['value'] as int,
                    );
                  });
                },
                child: Column(
                  children: [
                    Text(
                      mood['emoji'] as String,
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mood['label'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (_selectedMoodEmoji != null) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    _selectedMoodEmoji!,
                    style: const TextStyle(fontSize: 100),
                  ),
                  const SizedBox(height: 16),
                  if (_moodMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _moodMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          VcCard(
            borderColor: AppColors.danger.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(Icons.phone, color: AppColors.danger),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acil Destek',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Kendinize zarar verme düşünceniz varsa hemen arayın',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                VcButton(
                  text: AppConstants.mentalHealthCrisis,
                  onPressed: _callCrisisLine,
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kriz hattını arar; cihazda arama başlatılamazsa (ör. simülatör,
  /// uygun uygulama yok) kullanıcıya sessizce hiçbir şey olmamış gibi
  /// görünmesin diye bunu bildirir.
  Future<void> _callCrisisLine() async {
    final started = await AccessProvider().callNumber(
      AppConstants.mentalHealthCrisis,
    );
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arama başlatılamadı. Lütfen ${AppConstants.mentalHealthCrisis} numarasını elle arayın.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Puan -> renk. Eşik ve etiketlerin kendisi PHQ9Scoring/GAD7Scoring
  /// içindedir; önceden ekran soruların ve eşiklerin ikinci bir kopyasını
  /// tutuyordu (birinin güncellenip diğerinin unutulması riski).
  Color _severityColor(int total) {
    if (total <= 4) return AppColors.success;
    if (total <= 9) return AppColors.primaryLight;
    if (total <= 14) return AppColors.warning;
    if (total <= 19) return AppColors.accentAddiction;
    return AppColors.danger;
  }

  Widget _buildPHQ9Tab() {
    return _buildTestTab(
      scores: _phq9Scores,
      title: 'PHQ-9 Depresyon Testi',
      description:
          'Son 2 hafta içinde aşağıdaki sorunlardan ne sıklıkla rahatsız oldunuz?',
      questions: PHQ9Scoring.questions,
      onComplete: (scores) async {
        final total = scores.reduce((a, b) => a + b);
        final severity = '${PHQ9Scoring.severity(total)} ($total/27)';

        if (PHQ9Scoring.hasSuicidalIdeation(scores)) {
          await _showCrisisAlert();
        }

        if (mounted) {
          await context.read<MentalProvider>().saveTestResult(
            'PHQ-9',
            total,
            severity,
          );
        }

        if (mounted) {
          _showResult(total, severity, _severityColor(total), 'PHQ-9');
        }
      },
    );
  }

  Widget _buildGAD7Tab() {
    return _buildTestTab(
      scores: _gad7Scores,
      title: 'GAD-7 Anksiyete Testi',
      description:
          'Son 2 hafta içinde aşağıdaki sorunlardan ne sıklıkla rahatsız oldunuz?',
      questions: GAD7Scoring.questions,
      onComplete: (scores) async {
        final total = scores.reduce((a, b) => a + b);
        final severity = '${GAD7Scoring.severity(total)} ($total/21)';
        await context.read<MentalProvider>().saveTestResult(
          'GAD-7',
          total,
          severity,
        );
        if (!mounted) return;
        // GAD-7'de 15+ "Şiddetli"dir (PHQ-9'daki 15-19 ara bandı yok).
        final color = total >= 15 ? AppColors.danger : _severityColor(total);
        _showResult(total, severity, color, 'GAD-7');
      },
    );
  }

  Widget _buildTestTab({
    required List<int> scores,
    required String title,
    required String description,
    required List<String> questions,
    required Future<void> Function(List<int>) onComplete,
  }) {
    final options = [
      'Hiç (0)',
      'Birkaç gün (1)',
      'Günlerin yarısından fazlası (2)',
      'Neredeyse her gün (3)',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            return VcCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}. ${entry.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...options.asMap().entries.map((opt) {
                    return RadioListTile<int>(
                      dense: true,
                      title: Text(
                        opt.value,
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: opt.key,
                      groupValue: scores[entry.key],
                      activeColor: AppColors.accentMental,
                      onChanged: (v) {
                        setState(() => scores[entry.key] = v ?? -1);
                      },
                    );
                  }),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: VcButton(
              text: 'Sonucu Gör',
              onPressed: () async {
                if (scores.contains(-1)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen tüm soruları yanıtlayın'),
                    ),
                  );
                  return;
                }
                await onComplete(scores);
              },
              color: AppColors.accentMental,
            ),
          ),
        ],
      ),
    );
  }

  void _showResult(int total, String severity, Color color, String testName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$testName Sonucu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                severity,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            if (total >= 10)
              Text(
                'Bu puan klinik değerlendirme gerektirebilir. Bir uzmana danışmanız önerilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            const SizedBox(height: 8),
            Text(
              AppConstants.medicalDisclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCrisisAlert() {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Önemli'),
          ],
        ),
        content: const Text(
          'Kendinize zarar verme düşünceniz varsa yalnız kalmayın; hemen 112\'yi arayın veya en yakın acil servise başvurun.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _callCrisisLine();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text(
              '112\'yi Ara',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markCbtCompleted(String id) async {
    final box = HiveService().getMoodBox();
    final done = List<dynamic>.from(box.get('cbt_completed') ?? const []);
    done.add({'id': id, 'date': DateTime.now().toIso8601String()});
    await box.put('cbt_completed', done);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Harika! Egzersiz kaydedildi.')),
    );
  }

  Widget _buildCBTTab() {
    if (_cbtExercises.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: _cbtExercises.length,
      itemBuilder: (context, index) {
        final exercise = _cbtExercises[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VcCard(
            borderColor: AppColors.accentMental.withValues(alpha: 0.2),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                exercise['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${exercise['duration_minutes']} dk • ${exercise['category']}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.accentMental,
                ),
              ),
              children: [
                Text(
                  exercise['description'],
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...(exercise['steps'] as List).asMap().entries.map((step) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${step.key + 1}. ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            step.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (exercise['example'] != null &&
                    exercise['example'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Örnek: ${exercise['example']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _markCbtCompleted('${exercise['id']}'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tamamladım'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
