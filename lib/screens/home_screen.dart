import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ayah.dart';
import '../services/app_state.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'browse_screen.dart';

String _formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return '${totalSeconds}s';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _dayMessages = [
    'Good start', // day 1
    'Two days now', // day 2
    'Three days, keep going', // day 3
    'Four days strong', // day 4
    "Five days in, a habit's forming", // day 5
    'Six days, nice rhythm', // day 6
    'One full week', // day 7
    'Eight days and counting', // day 8
    'Nine days, almost double digits', // day 9
    "Ten days — you've earned a grace day", // day 10
  ];

  String _greeting(String? name, int streak) {
    final who = name == null || name.isEmpty ? '' : ', $name';
    if (streak == 0) return "Let's start today$who";
    if (streak <= _dayMessages.length) return '${_dayMessages[streak - 1]}$who';
    if (streak < 50) return '$streak days strong$who';
    return '$streak days in — still going$who';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final streak = appState.streakState;
    final position = appState.lastPosition;
    final colorScheme = Theme.of(context).colorScheme;
    final verse = appState.quran.verseOfTheDay(DateTime.now());
    final resumeSurah = appState.quran.surahByNumber(position.surahNumber);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('wird.', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _greeting(appState.userName, streak.currentStreak),
                style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${streak.currentStreak}',
                      style: TextStyle(
                        fontSize: 76,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: colorScheme.primary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'day streak',
                      style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _ContinueReadingCard(
                surahName: resumeSurah.englishName,
                surahNumber: resumeSurah.number,
                ayahNumber: position.ayahNumber,
                ayahCount: resumeSurah.ayahCount,
              ),
              const SizedBox(height: 20),
              _VerseOfTheDay(verse: verse),
              const SizedBox(height: 32),
              _StatGroup(
                label: 'THIS WEEK',
                stats: [
                  _Stat('Today', '${appState.ayahsReadToday}'),
                  _Stat('This week', '${appState.ayahsReadThisWeek}'),
                  _Stat('Total', '${appState.totalAyahsRead}'),
                ],
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 20),
              _StatGroup(
                label: 'OVERALL',
                stats: [
                  _Stat('Best streak', '${appState.longestStreak}'),
                  _Stat('Sessions', '${appState.sessionCount}'),
                  _Stat('Time reading', _formatDuration(appState.totalReadingSeconds)),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BrowseScreen()),
                ),
                child: const Text('Browse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final String surahName;
  final int surahNumber;
  final int ayahNumber;
  final int ayahCount;

  const _ContinueReadingCard({
    required this.surahName,
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTINUE READING',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$surahNumber $surahName · $ayahNumber/$ayahCount',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu_book_rounded, size: 17, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReadingScreen(
                    initialSurahNumber: surahNumber,
                    initialAyahNumber: ayahNumber,
                  ),
                ),
              ),
              child: const Text('Read more'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseOfTheDay extends StatefulWidget {
  final Ayah verse;

  const _VerseOfTheDay({required this.verse});

  @override
  State<_VerseOfTheDay> createState() => _VerseOfTheDayState();
}

class _VerseOfTheDayState extends State<_VerseOfTheDay> {
  bool _expanded = false;

  bool _overflowsAtTwoLines(String text, TextStyle style, double maxWidth, {TextDirection? direction}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction ?? TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const arabicStyle = TextStyle(fontFamily: 'QuranNastaleeq', fontSize: 24, height: 2.1);
    final englishStyle = TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurface);

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReadingScreen(
              initialSurahNumber: widget.verse.surahNumber,
              initialAyahNumber: widget.verse.ayahNumber,
              updatesContinuePoint: false,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final overflows = !_expanded &&
                  (_overflowsAtTwoLines(widget.verse.arabicText, arabicStyle, maxWidth, direction: TextDirection.rtl) ||
                      _overflowsAtTwoLines(widget.verse.englishText, englishStyle, maxWidth));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'VERSE OF THE DAY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.verse.arabicText,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: arabicStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.verse.englishText,
                    textAlign: TextAlign.center,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: englishStyle,
                  ),
                  if (overflows) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                        onPressed: () => setState(() => _expanded = true),
                        child: const Text('Show more'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  _Stat(this.label, this.value);
}

class _StatGroup extends StatelessWidget {
  final String label;
  final List<_Stat> stats;

  const _StatGroup({required this.label, required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) SizedBox(width: 1, height: 40, child: Container(color: colorScheme.outlineVariant)),
              Expanded(
                child: Column(
                  children: [
                    Text(stats[i].value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(stats[i].label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
