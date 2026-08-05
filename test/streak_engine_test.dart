import 'package:flutter_test/flutter_test.dart';
import 'package:wird/models/streak_state.dart';
import 'package:wird/services/streak_engine.dart';

StreakState readNTimes(int n, [StreakState state = const StreakState()]) {
  var s = state;
  for (var i = 0; i < n; i++) {
    s = advanceDay(s, true);
  }
  return s;
}

void main() {
  group('reading days', () {
    test('streak increments by 1 per consecutive read day', () {
      var state = const StreakState();
      state = advanceDay(state, true);
      expect(state.currentStreak, 1);
      state = advanceDay(state, true);
      expect(state.currentStreak, 2);
      state = advanceDay(state, true);
      expect(state.currentStreak, 3);
    });

    test('daysSinceGraceEarned increments per read day while grace not available', () {
      var state = const StreakState();
      for (var i = 1; i <= 9; i++) {
        state = advanceDay(state, true);
        expect(state.daysSinceGraceEarned, i);
        expect(state.graceAvailable, false);
      }
    });

    test('grace becomes available on exactly the 10th consecutive read day', () {
      final state = readNTimes(9);
      expect(state.graceAvailable, false);

      final onTenth = advanceDay(state, true);
      expect(onTenth.graceAvailable, true);
      expect(onTenth.daysSinceGraceEarned, 10);
      expect(onTenth.currentStreak, 10);
    });

    test('daysSinceGraceEarned freezes once grace is available and unconsumed', () {
      var state = readNTimes(10);
      expect(state.graceAvailable, true);
      expect(state.daysSinceGraceEarned, 10);

      state = advanceDay(state, true);
      state = advanceDay(state, true);
      expect(state.graceAvailable, true);
      expect(state.daysSinceGraceEarned, 10);
      expect(state.currentStreak, 12);
    });
  });

  group('missed day with grace available', () {
    test('streak continues counting through the missed day (does not reset or double-count)', () {
      final afterTenReads = readNTimes(10);
      expect(afterTenReads.currentStreak, 10);

      final afterMiss = advanceDay(afterTenReads, false);
      expect(afterMiss.currentStreak, 11, reason: 'day 11 missed shows as day 11');
    });

    test('consumes grace and resets daysSinceGraceEarned', () {
      final afterTenReads = readNTimes(10);
      final afterMiss = advanceDay(afterTenReads, false);

      expect(afterMiss.graceAvailable, false);
      expect(afterMiss.daysSinceGraceEarned, 0);
    });

    test('reading again after a grace-saved miss resumes counting toward the next grace', () {
      final afterTenReads = readNTimes(10);
      final afterMiss = advanceDay(afterTenReads, false);
      final afterNextRead = advanceDay(afterMiss, true);

      expect(afterNextRead.currentStreak, 12);
      expect(afterNextRead.daysSinceGraceEarned, 1);
      expect(afterNextRead.graceAvailable, false);
    });
  });

  group('missed day without grace available', () {
    test('hard-resets streak and progress to zero', () {
      final afterFiveReads = readNTimes(5);
      expect(afterFiveReads.graceAvailable, false);

      final afterMiss = advanceDay(afterFiveReads, false);
      expect(afterMiss.currentStreak, 0);
      expect(afterMiss.daysSinceGraceEarned, 0);
      expect(afterMiss.graceAvailable, false);
    });

    test('missing on day one from a fresh state stays at zero', () {
      final afterMiss = advanceDay(const StreakState(), false);
      expect(afterMiss.currentStreak, 0);
    });
  });

  group('two consecutive missed days', () {
    test('hard-resets even if the first missed day was covered by grace', () {
      final afterTenReads = readNTimes(10);
      final afterFirstMiss = advanceDay(afterTenReads, false);
      expect(afterFirstMiss.currentStreak, 11);
      expect(afterFirstMiss.graceAvailable, false);

      final afterSecondMiss = advanceDay(afterFirstMiss, false);
      expect(afterSecondMiss.currentStreak, 0);
      expect(afterSecondMiss.graceAvailable, false);
      expect(afterSecondMiss.daysSinceGraceEarned, 0);
    });

    test('a third consecutive missed day stays at zero, no exceptions', () {
      final afterTenReads = readNTimes(10);
      var state = advanceDay(afterTenReads, false);
      state = advanceDay(state, false);
      state = advanceDay(state, false);

      expect(state.currentStreak, 0);
      expect(state.graceAvailable, false);
    });

    test('a single missed day followed by a read does not trigger the two-miss reset', () {
      final afterTenReads = readNTimes(10);
      var state = advanceDay(afterTenReads, false); // grace-saved miss, streak 11
      state = advanceDay(state, true); // read resumes normally
      expect(state.currentStreak, 12);

      final afterAnotherMiss = advanceDay(state, false);
      expect(afterAnotherMiss.currentStreak, 0, reason: 'no grace available, so this single miss hard-resets');
    });

    test('two misses in a row from a brand-new state stays at zero, no negative values or errors', () {
      final afterFirstMiss = advanceDay(const StreakState(), false);
      expect(afterFirstMiss.currentStreak, 0);
      expect(afterFirstMiss.graceAvailable, false);
      expect(afterFirstMiss.daysSinceGraceEarned, 0);
      expect(afterFirstMiss.consecutiveMissedDays, 1);

      final afterSecondMiss = advanceDay(afterFirstMiss, false);
      expect(afterSecondMiss.currentStreak, 0);
      expect(afterSecondMiss.graceAvailable, false);
      expect(afterSecondMiss.daysSinceGraceEarned, 0);
      expect(afterSecondMiss.consecutiveMissedDays, 2);
    });

    test('grace can be re-earned after a hard reset by reading 10 more consecutive days', () {
      final afterTenReads = readNTimes(10);
      var state = advanceDay(afterTenReads, false);
      state = advanceDay(state, false); // hard reset via two consecutive misses

      state = readNTimes(10, state);
      expect(state.graceAvailable, true);
      expect(state.currentStreak, 10);
    });
  });

  group('reconcile', () {
    test('applies advanceDay once per day strictly between lastProcessedDate and today', () {
      final lastProcessed = DateTime(2026, 1, 1);
      final today = DateTime(2026, 1, 4);
      final readDates = {
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 4),
      };

      final result = reconcile(
        state: const StreakState(),
        lastProcessedDate: lastProcessed,
        today: today,
        wasReadOnDate: (d) => readDates.any((r) => r.year == d.year && r.month == d.month && r.day == d.day),
      );

      expect(result.currentStreak, 3);
    });

    test('no-op when lastProcessedDate equals today', () {
      final today = DateTime(2026, 1, 4);
      final state = readNTimes(5);

      final result = reconcile(
        state: state,
        lastProcessedDate: today,
        today: today,
        wasReadOnDate: (_) => true,
      );

      expect(result, state);
    });

    test('correctly hard-resets across a multi-day gap with no reads', () {
      final afterTenReads = readNTimes(10);
      final lastProcessed = DateTime(2026, 1, 10);
      final today = DateTime(2026, 1, 15);

      final result = reconcile(
        state: afterTenReads,
        lastProcessedDate: lastProcessed,
        today: today,
        wasReadOnDate: (_) => false,
      );

      expect(result.currentStreak, 0);
      expect(result.graceAvailable, false);
    });
  });
}
