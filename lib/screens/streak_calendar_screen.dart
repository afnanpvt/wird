import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../utils/stat_formatting.dart';
import '../widgets/quick_page_physics.dart';

enum _Metric { ayahs, hasanat, time }

enum _Grain { week, month, year }

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Full month view of the same honest per-day activity the home screen's
/// weekly strip shows, followed - on the same screen, same scroll - by the
/// day-by-day stats that used to live behind a separate corner icon.
/// Consecutive read days within a week row merge into one connected pill
/// exactly like the weekly strip, but never across a row boundary: day 7 of
/// one week and day 1 of the next sit in different rows, so there's no
/// sensible single shape to draw them as.
///
/// The stats section below the calendar is a single real per-day metric,
/// switchable, one heatmap at a time - never three overlaid charts or a
/// blended "score" - plus a small set of derived insights (best day,
/// average across days you actually read, this week vs last, how many of
/// your days since you started have had any reading at all). Every number
/// here, insights included, comes from real recorded activity: no invented
/// goals, no completion percentage against a target the app made up, no
/// "vs average reader" comparison.
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

  // Stats section state - independent of the calendar's own month paging
  // above, since they're two different views of two different things
  // (habit status vs a chosen metric's value) that just happen to both be
  // about days.
  _Metric _metric = _Metric.ayahs;
  _Grain _grain = _Grain.month;
  late DateTime _statsVisibleMonth;
  late int _statsVisibleYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month, 1);
    _visibleMonth = ValueNotifier(_anchorMonth);
    _pageController = PageController(initialPage: _initialPage);
    _statsVisibleMonth = DateTime(now.year, now.month, 1);
    _statsVisibleYear = now.year;
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

  bool _isCurrentMonth(DateTime month) {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

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

  int _valueFor(AppState appState, DateTime date) {
    switch (_metric) {
      case _Metric.ayahs:
        return appState.ayahsReadOn(date);
      case _Metric.hasanat:
        return appState.hasanatOn(date);
      case _Metric.time:
        return appState.readingSecondsOn(date);
    }
  }

  Map<String, int> _dailyMapFor(AppState appState) {
    switch (_metric) {
      case _Metric.ayahs:
        return appState.allDailyAyahs;
      case _Metric.hasanat:
        return appState.allDailyHasanat;
      case _Metric.time:
        return appState.allDailyReadingSeconds;
    }
  }

  String _formatValue(int value) {
    switch (_metric) {
      case _Metric.ayahs:
        return '$value';
      case _Metric.hasanat:
        return formatCompactCount(value);
      case _Metric.time:
        return formatDuration(value);
    }
  }

  String get _metricUnitLabel {
    switch (_metric) {
      case _Metric.ayahs:
        return 'ayahs';
      case _Metric.hasanat:
        return 'hasanat';
      case _Metric.time:
        return 'reading time';
    }
  }

  void _showDaySheet(BuildContext context, DateTime date) {
    final appState = context.read<AppState>();
    final today = DateTime.now();
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
    if (isFuture) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DayDetailSheet(
        date: date,
        ayahs: appState.ayahsReadOn(date),
        hasanat: appState.hasanatOn(date),
        seconds: appState.readingSecondsOn(date),
        outcome: appState.dayOutcome(date),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final earliest = appState.earliestLoggedDate;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Reading calendar')),
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 40),
              _StreakSummaryRow(current: appState.streakState.currentStreak, longest: appState.longestStreak),
              const SizedBox(height: 36),
              Text('STATS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              _MetricSelector(selected: _metric, onChanged: (m) => setState(() => _metric = m)),
              const SizedBox(height: 20),
              _GrainSelector(selected: _grain, onChanged: (g) => setState(() => _grain = g)),
              const SizedBox(height: 24),
              if (earliest == null)
                _EmptyHistory(colorScheme: colorScheme)
              else ...[
                switch (_grain) {
                  _Grain.week => _WeekGrid(
                      valueFor: (d) => _valueFor(appState, d),
                      formatValue: _formatValue,
                      onTapDay: (d) => _showDaySheet(context, d),
                    ),
                  _Grain.month => _MonthHeatmap(
                      month: _statsVisibleMonth,
                      valueFor: (d) => _valueFor(appState, d),
                      onTapDay: (d) => _showDaySheet(context, d),
                      onPrevMonth: () => setState(
                        () => _statsVisibleMonth = DateTime(_statsVisibleMonth.year, _statsVisibleMonth.month - 1, 1),
                      ),
                      onNextMonth: _isCurrentMonth(_statsVisibleMonth)
                          ? null
                          : () => setState(
                              () => _statsVisibleMonth = DateTime(_statsVisibleMonth.year, _statsVisibleMonth.month + 1, 1),
                            ),
                    ),
                  _Grain.year => _YearHeatmap(
                      year: _statsVisibleYear,
                      valueFor: (d) => _valueFor(appState, d),
                      onTapDay: (d) => _showDaySheet(context, d),
                      onPrevYear: () => setState(() => _statsVisibleYear--),
                      onNextYear: _statsVisibleYear >= DateTime.now().year ? null : () => setState(() => _statsVisibleYear++),
                    ),
                },
                const SizedBox(height: 20),
                _RangeTotal(
                  grain: _grain,
                  month: _statsVisibleMonth,
                  year: _statsVisibleYear,
                  metricUnitLabel: _metricUnitLabel,
                  formatValue: _formatValue,
                  valueFor: (d) => _valueFor(appState, d),
                  earliest: earliest,
                ),
                const SizedBox(height: 28),
                _InsightsGrid(
                  insights: _Insights.compute(_dailyMapFor(appState)),
                  metricLabel: _metricUnitLabel,
                  formatValue: _formatValue,
                  activeDaysMap: appState.allDailyAyahs,
                  earliest: earliest,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Current and longest streak, side by side - pulling the calendar's own
/// headline numbers up top instead of leaving them implicit in the grid
/// below. Purely a display of state StreakService already tracks.
class _StreakSummaryRow extends StatelessWidget {
  final int current;
  final int longest;

  const _StreakSummaryRow({required this.current, required this.longest});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StreakSummaryTile(label: 'Current streak', value: '$current', unit: current == 1 ? 'day' : 'days')),
        const SizedBox(width: 12),
        Expanded(child: _StreakSummaryTile(label: 'Longest streak', value: '$longest', unit: longest == 1 ? 'day' : 'days')),
      ],
    );
  }
}

class _StreakSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StreakSummaryTile({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
              const SizedBox(width: 5),
              Text(unit, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Real, derived-but-never-invented insights for whichever metric is
/// selected: the single best day ever recorded, the average across only the
/// days that actually had reading (never divided by empty calendar days,
/// which would silently read as a disguised completion score), and this
/// week's total against last week's. Nothing here compares against a target
/// the app made up.
class _Insights {
  final int bestValue;
  final DateTime? bestDate;
  final int activeDays;
  final double averagePerActiveDay;
  final int thisWeekTotal;
  final int lastWeekTotal;

  const _Insights({
    required this.bestValue,
    required this.bestDate,
    required this.activeDays,
    required this.averagePerActiveDay,
    required this.thisWeekTotal,
    required this.lastWeekTotal,
  });

  static _Insights compute(Map<String, int> dailyMap) {
    var total = 0;
    var bestValue = 0;
    var activeDays = 0;
    DateTime? bestDate;
    for (final entry in dailyMap.entries) {
      final v = entry.value;
      if (v <= 0) continue;
      total += v;
      activeDays++;
      if (v > bestValue) {
        bestValue = v;
        bestDate = DateTime.parse(entry.key);
      }
    }
    final average = activeDays == 0 ? 0.0 : total / activeDays;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisSunday = today.subtract(Duration(days: today.weekday % 7));
    final lastSunday = thisSunday.subtract(const Duration(days: 7));

    int sumRange(DateTime start, DateTime endExclusive) {
      var sum = 0;
      for (var d = start; d.isBefore(endExclusive); d = d.add(const Duration(days: 1))) {
        sum += dailyMap[_dateKey(d)] ?? 0;
      }
      return sum;
    }

    return _Insights(
      bestValue: bestValue,
      bestDate: bestDate,
      activeDays: activeDays,
      averagePerActiveDay: average,
      thisWeekTotal: sumRange(thisSunday, thisSunday.add(const Duration(days: 7))),
      lastWeekTotal: sumRange(lastSunday, thisSunday),
    );
  }
}

class _InsightsGrid extends StatelessWidget {
  final _Insights insights;
  final String metricLabel;
  final String Function(int) formatValue;
  final Map<String, int> activeDaysMap;
  final DateTime earliest;

  const _InsightsGrid({
    required this.insights,
    required this.metricLabel,
    required this.formatValue,
    required this.activeDaysMap,
    required this.earliest,
  });

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final bestLabel = insights.bestDate == null
        ? '—'
        : '${formatValue(insights.bestValue)} · ${_monthNames[insights.bestDate!.month - 1]} ${insights.bestDate!.day}';

    final avgLabel = insights.activeDays == 0 ? '—' : formatValue(insights.averagePerActiveDay.round());

    final delta = insights.thisWeekTotal - insights.lastWeekTotal;
    final trendLabel = delta == 0 ? 'Same as last week' : '${delta > 0 ? '+' : ''}${formatValue(delta)} vs last week';
    final trendColor = delta > 0
        ? colorScheme.primary
        : delta < 0
            ? colorScheme.onSurfaceVariant
            : colorScheme.onSurfaceVariant;

    var activeCount = 0;
    for (final v in activeDaysMap.values) {
      if (v > 0) activeCount++;
    }
    final daysSinceStart = todayDate.difference(earliest).inDays + 1;
    final consistencyPct = daysSinceStart <= 0 ? 0 : ((activeCount / daysSinceStart) * 100).round();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        _InsightTile(label: 'Best day', value: bestLabel),
        _InsightTile(label: 'Avg. per active day', value: insights.activeDays == 0 ? '—' : '$avgLabel $metricLabel'),
        _InsightTile(label: 'This week', value: formatValue(insights.thisWeekTotal), caption: trendLabel, captionColor: trendColor),
        _InsightTile(label: 'Consistency', value: '$consistencyPct%', caption: 'of days since ${_monthNames[earliest.month - 1]} ${earliest.day}'),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? captionColor;

  const _InsightTile({required this.label, required this.value, this.caption, this.captionColor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: captionColor ?? colorScheme.onSurfaceVariant),
            ),
          ],
        ],
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
          style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Jump to month',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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

class _MetricSelector extends StatelessWidget {
  final _Metric selected;
  final ValueChanged<_Metric> onChanged;

  const _MetricSelector({required this.selected, required this.onChanged});

  static const _labels = {
    _Metric.ayahs: 'Ayahs',
    _Metric.hasanat: 'Hasanat',
    _Metric.time: 'Time',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final metric in _Metric.values)
            Expanded(
              child: _SegmentButton(
                label: _labels[metric]!,
                selected: metric == selected,
                onTap: () => onChanged(metric),
              ),
            ),
        ],
      ),
    );
  }
}

