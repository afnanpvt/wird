import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wird/models/quran_script.dart';

Future<List<Map<String, dynamic>>> _loadAyahs(String path) async {
  final decoded = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  return (decoded['quran'] as List<dynamic>).cast<Map<String, dynamic>>();
}

/// Ayahs carry a trailing ayah-end ornament: U+06DF, optionally a waqf mark,
/// then a U+F5xx codepoint drawing the ayah number. Previews drop it, the same
/// way the Bismillah at the head of a surah does.
String _withoutAyahEndOrnament(String text) {
  final i = text.lastIndexOf('۟');
  return i == -1 ? text : text.substring(0, i).trimRight();
}

void main() {
  test('opening ayah in the Indo-Pak asset is stored as readable Arabic text', () async {
    final verses = await _loadAyahs('assets/data/quran_ar_indopak.json');
    final firstAyah = verses.first;
    final text = firstAyah['text'] as String;

    expect(firstAyah['chapter'], 1);
    expect(firstAyah['verse'], 1);
    expect(text, isNot(contains('Ã')));
    expect(RegExp(r'[؀-ۿ]').hasMatch(text), isTrue);
    expect(text, contains('اللّٰه'));
  });

  test('every script previews its own real Bismillah, not an approximation', () async {
    for (final script in QuranScript.values) {
      final verses = await _loadAyahs(script.dataAsset);
      final bismillah = _withoutAyahEndOrnament(verses.first['text'] as String);
      expect(
        script.previewText,
        bismillah,
        reason: '${script.displayName} preview has drifted from ${script.dataAsset}. '
            'Copy the asset text verbatim rather than editing the preview by hand.',
      );
    }
  });

  test('Indo-Pak text keeps its iqlab marks', () async {
    // U+F65D is the iqlab meem in this font-locked text: the small meem over a
    // nun-sukun or tanween followed by a ba. A previous import stripped all
    // Private-Use codepoints as "ornaments" and silently deleted every one of
    // these, changing how those ayahs are pronounced. See DESIGN.md.
    const iqlab = '';
    final verses = await _loadAyahs('assets/data/quran_ar_indopak.json');

    final total = verses.fold<int>(
      0,
      (n, v) => n + iqlab.allMatches(v['text'] as String).length,
    );
    expect(total, 277, reason: 'expected 277 iqlab marks across the Indo-Pak text');

    // 7:17 is the ayah that surfaced the bug: "mim baini", not "min baini".
    final ayah = verses.firstWhere((v) => v['chapter'] == 7 && v['verse'] == 17);
    expect(ayah['text'], contains('نْ$iqlab'));

    // No word-final nun-sukun followed by a word starting with ba may lack it.
    var missing = 0;
    for (final v in verses) {
      final words = (v['text'] as String).split(' ');
      for (var i = 0; i < words.length - 1; i++) {
        if (!words[i + 1].startsWith('ب')) continue;
        if (words[i].endsWith('نْ')) missing++;
      }
    }
    expect(missing, 0, reason: 'found $missing iqlab positions with the mark stripped');
  });
}
