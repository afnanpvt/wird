import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ayah.dart';
import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../widgets/coach_tour.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settingsKey = GlobalKey();
  final _continueReadingKey = GlobalKey();
  final _browseKey = GlobalKey();

  // Randomized once per app open rather than per rebuild, so it doesn't
  // change every time something else on the screen triggers a rebuild.
  static const _islamicGreetings = [
    'Assalamu alaikum',
    'As-salamu alaykum',
    'Peace be upon you',
    'Salaam',
  ];
  late final String _islamicGreeting;

  // The streak number is already the loud, visible thing right below this -
  // no need for a second congratulatory line repeating it in words.
  String _greeting(String? name) {
    final who = name == null || name.isEmpty ? '' : ', $name';
    return '$_islamicGreeting$who';
  }

  @override
  void initState() {
    super.initState();
    _islamicGreeting = _islamicGreetings[Random().nextInt(_islamicGreetings.length)];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (appState.hasSeenCoachTour) return;
      appState.markCoachTourSeen();
      CoachTour.show(context, [
        CoachStep(
          targetKey: _settingsKey,
          title: 'Your settings',
          description: "Change your name, script, theme, or translation style here.",
        ),
        CoachStep(
          targetKey: _continueReadingKey,
          title: 'Pick up where you left off',
          description: "This always points to your last read ayah, so you never lose your place.",
        ),
        CoachStep(
          targetKey: _browseKey,
          title: 'Browse any Surah or Juz',
          description: "Jump anywhere in the Quran whenever you want, without disturbing your progress.",
        ),
      ]);
    });
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
            key: _settingsKey,
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
                _greeting(appState.userName),
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
              KeyedSubtree(
                key: _continueReadingKey,
                child: _ContinueReadingCard(
                  surahName: resumeSurah.englishName,
                  surahNumber: resumeSurah.number,
                  ayahNumber: position.ayahNumber,
                  ayahCount: resumeSurah.ayahCount,
                  isNewUser: appState.totalAyahsRead == 0,
                ),
              ),
              const SizedBox(height: 20),
              DateTime.now().weekday == DateTime.friday ? const _FridayCard() : _VerseOfTheDay(verse: verse),
              const SizedBox(height: 20),
              const _StatsCard(),
              const SizedBox(height: 24),
              OutlinedButton(
                key: _browseKey,
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
  final bool isNewUser;

  const _ContinueReadingCard({
    required this.surahName,
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahCount,
    required this.isNewUser,
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
                      isNewUser ? 'START HERE' : 'CONTINUE READING',
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
              child: Text(isNewUser ? 'Start reading' : 'Read more'),
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
    final fontFamily = context.watch<AppState>().quranScript.fontFamily;
    final arabicStyle = TextStyle(fontFamily: fontFamily, fontSize: 24, height: 2.1);
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

/// Swipeable Today / Week / All time stats, so the home screen surfaces one
/// clear window at a time instead of every number at once.
class _StatsCard extends StatefulWidget {
  const _StatsCard();

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorColor: colorScheme.onSurface,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: colorScheme.onSurface,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Today'), Tab(text: 'Week'), Tab(text: 'All time')],
          ),
          SizedBox(
            height: 96,
            child: TabBarView(
              controller: _tabController,
              children: [
                _StatsRow(stats: [
                  _Stat('Ayahs read', '${appState.ayahsReadToday}'),
                  _Stat('Time reading', _formatDuration(appState.readingSecondsToday)),
                ]),
                _StatsRow(stats: [
                  _Stat('Ayahs read', '${appState.ayahsReadThisWeek}'),
                  _Stat('Time reading', _formatDuration(appState.readingSecondsThisWeek)),
                ]),
                _StatsRow(stats: [
                  _Stat('Ayahs read', '${appState.totalAyahsRead}'),
                  _Stat('Time reading', _formatDuration(appState.totalReadingSeconds)),
                  _Stat('Best streak', '${appState.longestStreak}'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_Stat> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
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
    );
  }
}

/// Shown instead of the Verse of the Day on Fridays: Surah Al-Kahf is the
/// one day-specific recitation with broad, well-attested backing (unlike
/// other days, which don't have an equally universal recommendation).
/// Deliberately doesn't move the continue-reading position - see
/// [ReadingScreen.updatesContinuePoint].
class _FridayCard extends StatelessWidget {
  const _FridayCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = context.read<AppState>();
    final surah = appState.quran.surahByNumber(18);

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ReadingScreen(
              initialSurahNumber: 18,
              initialAyahNumber: 1,
              updatesContinuePoint: false,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "IT'S JUMU'AH",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Text(
                "Friday is the best day of the week. Many Muslims read Surah Al-Kahf today, a tradition going back to the Prophet's own recommendation.",
                style: TextStyle(fontSize: 14, height: 1.5, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text('18 ${surah.englishName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
