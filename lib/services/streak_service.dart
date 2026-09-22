import 'package:hive/hive.dart';

import '../models/streak_state.dart';
import 'hive_service.dart';
import 'streak_engine.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) {
  final dd = dateOnly(d);
  return '${dd.year.toString().padLeft(4, '0')}-${dd.month.toString().padLeft(2, '0')}-${dd.day.toString().padLeft(2, '0')}';
}

/// Wraps the pure [advanceDay]/[reconcile] state machine with Hive-backed
/// persistence: the streak state itself, a daily ayah-read log (used both to
/// tell reconcile whether a given day was read, and for stats), and the last
/// calendar day the state machine has been advanced through.
class StreakService {
  Box get _streakBox => Hive.box(HiveBoxes.streak);
  Box get _dailyLogsBox => Hive.box(HiveBoxes.dailyLogs);
  Box get _dailyReadingSecondsBox => Hive.box(HiveBoxes.dailyReadingSeconds);
  Box get _dailyHasanatBox => Hive.box(HiveBoxes.dailyHasanat);

  StreakState getState() {
    final map = _streakBox.get('state');
    if (map == null) return const StreakState();
    return StreakState.fromMap(map as Map);
  }

  int getLongestStreak() => _streakBox.get('longestStreak') as int? ?? 0;

  Future<void> _saveState(StreakState state) async {
    await _streakBox.put('state', state.toMap());
    if (state.currentStreak > getLongestStreak()) {
      await _streakBox.put('longestStreak', state.currentStreak);
    }
  }

  /// On first-ever run this defaults to yesterday, not today: it means
  /// "no day has been processed yet", so the state machine still advances
  /// through today the first time the user reads something.
  DateTime getLastProcessedDate() {
    final iso = _streakBox.get('lastProcessedDate') as String?;
    if (iso == null) return dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    return DateTime.parse(iso);
  }

  Future<void> _saveLastProcessedDate(DateTime date) =>
      _streakBox.put('lastProcessedDate', dateOnly(date).toIso8601String());

  bool _wasReadOn(DateTime date) => (_dailyLogsBox.get(dateKey(date)) as int? ?? 0) > 0;

  /// Call on app start. Catches up any missed days strictly before today,
  /// without deciding today's outcome yet since the user may still read today.
  Future<void> reconcileToYesterday() async {
    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final lastProcessed = getLastProcessedDate();
    if (!lastProcessed.isBefore(yesterday)) return;

    final updated = reconcile(
      state: getState(),
      lastProcessedDate: lastProcessed,
      today: yesterday,
      wasReadOnDate: _wasReadOn,
    );
    await _saveState(updated);
    await _saveLastProcessedDate(yesterday);
  }

  /// Call whenever the user reads an ayah (i.e. a reading-screen visit pages
  /// past it, or dwells on it long enough - see [QuranRepository.hasanatForAyah]
  /// for [hasanat]). Every call unconditionally adds to today's counts and
  /// total hasanat - deliberately re-earnable on every genuine reading pass,
  /// not just the first time an ayah is ever read, matching hasanat being a
  /// reward for reciting rather than a one-time completion badge. Not calling
  /// this twice for the same pass is the caller's job (see
  /// `_ReadingScreenState._creditAyahRead`'s per-visit guard).
  Future<void> recordAyahRead(int surahNumber, int ayahNumber, int hasanat) async {
    final today = dateOnly(DateTime.now());
    final todayCount = (_dailyLogsBox.get(dateKey(today)) as int? ?? 0) + 1;
    await _dailyLogsBox.put(dateKey(today), todayCount);

    final todayHasanat = (_dailyHasanatBox.get(dateKey(today)) as int? ?? 0) + hasanat;
    await _dailyHasanatBox.put(dateKey(today), todayHasanat);
    await _streakBox.put('totalHasanat', totalHasanat() + hasanat);

    final lastProcessed = getLastProcessedDate();
    if (lastProcessed.isBefore(today)) {
      final updated = reconcile(
        state: getState(),
        lastProcessedDate: lastProcessed,
        today: today,
        wasReadOnDate: _wasReadOn,
      );
      await _saveState(updated);
      await _saveLastProcessedDate(today);
    }
  }

  /// Full day-by-day maps for [BackupService] to push - see [restoreFrom]
  /// for the other direction.
  Map<String, int> allDailyLogs() => Map<String, int>.from(_dailyLogsBox.toMap());
  Map<String, int> allDailyHasanat() => Map<String, int>.from(_dailyHasanatBox.toMap());
  Map<String, int> allDailyReadingSeconds() => Map<String, int>.from(_dailyReadingSecondsBox.toMap());

