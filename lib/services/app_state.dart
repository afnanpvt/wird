import 'package:flutter/foundation.dart';

import '../models/bookmark.dart';
import '../models/favorite_ayah.dart';
import '../models/quran_script.dart';
import '../models/streak_state.dart';
import 'bookmarks_service.dart';
import 'favorites_service.dart';
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
  final FavoritesService _favoritesService = FavoritesService();
  final BookmarksService _bookmarksService = BookmarksService();

  bool isLoaded = false;
  StreakState streakState = const StreakState();
  List<Bookmark> bookmarks = const [];
  String? userName;
  AppThemeMode themeMode = AppThemeMode.light;
  bool useSimpleTranslation = false;
  QuranScript quranScript = QuranScript.indoPakNastaleeq;
  List<FavoriteAyah> favorites = const [];
  double fontScale = 1.0;
  bool showTranslation = true;
  bool showTransliteration = false;

  Bookmark get defaultBookmark => bookmarks.firstWhere((b) => b.isDefault, orElse: () => bookmarks.first);

  Future<void> init() async {
    quranScript = _settingsService.getScript();
    await quran.load(quranScript);
    await _streakService.reconcileToYesterday();
    streakState = _streakService.getState();
    await _bookmarksService.migrateLegacyPosition(_progressService.getLastPosition());
    bookmarks = _bookmarksService.getAll();
    userName = _settingsService.getName();
    themeMode = _settingsService.getThemeMode();
    useSimpleTranslation = _settingsService.getUseSimpleTranslation();
    fontScale = _settingsService.getFontScale();
    showTranslation = _settingsService.getShowTranslation();
    showTransliteration = _settingsService.getShowTransliteration();
    favorites = _favoritesService.getAll();
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

  Future<void> setFontScale(double scale) async {
    fontScale = scale;
    await _settingsService.saveFontScale(scale);
    notifyListeners();
  }

  Future<void> setShowTranslation(bool value) async {
    showTranslation = value;
    await _settingsService.saveShowTranslation(value);
    notifyListeners();
  }

  Future<void> setShowTransliteration(bool value) async {
    showTransliteration = value;
    await _settingsService.saveShowTransliteration(value);
    notifyListeners();
  }

  /// Updates streak/stats tracking only. Does not touch any bookmark's
  /// position — callers decide separately, via [updateBookmarkPosition],
  /// whether this read should move a bookmark.
  Future<void> recordAyahRead(int surahNumber, int ayahNumber) async {
    final hasanat = quran.hasanatForAyah(surahNumber, ayahNumber);
    await _streakService.recordAyahRead(surahNumber, ayahNumber, hasanat);
    streakState = _streakService.getState();
    notifyListeners();
  }

  Future<void> updateBookmarkPosition(String bookmarkId, int surahNumber, int ayahNumber) async {
    await _bookmarksService.updatePosition(bookmarkId, surahNumber, ayahNumber);
    bookmarks = _bookmarksService.getAll();
    notifyListeners();
  }

  Future<Bookmark> createBookmark({
    required String name,
    required int surahNumber,
    required int ayahNumber,
    required bool isDefault,
  }) async {
    final bookmark = await _bookmarksService.create(
      name: name,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      isDefault: isDefault,
    );
    bookmarks = _bookmarksService.getAll();
    notifyListeners();
    return bookmark;
  }

  Future<void> renameBookmark(String id, String name) async {
    await _bookmarksService.rename(id, name);
    bookmarks = _bookmarksService.getAll();
    notifyListeners();
  }

  Future<void> setDefaultBookmark(String id) async {
    await _bookmarksService.setDefault(id);
    bookmarks = _bookmarksService.getAll();
    notifyListeners();
  }

  /// Refuses to delete the last remaining bookmark — the app always needs
  /// exactly one bookmark so the home screen always has somewhere to point.
  /// If the deleted bookmark was the default, the most recently updated
  /// remaining one is promoted automatically.
  Future<void> deleteBookmark(String id) async {
    if (bookmarks.length <= 1) return;
    final wasDefault = bookmarks.firstWhere((b) => b.id == id).isDefault;
    await _bookmarksService.delete(id);
    bookmarks = _bookmarksService.getAll();
    if (wasDefault && bookmarks.isNotEmpty) {
      await _bookmarksService.setDefault(bookmarks.first.id);
      bookmarks = _bookmarksService.getAll();
    }
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
  int get readingSecondsToday => _streakService.readingSecondsToday();
  int get readingSecondsThisWeek => _streakService.readingSecondsThisWeek();
  int get hasanatToday => _streakService.hasanatToday();
  int get hasanatThisWeek => _streakService.hasanatThisWeek();
  int get totalHasanat => _streakService.totalHasanat();

  bool wasReadOnDate(DateTime date) => _streakService.ayahsReadOn(date) > 0;

  Future<void> addReadingSeconds(int seconds) => _streakService.addReadingSeconds(seconds);

  int get sessionCount => _streakService.getSessionCount();

  Future<void> recordSessionStarted() => _streakService.recordSessionStarted();

  bool isFavorite(int surahNumber, int ayahNumber) =>
      favorites.any((f) => f.surahNumber == surahNumber && f.ayahNumber == ayahNumber);

  Future<void> toggleFavorite(int surahNumber, int ayahNumber) async {
    if (isFavorite(surahNumber, ayahNumber)) {
      await _favoritesService.remove(surahNumber, ayahNumber);
    } else {
      await _favoritesService.add(surahNumber, ayahNumber);
    }
    favorites = _favoritesService.getAll();
    notifyListeners();
  }
}
