import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';

/// Full month view of the same honest per-day activity the home screen's
/// weekly strip shows - lets you look back at any past month, not just this
/// week. Consecutive read days within a week row merge into one connected
/// pill exactly like the weekly strip, but never across a row boundary: day
/// 7 of one week and day 1 of the next sit in different rows, so there's no
/// sensible single shape to draw them as.
///
/// Always renders a fixed 6 rows regardless of how many the visible month
/// actually needs, so the grid's height - and everything below it - never
/// shifts as you page between shorter and longer months.
class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  late DateTime _visibleMonth;

  static const _weeksPerGrid = 6;
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _visibleMonth.year == now.year && _visibleMonth.month == now.month;
  }

  void _goToPreviousMonth() => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1));

  void _goToNextMonth() {
    if (_isCurrentMonth) return;
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // DateTime.weekday is 1=Mon..7=Sun; shift to a Sun-start column index.
    final firstWeekdayColumn = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;

    var daysReadThisMonth = 0;
    final weeks = List.generate(_weeksPerGrid, (week) {
      return List.generate(7, (column) {
        final dayNumber = week * 7 + column - firstWeekdayColumn + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) return null;
        final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
        final isFuture = date.isAfter(today);
        final wasRead = !isFuture && appState.wasReadOnDate(date);
        if (wasRead) daysReadThisMonth++;
        return (day: dayNumber, isFuture: isFuture, isToday: date == today, wasRead: wasRead);
      });
    });

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Reading calendar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _goToPreviousMonth,
                ),
                Text(
                  '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _isCurrentMonth ? null : _goToNextMonth,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final label in _weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (final week in weeks) ...[
              Row(
                children: List.generate(7, (i) {
                  final cell = week[i];
                  final leftNeighbor = i > 0 ? week[i - 1] : null;
                  final rightNeighbor = i < 6 ? week[i + 1] : null;
                  final joinsLeft = cell != null && cell.wasRead && leftNeighbor != null && leftNeighbor.wasRead;
                  final joinsRight = cell != null && cell.wasRead && rightNeighbor != null && rightNeighbor.wasRead;

                  return Expanded(
                    child: cell == null
                        ? const SizedBox.shrink()
                        : _DayCell(
                            day: cell.day,
                            filled: cell.wasRead,
                            isToday: cell.isToday,
                            isFuture: cell.isFuture,
                            joinsLeft: joinsLeft,
                            joinsRight: joinsRight,
                          ),
                  );
                }),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            Text(
              '$daysReadThisMonth day${daysReadThisMonth == 1 ? '' : 's'} read this month',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool filled;
  final bool isToday;
  final bool isFuture;
  final bool joinsLeft;
  final bool joinsRight;

  const _DayCell({
    required this.day,
    required this.filled,
    required this.isToday,
    required this.isFuture,
    required this.joinsLeft,
    required this.joinsRight,
  });

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (filled) {
      return Container(
        height: _height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(joinsLeft ? 0 : _height / 2),
            right: Radius.circular(joinsRight ? 0 : _height / 2),
          ),
        ),
        child: Text(
          '$day',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onPrimary),
        ),
      );
    }

    return Center(
      child: Container(
        width: _height,
        height: _height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isToday
                ? colorScheme.primary
                : isFuture
                    ? colorScheme.outlineVariant.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant,
            width: isToday ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isFuture ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
