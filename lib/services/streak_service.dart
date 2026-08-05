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
  Box get _readAyahsBox => Hive.box(HiveBoxes.readAyahs);

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

  void _markAyahRead(int surahNumber, int ayahNumber) {
    _readAyahsBox.put('$surahNumber:$ayahNumber', true);
  }

  int uniqueAyahsRead() => _readAyahsBox.length;

  bool isAyahRead(int surahNumber, int ayahNumber) =>
      _readAyahsBox.containsKey('$surahNumber:$ayahNumber');

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

  /// Call whenever the user reads an ayah (i.e. views a page in the reading screen).
  Future<void> recordAyahRead(int surahNumber, int ayahNumber) async {
    final today = dateOnly(DateTime.now());
    final todayCount = (_dailyLogsBox.get(dateKey(today)) as int? ?? 0) + 1;
    await _dailyLogsBox.put(dateKey(today), todayCount);
    _markAyahRead(surahNumber, ayahNumber);

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

  Future<void> addReadingSeconds(int seconds) =>
      _streakBox.put('totalReadingSeconds', getTotalReadingSeconds() + seconds);
}
