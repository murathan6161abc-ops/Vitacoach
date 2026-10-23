import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_utils.dart';
import '../models/food_model.dart';

/// Yemek arama ekranı. Seçilen yemeği [close] ile geri döndürür; kaydetmeyi
/// çağıran ekran yapar.
///
/// Önceki sürüm hiçbir yerden açılmıyordu; açılsaydı da seçimi
/// NutritionProvider üzerinden kendi başına Hive'a yazıyordu. Beslenme
/// ekranı aynı gün anahtarını kendi listesiyle yönettiği için iki yazıcı
/// birbirinin kaydını silecekti.
class FoodSearchDelegate extends SearchDelegate<Food?> {
  final List<Food> foods;
  final bool isDiabetic;

  FoodSearchDelegate({required this.foods, this.isDiabetic = false})
    : super(
        searchFieldLabel: 'Yemek ara...',
        searchFieldStyle: const TextStyle(fontSize: 16),
      );

  List<Food> _search(String query) {
    final q = InputUtils.normalizeForSearch(query);
    if (q.isEmpty) return const [];
    return foods
        .where((f) => InputUtils.normalizeForSearch(f.name).contains(q))
        .toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Text(
          'Yemek adı yazarak arayın',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    final results = _search(query);
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Sonuç bulunamadı',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final food = results[index];
        final isHighGI = isDiabetic && food.isHighGI;
        return ListTile(
          title: Text(
            food.name,
            style: TextStyle(color: isHighGI ? AppColors.danger : null),
          ),
          subtitle: Text(
            '${food.calories} kcal • ${food.portion}'
            '${isHighGI ? ' (Yüksek GI!)' : ''}',
          ),
          trailing: IconButton(
            tooltip: 'Ekle',
            icon: Icon(Icons.add_circle, color: AppColors.primary),
            onPressed: () => close(context, food),
          ),
          onTap: () => close(context, food),
        );
      },
    );
  }
}