  /// Overwrites this device's streak/hasanat/reading-time state with a
  /// restored backup - only called from [BackupService]'s restore flow,
  /// only after the user has explicitly confirmed (see BackupScreen). Every
  /// box this touches is fully replaced, not merged: two independent
  /// reading histories can't be meaningfully combined, so restoring means
  /// picking the backup over whatever (if anything) is on this device.
  Future<void> restoreFrom({
    required StreakState state,
    required int longestStreak,
    required int totalHasanat,
    required int totalReadingSeconds,
    required Map<String, int> dailyLogs,
    required Map<String, int> dailyHasanat,
    required Map<String, int> dailyReadingSeconds,
  }) async {
    await _saveState(state);
    await _streakBox.put('longestStreak', longestStreak);
    await _streakBox.put('totalHasanat', totalHasanat);
    await _streakBox.put('totalReadingSeconds', totalReadingSeconds);
    await _dailyLogsBox.clear();
    await _dailyLogsBox.putAll(dailyLogs);
    await _dailyHasanatBox.clear();
    await _dailyHasanatBox.putAll(dailyHasanat);
    await _dailyReadingSecondsBox.clear();
    await _dailyReadingSecondsBox.putAll(dailyReadingSeconds);
    // Reconciling forward from the backup's own last-read date (not this
    // device's clock) means a gap between "last read on the old device" and
    // "restored on this one" is treated as an ordinary missed-days gap, the
    // same grace/reset logic that already handles any offline stretch.
    final lastReadDate = dailyLogs.keys.isEmpty
        ? dateOnly(DateTime.now()).subtract(const Duration(days: 1))
        : DateTime.parse((dailyLogs.keys.toList()..sort()).last);
    await _saveLastProcessedDate(lastReadDate);
  }

  /// The earliest date anything was ever logged as read, or null if nothing
  /// has been read yet - the calendar uses this so it never marks a day
  /// before the app was even in use as "missed".
  DateTime? earliestLoggedDate() {
    DateTime? earliest;
    for (final key in _dailyLogsBox.keys) {
      final date = DateTime.parse(key as String);
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    return earliest;
  }

  Map<DateTime, DayOutcome> dayOutcomes({required DateTime start, required DateTime end}) =>
      classifyDays(start: start, end: end, wasReadOnDate: _wasReadOn);

  int ayahsReadOn(DateTime date) => _dailyLogsBox.get(dateKey(date)) as int? ?? 0;

  int ayahsReadToday() => ayahsReadOn(DateTime.now());

  int ayahsReadThisWeek() {
    var total = 0;
    final today = dateOnly(DateTime.now());
    for (var i = 0; i < 7; i++) {
      total += ayahsReadOn(today.subtract(Duration(days: i)));
    }
    return total;
  }

  int totalAyahsRead() {
    var total = 0;
    for (final value in _dailyLogsBox.values) {
      total += value as int;
    }
    return total;
  }

  /// Total time ever spent on the reading screen, across all sessions and
  /// app restarts. Never resets.
  int getTotalReadingSeconds() => _streakBox.get('totalReadingSeconds') as int? ?? 0;

  Future<void> addReadingSeconds(int seconds) async {
    await _streakBox.put('totalReadingSeconds', getTotalReadingSeconds() + seconds);
    final today = dateKey(DateTime.now());
    final todaySeconds = (_dailyReadingSecondsBox.get(today) as int? ?? 0) + seconds;
    await _dailyReadingSecondsBox.put(today, todaySeconds);
  }

  int readingSecondsOn(DateTime date) => _dailyReadingSecondsBox.get(dateKey(date)) as int? ?? 0;

  int readingSecondsToday() => readingSecondsOn(DateTime.now());

  int readingSecondsThisWeek() {
    var total = 0;
    final today = dateOnly(DateTime.now());
    for (var i = 0; i < 7; i++) {
      total += readingSecondsOn(today.subtract(Duration(days: i)));
    }
    return total;
  }

  int hasanatOn(DateTime date) => _dailyHasanatBox.get(dateKey(date)) as int? ?? 0;

  int hasanatToday() => hasanatOn(DateTime.now());

  int hasanatThisWeek() {
    var total = 0;
    final today = dateOnly(DateTime.now());
    for (var i = 0; i < 7; i++) {
      total += hasanatOn(today.subtract(Duration(days: i)));
    }
    return total;
  }

  int totalHasanat() => _streakBox.get('totalHasanat') as int? ?? 0;

  /// Number of times a reading screen has been opened. Counted at session
  /// start rather than on "I'm done", since many sessions end by just
  /// navigating away.
  int getSessionCount() => _streakBox.get('sessionCount') as int? ?? 0;

  Future<void> recordSessionStarted() => _streakBox.put('sessionCount', getSessionCount() + 1);
}
