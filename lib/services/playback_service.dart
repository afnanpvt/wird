import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ayah.dart';
import '../models/reciter.dart';

enum VerseAudioStatus { idle, loading, playing, error }

/// Which single ayah (if any) is loading/playing/erroring via
/// [PlaybackService.playVerse] - the reading screen's tap-to-play-one-verse
/// mode. Mutually exclusive with continuous Surah playback below.
class VerseAudioState {
  final int? surahNumber;
  final int? ayahNumber;
  final VerseAudioStatus status;

  const VerseAudioState({this.surahNumber, this.ayahNumber, this.status = VerseAudioStatus.idle});

  bool isFor(int surahNumber, int ayahNumber) => this.surahNumber == surahNumber && this.ayahNumber == ayahNumber;

  static const idle = VerseAudioState();
}

enum SurahPlaybackStatus { idle, loading, playing, paused, error }

/// Which surah (if any) is queued for continuous listening, and where in it.
class SurahPlaybackState {
  final int? surahNumber;
  final String? surahName;
  final int ayahCount;
  final int currentAyahIndex;
  final SurahPlaybackStatus status;

  const SurahPlaybackState({
    this.surahNumber,
    this.surahName,
    this.ayahCount = 0,
    this.currentAyahIndex = 0,
    this.status = SurahPlaybackStatus.idle,
  });

  bool get isActive => surahNumber != null;

  int get currentAyahNumber => currentAyahIndex + 1;

  SurahPlaybackState copyWith({int? currentAyahIndex, SurahPlaybackStatus? status}) => SurahPlaybackState(
        surahNumber: surahNumber,
        surahName: surahName,
        ayahCount: ayahCount,
        currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
        status: status ?? this.status,
      );

  static const idle = SurahPlaybackState();
}

enum _Mode { none, verse, surah }

