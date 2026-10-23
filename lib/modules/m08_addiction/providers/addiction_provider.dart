import 'package:flutter/material.dart';
import '../../../services/hive_service.dart';
import '../models/addiction_model.dart';

class AddictionProvider extends ChangeNotifier {
  final _hiveService = HiveService();

  SmokingProfile _profile = SmokingProfile();
  List<String> _cravingLog = [];

  SmokingProfile get profile => _profile;
  List<String> get cravingLog => _cravingLog;

  List<HealthMilestone> get milestones {
    final hours = _profile.hoursSinceQuit;
    return [
      HealthMilestone(
        time: '20 dakika',
        benefit: 'Nabız ve tansiyon normale döner',
        hoursRequired: 0,
        achieved: hours > 0,
      ),
      HealthMilestone(
        time: '8 saat',
        benefit: 'Kandaki oksijen seviyesi normale döner',
        hoursRequired: 8,
        achieved: hours >= 8,
      ),
      HealthMilestone(
        time: '24 saat',
        benefit: 'Kalp krizi riski azalmaya başlar',
        hoursRequired: 24,
        achieved: hours >= 24,
      ),
      HealthMilestone(
        time: '48 saat',
        benefit: 'Tat ve koku duyusu iyileşmeye başlar',
        hoursRequired: 48,
        achieved: hours >= 48,
      ),
      HealthMilestone(
        time: '72 saat',
        benefit: 'Bronşlar gevşer, nefes almak kolaylaşır',
        hoursRequired: 72,
        achieved: hours >= 72,
      ),
      HealthMilestone(
        time: '2 hafta',
        benefit: 'Kan dolaşımı iyileşir, yürümek kolaylaşır',
        hoursRequired: 336,
        achieved: hours >= 336,
      ),
      HealthMilestone(
        time: '1 ay',
        benefit: 'Öksürük ve nefes darlığı azalır',
        hoursRequired: 720,
        achieved: hours >= 720,
      ),
      HealthMilestone(
        time: '3 ay',
        benefit: 'Akciğer fonksiyonu %30 artar',
        hoursRequired: 2160,
        achieved: hours >= 2160,
      ),
      HealthMilestone(
        time: '9 ay',
        benefit: 'Akciğer silia (tüyleri) rejenerasyonu tamamlanır',
        hoursRequired: 6480,
        achieved: hours >= 6480,
      ),
      HealthMilestone(
        time: '1 yıl',
        benefit: 'Kalp hastalığı riski yarıya iner',
        hoursRequired: 8760,
        achieved: hours >= 8760,
      ),
      HealthMilestone(
        time: '5 yıl',
        benefit: 'İnme riski sigara içmeyenlerle eşitlenir',
        hoursRequired: 43800,
        achieved: hours >= 43800,
      ),
      HealthMilestone(
        time: '10 yıl',
        benefit: 'Akciğer kanseri riski yarıya iner',
        hoursRequired: 87600,
        achieved: hours >= 87600,
      ),
    ];
  }

  List<AddictionBadge> get badges =>
      AddictionBadge.getBadges(_profile.daysSinceQuit);
  int get earnedBadgeCount => badges.where((b) => b.earned).length;

  void loadData() {
    final box = _hiveService.getAddictionBox();
    final quitDateStr = box.get('quit_date');
    final price = box.get('daily_cigarette_price', defaultValue: 1.5);
    final count = box.get('daily_cigarettes', defaultValue: 20);
    final log = box.get('craving_log', defaultValue: <dynamic>[]) ?? [];

    _profile = SmokingProfile(
      quitDate: quitDateStr != null ? DateTime.tryParse(quitDateStr) : null,
      dailyCigarettes: (count as num).toInt(),
      pricePerCigarette: (price as num).toDouble(),
    );
    _cravingLog = List<String>.from(log);
    notifyListeners();
  }

  Future<void> setQuitDate(DateTime date) async {
    final box = _hiveService.getAddictionBox();
    await box.put('quit_date', date.toIso8601String());
    _profile = SmokingProfile(
      quitDate: date,
      dailyCigarettes: _profile.dailyCigarettes,
      pricePerCigarette: _profile.pricePerCigarette,
    );
    notifyListeners();
  }

  Future<void> updateSettings({
    int? dailyCigarettes,
    double? pricePerCigarette,
  }) async {
    final box = _hiveService.getAddictionBox();
    if (dailyCigarettes != null) {
      await box.put('daily_cigarettes', dailyCigarettes);
    }
    if (pricePerCigarette != null) {
      await box.put('daily_cigarette_price', pricePerCigarette);
    }
    _profile = SmokingProfile(
      quitDate: _profile.quitDate,
      dailyCigarettes: dailyCigarettes ?? _profile.dailyCigarettes,
      pricePerCigarette: pricePerCigarette ?? _profile.pricePerCigarette,
    );
    notifyListeners();
  }

  Future<void> logCraving(String note) async {
    final entry = '${DateTime.now().toIso8601String()}|$note';
    _cravingLog.add(entry);
    final box = _hiveService.getAddictionBox();
    await box.put('craving_log', _cravingLog);
    notifyListeners();
  }

  Future<void> reset() async {
    final box = _hiveService.getAddictionBox();
    await box.delete('quit_date');
    _profile = SmokingProfile(
      dailyCigarettes: _profile.dailyCigarettes,
      pricePerCigarette: _profile.pricePerCigarette,
    );
    notifyListeners();
  }
}
