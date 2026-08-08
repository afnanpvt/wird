import 'package:flutter/foundation.dart';

import '../models/quran_script.dart';
import '../models/reading_progress.dart';
import '../models/streak_state.dart';
import 'progress_service.dart';
import 'quran_repository.dart';
import 'settings_service.dart';
import 'streak_service.dart';

export 'settings_service.dart' show AppThemeMode;

class AppState extends ChangeNotifier {
  final QuranRepository quran = QuranRepository();
  final StreakService _streakService = StreakService();
  final ProgressService _progressService = ProgressService();
  final SettingsService _settingsService = SettingsService();

  bool isLoaded = false;
  StreakState streakState = const StreakState();
  ReadingProgress lastPosition = ReadingProgress.start;
  String? userName;
  AppThemeMode themeMode = AppThemeMode.light;
  bool useSimpleTranslation = false;
  QuranScript quranScript = QuranScript.indoPakNastaleeq;

  Future<void> init() async {
    quranScript = _settingsService.getScript();
    await quran.load(quranScript);
    await _streakService.reconcileToYesterday();
    streakState = _streakService.getState();
    lastPosition = _progressService.getLastPosition();
    userName = _settingsService.getName();
    themeMode = _settingsService.getThemeMode();
    useSimpleTranslation = _settingsService.getUseSimpleTranslation();
    isLoaded = true;
    notifyListeners();
  }

  Future<void> setScript(QuranScript script) async {
    if (script == quranScript) return;
    quranScript = script;
    await quran.load(script);
    await _settingsService.saveScript(script);
    notifyListeners();
  }

  bool get hasCompletedOnboarding => _settingsService.getHasCompletedOnboarding();

  Future<void> completeOnboarding({required String? name, required QuranScript script}) async {
    userName = name?.trim().isEmpty ?? true ? null : name!.trim();
    await _settingsService.saveName(userName ?? '');
    await setScript(script);
    await _settingsService.saveHasCompletedOnboarding();
    notifyListeners();
  }

  bool get hasSeenCoachTour => _settingsService.getHasSeenCoachTour();

  Future<void> markCoachTourSeen() => _settingsService.saveHasSeenCoachTour();

  Future<void> saveThemeMode(AppThemeMode mode) async {
    themeMode = mode;
    await _settingsService.saveThemeMode(mode);
    notifyListeners();
  }

  Future<void> setUseSimpleTranslation(bool value) async {
    useSimpleTranslation = value;
    await _settingsService.saveUseSimpleTranslation(value);
    notifyListeners();
  }

  /// Updates streak/stats tracking only. Does not touch the "Continue
  /// Reading" resume point — callers decide separately, via
  /// [saveLastPosition], whether this read should move that pointer.
  Future<void> recordAyahRead(int surahNumber, int ayahNumber) async {
    await _streakService.recordAyahRead(surahNumber, ayahNumber);
    streakState = _streakService.getState();
    notifyListeners();
  }

  Future<void> saveLastPosition(ReadingProgress progress) async {
    lastPosition = progress;
    await _progressService.saveLastPosition(progress);
    notifyListeners();
  }

  Future<void> saveName(String name) async {
    userName = name.trim().isEmpty ? null : name.trim();
    await _settingsService.saveName(userName ?? '');
    notifyListeners();
  }

  /// 'first' the very first time the app is ever opened, 'back' when
  /// returning on a new calendar day, or null if already shown today.
  String? checkWelcomeModal() {
    final last = _settingsService.getLastWelcomedDate();
    if (last == null) return 'first';
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return last.isBefore(todayDate) ? 'back' : null;
  }

  Future<void> markWelcomeModalShown() => _settingsService.saveLastWelcomedDate(DateTime.now());

  int get ayahsReadToday => _streakService.ayahsReadToday();
  int get ayahsReadThisWeek => _streakService.ayahsReadThisWeek();
  int get totalAyahsRead => _streakService.totalAyahsRead();
  int get longestStreak => _streakService.getLongestStreak();
  int get totalReadingSeconds => _streakService.getTotalReadingSeconds();

  Future<void> addReadingSeconds(int seconds) => _streakService.addReadingSeconds(seconds);

  int get sessionCount => _streakService.getSessionCount();

  Future<void> recordSessionStarted() => _streakService.recordSessionStarted();
}
