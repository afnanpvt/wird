import 'package:hive/hive.dart';

import 'hive_service.dart';

/// Persisted values: 'system', 'light', 'dark'.
enum AppThemeMode { system, light, dark }

class SettingsService {
  Box get _box => Hive.box(HiveBoxes.settings);

  String? getName() => _box.get('name') as String?;

  Future<void> saveName(String name) => _box.put('name', name.trim());

  AppThemeMode getThemeMode() {
    final value = _box.get('themeMode') as String? ?? 'dark';
    return AppThemeMode.values.firstWhere((m) => m.name == value, orElse: () => AppThemeMode.dark);
  }

  Future<void> saveThemeMode(AppThemeMode mode) => _box.put('themeMode', mode.name);

  bool getUseSimpleTranslation() => _box.get('useSimpleTranslation') as bool? ?? false;

  Future<void> saveUseSimpleTranslation(bool value) => _box.put('useSimpleTranslation', value);

  DateTime? getLastWelcomedDate() {
    final value = _box.get('lastWelcomedDate') as String?;
    return value == null ? null : DateTime.parse(value);
  }

  Future<void> saveLastWelcomedDate(DateTime date) =>
      _box.put('lastWelcomedDate', DateTime(date.year, date.month, date.day).toIso8601String());
}
