import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/ayah.dart';
import '../models/bookmark.dart';
import '../models/juz_progress.dart';
import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/quick_page_physics.dart';

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

  /// Whether reading here should auto-advance the home screen's default
  /// bookmark. True for the normal continuous-reading flow; false for
  /// one-off jumps (Browse, Juz, verse of the day, a non-default bookmark)
  /// so they don't clobber real progress.
  final bool updatesContinuePoint;

  /// Internal: threads which specific bookmark is being auto-advanced across
  /// a surah transition (see [_goForward]). Callers outside this file should
  /// use [updatesContinuePoint] instead — leave this null.
  final String? trackingBookmarkId;

  const ReadingScreen({
    super.key,
    required this.initialSurahNumber,
    required this.initialAyahNumber,
    this.updatesContinuePoint = true,
    this.trackingBookmarkId,
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
  String? _trackingBookmarkId;
  late int _lastJuzNumber;
  int _sessionAyahCount = 0;
  int _sessionHasanat = 0;
  late final ConfettiController _confettiController;

  /// Held in a notifier rather than plain state so the once-a-second tick
  /// repaints only the timer chip. A setState here would rebuild the whole
  /// screen - including the PageView and its Arabic text layout - once every
  /// second, which lands mid-swipe and drops frames.
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  Timer? _ticker;

  /// Reading time is counted every second but only written to disk every
  /// [_flushEverySeconds] (and on pause/exit). Persisting each tick meant two
  /// Hive writes a second for the entire session.
  static const _flushEverySeconds = 10;
  int _unflushedSeconds = 0;
  late final AppState _appState;

  int get _pageCount => _ayahs.length;
  bool get _isTracking => _trackingBookmarkId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final appState = context.read<AppState>();
    _appState = appState;
    final quran = appState.quran;
    _ayahs = quran.ayahsForSurah(widget.initialSurahNumber);
    _hasBismillah = widget.initialSurahNumber != 1 && !_surahsWithoutBismillah.contains(widget.initialSurahNumber);
    _bismillahText = _withoutAyahEndOrnament(quran.ayahsForSurah(1).first.arabicText);

    _currentIndex = (widget.initialAyahNumber - 1).clamp(0, _ayahs.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _trackingBookmarkId =
        widget.trackingBookmarkId ?? (widget.updatesContinuePoint ? appState.defaultBookmark.id : null);
    _sessionAyahCount = 1;
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _lastJuzNumber = quran.juzProgressFor(widget.initialSurahNumber, widget.initialAyahNumber).juzNumber;
    _elapsed.value = Duration(seconds: context.read<AppState>().totalReadingSeconds);
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
    _ticker?.cancel();
    _flushReadingSeconds();
    _pageController.dispose();
    _confettiController.dispose();
    _elapsed.dispose();
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
      _elapsed.value += const Duration(seconds: 1);
      _unflushedSeconds++;
      if (_unflushedSeconds >= _flushEverySeconds) _flushReadingSeconds();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _flushReadingSeconds();
  }

  void _flushReadingSeconds() {
    if (_unflushedSeconds == 0) return;
    // Uses the reference captured in initState rather than a context lookup,
    // so this is still safe to call while the screen is being disposed.
    _appState.addReadingSeconds(_unflushedSeconds);
    _unflushedSeconds = 0;
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

  void _recordPage(int index) {
    final content = _contentAt(index);
    final appState = context.read<AppState>();
    appState.recordAyahRead(content.surahNumber, content.ayahNumber);
    _sessionHasanat += appState.quran.hasanatForAyah(content.surahNumber, content.ayahNumber);
    if (_trackingBookmarkId != null) {
      appState.updateBookmarkPosition(_trackingBookmarkId!, content.surahNumber, content.ayahNumber);
    }
  }

  Future<void> _showDisplaySettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _DisplaySettingsSheet(),
    );
  }

  Future<void> _showSaveBookmarkSheet() async {
    final appState = context.read<AppState>();
    final content = _contentAt(_currentIndex);
    final surah = appState.quran.surahByNumber(content.surahNumber);
    final resultId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SaveBookmarkSheet(
        existingBookmarks: appState.bookmarks,
        surahNumber: content.surahNumber,
        ayahNumber: content.ayahNumber,
        positionLabel: '${surah.englishName}, ayah ${content.ayahNumber}',
      ),
    );
    if (resultId != null && mounted) {
      setState(() => _trackingBookmarkId = resultId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only a real backgrounding (home button, app switch) pauses the timer —
    // never counted while the app isn't actually in front of the user.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopTicker();
      if (_trackingBookmarkId != null) {
        final content = _contentAt(_currentIndex);
        context.read<AppState>().updateBookmarkPosition(_trackingBookmarkId!, content.surahNumber, content.ayahNumber);
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
            updatesContinuePoint: _isTracking,
            trackingBookmarkId: _trackingBookmarkId,
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

  Future<void> _toggleFavorite() async {
    final appState = context.read<AppState>();
    final content = _contentAt(_currentIndex);
    await appState.toggleFavorite(content.surahNumber, content.ayahNumber);
    if (mounted) setState(() {});
  }

  Future<void> _finishReading() async {
    final appState = context.read<AppState>();
    await showCompletionDialog(
      context,
      ayahsThisSession: _sessionAyahCount,
      ayahsToday: appState.ayahsReadToday,
      hasanatThisSession: _sessionHasanat,
    );
    if (mounted) Navigator.of(context).pop();
  }

  static String _formatElapsed(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
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
          IconButton(
            tooltip: appState.isFavorite(content.surahNumber, content.ayahNumber)
                ? 'Remove from saved verses'
                : 'Add to saved verses',
            icon: Icon(
              appState.isFavorite(content.surahNumber, content.ayahNumber) ? Icons.favorite : Icons.favorite_border,
              color: appState.isFavorite(content.surahNumber, content.ayahNumber) ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: _toggleFavorite,
          ),
          if (!_isTracking)
            IconButton(
              tooltip: 'Save this spot',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _showSaveBookmarkSheet,
            ),
          IconButton(
            tooltip: 'Jump to ayah',
            icon: const Icon(Icons.format_list_numbered_rounded),
            onPressed: _showJumpToAyahSheet,
          ),
          IconButton(
            tooltip: 'Display settings',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: _showDisplaySettingsSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _JuzProgressHeader(
                progress: juzProgress,
                sessionAyahCount: _sessionAyahCount,
                elapsed: _elapsed,
                hasanatLabel: _formatCompactHasanat(_sessionHasanat),
              ),
              Expanded(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _pageCount,
                      pageSnapping: false,
                      physics: const QuickPageScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      // Each ayah's Arabic text is expensive to lay out, and
                      // the neighbouring pages are alive during a swipe -
                      // isolating them keeps a repaint on one page from
                      // re-rasterising the others.
                      itemBuilder: (context, index) => RepaintBoundary(
                        child: _AyahPage(
                          ayah: _contentAt(index),
                          bismillahText: _showsBismillah(index) ? _bismillahText : null,
                        ),
                      ),
                    ),
                    // Tap zones over the outer edges only, so the centered
                    // translation-toggle button in _AyahPage stays reachable.
                    // behavior: translucent lets swipes on the PageView
                    // underneath keep working - only a stationary tap (no
                    // drag) is claimed here.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.22,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _currentIndex > 0 ? _goBack : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.22,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _goForward,
                      ),
                    ),
                  ],
                ),
              ),
              _NavigationBar(
                canGoBack: _currentIndex > 0,
                canGoForward: _currentIndex < _pageCount - 1 || widget.initialSurahNumber < 114,
                onBack: _goBack,
                onForward: _goForward,
                onDone: _finishReading,
                ayahHasanat: appState.quran.hasanatForAyah(content.surahNumber, content.ayahNumber),
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

/// Compact so a long session's running hasanat tally never crowds out the
/// other two chips - full precision shows up in the completion dialog
/// instead, once the session's over and there's room for it.
String _formatCompactHasanat(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${(n / 1000).round()}k';
}

class _JuzProgressHeader extends StatelessWidget {
  final JuzProgress progress;
  final int sessionAyahCount;
  final ValueListenable<Duration> elapsed;
  final String hasanatLabel;

  const _JuzProgressHeader({
    required this.progress,
    required this.sessionAyahCount,
    required this.elapsed,
    required this.hasanatLabel,
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
              _StatChip(
                icon: Icons.auto_awesome_rounded,
                label: hasanatLabel,
                tooltip: 'Hasanat: the reward for reciting the Quran - 10 for every Arabic letter, earned this session.',
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.menu_book_rounded,
                label: '$sessionAyahCount',
                tooltip: 'Verses read this session.',
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<Duration>(
                valueListenable: elapsed,
                builder: (context, value, _) => _StatChip(
                  icon: Icons.timer_outlined,
                  label: _ReadingScreenState._formatElapsed(value),
                  tooltip: 'Time spent reading this session.',
                ),
              ),
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
  final String tooltip;

  const _StatChip({required this.icon, required this.label, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            // Tabular figures give every digit the same advance width, so a
            // chip's width - and everything to its right in the row - stays
            // put as the number inside it changes. Without this the ticking
            // timer chip visibly shifted the whole row every second.
            style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
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
    final fontScale = appState.fontScale;

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
                      style: TextStyle(
                        fontFamily: appState.quranScript.fontFamily,
                        fontSize: 27 * fontScale,
                        height: 2.1,
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                      style: TextStyle(fontFamily: appState.quranScript.fontFamily, fontSize: 42 * fontScale, height: 2.2),
                    ),
                  ),
                  if (appState.showTransliteration) ...[
                    const SizedBox(height: 14),
                    // Plain text, not another bordered card - it's a
                    // pronunciation aid riding along with the Arabic above
                    // it, not a third independent block competing for
                    // attention the way the translation panel does.
                    Text(
                      ayah.transliterationText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14 * fontScale,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (appState.showTranslation) ...[
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
                        style: TextStyle(fontSize: 16 * fontScale, height: 1.6),
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
  final int ayahHasanat;

  const _NavigationBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onDone,
    required this.ayahHasanat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+$ayahHasanat',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
              ),
              const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}

/// Lets the reader adjust text size, switch the Arabic script, and hide the
/// translation panel, all without leaving the ayah they're on - the same
/// three settings live permanently in Settings, but jumping out of the
/// reading flow to change them mid-session is exactly the friction this
/// sheet avoids.
class _DisplaySettingsSheet extends StatefulWidget {
  const _DisplaySettingsSheet();

  @override
  State<_DisplaySettingsSheet> createState() => _DisplaySettingsSheetState();
}

class _DisplaySettingsSheetState extends State<_DisplaySettingsSheet> {
  static const _minScale = 0.8;
  static const _maxScale = 1.6;

  // Local so the slider tracks the finger smoothly; only committed to
  // AppState (and therefore Hive) on release, not on every drag tick.
  late double _fontScale;

  @override
  void initState() {
    super.initState();
    _fontScale = context.read<AppState>().fontScale;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Display', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
          const SizedBox(height: 20),
          Text(
            'TEXT SIZE',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant),
          ),
          Slider(
            value: _fontScale,
            min: _minScale,
            max: _maxScale,
            divisions: 8,
            label: '${(_fontScale * 100).round()}%',
            onChanged: (value) => setState(() => _fontScale = value),
            onChangeEnd: (value) => appState.setFontScale(value),
          ),
          const SizedBox(height: 8),
          Text(
            'SCRIPT',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final script in QuranScript.values) ...[
            _CompactScriptOption(
              script: script,
              selected: appState.quranScript == script,
              onTap: () => appState.setScript(script),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Show translation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
              ),
              Switch(value: appState.showTranslation, onChanged: appState.setShowTranslation),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Show transliteration',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
              ),
              Switch(value: appState.showTransliteration, onChanged: appState.setShowTransliteration),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactScriptOption extends StatelessWidget {
  final QuranScript script;
  final bool selected;
  final VoidCallback onTap;

  const _CompactScriptOption({required this.script, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Expanded(child: Text(script.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
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

/// Lets the reader either create a new named bookmark at the current ayah,
/// or move an existing one here — and optionally make the result the
/// bookmark shown on the home screen. Pops with the resulting bookmark's id
/// so the reading screen can pick up auto-tracking it going forward.
class _SaveBookmarkSheet extends StatefulWidget {
  final List<Bookmark> existingBookmarks;
  final int surahNumber;
  final int ayahNumber;
  final String positionLabel;

  const _SaveBookmarkSheet({
    required this.existingBookmarks,
    required this.surahNumber,
    required this.ayahNumber,
    required this.positionLabel,
  });

  @override
  State<_SaveBookmarkSheet> createState() => _SaveBookmarkSheetState();
}

class _SaveBookmarkSheetState extends State<_SaveBookmarkSheet> {
  static const _newBookmarkChoice = '__new__';

  late String _selected;
  late final TextEditingController _nameController;
  late bool _makeDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = _newBookmarkChoice;
    _nameController = TextEditingController();
    _makeDefault = widget.existingBookmarks.isEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _selectedIsAlreadyDefault {
    if (_selected == _newBookmarkChoice) return false;
    return widget.existingBookmarks.firstWhere((b) => b.id == _selected).isDefault;
  }

  bool get _canSave => _selected != _newBookmarkChoice || _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    final appState = context.read<AppState>();
    String bookmarkId;
    if (_selected == _newBookmarkChoice) {
      final bookmark = await appState.createBookmark(
        name: _nameController.text.trim(),
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
        isDefault: _makeDefault,
      );
      bookmarkId = bookmark.id;
    } else {
      await appState.updateBookmarkPosition(_selected, widget.surahNumber, widget.ayahNumber);
      if (_makeDefault) await appState.setDefaultBookmark(_selected);
      bookmarkId = _selected;
    }
    if (mounted) Navigator.of(context).pop(bookmarkId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Save this spot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(widget.positionLabel, style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          _BookmarkChoiceCard(
            selected: _selected == _newBookmarkChoice,
            onTap: () => setState(() => _selected = _newBookmarkChoice),
            icon: Icons.add_rounded,
            title: 'New bookmark',
            child: _selected == _newBookmarkChoice
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Work, With the kids',
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  )
                : null,
          ),
          if (widget.existingBookmarks.isNotEmpty) const SizedBox(height: 10),
          for (final bookmark in widget.existingBookmarks) ...[
            _BookmarkChoiceCard(
              selected: _selected == bookmark.id,
              onTap: () => setState(() => _selected = bookmark.id),
              icon: bookmark.isDefault ? Icons.home_rounded : Icons.bookmark_outline_rounded,
              title: bookmark.name,
              subtitle: 'Move here, from Surah ${bookmark.surahNumber}, ayah ${bookmark.ayahNumber}',
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _makeDefault || _selectedIsAlreadyDefault,
            onChanged: _selectedIsAlreadyDefault ? null : (value) => setState(() => _makeDefault = value),
            title: const Text('Show on home screen'),
            subtitle: Text(
              _selectedIsAlreadyDefault ? "This is already your home screen bookmark" : 'Replaces your current home screen bookmark',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            activeThumbColor: colorScheme.primary,
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
              onPressed: _canSave && !_saving ? _save : null,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.surface),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkChoiceCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? child;

  const _BookmarkChoiceCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
              ?child,
            ],
          ),
        ),
      ),
    );
  }
}
