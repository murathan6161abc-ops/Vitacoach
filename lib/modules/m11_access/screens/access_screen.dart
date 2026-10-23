import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/vc_card.dart';
import '../providers/access_provider.dart';

class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sağlık Erişimi'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: [
              Tab(text: 'Jenerik İlaçlar'),
              Tab(text: 'Yakın Tesisler'),
              Tab(text: 'Acil Numaralar'),
            ],
          ),
        ),
        body: Consumer<AccessProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: [
                _buildDrugsTab(context, provider),
                _buildFacilitiesTab(context, provider),
                _buildEmergencyTab(context, provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrugsTab(BuildContext context, AccessProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: provider.searchDrugs,
                decoration: InputDecoration(
                  hintText: 'İlaç adı veya kullanım alanı ara...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${provider.filteredDrugs.length} jenerik ilaç alternatifi',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.filteredDrugs.isEmpty
              ? Center(
                  child: Text(
                    'Sonuç bulunamadı.',
                    style: TextStyle(color: AppColors.textHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMD,
                  ),
                  itemCount: provider.filteredDrugs.length,
                  itemBuilder: (context, index) {
                    final drug = provider.filteredDrugs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VcCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentAccess.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.medication,
                                color: AppColors.accentAccess,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        drug['original'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: AppColors.textHint,
                                      ),
                                      Flexible(
                                        child: Text(
                                          drug['generic'] as String,
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    drug['use'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                drug['savings'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFacilitiesTab(BuildContext context, AccessProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // MHRS kartı
        VcCard(
          borderColor: AppColors.accentAccess.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month, color: AppColors.accentAccess),
                  SizedBox(width: 8),
                  Text(
                    'MHRS Randevu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Merkezi Hekim Randevu Sistemi üzerinden devlet hastanelerinden randevu alabilirsiniz.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callWithFeedback(context, provider, '182'),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('182 Ara'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentAccess,
                        side: const BorderSide(color: AppColors.accentAccess),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.openMhrs(),
                      icon: const Icon(Icons.language, size: 16),
                      label: const Text('mhrs.gov.tr'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAccess,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Yakın tesisler
        VcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_hospital, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Yakın Sağlık Tesisleri',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Haritada açmak için bir tesis türüne dokunun.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 8),
              ...AccessProvider.facilityTypes.map(
                (facility) => ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (facility['color'] as Color).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      facility['icon'] as IconData,
                      color: facility['color'] as Color,
                      size: 20,
                    ),
                  ),
                  title: Text(facility['name'] as String),
                  subtitle: const Text(
                    'Google Haritalar\'da ara',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                  onTap: () =>
                      provider.openMapsSearch(facility['query'] as String),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyTab(BuildContext context, AccessProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        VcCard(
          borderColor: AppColors.danger.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Acil Numaralar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Aramak için numaraya dokunun.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              const SizedBox(height: 12),
              ...AccessProvider.emergencyNumbers.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () => _callWithFeedback(context, provider, entry.value),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: AppColors.danger,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Numarayı arar; cihazda arama başlatılamazsa (uygun uygulama yok vb.)
/// kullanıcıya bunu bildirir. Aksi halde acil bir numarada sessiz
/// başarısızlık, kullanıcının yardım çağrıldığını sanmasına yol açabilir.
Future<void> _callWithFeedback(
  BuildContext context,
  AccessProvider provider,
  String number,
) async {
  final started = await provider.callNumber(number);
  if (!started && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Arama başlatılamadı. Lütfen $number numarasını elle arayın.'),
        backgroundColor: AppColors.danger,
      ),
    );
  }
}
