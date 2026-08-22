import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quran_script.dart';
import '../services/app_state.dart';
import '../services/playback_service.dart';
import '../screens/reading_screen.dart';

/// Lowercases and strips everything but letters/digits, so "Al-Baqara",
/// "al baqara" and "ALBAQARA" all compare equal - the transliterated names
/// in the data use hyphens and capitalization inconsistently enough that a
/// literal substring match would miss obvious hits.
String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _matchesQuery(String query, {required int number, required List<String> names}) {
  if (query.isEmpty) return true;
  if (number.toString().startsWith(query.trim())) return true;
  final normalizedQuery = _normalize(query);
  return names.any((name) => _normalize(name).contains(normalizedQuery));
}

/// "Juz 1" for a surah wholly inside one Juz, "Juz 1-3" for one spanning several.
String _juzRangeLabel(List<int> juzNumbers) {
  if (juzNumbers.length == 1) return 'Juz ${juzNumbers.first}';
  return 'Juz ${juzNumbers.first}-${juzNumbers.last}';
}

/// Every surah, each row playable in place via [PlaybackService] - shared
/// between Browse's Surah tab and the standalone Listen tab so the two never
/// drift out of sync with each other.
///
/// The one difference between those two callers is what tapping a row does,
/// controlled by [tapToListen]: Browse is for reading, so a tap opens the
/// Reading screen and a dedicated play button starts the recitation. Listen
/// is for listening, so there's no separate button to hit - the whole row
/// is the play/pause target, matching what a reader is actually there to do.
class SurahListView extends StatelessWidget {
  final String query;
  final bool tapToListen;

  const SurahListView({super.key, required this.query, this.tapToListen = false});

  @override
  Widget build(BuildContext context) {
    final quran = context.read<AppState>().quran;
    final allSurahs = quran.surahs;
    final fontFamily = context.watch<AppState>().quranScript.fontFamily;
    final colorScheme = Theme.of(context).colorScheme;

    final surahs = allSurahs
        .where((s) => _matchesQuery(query, number: s.number, names: [s.name, s.englishName]))
        .toList();

    if (surahs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No matches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final surah = surahs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: SizedBox(
            width: 32,
            child: Text('${surah.number}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          title: Text(surah.englishName, style: const TextStyle(fontWeight: FontWeight.w500)),
          // Always exactly two lines (rather than one long line that wraps
          // unpredictably) so every row is the same height - otherwise the
          // vertically-centered trailing play button/Arabic name drift up or
          // down row to row depending on whether that row's text happened
          // to wrap.
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${surah.name} · ${surah.ayahCount} ayahs'),
              Text(_juzRangeLabel(quran.juzNumbersForSurah(surah.number))),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<PlaybackService>(
                builder: (context, playback, _) {
                  final isThisSurah = playback.surahState.surahNumber == surah.number;
                  final isPlaying = isThisSurah && playback.surahState.status == SurahPlaybackStatus.playing;
                  final isLoading = isThisSurah && playback.surahState.status == SurahPlaybackStatus.loading;
                  // In Listen, the row itself is already the play/pause
                  // target - a second, separately-tappable button here
                  // would be redundant, so this is just a status glyph
                  // (not wrapped in IconButton) rather than its own control.
                  if (tapToListen) {
                    return SizedBox(
                      width: 32,
                      height: 32,
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : isThisSurah
                              ? Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
                                  color: colorScheme.primary)
                              : null,
                    );
                  }
                  return IconButton(
                    tooltip: isPlaying ? 'Pause' : 'Listen to this Surah',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
                            color: isThisSurah ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                    onPressed: () => isThisSurah
                        ? playback.togglePlayPause()
                        : context.read<AppState>().playSurah(playback, surah.number),
                  );
                },
              ),
              const SizedBox(width: 10),
              // Fixed width, not just natural text width: Arabic surah names
              // render at very different pixel widths from one another, and
              // without this the play button to their left would drift left
              // or right row to row by however much shorter or longer the
              // next name happened to be.
              SizedBox(
                width: 76,
                child: Text(
                  surah.arabicName,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: fontFamily, fontSize: 18, height: 1.8),
                ),
              ),
            ],
          ),
          onTap: tapToListen
              ? () {
                  final playback = context.read<PlaybackService>();
                  final isThisSurah = playback.surahState.surahNumber == surah.number;
                  if (isThisSurah) {
                    playback.togglePlayPause();
                  } else {
                    context.read<AppState>().playSurah(playback, surah.number);
                  }
                }
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReadingScreen(
                        initialSurahNumber: surah.number,
                        initialAyahNumber: 1,
                        updatesContinuePoint: false,
                      ),
                    ),
                  ),
        );
      },
    );
  }
}
