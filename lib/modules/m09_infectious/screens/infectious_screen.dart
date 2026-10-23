import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/vc_card.dart';

class InfectiousScreen extends StatefulWidget {
  const InfectiousScreen({super.key});

  @override
  State<InfectiousScreen> createState() => _InfectiousScreenState();
}

class _InfectiousScreenState extends State<InfectiousScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _childVaccines = [];
  List<dynamic> _adultVaccines = [];
  Set<String> _completedVaccines = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/vaccine_schedule_tr.json',
      );
      final data = json.decode(jsonString);
      final box = HiveService().getVaccineBox();
      final completed =
          box.get('completed_vaccines', defaultValue: <dynamic>[]) ?? [];
      if (!mounted) return;
      setState(() {
        _childVaccines = data['child_vaccines'];
        _adultVaccines = data['adult_vaccines'];
        _completedVaccines = Set<String>.from(completed);
      });
    } catch (e) {
      debugPrint('Aşı verisi yükleme hatası: $e');
    }
  }

  Future<void> _toggleVaccine(String id) async {
    setState(() {
      if (_completedVaccines.contains(id)) {
        _completedVaccines.remove(id);
      } else {
        _completedVaccines.add(id);
      }
    });
    final box = HiveService().getVaccineBox();
    await box.put('completed_vaccines', _completedVaccines.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aşı & Bulaşıcı Hastalık'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Çocuk Aşıları'),
            Tab(text: 'Yetişkin Aşıları'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChildVaccineList(), _buildAdultVaccineList()],
      ),
    );
  }

  Widget _buildChildVaccineList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: _childVaccines.length,
      itemBuilder: (context, index) {
        final vaccine = _childVaccines[index];
        final completed = _completedVaccines.contains(vaccine['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VcCard(
            borderColor: completed
                ? AppColors.success.withValues(alpha: 0.3)
                : null,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: completed,
                activeColor: AppColors.success,
                onChanged: (_) => _toggleVaccine(vaccine['id']),
              ),
              title: Text(
                vaccine['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vaccine['age_label'],
                    style: const TextStyle(color: AppColors.accentInfectious),
                  ),
                  if (vaccine['notes'].isNotEmpty)
                    Text(
                      vaccine['notes'],
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdultVaccineList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: _adultVaccines.length,
      itemBuilder: (context, index) {
        final vaccine = _adultVaccines[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VcCard(
            borderColor: AppColors.accentInfectious.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaccine['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sıklık: ${vaccine['frequency']}',
                  style: const TextStyle(color: AppColors.accentInfectious),
                ),
                Text(
                  'Hedef grup: ${vaccine['target_group']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (vaccine['notes'].isNotEmpty)
                  Text(
                    vaccine['notes'],
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
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
