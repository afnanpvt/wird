import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/ayah.dart';
import '../models/juz_progress.dart';
import '../models/quran_script.dart';
import '../models/reading_progress.dart';
import '../services/app_state.dart';
import '../widgets/completion_dialog.dart';

/// Surahs that traditionally omit the opening Bismillah (only At-Tawbah).
const _surahsWithoutBismillah = {9};

/// Strips the trailing ayah-end ornament from an ayah's text.
///
/// In the bundled Indo-Pak text each ayah ends with U+06DF (the ayah-end
/// circle), optionally a waqf/pause mark, then a Private-Use codepoint in the
/// U+F5xx range that draws the ayah *number* inside the circle. That's correct
/// on a real ayah, but the Bismillah shown at the head of a surah is not ayah 1
/// of that surah (except in Al-Fatiha, where it genuinely is), so reusing 1:1
/// verbatim would stamp a "1" ornament on every surah opener.
String _withoutAyahEndOrnament(String text) {
  final i = text.lastIndexOf('۟');
  if (i == -1) return text;
  return text.substring(0, i).trimRight();
}

class ReadingScreen extends StatefulWidget {
  final int initialSurahNumber;
  final int initialAyahNumber;

  /// Whether reading here should move the "Continue Reading" resume point.
  /// True for the normal continuous-reading flow; false for one-off jumps
  /// (Browse, Juz, verse of the day) so they don't clobber real progress.
  final bool updatesContinuePoint;

