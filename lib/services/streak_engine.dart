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
