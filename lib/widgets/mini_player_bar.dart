import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/now_playing_screen.dart';
import '../services/playback_service.dart';

/// Persistent bar above the bottom nav, visible on every tab while a Surah
/// is playing continuously - mirrors Spotify's mini-player. Renders nothing
/// when no Surah is queued, so [RootScreen] can always include it.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackService>();
    final state = playback.surahState;
    if (!state.isActive) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = state.status == SurahPlaybackStatus.loading;
    final isPlaying = state.status == SurahPlaybackStatus.playing;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressLine(playback: playback),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: colorScheme.onSurface, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${state.surahNumber}',
                      style: TextStyle(color: colorScheme.surface, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.surahName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          'Ayah ${state.currentAyahNumber} of ${state.ayahCount}',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    icon: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    onPressed: playback.togglePlayPause,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final PlaybackService playback;

  const _ProgressLine({required this.playback});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration?>(
      stream: playback.player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data;
        return StreamBuilder<Duration>(
          stream: playback.player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final value = (duration == null || duration.inMilliseconds == 0)
                ? 0.0
                : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
            return LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: colorScheme.outlineVariant,
              color: colorScheme.primary,
            );
          },
        );
      },
    );
  }
}
