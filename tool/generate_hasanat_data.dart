// Generates assets/data/quran_letter_counts.json: the per-ayah Arabic letter
// count that lib/services/quran_repository.dart multiplies by 10 to show
// hasanat, per the hadith that every letter of the Quran recited earns a
// reward multiplied tenfold (Tirmidhi 2910: "...Alif is a letter, Lam is a
// letter, Meem is a letter").
//
// This is a one-time, offline generation step, not runtime logic - the app
// never runs a counting algorithm on-device, it only reads the numbers this
// script produced. Re-run it (`dart run tool/generate_hasanat_data.dart`)
// only if the counting rule below is deliberately revised.
//
// Source text: assets/data/quran_ar_uthmani.json, the same canonical Uthmani
// text used regardless of which script the reader has selected, so the
// count for a given ayah never depends on a display preference.
//
// Counting rule: count Arabic letters, not diacritics. Concretely:
//   - U+0621-U+064A (the main Arabic letters block) counts, EXCEPT
//   - U+0640 (tatweel) is excluded - it's a stretch glyph, not a letter.
//   - U+0671 (alef wasla) counts - it's an alef.
//   - U+0654 / U+0655 (hamza above/below with no seat letter) count - each
//     stands in for a written hamza that has no base letter of its own.
//   - Everything else (fatha/damma/kasra and their tanwin, shadda, sukun,
//     the dagger alef, waqf/pause marks, small high marks) is a diacritic
//     or annotation, not counted as a letter.
//
// This rule is calibrated against the traditionally cited fact that the
// Bismillah has 19 letters - run this script and check chapter 1, verse 1
// reads `"letters": 19` if you ever revise the rule.

import 'dart:convert';
import 'dart:io';

bool _isCountedLetter(int codePoint) {
  if (codePoint == 0x0640) return false;
  if (codePoint >= 0x0621 && codePoint <= 0x064A) return true;
  if (codePoint == 0x0671) return true;
  if (codePoint == 0x0654 || codePoint == 0x0655) return true;
  return false;
}

int _countArabicLetters(String text) {
  var count = 0;
  for (final rune in text.runes) {
    if (_isCountedLetter(rune)) count++;
  }
  return count;
}

void main() {
  const sourcePath = 'assets/data/quran_ar_uthmani.json';
  const outputPath = 'assets/data/quran_letter_counts.json';

  final source = jsonDecode(File(sourcePath).readAsStringSync()) as Map<String, dynamic>;
  final verses = source['quran'] as List;

  final output = <Map<String, dynamic>>[];
  var totalLetters = 0;
  for (final v in verses) {
    final map = v as Map<String, dynamic>;
    final letters = _countArabicLetters(map['text'] as String);
    output.add({'chapter': map['chapter'], 'verse': map['verse'], 'letters': letters});
    totalLetters += letters;
  }

  File(outputPath).writeAsStringSync(jsonEncode({'quran': output}));

  final bismillah = output.first;
  stdout.writeln('Wrote $outputPath: ${output.length} ayahs, $totalLetters letters total.');
  stdout.writeln(
    'Bismillah (1:1): ${bismillah['letters']} letters '
    '${bismillah['letters'] == 19 ? '(matches the traditional count)' : '(!! expected 19 - check the rule above)'}',
  );
}
