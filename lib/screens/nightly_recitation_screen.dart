import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ayah.dart';
import '../models/quran_script.dart';
import '../services/app_state.dart';

class _NightlyStep {
  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final String label;
  final String source;
  const _NightlyStep({
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
    required this.label,
    required this.source,
  });
}

// The five authentically-established nightly recitations (see the
// hadith research behind the home screen's card) - shown in one guided
// sequence rather than five separate reading-screen trips, since the
// point is to move through all five in one sitting, one Next tap at a
// time, with a sense of visible progress.
const _steps = [
  _NightlyStep(surahNumber: 2, fromAyah: 255, toAyah: 255, label: 'Ayat al-Kursi', source: 'Sahih al-Bukhari 2311'),
  _NightlyStep(surahNumber: 2, fromAyah: 285, toAyah: 286, label: "Al-Baqarah's last two verses", source: 'Sahih al-Bukhari 5051, Sahih Muslim 807'),
  _NightlyStep(surahNumber: 112, fromAyah: 1, toAyah: 4, label: 'Al-Ikhlas', source: 'Sahih al-Bukhari 5017'),
  _NightlyStep(surahNumber: 113, fromAyah: 1, toAyah: 5, label: 'Al-Falaq', source: 'Sahih al-Bukhari 5017'),
  _NightlyStep(surahNumber: 114, fromAyah: 1, toAyah: 6, label: 'An-Nas', source: 'Sahih al-Bukhari 5017'),
  _NightlyStep(surahNumber: 109, fromAyah: 1, toAyah: 6, label: 'Al-Kafirun', source: "Abu Dawud 5055, Jami' at-Tirmidhi 3403"),
  _NightlyStep(surahNumber: 67, fromAyah: 1, toAyah: 30, label: 'Al-Mulk', source: "Sunan an-Nasa'i, hasan"),
];

/// One guided pass through all seven nightly recitation steps (the three
/// Quls count as three, since each is its own surah) - a stepper, not
/// five separate ReadingScreen sessions. Deliberately doesn't touch the
/// continue-reading bookmark; this is its own short, self-contained
/// sitting, not "where you're up to" in the Quran.
class NightlyRecitationScreen extends StatefulWidget {
  const NightlyRecitationScreen({super.key});

  @override
  State<NightlyRecitationScreen> createState() => _NightlyRecitationScreenState();
}

class _NightlyRecitationScreenState extends State<NightlyRecitationScreen> {
  final _pageController = PageController();
  late final ConfettiController _confettiController;
  int _step = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _steps.length - 1) {
      setState(() => _finished = true);
      _confettiController.play();
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Tonight')),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: _finished
                ? _CompletionView(onDone: () => Navigator.of(context).pop())
                : Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 4,
                              width: i == _step ? 24 : 14,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i <= _step ? colorScheme.primary : colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_step + 1} of ${_steps.length}',
                        style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [for (final step in _steps) _StepView(step: step)],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Row(
                          children: [
                            if (_step > 0)
                              IconButton(
                                onPressed: _back,
                                icon: const Icon(Icons.arrow_back_rounded),
                                style: IconButton.styleFrom(backgroundColor: colorScheme.surfaceContainerLow),
                              ),
                            if (_step > 0) const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.onSurface,
                                  foregroundColor: colorScheme.surface,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: _next,
                                child: Text(_step == _steps.length - 1 ? 'Finish' : 'Next'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 1.5708,
              maxBlastForce: 6,
              minBlastForce: 3,
              emissionFrequency: 0.06,
              numberOfParticles: 16,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final _NightlyStep step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    final surah = appState.quran.surahByNumber(step.surahNumber);
    final allAyahs = appState.quran.ayahsForSurah(step.surahNumber);
    final ayahs = allAyahs.where((a) => a.ayahNumber >= step.fromAyah && a.ayahNumber <= step.toAyah).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(step.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${surah.number} ${surah.englishName} · ${step.source}',
            style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          for (final ayah in ayahs) _AyahBlock(ayah: ayah),
        ],
      ),
    );
  }
}

class _AyahBlock extends StatelessWidget {
  final Ayah ayah;
  const _AyahBlock({required this.ayah});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ayah.arabicText,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: appState.quranScript.fontFamily,
              fontSize: 26 * appState.fontScale,
              height: 1.9,
            ),
          ),
          if (appState.showTranslation) ...[
            const SizedBox(height: 10),
            Text(
              ayah.englishText,
              style: TextStyle(fontSize: 14.5 * appState.fontScale, height: 1.5, color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (appState.showTransliteration) ...[
            const SizedBox(height: 6),
            Text(
              ayah.transliterationText,
              style: TextStyle(fontSize: 13 * appState.fontScale, height: 1.5, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  final VoidCallback onDone;
  const _CompletionView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.nightlight_rounded, size: 44, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Well done',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Text(
            "You've made it through tonight's recitations. Sleep well.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
