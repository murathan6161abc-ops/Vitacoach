import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../m03_chronic/providers/chronic_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _hiveService = HiveService();

  String _name = '';
  double _height = 0;
  double _weight = 0;
  String _gender = '';
  List<dynamic> _conditions = [];
  List<dynamic> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final box = _hiveService.getProfileBox();
    setState(() {
      _name = box.get('name', defaultValue: '') ?? '';
      // Eski sürümler bu alanlara int (0) yazmış olabilir; doğrudan double
      // alana atamak TypeError ile ekranı çökertir.
      _height = (box.get('height') as num?)?.toDouble() ?? 0;
      _weight = (box.get('weight') as num?)?.toDouble() ?? 0;
      _gender = box.get('gender', defaultValue: '') ?? '';
      _conditions = List<dynamic>.from(box.get('conditions') ?? const []);
      _goals = List<dynamic>.from(box.get('goals') ?? const []);
    });
  }

  /// Bu ekran boy/kilo/hastalık/hedef değişikliklerini doğrudan Hive'a
  /// yazar. ProfileProvider'ı da tazelemezsek, uygulamanın geri kalanı
  /// (ör. ana ekran karşılaması, beslenme/kalori hesapları) yeniden
  /// başlatılana kadar eski profille çalışmaya devam eder.
  void _syncProvider() {
    if (!mounted) return;
    context.read<ProfileProvider>().loadProfile();
  }

  double get _bmi {
    if (_height <= 0 || _weight <= 0) return 0;
    final heightM = _height / 100;
    return _weight / (heightM * heightM);
  }

  String get _bmiCategory {
    if (_bmi == 0) return '';
    if (_bmi < 18.5) return 'Zayıf';
    if (_bmi < 25) return 'Normal';
    if (_bmi < 30) return 'Fazla Kilolu';
    return 'Obez';
  }

  Future<void> _showEditDialog() async {
    String format(double v) => v <= 0
        ? ''
        : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    final heightCtrl = TextEditingController(text: format(_height));
    final weightCtrl = TextEditingController(text: format(_weight));
    final chronic = context.read<ChronicProvider>();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Boy ve Kilo Güncelle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Boy (cm)',
                  suffixText: 'cm',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Kilo (kg)',
                  suffixText: 'kg',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(errorText!, style: TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Virgüllü girişi ("72,5") de kabul et; önceden sessizce
                // reddediliyor ve Kaydet hiçbir şey yapmıyordu.
                final h = InputUtils.inRange(
                  InputUtils.parseDecimal(heightCtrl.text),
                  50.0,
                  250.0,
                );
                final w = InputUtils.inRange(
                  InputUtils.parseDecimal(weightCtrl.text),
                  20.0,
                  350.0,
                );
                if (h == null || w == null) {
                  setDialogState(() {
                    errorText = h == null
                        ? 'Boy 50-250 cm arasında olmalı.'
                        : 'Kilo 20-350 kg arasında olmalı.';
                  });
                  return;
                }
                await _hiveService.getProfileBox().put('height', h);
                // Kilo yalnızca profile yazılıyor, geçmişe hiç işlenmiyordu;
                // kilo trendi, PDF rapor ve asistan boş kalıyordu.
                if (w != _weight) await chronic.addWeight(w);
                if (ctx.mounted) {
                  setState(() {
                    _height = h;
                    _weight = w;
                  });
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    if (!mounted) return;
    _syncProvider();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bilgiler başarıyla güncellendi.')),
    );
  }

  Future<void> _showConditionsEditDialog() async {
    final availableConditions = [
      'Diyabet',
      'Hipertansiyon',
      'Astım',
      'Kalp Hastalığı',
      'Kanser',
      'Yok',
    ];
    final selected = List<String>.from(_conditions);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Kronik Hastalıklar'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: availableConditions.map((c) {
                  return CheckboxListTile(
                    title: Text(c),
                    value: selected.contains(c),
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          if (c == 'Yok') {
                            selected.clear();
                            selected.add('Yok');
                          } else {
                            selected.remove('Yok');
                            selected.add(c);
                          }
                        } else {
                          selected.remove(c);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await _hiveService.getProfileBox().put('conditions', selected);
      setState(() => _conditions = selected);
      _syncProvider();
    }
  }

  Future<void> _showGoalsEditDialog() async {
    final availableGoals = [
      'Kilo ver',
      'Sağlıklı beslen',
      'Sigara bırak',
      'Stres azalt',
      'Egzersiz yap',
    ];
    final selected = List<String>.from(_goals);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Hedefler'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: availableGoals.map((g) {
                  return CheckboxListTile(
                    title: Text(g),
                    value: selected.contains(g),
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          selected.add(g);
                        } else {
                          selected.remove(g);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await _hiveService.getProfileBox().put('goals', selected);
      setState(() => _goals = selected);
      _syncProvider();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppConstants.routeSettings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildBmiCard(),
            const SizedBox(height: 16),
            _buildInfoCard(
              'Kronik Hastalıklar',
              _conditions,
              onEdit: _showConditionsEditDialog,
            ),
            const SizedBox(height: 16),
            _buildInfoCard('Hedefler', _goals, onEdit: _showGoalsEditDialog),
            const SizedBox(height: 16),
            VcCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.medical_information,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Acil Sağlık Kartı',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Kan grubu, alerjiler, acil kişiler, QR',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppConstants.routeEmergencyCard),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.picture_as_pdf,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Doktor İçin PDF Rapor',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Ölçümler, ilaçlar ve risk skorları'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppConstants.routeReport),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return VcCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              _name.isNotEmpty ? InputUtils.upperTr(_name[0]) : '?',
              style: TextStyle(
                fontSize: 28,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileSummary,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: AppColors.primary),
            onPressed: _showEditDialog,
          ),
        ],
      ),
    );
  }

  /// Boş alanlar "• 0 cm • 0 kg" gibi anlamsız bir özet üretiyordu.
  String get _profileSummary {
    final parts = <String>[
      if (_gender.isNotEmpty) _gender,
      if (_height > 0) '${_height.round()} cm',
      if (_weight > 0)
        '${_weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1)} kg',
    ];
    return parts.isEmpty ? 'Boy ve kilo bilgisi girilmedi' : parts.join(' • ');
  }

  Widget _buildBmiCard() {
    if (_bmi <= 0) {
      return VcCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.monitor_weight, color: AppColors.primary),
          title: const Text(
            'Vücut Kitle İndeksi (BMI)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Hesaplamak için boy ve kilonuzu girin.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showEditDialog,
        ),
      );
    }

    final color = _bmi < 18.5
        ? AppColors.warning
        : _bmi < 25
        ? AppColors.success
        : _bmi < 30
        ? AppColors.warning
        : AppColors.danger;

    return VcCard(
      borderColor: color.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vücut Kitle İndeksi (BMI)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _bmiCategory,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _bmi.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    List<dynamic> items, {
    VoidCallback? onEdit,
  }) {
    return VcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.primary, size: 20),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(
                      item.toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                    backgroundColor: AppColors.primaryContainer,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
