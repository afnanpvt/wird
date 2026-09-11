import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../utils/stat_formatting.dart';

enum _Metric { ayahs, hasanat, time }

enum _Grain { week, month, year }

/// A single real per-day metric, switchable, one heatmap at a time - never
/// three overlaid charts or a blended "score". Every number here comes
/// straight from what StreakService already tracks; nothing here is
/// invented or derived (no completion %, no goal, no "vs average").
class DayStatsScreen extends StatefulWidget {
  const DayStatsScreen({super.key});

  @override
  State<DayStatsScreen> createState() => _DayStatsScreenState();
}

class _DayStatsScreenState extends State<DayStatsScreen> {
  _Metric _metric = _Metric.ayahs;
  _Grain _grain = _Grain.month;

  // Which month/year page is currently visible - independent of each other
  // so switching grain doesn't lose your place in either.
  late DateTime _visibleMonth;
  late int _visibleYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _visibleYear = now.year;
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
      appBar: AppBar(elevation: 0, title: const Text('Your reading, by day')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricSelector(
                selected: _metric,
                onChanged: (m) => setState(() => _metric = m),
              ),
              const SizedBox(height: 20),
              _GrainSelector(
                selected: _grain,
                onChanged: (g) => setState(() => _grain = g),
              ),
              const SizedBox(height: 24),
              if (earliest == null)
                _EmptyHistory(colorScheme: colorScheme)
              else ...[
                switch (_grain) {
                  _Grain.week => _WeekGrid(
                      metric: _metric,
                      valueFor: (d) => _valueFor(appState, d),
                      formatValue: _formatValue,
                      onTapDay: (d) => _showDaySheet(context, d),
                    ),
                  _Grain.month => _MonthHeatmap(
                      month: _visibleMonth,
                      metric: _metric,
                      valueFor: (d) => _valueFor(appState, d),
                      onTapDay: (d) => _showDaySheet(context, d),
                      onPrevMonth: () => setState(
                        () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1),
                      ),
                      onNextMonth: _isCurrentMonth(_visibleMonth)
                          ? null
                          : () => setState(
                              () => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1),
                            ),
                    ),
                  _Grain.year => _YearHeatmap(
                      year: _visibleYear,
                      metric: _metric,
                      valueFor: (d) => _valueFor(appState, d),
                      onTapDay: (d) => _showDaySheet(context, d),
                      onPrevYear: () => setState(() => _visibleYear--),
                      onNextYear: _visibleYear >= DateTime.now().year ? null : () => setState(() => _visibleYear++),
                    ),
                },
                const SizedBox(height: 20),
                _RangeTotal(
                  grain: _grain,
                  month: _visibleMonth,
                  year: _visibleYear,
                  metricUnitLabel: _metricUnitLabel,
                  formatValue: _formatValue,
                  valueFor: (d) => _valueFor(appState, d),
                  earliest: earliest,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isCurrentMonth(DateTime month) {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
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
  final _Metric metric;
  final int Function(DateTime) valueFor;
  final String Function(int) formatValue;
  final ValueChanged<DateTime> onTapDay;

  const _WeekGrid({
    required this.metric,
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
  final _Metric metric;
  final int Function(DateTime) valueFor;
  final ValueChanged<DateTime> onTapDay;
  final VoidCallback onPrevMonth;
  final VoidCallback? onNextMonth;

  const _MonthHeatmap({
    required this.month,
    required this.metric,
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
  final _Metric metric;
  final int Function(DateTime) valueFor;
  final ValueChanged<DateTime> onTapDay;
  final VoidCallback onPrevYear;
  final VoidCallback? onNextYear;

  const _YearHeatmap({
    required this.year,
    required this.metric,
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
