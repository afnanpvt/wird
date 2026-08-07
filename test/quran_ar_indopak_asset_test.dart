import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening ayah in the Indo-Pak asset is stored as readable Arabic text', () async {
    final raw = await File('assets/data/quran_ar_indopak.json').readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final verses = decoded['quran'] as List<dynamic>;
    final firstAyah = verses.first as Map<String, dynamic>;
    final text = firstAyah['text'] as String;

    expect(firstAyah['chapter'], 1);
    expect(firstAyah['verse'], 1);
    expect(text, isNot(contains('Ã')));
    expect(RegExp(r'[\u0600-\u06FF]').hasMatch(text), isTrue);
    expect(text, contains('\u0627\u0644\u0644\u0651\u0670\u0647'));
  });
}
