import 'package:flutter/foundation.dart';

class AppStateService {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void restartProviders() {
    revision.value++;
  }
}