class _GrainSelector extends StatelessWidget {
  final _Grain selected;
  final ValueChanged<_Grain> onChanged;

  const _GrainSelector({required this.selected, required this.onChanged});

  static const _labels = {
    _Grain.week: 'Week',
    _Grain.month: 'Month',
    _Grain.year: 'Year',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final grain in _Grain.values)
            Expanded(
              child: _SegmentButton(
                label: _labels[grain]!,
                selected: grain == selected,
                onTap: () => onChanged(grain),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// A day's fill intensity for whichever metric is selected - 5 steps,
/// matching the GitHub-style scale this whole design is patterned on. Scale
/// is relative to the highest single day in the currently visible range,
/// not a fixed absolute threshold, so a light reader's heatmap doesn't just
/// look permanently empty next to a heavy reader's.
Color _intensityColor(ColorScheme colorScheme, int value, int maxInRange) {
  if (value <= 0) return Colors.transparent;
  if (maxInRange <= 0) return colorScheme.primary;
  final ratio = value / maxInRange;
  final steps = [0.2, 0.4, 0.6, 0.8, 1.0];
  var alpha = steps.first;
  for (final step in steps) {
    if (ratio <= step) {
      alpha = step;
      break;
    }
    alpha = step;
  }
  return colorScheme.primary.withValues(alpha: 0.28 + alpha * 0.72);
}

class _WeekGrid extends StatelessWidget {
  final int Function(DateTime) valueFor;
  final String Function(int) formatValue;
  final ValueChanged<DateTime> onTapDay;

  const _WeekGrid({
    required this.valueFor,
    required this.formatValue,
    required this.onTapDay,
  });

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    final dates = List.generate(7, (i) => sunday.add(Duration(days: i)));
    final values = [for (final d in dates) d.isAfter(today) ? 0 : valueFor(d)];
    final maxValue = values.fold(0, (a, b) => a > b ? a : b);

    return Row(
      children: List.generate(7, (i) {
        final date = dates[i];
        final isFuture = date.isAfter(today);
        final isToday = date == today;
        final value = values[i];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dayLabels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isToday ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: isFuture ? null : () => onTapDay(date),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFuture ? null : _intensityColor(colorScheme, value, maxValue),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: isFuture ? 0.4 : 0.7),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: value > 0
                        ? Text(
                            formatValue(value),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: value / (maxValue == 0 ? 1 : maxValue) > 0.55 ? colorScheme.onPrimary : colorScheme.onSurface,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _MonthHeatmap extends StatelessWidget {
  final DateTime month;
  final int Function(DateTime) valueFor;
  final ValueChanged<DateTime> onTapDay;
  final VoidCallback onPrevMonth;
  final VoidCallback? onNextMonth;

  const _MonthHeatmap({
    required this.month,
    required this.valueFor,
    required this.onTapDay,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekdayColumn = DateTime(month.year, month.month, 1).weekday % 7;

    final values = <int, int>{};
    var maxValue = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.isAfter(today)) continue;
      final v = valueFor(date);
      values[d] = v;
      if (v > maxValue) maxValue = v;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: onPrevMonth,
            ),
            Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in _dayLabels)
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
        const SizedBox(height: 8),
        for (var week = 0; week < 6; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(7, (column) {
                final dayNumber = week * 7 + column - firstWeekdayColumn + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }
                final date = DateTime(month.year, month.month, dayNumber);
                final isFuture = date.isAfter(today);
                final isToday = date == today;
                final value = values[dayNumber] ?? 0;

                return Expanded(
                  child: GestureDetector(
                    onTap: isFuture ? null : () => onTapDay(date),
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isFuture ? null : _intensityColor(colorScheme, value, maxValue),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(color: colorScheme.primary, width: 1.5) : null,
                      ),
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isFuture
                              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35)
                              : value / (maxValue == 0 ? 1 : maxValue) > 0.55
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// A full calendar year rendered as one GitHub-style grid: 53 week-columns
/// of 7 day-cells, drawn with a single CustomPainter rather than 371
/// separate widgets - the one place in this screen where the naive
/// per-cell-widget approach the month view uses would actually start to
/// matter (per the researched contribution_heatmap package's own approach).
class _YearHeatmap extends StatelessWidget {
  final int year;
  final int Function(DateTime) valueFor;
  final ValueChanged<DateTime> onTapDay;
  final VoidCallback onPrevYear;
  final VoidCallback? onNextYear;

  const _YearHeatmap({
    required this.year,
    required this.valueFor,
    required this.onTapDay,
    required this.onPrevYear,
    required this.onNextYear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final jan1 = DateTime(year, 1, 1);
    final dec31 = DateTime(year, 12, 31);

    // Precompute the whole year's values once per build, same caching
    // instinct AppState already uses for day outcomes - never call into
    // AppState per-cell during paint.
    final values = <DateTime, int>{};
    var maxValue = 0;
    for (var d = jan1; !d.isAfter(dec31); d = d.add(const Duration(days: 1))) {
      if (d.isAfter(today)) continue;
      final v = valueFor(d);
      if (v > 0) values[d] = v;
      if (v > maxValue) maxValue = v;
    }

    // Sunday-start columns, one column per week, spanning from the Sunday
    // on/before Jan 1 to the Saturday on/after Dec 31 - same convention as
    // GitHub's own contribution graph.
    final gridStart = jan1.subtract(Duration(days: jan1.weekday % 7));
    final totalDays = dec31.difference(gridStart).inDays + 1;
    final weekCount = (totalDays / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Previous year',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: onPrevYear,
            ),
            Text('$year', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: 'Next year',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: onNextYear,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const cellGap = 3.0;
            final cellSize = (constraints.maxWidth - (weekCount - 1) * cellGap) / weekCount;
            final gridHeight = cellSize * 7 + cellGap * 6;
            return SizedBox(
              height: gridHeight,
              child: GestureDetector(
                onTapUp: (details) {
                  final column = (details.localPosition.dx / (cellSize + cellGap)).floor();
                  final row = (details.localPosition.dy / (cellSize + cellGap)).floor();
                  if (column < 0 || column >= weekCount || row < 0 || row > 6) return;
                  final date = gridStart.add(Duration(days: column * 7 + row));
                  if (date.year != year || date.isAfter(today)) return;
                  onTapDay(date);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, gridHeight),
                  painter: _YearHeatmapPainter(
                    gridStart: gridStart,
                    weekCount: weekCount,
                    year: year,
                    today: today,
                    values: values,
                    maxValue: maxValue,
                    cellSize: cellSize,
                    cellGap: cellGap,
                    baseColor: colorScheme.primary,
                    emptyColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    todayColor: colorScheme.primary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _YearHeatmapPainter extends CustomPainter {
  final DateTime gridStart;
  final int weekCount;
  final int year;
  final DateTime today;
  final Map<DateTime, int> values;
  final int maxValue;
  final double cellSize;
  final double cellGap;
  final Color baseColor;
  final Color emptyColor;
  final Color todayColor;

  _YearHeatmapPainter({
    required this.gridStart,
    required this.weekCount,
    required this.year,
    required this.today,
    required this.values,
    required this.maxValue,
    required this.cellSize,
    required this.cellGap,
    required this.baseColor,
    required this.emptyColor,
    required this.todayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(cellSize * 0.25);
    final fillPaint = Paint();
    final emptyPaint = Paint()..color = emptyColor;
    final todayPaint = Paint()
      ..color = todayColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var week = 0; week < weekCount; week++) {
      for (var dow = 0; dow < 7; dow++) {
        final date = gridStart.add(Duration(days: week * 7 + dow));
        if (date.year != year) continue;

        final rect = Rect.fromLTWH(
          week * (cellSize + cellGap),
          dow * (cellSize + cellGap),
          cellSize,
          cellSize,
        );
        final rrect = RRect.fromRectAndRadius(rect, radius);

        if (date.isAfter(today)) continue;

        final value = values[date] ?? 0;
        if (value > 0) {
          final ratio = maxValue <= 0 ? 1.0 : value / maxValue;
          fillPaint.color = baseColor.withValues(alpha: 0.28 + ratio.clamp(0.0, 1.0) * 0.72);
          canvas.drawRRect(rrect, fillPaint);
        } else {
          canvas.drawRRect(rrect, emptyPaint);
        }

        if (date == today) {
          canvas.drawRRect(rrect.deflate(0.75), todayPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_YearHeatmapPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.maxValue != maxValue || oldDelegate.cellSize != cellSize;
}

class _RangeTotal extends StatelessWidget {
  final _Grain grain;
  final DateTime month;
  final int year;
  final String metricUnitLabel;
  final String Function(int) formatValue;
  final int Function(DateTime) valueFor;
  final DateTime earliest;

  const _RangeTotal({
    required this.grain,
    required this.month,
    required this.year,
    required this.metricUnitLabel,
    required this.formatValue,
    required this.valueFor,
    required this.earliest,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int total = 0;
    int daysWithReading = 0;
    late DateTime start;
    late DateTime end;

    switch (grain) {
      case _Grain.week:
        final sunday = today.subtract(Duration(days: today.weekday % 7));
        start = sunday;
        end = sunday.add(const Duration(days: 6));
      case _Grain.month:
        start = DateTime(month.year, month.month, 1);
        end = DateTime(month.year, month.month + 1, 0);
      case _Grain.year:
        start = DateTime(year, 1, 1);
        end = DateTime(year, 12, 31);
    }

    for (var d = start; !d.isAfter(end) && !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      final v = valueFor(d);
      if (v > 0) {
        total += v;
        daysWithReading++;
      }
    }

    final daysSinceStart = today.difference(earliest).inDays + 1;
    final isNewUser = daysSinceStart <= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatValue(total)} $metricUnitLabel',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          '$daysWithReading day${daysWithReading == 1 ? '' : 's'} with reading, this ${_grainNoun(grain)}',
          style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
        ),
        if (isNewUser) ...[
          const SizedBox(height: 10),
          Text(
            "$daysSinceStart day${daysSinceStart == 1 ? '' : 's'} in - every one counts.",
            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  String _grainNoun(_Grain grain) => switch (grain) {
        _Grain.week => 'week',
        _Grain.month => 'month',
        _Grain.year => 'year',
      };
}

class _EmptyHistory extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyHistory({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Nothing logged yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Read a verse and your history starts showing up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final int ayahs;
  final int hasanat;
  final int seconds;
  final DayOutcome? outcome;

  const _DayDetailSheet({
    required this.date,
    required this.ayahs,
    required this.hasanat,
    required this.seconds,
    required this.outcome,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _outcomeLabel => switch (outcome) {
        DayOutcome.read => 'On streak',
        DayOutcome.graceForgiven => 'Grace day, forgiven',
        DayOutcome.missed => 'Missed',
        null => ayahs > 0 ? 'On streak' : 'Not tracked',
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_monthNames[date.month - 1]} ${date.day}, ${date.year}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(_outcomeLabel, style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (ayahs == 0)
            Text(
              'Nothing read this day.',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            )
          else
            Row(
              children: [
                Expanded(child: _DayStat(label: 'Ayahs', value: '$ayahs')),
                Expanded(child: _DayStat(label: 'Hasanat', value: formatCompactCount(hasanat))),
                Expanded(child: _DayStat(label: 'Time', value: formatDuration(seconds))),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayStat extends StatelessWidget {
  final String label;
  final String value;

  const _DayStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
