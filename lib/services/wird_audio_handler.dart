import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'playback_service.dart';

/// Bridges [PlaybackService]'s shared player to the OS media session - the
/// lock screen, the notification, and headset/Bluetooth buttons.
///
/// This exists specifically so the previous/next controls there can skip a
/// whole Surah instead of one ayah. `just_audio_background` (used earlier)
/// hard-wires those controls to the ayah queue with no way to override them;
/// writing this handler by hand is what makes them redirectable to
/// [PlaybackService.skipToSurah] instead. Everything else it does - play,
/// pause, seek, the notification itself staying up as a foreground service -
/// is the same job `audio_service` was already doing underneath that plugin.
class WirdAudioHandler extends BaseAudioHandler {
  final PlaybackService _playback;

  WirdAudioHandler(this._playback) {
    _playback.player.playbackEventStream.listen((_) => _broadcastPlaybackState());
    _playback.addListener(_onChanged);
    _playback.verseState.addListener(_onChanged);
    _onChanged();
  }

  void _onChanged() {
    unawaited(_updateMediaItem());
    _broadcastPlaybackState();
  }

  Future<void> _updateMediaItem() async {
    final surah = _playback.surahState;
    final verse = _playback.verseState.value;

    if (surah.isActive) {
      mediaItem.add(MediaItem(
        id: 'surah:${surah.surahNumber}',
        // The Surah name, not the ayah number, is the title - it's what
        // changes when playback crosses into the next Surah, which is the
        // thing worth announcing on the lock screen.
        title: surah.surahName ?? '',
        artist: surah.reciterName,
        album: 'Ayah ${surah.currentAyahNumber} of ${surah.ayahCount}',
        artUri: await _playback.resolveArtUri(),
      ));
    } else if (verse.status != VerseAudioStatus.idle && verse.surahNumber != null) {
      mediaItem.add(MediaItem(
        id: 'verse:${verse.surahNumber}:${verse.ayahNumber}',
        title: 'Ayah ${verse.ayahNumber}',
        album: verse.surahName,
        artUri: await _playback.resolveArtUri(),
      ));
    }
  }

  void _broadcastPlaybackState() {
    final player = _playback.player;
    final surah = _playback.surahState;
    final hasPrevious = surah.isActive && surah.surahNumber! > 1;
    final hasNext = surah.isActive && surah.surahNumber! < 114;

    final controls = [
      if (hasPrevious) MediaControl.skipToPrevious,
      if (player.playing) MediaControl.pause else MediaControl.play,
      if (hasNext) MediaControl.skipToNext,
    ];

    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      systemActions: {
        MediaAction.seek,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
        if (hasPrevious) MediaAction.skipToPrevious,
        if (hasNext) MediaAction.skipToNext,
      },
      androidCompactActionIndices: List.generate(controls.length, (i) => i),
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      speed: player.speed,
    ));
  }

  @override
  Future<void> play() => _playback.player.play();

  @override
  Future<void> pause() => _playback.player.pause();

  @override
  Future<void> seek(Duration position) => _playback.player.seek(position);

  @override
  Future<void> stop() async {
    await _playback.player.stop();
    await super.stop();
  }

  // The whole point of this handler: these jump a full Surah, via the same
  // callback the in-app Now Playing screen's Surah buttons use, rather than
  // moving one ayah at a time through the current Surah's queue.
  @override
  Future<void> skipToNext() => _playback.skipToSurah((_playback.surahState.surahNumber ?? 0) + 1);

  @override
  Future<void> skipToPrevious() => _playback.skipToSurah((_playback.surahState.surahNumber ?? 0) - 1);
}
