import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../widgets/quick_page_physics.dart';

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
///
/// Months are paged with a PageView (same swipe mechanism as the home
/// screen's Today/Week/All time stats card) so the whole grid can be swiped
/// left/right, and the header can also jump straight to a month/year via a
/// picker sheet.
class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  // How many months back paging is allowed to go. 100 years is effectively
  // unbounded for this app while keeping the PageView's item count finite.
  static const _pastMonthsWindow = 1200;
  static const _initialPage = _pastMonthsWindow;

  late final DateTime _anchorMonth;
  late final PageController _pageController;

  /// Only the header row (month label + arrows) depends on which month is
  /// showing, so this is a notifier rather than plain state - a setState on
  /// every page change would rebuild all three live month grids, 42 cells
  /// apiece, in the middle of the swipe animation.
  late final ValueNotifier<DateTime> _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month, 1);
    _visibleMonth = ValueNotifier(_anchorMonth);
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _visibleMonth.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    final offset = page - _initialPage;
    return DateTime(_anchorMonth.year, _anchorMonth.month + offset, 1);
  }

  int _pageForMonth(DateTime month) {
    return _initialPage + (month.year - _anchorMonth.year) * 12 + (month.month - _anchorMonth.month);
  }

  bool _isCurrentMonth(DateTime month) => month.year == _anchorMonth.year && month.month == _anchorMonth.month;

  void _goToPreviousMonth() {
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goToNextMonth() {
    if (_isCurrentMonth(_visibleMonth.value)) return;
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _jumpToMonth(DateTime month) {
    if (month == _visibleMonth.value) return;
    _pageController.jumpToPage(_pageForMonth(month));
    _visibleMonth.value = month;
  }

  Future<void> _openMonthYearPicker() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MonthYearSheet(
        initialMonth: _visibleMonth.value,
        earliestYear: _anchorMonth.year - _pastMonthsWindow ~/ 12,
        latestMonth: _anchorMonth,
      ),
    );
    if (picked != null) _jumpToMonth(picked);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Reading calendar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<DateTime>(
              valueListenable: _visibleMonth,
              builder: (context, month, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _goToPreviousMonth,
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _openMonthYearPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_MonthYearSheet.monthNames[month.month - 1]} ${month.year}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.expand_more_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _isCurrentMonth(month) ? null : _goToNextMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final label in _MonthGrid.weekdayLabels)
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
            SizedBox(
              // The footer line's rendered height depends on the system font
              // scale, so it's measured against the current text scaler
              // rather than assumed - a fixed guess overflows by a pixel or
              // more once the user bumps up their system text size.
              height: _MonthGrid.weeksPerGrid * (_MonthGrid.rowHeight + _MonthGrid.rowSpacing) +
                  _MonthGrid.footerTopSpacing +
                  MediaQuery.textScalerOf(context).scale(_MonthGrid.footerBaseHeight),
              child: PageView.builder(
                controller: _pageController,
                itemCount: _initialPage + 1,
                pageSnapping: false,
                physics: const QuickPageScrollPhysics(),
                onPageChanged: (page) => _visibleMonth.value = _monthForPage(page),
                itemBuilder: (context, page) =>
                    RepaintBoundary(child: _MonthGrid(month: _monthForPage(page), appState: appState)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page of the calendar: the fixed 6-row day grid plus the "N days read
/// this month" footer, for a single month.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final AppState appState;

  const _MonthGrid({required this.month, required this.appState});

  static const weeksPerGrid = 6;
  static const rowHeight = 36.0;
  static const rowSpacing = 8.0;
  static const footerTopSpacing = 16.0;
  // Generous baseline for a single line of 13px text; scaled by the
  // system text scaler wherever this is used to size a fixed-height box.
  static const footerBaseHeight = 22.0;
  static const weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is 1=Mon..7=Sun; shift to a Sun-start column index.
    final firstWeekdayColumn = DateTime(month.year, month.month, 1).weekday % 7;

    var daysReadThisMonth = 0;
    final weeks = List.generate(weeksPerGrid, (week) {
      return List.generate(7, (column) {
        final dayNumber = week * 7 + column - firstWeekdayColumn + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) return null;
        final date = DateTime(month.year, month.month, dayNumber);
        final isFuture = date.isAfter(today);
        final wasRead = !isFuture && appState.wasReadOnDate(date);
        if (wasRead) daysReadThisMonth++;
        return (
          day: dayNumber,
          isFuture: isFuture,
          isToday: date == today,
          wasRead: wasRead,
          outcome: isFuture ? null : appState.dayOutcome(date),
        );
      });
    });

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final week in weeks) ...[
          // A Row with no explicit height of its own sizes to its tallest
          // child - so a trailing week that's entirely SizedBox.shrink()
          // (no real day lands in any of its 7 slots, which happens for
          // every month needing fewer than 6 rows) collapsed to 0px instead
          // of reserving a row's worth of space. That's what let the footer
          // text bob up and down between months. Pinning the row's own
          // height keeps it reserved regardless of what's inside it.
          SizedBox(
            height: rowHeight,
            child: Row(
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
                          outcome: cell.outcome,
                          joinsLeft: joinsLeft,
                          joinsRight: joinsRight,
                        ),
                );
              }),
            ),
          ),
          const SizedBox(height: rowSpacing),
        ],
        const SizedBox(height: footerTopSpacing),
        Text(
          '$daysReadThisMonth day${daysReadThisMonth == 1 ? '' : 's'} read this month',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool filled;
  final bool isToday;
  final bool isFuture;
  final DayOutcome? outcome;
  final bool joinsLeft;
  final bool joinsRight;

  const _DayCell({
    required this.day,
    required this.filled,
    required this.isToday,
    required this.isFuture,
    required this.outcome,
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

    // A grace-forgiven miss gets a dashed ring in the streak's own color -
    // it still counts, so it borrows the streak's color rather than reading
    // as a plain gap. A hard miss gets a solid error-tinted ring and a faint
    // fill, so the two unread states are told apart by more than memory.
    final Color borderColor;
    final double borderWidth;
    final Color? fillColor;
    if (isToday) {
      borderColor = colorScheme.primary;
      borderWidth = 2;
      fillColor = null;
    } else if (outcome == DayOutcome.graceForgiven) {
      borderColor = colorScheme.primary;
      borderWidth = 1.5;
      fillColor = colorScheme.primary.withValues(alpha: 0.08);
    } else if (outcome == DayOutcome.missed) {
      borderColor = colorScheme.error;
      borderWidth = 1.5;
      fillColor = colorScheme.error.withValues(alpha: 0.08);
    } else {
      borderColor = isFuture ? colorScheme.outlineVariant.withValues(alpha: 0.5) : colorScheme.outlineVariant;
      borderWidth = 1;
      fillColor = null;
    }

    return Center(
      child: Container(
        width: _height,
        height: _height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          border: outcome == DayOutcome.graceForgiven
              ? null
              : Border.all(color: borderColor, width: borderWidth),
        ),
        // No `alignment` here deliberately - it would loosen the constraints
        // passed to the CustomPaint child below, so it'd size to its Text
        // instead of filling this 36x36 box, and the dashed ring would be
        // painted far too small.
        child: CustomPaint(
          painter: outcome == DayOutcome.graceForgiven
              ? _DashedCirclePainter(color: borderColor, strokeWidth: borderWidth)
              : null,
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isFuture ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed ring, since Flutter's [Border] has no dashed style built in -
/// used for a grace-forgiven day, to read as distinct from both a solid
/// missed-day ring and a plain untracked one at a glance, with no text.
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final circumference = 2 * pi * radius;
    const dashLength = 4.0;
    const gapLength = 3.0;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashLength + gapLength) / circumference) * 2 * pi;
      final sweepAngle = (dashLength / circumference) * 2 * pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Bottom sheet for jumping straight to a month/year, instead of paging one
/// month at a time. A year stepper up top, a 3x4 grid of months below -
/// months after the latest allowed month (the current one) are disabled,
/// same rule the calendar's own "next month" arrow follows.
class _MonthYearSheet extends StatefulWidget {
  final DateTime initialMonth;
  final int earliestYear;
  final DateTime latestMonth;

  const _MonthYearSheet({required this.initialMonth, required this.earliestYear, required this.latestMonth});

  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialMonth.year;
  }

  bool get _isLatestYear => _selectedYear == widget.latestMonth.year;
  bool get _isEarliestYear => _selectedYear == widget.earliestYear;

  void _changeYear(int delta) {
    final next = _selectedYear + delta;
    if (next > widget.latestMonth.year || next < widget.earliestYear) return;
    setState(() => _selectedYear = next);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Jump to month',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous year',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _isEarliestYear ? null : () => _changeYear(-1),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '$_selectedYear',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _isLatestYear ? null : () => _changeYear(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: List.generate(12, (i) {
              final monthNumber = i + 1;
              final isSelected = monthNumber == widget.initialMonth.month && _selectedYear == widget.initialMonth.year;
              final isDisabled = _isLatestYear && monthNumber > widget.latestMonth.month;
              return _MonthOption(
                label: _MonthYearSheet.monthNames[i].substring(0, 3),
                selected: isSelected,
                disabled: isDisabled,
                onTap: isDisabled
                    ? null
                    : () => Navigator.of(context).pop(DateTime(_selectedYear, monthNumber, 1)),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MonthOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _MonthOption({required this.label, required this.selected, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.primary : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected
                  ? colorScheme.onPrimary
                  : disabled
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
