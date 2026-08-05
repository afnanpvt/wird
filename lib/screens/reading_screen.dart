import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ayah.dart';
import '../models/juz_progress.dart';
import '../models/reading_progress.dart';
import '../services/app_state.dart';
import '../widgets/completion_dialog.dart';

/// Surahs that traditionally omit the opening Bismillah (only At-Tawbah).
const _surahsWithoutBismillah = {9};

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

class _ReadingScreenState extends State<ReadingScreen> with WidgetsBindingObserver {
  late final List<Ayah> _ayahs;
  late final bool _hasBismillah;
  late final Ayah _bismillah;
  late final PageController _pageController;
  late int _currentIndex;
  int _sessionAyahCount = 0;

  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  int get _pageCount => _ayahs.length + (_hasBismillah ? 1 : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final quran = context.read<AppState>().quran;
    _ayahs = quran.ayahsForSurah(widget.initialSurahNumber);
    _hasBismillah = widget.initialSurahNumber != 1 && !_surahsWithoutBismillah.contains(widget.initialSurahNumber);
    _bismillah = quran.ayahsForSurah(1).first;

    final startAyahIndex = (widget.initialAyahNumber - 1).clamp(0, _ayahs.length - 1);
    _currentIndex = _hasBismillah && widget.initialAyahNumber <= 1 ? 0 : startAyahIndex + (_hasBismillah ? 1 : 0);
    _pageController = PageController(initialPage: _currentIndex);
    _sessionAyahCount = 1;
    _elapsed = Duration(seconds: context.read<AppState>().totalReadingSeconds);
    _recordPage(_currentIndex);
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

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

  bool _isBismillahPage(int index) => _hasBismillah && index == 0;

  Ayah _contentAt(int index) => _isBismillahPage(index) ? _bismillah : _ayahs[_hasBismillah ? index - 1 : index];

  int _ayahNumberForDisplay(int index) => _hasBismillah ? index : index + 1;

  ReadingProgress _resumePositionAt(int index) => ReadingProgress(
        surahNumber: widget.initialSurahNumber,
        ayahNumber: _isBismillahPage(index) ? 1 : (_hasBismillah ? index : index + 1),
      );

  void _recordPage(int index) {
    final content = _contentAt(index);
    final appState = context.read<AppState>();
    appState.recordAyahRead(content.surahNumber, content.ayahNumber);
    if (widget.updatesContinuePoint) {
      appState.saveLastPosition(_resumePositionAt(index));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only a real backgrounding (home button, app switch) pauses the timer —
    // never counted while the app isn't actually in front of the user.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopTicker();
      if (widget.updatesContinuePoint) {
        context.read<AppState>().saveLastPosition(_resumePositionAt(_currentIndex));
      }
    } else if (state == AppLifecycleState.resumed) {
      _startTicker();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _sessionAyahCount++;
    _recordPage(index);
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
      Navigator.of(context).push(_surahTransitionRoute(
        ReadingScreen(
          initialSurahNumber: widget.initialSurahNumber + 1,
          initialAyahNumber: 1,
          updatesContinuePoint: widget.updatesContinuePoint,
        ),
      ));
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
    final onBismillah = _isBismillahPage(_currentIndex);
    final content = _contentAt(_currentIndex);
    final juzProgress = appState.quran.juzProgressFor(content.surahNumber, content.ayahNumber);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          onBismillah
              ? surah.englishName
              : '${surah.englishName} · ${_ayahNumberForDisplay(_currentIndex)}/${_ayahs.length}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _JuzProgressHeader(progress: juzProgress, sessionAyahCount: _sessionAyahCount, elapsedLabel: _elapsedLabel),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _AyahPage(ayah: _contentAt(index)),
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

class _AyahPage extends StatelessWidget {
  final Ayah ayah;

  const _AyahPage({required this.ayah});

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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      ayah.arabicText,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'QuranNaskh', fontSize: 32, height: 1.9),
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
