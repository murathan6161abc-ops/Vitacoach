import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hive_service.dart';
import '../../../shared/widgets/vc_card.dart';
import '../../../shared/widgets/vc_button.dart';
import '../../m01_profile/models/user_profile.dart';
import '../models/food_model.dart';
import '../providers/nutrition_provider.dart';
import '../services/meal_planner.dart';
import '../widgets/food_search_delegate.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MealPlan? _mealPlan;
  int _planSeed = DateTime.now().difference(DateTime(2024)).inDays;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Öğün ve su verisi NutritionProvider'da tek kaynaktan gelir; ekran
  // kendi kopyasını tutmaz (build'de watch ile dinlenir).
  NutritionProvider get _nutrition => context.read<NutritionProvider>();
  List<Map<String, dynamic>> get _foodCategories => _nutrition.foodCategories;
  List<Map<String, dynamic>> get _todayMeals => _nutrition.todayMeals;
  int get _waterCount => _nutrition.waterCount;
  bool get _isDiabetic => _nutrition.isDiabetic;
  int get _totalCalories => _nutrition.totalCalories;
  int get _totalProtein => _nutrition.totalProtein;
  int get _totalCarbs => _nutrition.totalCarbs;
  int get _totalFat => _nutrition.totalFat;

  Future<void> _addFood(Map<String, dynamic> food) => _nutrition.addMeal(food);

  Future<void> _addWater() async {
    await _nutrition.addWater();
    if (!mounted) return;
    if (_waterCount * AppConstants.waterGlassMl > 4000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fazla su tüketimi (su zehirlenmesi) riski! Lütfen dikkatli olun.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Yanlışlıkla eklenen öğün önceden gün boyu silinemiyordu.
  Future<void> _removeMeal(int index) async {
    final removed = await _nutrition.removeMeal(index);
    if (removed == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${removed['name'] ?? 'Öğün'} silindi')),
    );
  }

  Future<void> _removeWater() => _nutrition.removeWater();

  Future<void> _openFoodSearch() async {
    final selected = await showSearch<Food?>(
      context: context,
      delegate: FoodSearchDelegate(
        foods: _nutrition.allFoods,
        isDiabetic: _isDiabetic,
      ),
    );
    if (selected == null || !mounted) return;
    await _addFood(selected.toMap());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${selected.name} eklendi')));
  }

  /// Cihaz üzerinde, profil ve hedeflere göre öğün planı oluşturur.
  /// (Önceden bu özellik internet üzerinden bir yapay zekâ servisine
  /// bağlıydı; artık hiçbir veri cihazdan çıkmaz.)
  void _generateMealPlan({bool newVariant = false}) {
    if (_foodCategories.isEmpty) return;
    final box = HiveService().getProfileBox();
    final profile = UserProfile.fromMap({
      'birth_date': box.get('birth_date'),
      'gender': box.get('gender'),
      'height': box.get('height'),
      'weight': box.get('weight'),
      'conditions': box.get('conditions'),
      'goals': box.get('goals'),
    });
    final hasData = profile.height > 0 && profile.weight > 0 && profile.age > 0;
    final target = MealPlanner.dailyTarget(
      bmr: profile.dailyCalorieNeed,
      wantsToLoseWeight: profile.wantsToLoseWeight,
      isMale: profile.gender == 'Erkek',
      hasProfileData: hasData,
    );
    if (newVariant) _planSeed++;
    setState(() {
      _mealPlan = MealPlanner.generate(
        foodsByCategory: _nutrition.foodsByCategory,
        targetCalories: target,
        diabetic: _isDiabetic,
        seed: _planSeed,
      );
    });
  }

  Future<void> _addPlannedMeal(PlannedMeal meal) async {
    for (final food in meal.items) {
      await _addFood({...food.toMap(), 'meal_type': meal.mealType});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${meal.title} günlüğe eklendi')));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<NutritionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beslenme'),
        actions: [
          IconButton(
            tooltip: 'Yemek ara',
            icon: const Icon(Icons.search),
            onPressed: _foodCategories.isEmpty ? null : _openFoodSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Günlük'),
            Tab(text: 'Yemek Ekle'),
            Tab(text: 'Öğün Planı'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDailyTab(), _buildFoodListTab(), _buildPlanTab()],
      ),
    );
  }

  Widget _buildDailyTab() {
    final waterProgress =
        _waterCount * AppConstants.waterGlassMl / AppConstants.dailyWaterGoalMl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        children: [
          VcCard(
            child: Column(
              children: [
                Text(
                  'Bugünkü Kalori',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$_totalCalories',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text('kcal', style: TextStyle(color: AppColors.textHint)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _macroChip(
                      'Protein',
                      '${_totalProtein}g',
                      AppColors.accentFitness,
                    ),
                    _macroChip('Karb', '${_totalCarbs}g', AppColors.warning),
                    _macroChip(
                      'Yağ',
                      '${_totalFat}g',
                      AppColors.accentMaternal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          VcCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Su Takibi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_waterCount * AppConstants.waterGlassMl} / ${AppConstants.dailyWaterGoalMl} ml',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: waterProgress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.primaryContainer,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Bir bardak geri al',
                      onPressed: _waterCount > 0 ? _removeWater : null,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: VcButton(
                        text: '+ 1 Bardak (250ml)',
                        onPressed: _addWater,
                        icon: Icons.water_drop,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_todayMeals.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bugün Yedikleriniz',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ..._todayMeals.asMap().entries.map(
              (entry) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.restaurant,
                  color: AppColors.accentNutrition,
                ),
                title: Text('${entry.value['name'] ?? ''}'),
                subtitle: Text('${entry.value['calories'] ?? 0} kcal'),
                trailing: IconButton(
                  tooltip: 'Sil',
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  onPressed: () => _removeMeal(entry.key),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildFoodListTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: _foodCategories.length,
      itemBuilder: (context, index) {
        final category = _foodCategories[index];
        return ExpansionTile(
          title: Text(
            category['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: (category['foods'] as List).map<Widget>((food) {
            final isHighGI = _isDiabetic && (food['gi'] as num) > 55;
            return ListTile(
              title: Text(
                food['name'],
                style: TextStyle(
                  color: isHighGI ? AppColors.danger : null,
                  decoration: isHighGI ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${food['calories']} kcal • ${food['portion']}${isHighGI ? ' (Yüksek GI!)' : ''}',
              ),
              trailing: IconButton(
                icon: Icon(Icons.add_circle, color: AppColors.primary),
                onPressed: () {
                  _addFood(Map<String, dynamic>.from(food));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${food['name']} eklendi')),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPlanTab() {
    final plan = _mealPlan;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VcCard(
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 48,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kişisel Öğün Planı',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Günlük kalori ihtiyacınız profilinizdeki boy, kilo, yaş ve '
                  'cinsiyetten (Harris-Benedict) hesaplanır; hedefinize göre '
                  'ayarlanır.${_isDiabetic ? ' Diyabet seçili olduğu için yüksek glisemik indeksli (GI>55) yiyecekler çıkarılır.' : ''} '
                  'Plan tamamen cihazınızda oluşturulur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                VcButton(
                  text: plan == null
                      ? 'Öğün Planı Oluştur'
                      : 'Farklı Plan Öner',
                  onPressed: () => _generateMealPlan(newVariant: plan != null),
                  icon: Icons.autorenew,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 16),
            VcCard(
              borderColor: AppColors.secondary.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Günlük hedef: ${plan.targetCalories} kcal\n'
                      'Plan toplamı: ${plan.calories} kcal',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            ...plan.meals.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: VcCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meal.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${meal.calories} kcal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...meal.items.map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${f.name} — ${f.portion}')),
                              Text(
                                '${f.calories}',
                                style: TextStyle(color: AppColors.textHint),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'P ${meal.protein}g • K ${meal.carbs}g • Y ${meal.fat}g',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _addPlannedMeal(meal),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Günlüğe ekle'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppConstants.medicalDisclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}
