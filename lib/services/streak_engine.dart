import '../models/streak_state.dart';

const int graceThresholdDays = 10;

/// Advances the streak state by exactly one calendar day.
///
/// [wasRead] is whether the user read at least one ayah on that day.
/// `consecutiveMissedDays` tracks a run of missed days so that two in a row
/// always hard-resets, independent of grace — grace can only ever save a
/// single isolated missed day.
StreakState advanceDay(StreakState state, bool wasRead) {
  if (wasRead) {
    final newDaysSinceGrace = state.graceAvailable
        ? state.daysSinceGraceEarned
        : state.daysSinceGraceEarned + 1;
    return state.copyWith(
      currentStreak: state.currentStreak + 1,
      consecutiveMissedDays: 0,
      graceAvailable: state.graceAvailable || newDaysSinceGrace >= graceThresholdDays,
      daysSinceGraceEarned: newDaysSinceGrace,
    );
  }

  final isSecondConsecutiveMiss = state.consecutiveMissedDays >= 1;

  if (isSecondConsecutiveMiss) {
    return state.copyWith(
      currentStreak: 0,
      graceAvailable: false,
      daysSinceGraceEarned: 0,
      consecutiveMissedDays: state.consecutiveMissedDays + 1,
    );
  }

  if (state.graceAvailable) {
    return state.copyWith(
      currentStreak: state.currentStreak + 1,
      graceAvailable: false,
      daysSinceGraceEarned: 0,
      consecutiveMissedDays: 1,
    );
  }

  return state.copyWith(
    currentStreak: 0,
    daysSinceGraceEarned: 0,
    consecutiveMissedDays: 1,
  );
}

/// What happened on one specific day, as opposed to [StreakState] which only
/// ever reports the state *after* a day - it can't say whether a given past
/// miss was the one grace forgave or the one that reset the streak.
enum DayOutcome { read, graceForgiven, missed }

/// Replays [advanceDay] across every date from [start] to [end] (inclusive,
/// truncated to day precision), classifying each one - the calendar uses
/// this to show a grace-forgiven miss differently from a hard-reset one.
Map<DateTime, DayOutcome> classifyDays({
  required DateTime start,
  required DateTime end,
  required bool Function(DateTime date) wasReadOnDate,
}) {
  final result = <DateTime, DayOutcome>{};
  var state = const StreakState();
  var cursor = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!cursor.isAfter(last)) {
    final wasRead = wasReadOnDate(cursor);
    if (wasRead) {
      result[cursor] = DayOutcome.read;
    } else {
      // Mirrors advanceDay's own branching: a miss is only forgiven when
      // it isn't the second in a row and grace is actually available.
      final isSecondConsecutiveMiss = state.consecutiveMissedDays >= 1;
      result[cursor] =
          (!isSecondConsecutiveMiss && state.graceAvailable) ? DayOutcome.graceForgiven : DayOutcome.missed;
    }
    state = advanceDay(state, wasRead);
    cursor = cursor.add(const Duration(days: 1));
  }
  return result;
}

/// Advances the streak across every calendar day strictly between
/// [lastProcessedDate] and [today] (both dates truncated to day precision),
/// using [wasReadOnDate] to determine whether each day was read.
StreakState reconcile({
  required StreakState state,
  required DateTime lastProcessedDate,
  required DateTime today,
  required bool Function(DateTime date) wasReadOnDate,
}) {
  final start = DateTime(lastProcessedDate.year, lastProcessedDate.month, lastProcessedDate.day);
  final end = DateTime(today.year, today.month, today.day);

  var result = state;
  var cursor = start.add(const Duration(days: 1));
  while (!cursor.isAfter(end)) {
    result = advanceDay(result, wasReadOnDate(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return result;
}
