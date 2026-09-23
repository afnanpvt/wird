import 'package:hive/hive.dart';

import '../models/quran_script.dart';
import '../models/reciter.dart';
import 'hive_service.dart';

/// Persisted values: 'system', 'light', 'dark'.
enum AppThemeMode { system, light, dark }

class SettingsService {
  Box get _box => Hive.box(HiveBoxes.settings);

  String? getName() => _box.get('name') as String?;

  Future<void> saveName(String name) => _box.put('name', name.trim());

  /// Core profile identity, available regardless of whether Friends is
  /// ever enabled - see models/avatar_seeds.dart for the fixed picker set.
  /// Null means "never chosen one yet" (pre-onboarding-update installs, or
  /// mid-onboarding before the avatar step completes).
  String? getAvatarSeed() => _box.get('avatarSeed') as String?;

  Future<void> saveAvatarSeed(String seed) => _box.put('avatarSeed', seed);

  AppThemeMode getThemeMode() {
    final value = _box.get('themeMode') as String? ?? 'light';
    return AppThemeMode.values.firstWhere((m) => m.name == value, orElse: () => AppThemeMode.light);
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

  QuranScript getScript() {
    final value = _box.get('quranScript') as String?;
    if (value == null) return QuranScript.indoPakNastaleeq;
    return QuranScript.values.firstWhere((s) => s.name == value, orElse: () => QuranScript.indoPakNastaleeq);
  }

  Future<void> saveScript(QuranScript script) => _box.put('quranScript', script.name);

  bool getHasCompletedOnboarding() => _box.get('hasCompletedOnboarding') as bool? ?? false;

  Future<void> saveHasCompletedOnboarding() => _box.put('hasCompletedOnboarding', true);

  bool getHasSeenCoachTour() => _box.get('hasSeenCoachTour') as bool? ?? false;

  Future<void> saveHasSeenCoachTour() => _box.put('hasSeenCoachTour', true);

  double getFontScale() => _box.get('fontScale') as double? ?? 1.0;

  Future<void> saveFontScale(double scale) => _box.put('fontScale', scale);

  bool getShowTranslation() => _box.get('showTranslation') as bool? ?? true;

  Future<void> saveShowTranslation(bool value) => _box.put('showTranslation', value);

  bool getShowTransliteration() => _box.get('showTransliteration') as bool? ?? false;

  Future<void> saveShowTransliteration(bool value) => _box.put('showTransliteration', value);

  Reciter getReciter() {
    final value = _box.get('reciter') as String?;
    if (value == null) return Reciter.yasserAlDosari;
    return Reciter.values.firstWhere((r) => r.name == value, orElse: () => Reciter.yasserAlDosari);
  }

  Future<void> saveReciter(Reciter reciter) => _box.put('reciter', reciter.name);

  int getKahfAyahNumber() => _box.get('kahfAyahNumber') as int? ?? 1;

  Future<void> saveKahfAyahNumber(int ayahNumber) => _box.put('kahfAyahNumber', ayahNumber);

  /// Whether the home screen's "back up with Google" card has been
  /// dismissed for good. Skipping it during onboarding does NOT set this -
  /// skipping there just means "not right now", not "never ask again";
  /// this flag is only set by an explicit dismissal of the home card
  /// itself. See HomeScreen's _BackupPromptCard.
  bool getBackupPromptDismissed() => _box.get('backupPromptDismissed') as bool? ?? false;

  Future<void> saveBackupPromptDismissed() => _box.put('backupPromptDismissed', true);
}