  const ReadingScreen({
    super.key,
    required this.initialSurahNumber,
    required this.initialAyahNumber,
    this.updatesContinuePoint = true,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> with WidgetsBindingObserver, RouteAware {
  late final List<Ayah> _ayahs;
  late final bool _hasBismillah;
  late final String _bismillahText;
  late final PageController _pageController;
  late int _currentIndex;
  late bool _tracksContinue;
  late int _lastJuzNumber;
  int _sessionAyahCount = 0;
  late final ConfettiController _confettiController;

  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  int get _pageCount => _ayahs.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final quran = context.read<AppState>().quran;
    _ayahs = quran.ayahsForSurah(widget.initialSurahNumber);
    _hasBismillah = widget.initialSurahNumber != 1 && !_surahsWithoutBismillah.contains(widget.initialSurahNumber);
    _bismillahText = _withoutAyahEndOrnament(quran.ayahsForSurah(1).first.arabicText);

    _currentIndex = (widget.initialAyahNumber - 1).clamp(0, _ayahs.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _tracksContinue = widget.updatesContinuePoint;
    _sessionAyahCount = 1;
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _lastJuzNumber = quran.juzProgressFor(widget.initialSurahNumber, widget.initialAyahNumber).juzNumber;
    _elapsed = Duration(seconds: context.read<AppState>().totalReadingSeconds);
    _recordPage(_currentIndex);
    context.read<AppState>().recordSessionStarted();
    _startTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<void>);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    _confettiController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  /// Another route (e.g. the next surah's reading screen) was pushed on top
  /// of this one. This screen is still alive underneath for back-navigation,
  /// so its ticker must stop or it'd double-count reading time alongside
  /// the new screen's own ticker.
  @override
  void didPushNext() => _stopTicker();

  @override
  void didPopNext() => _startTicker();

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      context.read<AppState>().addReadingSeconds(1);
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  bool _showsBismillah(int index) => _hasBismillah && index == 0;

  Ayah _contentAt(int index) => _ayahs[index];

  int _ayahNumberForDisplay(int index) => index + 1;

  int _pageIndexForAyah(int ayahNumber) => ayahNumber - 1;

  void _goToAyah(int ayahNumber) {
    _pageController.animateToPage(
      _pageIndexForAyah(ayahNumber),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showJumpToAyahSheet() async {
    final currentAyah = _ayahNumberForDisplay(_currentIndex).clamp(1, _ayahs.length);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _JumpToAyahSheet(
        totalAyahs: _ayahs.length,
        initialAyah: currentAyah,
        onGo: (ayahNumber) {
          Navigator.of(sheetContext).pop();
          _goToAyah(ayahNumber);
        },
      ),
    );
  }

  ReadingProgress _resumePositionAt(int index) => ReadingProgress(
        surahNumber: widget.initialSurahNumber,
        ayahNumber: index + 1,
      );

  void _recordPage(int index) {
    final content = _contentAt(index);
    final appState = context.read<AppState>();
    appState.recordAyahRead(content.surahNumber, content.ayahNumber);
    if (_tracksContinue) {
      appState.saveLastPosition(_resumePositionAt(index));
    }
  }

  Future<void> _confirmSetAsContinueReading() async {
    final appState = context.read<AppState>();
    final surah = appState.quran.surahByNumber(widget.initialSurahNumber);
    final position = _resumePositionAt(_currentIndex);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Continue from here?'),
        content: Text(
          "Your home screen will pick up from ${surah.englishName}, ayah ${position.ayahNumber}, instead of wherever you left off before.",
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save this spot'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _tracksContinue = true);
      await appState.saveLastPosition(position);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only a real backgrounding (home button, app switch) pauses the timer —
    // never counted while the app isn't actually in front of the user.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopTicker();
      if (_tracksContinue) {
        context.read<AppState>().saveLastPosition(_resumePositionAt(_currentIndex));
      }
    } else if (state == AppLifecycleState.resumed) {
      if ((ModalRoute.of(context) as PageRoute<void>?)?.isCurrent ?? false) {
        _startTicker();
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _sessionAyahCount++;
    _recordPage(index);
    final content = _contentAt(index);
    final juzNumber = context.read<AppState>().quran.juzProgressFor(content.surahNumber, content.ayahNumber).juzNumber;
    if (juzNumber > _lastJuzNumber) {
      _lastJuzNumber = juzNumber;
      _confettiController.play();
    }
  }

  void _goBack() {
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goForward() {
    if (_currentIndex < _pageCount - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      return;
    }
    if (widget.initialSurahNumber < 114) {
      _confettiController.play();
      // Let the burst actually be seen before the slide transition covers it.
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        Navigator.of(context).push(_surahTransitionRoute(
          ReadingScreen(
            initialSurahNumber: widget.initialSurahNumber + 1,
            initialAyahNumber: 1,
            updatesContinuePoint: _tracksContinue,
          ),
        ));
      });
    }
  }

  /// Matches the PageView's own horizontal slide instead of the platform's
  /// default vertical/fade route transition, so moving into a new surah
  /// feels like a continuation of the same swipe rather than a screen change.
  Route<void> _surahTransitionRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOut))
              .animate(animation),
          child: child,
        );
      },
    );
  }

  Future<void> _finishReading() async {
    final appState = context.read<AppState>();
    await showCompletionDialog(
      context,
      ayahsThisSession: _sessionAyahCount,
      ayahsToday: appState.ayahsReadToday,
    );
    if (mounted) Navigator.of(context).pop();
  }

  String get _elapsedLabel {
    final hours = _elapsed.inHours;
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final surah = appState.quran.surahByNumber(widget.initialSurahNumber);
    final content = _contentAt(_currentIndex);
    final juzProgress = appState.quran.juzProgressFor(content.surahNumber, content.ayahNumber);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          '${surah.englishName} · ${_ayahNumberForDisplay(_currentIndex)}/${_ayahs.length}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_tracksContinue)
            IconButton(
              tooltip: 'Save as continue reading',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _confirmSetAsContinueReading,
            ),
          IconButton(
            tooltip: 'Jump to ayah',
            icon: const Icon(Icons.format_list_numbered_rounded),
            onPressed: _showJumpToAyahSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _JuzProgressHeader(progress: juzProgress, sessionAyahCount: _sessionAyahCount, elapsedLabel: _elapsedLabel),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pageCount,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => _AyahPage(
                    ayah: _contentAt(index),
                    bismillahText: _showsBismillah(index) ? _bismillahText : null,
                  ),
                ),
              ),
              _NavigationBar(
                canGoBack: _currentIndex > 0,
                canGoForward: _currentIndex < _pageCount - 1 || widget.initialSurahNumber < 114,
                onBack: _goBack,
                onForward: _goForward,
                onDone: _finishReading,
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                maxBlastForce: 18,
                minBlastForce: 6,
                gravity: 0.25,
                emissionFrequency: 0.04,
                // A real, multi-colored celebration burst, not the UI's
                // monochrome palette - it's a one-off moment, not chrome,
                // so it doesn't need to follow the "accent is reserved"
                // rule the rest of the UI follows.
                colors: const [
                  Color(0xFFFFD700), // gold
                  Color(0xFFC0C0C0), // silver
                  Color(0xFFE63946), // red
                  Color(0xFF4169E1), // royal blue
                  Color(0xFF50C878), // emerald green
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JuzProgressHeader extends StatelessWidget {
  final JuzProgress progress;
  final int sessionAyahCount;
  final String elapsedLabel;

  const _JuzProgressHeader({
    required this.progress,
    required this.sessionAyahCount,
    required this.elapsedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Juz ${progress.juzNumber} · ${progress.versesLeftInJuz} verses left',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
              ),
              _StatChip(icon: Icons.menu_book_rounded, label: '$sessionAyahCount'),
              const SizedBox(width: 10),
              _StatChip(icon: Icons.timer_outlined, label: elapsedLabel),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentComplete.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: colorScheme.outlineVariant,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Quran text is rendered as ONE Text - one shaping run for the whole ayah.
///
/// An earlier version split the ayah on spaces into per-word widgets inside a
/// [Wrap] with artificial gaps, to force visible word separation out of a font
/// (PDMS Saleem) that set them too tight. Do not reintroduce that: splitting on
/// spaces detaches a trailing waqf/pause mark from the word it belongs to, so
/// e.g. 2:2 rendered the mark after `رَيْبَ` drifting onto `فِيْهِ`. The current
/// font spaces words correctly on its own.
///
/// Also note [TextStyle.letterSpacing] and [wordSpacing] are no-ops for RTL
/// script on this Flutter engine (flutter/flutter#177406), so they are not an
/// alternative lever here either.
class _ArabicText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _ArabicText({required this.text, required this.style});

  @override
  Widget build(BuildContext context) =>
      Text(text, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: style);
}

class _AyahPage extends StatelessWidget {
  final Ayah ayah;
  final String? bismillahText;

  const _AyahPage({required this.ayah, this.bismillahText});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = context.watch<AppState>();
    final useSimple = appState.useSimpleTranslation;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bismillahText != null) ...[
                    _ArabicText(
                      text: bismillahText!,
                      style: TextStyle(fontFamily: appState.quranScript.fontFamily, fontSize: 27, height: 2.1, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: _ArabicText(
                      text: ayah.arabicText,
                      style: TextStyle(fontFamily: appState.quranScript.fontFamily, fontSize: 42, height: 2.2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outlineVariant, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      useSimple ? ayah.simpleEnglishText : ayah.englishText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () => appState.setUseSimpleTranslation(!useSimple),
                    child: Text(useSimple ? 'Show original translation' : "I don't understand"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onDone;

  const _NavigationBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
              disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: const StadiumBorder(),
            ),
            onPressed: onDone,
            child: const Text("I'm done"),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
              disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _JumpToAyahSheet extends StatefulWidget {
  final int totalAyahs;
  final int initialAyah;
  final ValueChanged<int> onGo;

  const _JumpToAyahSheet({
    required this.totalAyahs,
    required this.initialAyah,
    required this.onGo,
  });

  @override
  State<_JumpToAyahSheet> createState() => _JumpToAyahSheetState();
}

class _JumpToAyahSheetState extends State<_JumpToAyahSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialAyah;
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
            'Jump to ayah',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Ayah $_selected of ${widget.totalAyahs}',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          Slider(
            value: _selected.toDouble(),
            min: 1,
            max: widget.totalAyahs.toDouble(),
            divisions: widget.totalAyahs > 1 ? widget.totalAyahs - 1 : null,
            label: '$_selected',
            onChanged: (value) => setState(() => _selected = value.round()),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => widget.onGo(_selected),
              child: const Text('Go'),
            ),
          ),
        ],
      ),
    );
  }
}