/// The single shared audio engine for the whole app.
///
/// just_audio_background allows exactly one live [AudioPlayer] per process -
/// a second instance throws "just_audio_background supports only a single
/// player instance" - so this is the one and only player, used both for the
/// reading screen's tap-to-play-one-verse and for continuous "listen to this
/// Surah" playback. The two modes are mutually exclusive: starting one always
/// stops the other first.
class PlaybackService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  _Mode _mode = _Mode.none;
  int _requestId = 0;

  final ValueNotifier<VerseAudioState> verseState = ValueNotifier(VerseAudioState.idle);
  SurahPlaybackState surahState = SurahPlaybackState.idle;

  /// Wired once by [RootScreen] so a finished Surah can advance into the
  /// next one on its own, without this service needing to know about
  /// QuranRepository or the reciter setting itself.
  Future<void> Function(int surahNumber)? _playNextSurah;

  PlaybackService() {
    _player.playerStateStream.listen(_onPlayerState);
    _player.currentIndexStream.listen(_onCurrentIndex);
  }

  AudioPlayer get player => _player;

  void configureAutoAdvance(Future<void> Function(int surahNumber) playNextSurah) {
    _playNextSurah = playNextSurah;
  }

  /// Cover shown in the lock-screen/notification media player. There's no
  /// per-Surah artwork, so this is just the app's own square mark - still
  /// much better than the blank/generic icon a null [MediaItem.artUri]
  /// leaves behind. `MediaItem.artUri` needs a real file on disk (a `file://`
  /// URI is the only scheme audio_service resolves without a network round
  /// trip - see its `_loadArtwork`), so the bundled asset is copied out to
  /// the temp directory once and reused for every track after that.
  Future<Uri>? _artUriFuture;

  Future<Uri> _resolveArtUri() {
    return _artUriFuture ??= () async {
      final bytes = await rootBundle.load('assets/images/icon.png');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wird_cover.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), flush: true);
      return Uri.file(file.path);
    }();
  }

  void _onPlayerState(PlayerState state) {
    if (_mode == _Mode.verse) {
      final current = verseState.value;
      if (current.status == VerseAudioStatus.idle || current.status == VerseAudioStatus.error) return;
      if (state.processingState == ProcessingState.completed) {
        _mode = _Mode.none;
        verseState.value = VerseAudioState.idle;
      } else if (state.playing && current.status != VerseAudioStatus.playing) {
        verseState.value = VerseAudioState(surahNumber: current.surahNumber, ayahNumber: current.ayahNumber, status: VerseAudioStatus.playing);
      }
    } else if (_mode == _Mode.surah) {
      if (!surahState.isActive) return;
      final processing = state.processingState;
      if (processing == ProcessingState.completed) {
        _advanceToNextSurah();
        return;
      }
      final status = switch (processing) {
        ProcessingState.loading || ProcessingState.buffering => SurahPlaybackStatus.loading,
        _ => state.playing ? SurahPlaybackStatus.playing : SurahPlaybackStatus.paused,
      };
      if (status != surahState.status) {
        surahState = surahState.copyWith(status: status);
        notifyListeners();
      }
    }
  }

  void _onCurrentIndex(int? index) {
    if (_mode != _Mode.surah || index == null || !surahState.isActive) return;
    if (index != surahState.currentAyahIndex) {
      surahState = surahState.copyWith(currentAyahIndex: index);
      notifyListeners();
    }
  }

  /// Tapping the verse that's currently loading or playing stops it - single
  /// verse, no auto-continue, matching the reading screen's original design.
  Future<void> playVerse({required int surahNumber, required int ayahNumber, required String url, required String surahName}) async {
    if (_mode == _Mode.verse && verseState.value.isFor(surahNumber, ayahNumber) && verseState.value.status != VerseAudioStatus.error) {
      stopVerse();
      return;
    }
    stopSurah();
    _mode = _Mode.verse;
    final requestId = ++_requestId;
    verseState.value = VerseAudioState(surahNumber: surahNumber, ayahNumber: ayahNumber, status: VerseAudioStatus.loading);
    try {
      final artUri = await _resolveArtUri();
      if (requestId != _requestId) return;
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(id: '$surahNumber:$ayahNumber', title: 'Ayah $ayahNumber', album: surahName, artUri: artUri),
      ));
      if (requestId != _requestId) return;
      await _player.play();
    } catch (_) {
      if (requestId != _requestId) return;
      verseState.value = VerseAudioState(surahNumber: surahNumber, ayahNumber: ayahNumber, status: VerseAudioStatus.error);
    }
  }

  void stopVerse() {
    _requestId++;
    if (_mode != _Mode.verse) return;
    _mode = _Mode.none;
    _player.stop();
    verseState.value = VerseAudioState.idle;
  }

  /// Starts continuous playback through every ayah of [surahNumber] in
  /// order, auto-advancing into the next Surah when this one finishes (via
  /// [configureAutoAdvance]) - the "listen" counterpart to the reading
  /// screen's tap-one-verse mode.
  Future<void> playSurah({
    required int surahNumber,
    required String surahName,
    required List<Ayah> ayahs,
    required Reciter reciter,
    int startAyahIndex = 0,
  }) async {
    if (ayahs.isEmpty) return;
    stopVerse();
    _requestId++;
    _mode = _Mode.surah;
    surahState = SurahPlaybackState(
      surahNumber: surahNumber,
      surahName: surahName,
      ayahCount: ayahs.length,
      currentAyahIndex: startAyahIndex,
      status: SurahPlaybackStatus.loading,
    );
    notifyListeners();

    final artUri = await _resolveArtUri();
    if (_mode != _Mode.surah || surahState.surahNumber != surahNumber) return;
    final playlist = [
      for (final ayah in ayahs)
        AudioSource.uri(
          Uri.parse(reciter.audioUrlFor(ayah.surahNumber, ayah.ayahNumber)),
          tag: MediaItem(
            id: '${ayah.surahNumber}:${ayah.ayahNumber}',
            title: 'Ayah ${ayah.ayahNumber}',
            album: surahName,
            artist: reciter.displayName,
            artUri: artUri,
          ),
        ),
    ];
    try {
      await _player.setAudioSources(playlist, initialIndex: startAyahIndex);
      if (_mode != _Mode.surah || surahState.surahNumber != surahNumber) return;
      await _player.play();
    } catch (_) {
      if (_mode != _Mode.surah || surahState.surahNumber != surahNumber) return;
      surahState = surahState.copyWith(status: SurahPlaybackStatus.error);
      notifyListeners();
    }
  }

  void togglePlayPause() {
    if (_mode != _Mode.surah) return;
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void seekToAyahIndex(int index) {
    if (_mode != _Mode.surah) return;
    _player.seek(Duration.zero, index: index);
  }

  void stopSurah() {
    if (_mode != _Mode.surah) return;
    _mode = _Mode.none;
    _player.stop();
    surahState = SurahPlaybackState.idle;
    notifyListeners();
  }

  Future<void> _advanceToNextSurah() async {
    final current = surahState.surahNumber;
    final next = _playNextSurah;
    if (current == null || next == null || current >= 114) {
      stopSurah();
      return;
    }
    await next(current + 1);
  }

  @override
  void dispose() {
    verseState.dispose();
    _player.dispose();
    super.dispose();
  }
}
