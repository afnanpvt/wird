import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../services/playback_service.dart';

/// Full-screen "listening" view for continuous Surah playback - the
/// counterpart to [MiniPlayerBar], expanded. Shows the current ayah's
/// Arabic/translation synced to playback, a seek bar, and transport
/// controls (previous/next ayah; Surah boundaries are crossed automatically
/// by [PlaybackService]'s auto-advance).
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
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(state.surahName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
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
                  Container(
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
