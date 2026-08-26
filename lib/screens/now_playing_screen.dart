import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../services/playback_service.dart';
import '../widgets/listening_ambient.dart';

/// Full-screen "listening" view for continuous Surah playback - the
/// counterpart to [MiniPlayerBar], expanded. Shows the current ayah's
/// Arabic/translation synced to playback, a seek bar, and transport
/// controls (previous/next ayah; Surah boundaries are crossed automatically
/// by [PlaybackService]'s auto-advance).
///
/// The whole screen sits on [ListeningAmbient] - slow drifting glows that
/// brighten while playing and settle while paused. The app bar and body are
/// transparent over it; the ambient widget's own scrim keeps both edges calm.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = context.watch<AppState>();
    final playback = context.watch<PlaybackService>();
    final state = playback.surahState;

    if (!state.isActive) {
      // The Surah finished or was stopped while this screen was open (e.g.
      // reaching the end of Surah 114) - nothing left to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final ayahs = appState.quran.ayahsForSurah(state.surahNumber!);
    final ayah = ayahs[state.currentAyahIndex.clamp(0, ayahs.length - 1)];
    final isLoading = state.status == SurahPlaybackStatus.loading;
    final isPlaying = state.status == SurahPlaybackStatus.playing;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(state.surahName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // RepaintBoundary keeps every frame of the drifting glows inside
            // this layer - the text column above never rebuilds for them.
            child: RepaintBoundary(child: ListeningAmbient(playing: isPlaying)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Column(
                            key: ValueKey('ayah-${state.currentAyahIndex}'),
                            children: [
                              Text(
                                ayah.arabicText,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: appState.quranScript.fontFamily, fontSize: 32, height: 2.0),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                appState.useSimpleTranslation ? ayah.simpleEnglishText : ayah.englishText,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, height: 1.5, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Ayah ${state.currentAyahNumber} of ${state.ayahCount}',
                    style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  _SeekBar(playback: playback),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Previous Surah',
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: state.surahNumber! > 1 ? () => playback.skipToSurah(state.surahNumber! - 1) : null,
                      ),
                      IconButton(
                        iconSize: 32,
                        tooltip: 'Previous ayah',
                        icon: const Icon(Icons.navigate_before_rounded),
                        onPressed: state.currentAyahIndex > 0
                            ? () => playback.seekToAyahIndex(state.currentAyahIndex - 1)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _LoadingRipple(
                        loading: isLoading,
                        color: colorScheme.primary,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: colorScheme.onSurface, shape: BoxShape.circle),
                          child: IconButton(
                            icon: isLoading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.surface),
                                  )
                                : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: colorScheme.surface, size: 30),
                            onPressed: playback.togglePlayPause,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 32,
                        tooltip: 'Next ayah',
                        icon: const Icon(Icons.navigate_next_rounded),
                        onPressed: state.currentAyahIndex < state.ayahCount - 1
                            ? () => playback.seekToAyahIndex(state.currentAyahIndex + 1)
                            : null,
                      ),
                      IconButton(
                        tooltip: 'Next Surah',
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: state.surahNumber! < 114 ? () => playback.skipToSurah(state.surahNumber! + 1) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => playback.setLoopCurrentAyah(!playback.loopCurrentAyah),
                    icon: Icon(
                      Icons.repeat_one_rounded,
                      size: 18,
                      color: playback.loopCurrentAyah ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      'Repeat this ayah',
                      style: TextStyle(color: playback.loopCurrentAyah ? colorScheme.primary : colorScheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: playback.stopSurah,
                    child: Text('Stop listening', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expanding ripple ring behind the play button while recitation is buffering
/// - a quiet "working on it" pulse rather than a spinner doing all the work.
/// The ring grows and fades on repeat while [loading]; removed entirely under
/// the system reduce-motion setting.
class _LoadingRipple extends StatefulWidget {
  const _LoadingRipple({required this.loading, required this.color, required this.child});

  final bool loading;
  final Color color;
  final Widget child;

  @override
  State<_LoadingRipple> createState() => _LoadingRippleState();
}

class _LoadingRippleState extends State<_LoadingRipple> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.loading) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _LoadingRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) return;
    if (widget.loading) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (widget.loading && !reduceMotion)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_controller.value);
              return Container(
                width: 60 + 34 * t,
                height: 60 + 34 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color.withValues(alpha: (1 - t) * 0.35), width: 2),
                ),
              );
            },
          ),
        widget.child,
      ],
    );
  }
}

class _SeekBar extends StatelessWidget {
  final PlaybackService playback;

  const _SeekBar({required this.playback});

  String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(1, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration?>(
      stream: playback.player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: playback.player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMs = duration.inMilliseconds.toDouble();
            final valueMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs <= 0 ? 1.0 : maxMs);
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 3),
                  child: Slider(
                    value: maxMs <= 0 ? 0.0 : valueMs,
                    max: maxMs <= 0 ? 1.0 : maxMs,
                    onChanged: maxMs <= 0 ? null : (v) => playback.player.seek(Duration(milliseconds: v.round())),
                    activeColor: colorScheme.onSurface,
                    inactiveColor: colorScheme.outlineVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(position), style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      Text(_format(duration), style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
