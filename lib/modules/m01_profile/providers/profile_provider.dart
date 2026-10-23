import 'package:flutter/material.dart';
import '../../../services/hive_service.dart';
import '../models/user_profile.dart';

class ProfileProvider extends ChangeNotifier {
  final _hiveService = HiveService();
  UserProfile _profile = UserProfile();

  UserProfile get profile => _profile;

  void loadProfile() {
    final box = _hiveService.getProfileBox();
    _profile = UserProfile(
      name: box.get('name', defaultValue: '') ?? '',
      birthDate: box.get('birth_date') != null
          ? DateTime.tryParse(box.get('birth_date'))
          : null,
      gender: box.get('gender', defaultValue: '') ?? '',
      height: (box.get('height', defaultValue: 0.0) as num?)?.toDouble() ?? 0,
      weight: (box.get('weight', defaultValue: 0.0) as num?)?.toDouble() ?? 0,
      conditions: List<String>.from(
        box.get('conditions', defaultValue: <dynamic>[]) ?? [],
      ),
      goals: List<String>.from(
        box.get('goals', defaultValue: <dynamic>[]) ?? [],
      ),
      notificationsEnabled:
          box.get('notifications_enabled', defaultValue: true) ?? true,
    );
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    final box = _hiveService.getProfileBox();
    await box.put('name', profile.name);
    await box.put('birth_date', profile.birthDate?.toIso8601String());
    await box.put('gender', profile.gender);
    await box.put('height', profile.height);
    await box.put('weight', profile.weight);
    await box.put('conditions', profile.conditions);
    await box.put('goals', profile.goals);
    await box.put('notifications_enabled', profile.notificationsEnabled);
    notifyListeners();
  }

  Future<void> updateWeight(double weight) async {
    _profile = UserProfile(
      name: _profile.name,
      birthDate: _profile.birthDate,
      gender: _profile.gender,
      height: _profile.height,
      weight: weight,
      conditions: _profile.conditions,
      goals: _profile.goals,
      notificationsEnabled: _profile.notificationsEnabled,
    );
    await _hiveService.getProfileBox().put('weight', weight);

    // Also log weight history.
    // Not: ChronicProvider aynı kutuyu HealthEntry şemasıyla okur; bu yüzden
    // değer 'weight' değil 'value' anahtarıyla yazılmalıdır.
    final healthBox = _hiveService.getHealthBox();
    List<dynamic> history =
        healthBox.get('weight_history', defaultValue: <dynamic>[]) ?? [];
    history.add({'value': weight, 'date': DateTime.now().toIso8601String()});
    await healthBox.put('weight_history', history);
    notifyListeners();
  }
}
