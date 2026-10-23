import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../services/hive_service.dart';
import '../../../services/notification_service.dart';
import '../../../shared/widgets/vc_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Form data
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String _gender = '';
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final List<String> _selectedConditions = [];
  final List<String> _selectedGoals = [];
  bool _waterReminderEnabled = true;
  bool _medicationReminderEnabled = true;
  bool _exerciseReminderEnabled = true;

  final _conditions = [
    'Diyabet',
    'Hipertansiyon',
    'Astım',
    'Kalp Hastalığı',
    'Kanser',
    'Yok',
  ];

  final _goals = [
    'Kilo ver',
    'Sağlıklı beslen',
    'Sigara bırak',
    'Stres azalt',
    'Egzersiz yap',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Boy/kilo boş bırakılabilir; ama bir şey yazıldıysa geçerli olmalı.
  /// Aksi halde BMI ve kalori hesapları anlamsız sonuç üretir.
  String? _validatePersonalInfo() {
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();
    if (heightText.isNotEmpty &&
        InputUtils.inRange(InputUtils.parseDecimal(heightText), 50.0, 250.0) ==
            null) {
      return 'Boy 50-250 cm arasında olmalı.';
    }
    if (weightText.isNotEmpty &&
        InputUtils.inRange(InputUtils.parseDecimal(weightText), 20.0, 350.0) ==
            null) {
      return 'Kilo 20-350 kg arasında olmalı.';
    }
    return null;
  }

  void _nextStep() {
    if (_currentStep == 1) {
      final error = _validatePersonalInfo();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
    }
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeOnboarding() async {
    final hiveService = HiveService();
    final box = hiveService.getProfileBox();

    await box.put('name', _nameController.text.trim());
    await box.put('birth_date', _birthDate?.toIso8601String());
    await box.put('gender', _gender);
    // Mutlaka double yazılmalı: `?? 0` bir int üretir ve Profil ekranı bu
    // değeri double alana atarken TypeError ile çöker.
    await box.put(
      'height',
      InputUtils.parseDecimal(_heightController.text) ?? 0.0,
    );
    await box.put(
      'weight',
      InputUtils.parseDecimal(_weightController.text) ?? 0.0,
    );
    await box.put('conditions', _selectedConditions);
    await box.put('goals', _selectedGoals);

    // Hatırlatıcılar önceden yalnızca "açık" olarak kaydediliyor ama hiç
    // kurulmuyordu; Ayarlar ekranı açık gösterirken hiçbir bildirim
    // gelmiyordu. Seçilenleri gerçekten planla; izin verilmezse kapalı say.
    var water = _waterReminderEnabled;
    var exercise = _exerciseReminderEnabled;
    if (water || exercise || _medicationReminderEnabled) {
      try {
        final granted = await NotificationService().requestPermissions();
        if (!granted) {
          water = false;
          exercise = false;
        }
        if (water) await NotificationService().setWaterRemindersEnabled(true);
        if (exercise) {
          await NotificationService().setExerciseReminderEnabled(true);
        }
      } catch (error) {
        debugPrint('Hatırlatıcılar kurulamadı: $error');
        water = false;
        exercise = false;
      }
    }

    await box.put('water_reminder_enabled', water);
    await box.put('medication_reminder_enabled', _medicationReminderEnabled);
    await box.put('exercise_reminder_enabled', exercise);
    await box.put(
      'notifications_enabled',
      water || _medicationReminderEnabled || exercise,
    );
    await hiveService.setOnboardingCompleted(true);

    if (mounted) {
      context.go(AppConstants.routeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildPersonalInfoPage(),
                  _buildConditionsPage(),
                  _buildGoalsPage(),
                  _buildNotificationsPage(),
                ],
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Row(
        children: List.generate(5, (index) {
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: index <= _currentStep
                    ? AppColors.primary
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Uygulama simgesiyle aynı yuvarlak logo.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 112,
              height: 112,
              semanticLabel: 'VitaCoach logosu',
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'VitaCoach\'a Hoş Geldiniz!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Yapay zeka destekli kişisel sağlık koçunuz ile daha sağlıklı bir yaşama adım atın.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kişisel Bilgiler',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Adınız',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime(1990),
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _birthDate = date);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Doğum Tarihi',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Builder(
                builder: (context) {
                  final months = [
                    'Ocak',
                    'Şubat',
                    'Mart',
                    'Nisan',
                    'Mayıs',
                    'Haziran',
                    'Temmuz',
                    'Ağustos',
                    'Eylül',
                    'Ekim',
                    'Kasım',
                    'Aralık',
                  ];
                  return Text(
                    _birthDate != null
                        ? '${_birthDate!.day} ${months[_birthDate!.month - 1]} ${_birthDate!.year}'
                        : 'Seçin',
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cinsiyet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _GenderChip(
                label: 'Erkek',
                selected: _gender == 'Erkek',
                onTap: () => setState(() => _gender = 'Erkek'),
              ),
              const SizedBox(width: 12),
              _GenderChip(
                label: 'Kadın',
                selected: _gender == 'Kadın',
                onTap: () => setState(() => _gender = 'Kadın'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Boy (cm)',
                    prefixIcon: Icon(Icons.height),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Kilo (kg)',
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsPage() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kronik Hastalıklar',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Varsa kronik hastalıklarınızı seçin',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _conditions.map((condition) {
              final selected = _selectedConditions.contains(condition);
              return FilterChip(
                label: Text(condition),
                selected: selected,
                selectedColor: AppColors.primaryContainer,
                checkmarkColor: AppColors.primary,
                onSelected: (value) {
                  setState(() {
                    if (condition == 'Yok') {
                      _selectedConditions.clear();
                      if (value) _selectedConditions.add(condition);
                    } else {
                      _selectedConditions.remove('Yok');
                      if (value) {
                        _selectedConditions.add(condition);
                      } else {
                        _selectedConditions.remove(condition);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsPage() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hedefleriniz',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sağlık hedeflerinizi seçin',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goals.map((goal) {
              final selected = _selectedGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: selected,
                selectedColor: AppColors.primaryContainer,
                checkmarkColor: AppColors.primary,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedGoals.add(goal);
                    } else {
                      _selectedGoals.remove(goal);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPage() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bildirimler',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sağlık hatırlatıcıları almak ister misiniz?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          SwitchListTile(
            title: const Text('Su hatırlatıcısı'),
            subtitle: const Text('Günde 3 kez (10:00, 14:00, 18:00)'),
            value: _waterReminderEnabled,
            // ignore: deprecated_member_use
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _waterReminderEnabled = v),
          ),
          SwitchListTile(
            title: const Text('İlaç hatırlatıcısı'),
            subtitle: const Text('Belirlediğiniz saatlerde'),
            value: _medicationReminderEnabled,
            // ignore: deprecated_member_use
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _medicationReminderEnabled = v),
          ),
          SwitchListTile(
            title: const Text('Egzersiz hatırlatıcısı'),
            subtitle: const Text('Her gün 19:00'),
            value: _exerciseReminderEnabled,
            // ignore: deprecated_member_use
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _exerciseReminderEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Row(
        children: [
          if (_currentStep > 0)
            VcButton(text: 'Geri', onPressed: _previousStep, isOutlined: true),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: VcButton(
              text: _currentStep == 4 ? 'Tamamla' : 'İleri',
              onPressed: _nextStep,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.textHint,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
