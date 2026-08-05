import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ayah.dart';
import '../models/juz.dart';
import '../models/juz_progress.dart';
import '../models/surah.dart';

class QuranRepository {
  List<Surah> _surahs = const [];
  List<Juz> _juzs = const [];
  final Map<int, List<Ayah>> _ayahsBySurah = {};
  final List<Ayah> _allAyahs = [];
  final Map<String, int> _globalIndex = {};

  Future<void> load() async {
    if (_surahs.isNotEmpty) return;

    final surahJson = await rootBundle.loadString('assets/data/surah_list.json');
    _surahs = (jsonDecode(surahJson) as List)
        .map((e) => Surah.fromJson(e as Map<String, dynamic>))
        .toList();

    final juzJson = await rootBundle.loadString('assets/data/juz_starts.json');
    _juzs = (jsonDecode(juzJson) as List).map((e) => Juz.fromJson(e as Map<String, dynamic>)).toList();

    final arabicJson = await rootBundle.loadString('assets/data/quran_ar_indopak.json');
    final arabicVerses = (jsonDecode(arabicJson) as Map<String, dynamic>)['quran'] as List;

    final englishJson = await rootBundle.loadString('assets/data/quran_en_saheeh.json');
    final englishVerses = (jsonDecode(englishJson) as Map<String, dynamic>)['quran'] as List;

    final simpleJson = await rootBundle.loadString('assets/data/quran_en_simple.json');
    final simpleVerses = (jsonDecode(simpleJson) as Map<String, dynamic>)['quran'] as List;

    for (var i = 0; i < arabicVerses.length; i++) {
      final ar = arabicVerses[i] as Map<String, dynamic>;
      final en = englishVerses[i] as Map<String, dynamic>;
      final simple = simpleVerses[i] as Map<String, dynamic>;
      final surahNumber = ar['chapter'] as int;
      final ayah = Ayah(
        surahNumber: surahNumber,
        ayahNumber: ar['verse'] as int,
        arabicText: ar['text'] as String,
        englishText: en['text'] as String,
        simpleEnglishText: simple['text'] as String,
      );
      _ayahsBySurah.putIfAbsent(surahNumber, () => []).add(ayah);
      _globalIndex['$surahNumber:${ayah.ayahNumber}'] = _allAyahs.length;
      _allAyahs.add(ayah);
    }
  }

  int globalIndexOf(int surahNumber, int ayahNumber) => _globalIndex['$surahNumber:$ayahNumber'] ?? 0;

  /// Which Juz [surahNumber]:[ayahNumber] falls in, how many verses remain
  /// until the next Juz begins, and how far through the current Juz that is.
  JuzProgress juzProgressFor(int surahNumber, int ayahNumber) {
    final currentGlobal = globalIndexOf(surahNumber, ayahNumber);
    var juzIndex = 0;
    for (var i = 0; i < _juzs.length; i++) {
      if (globalIndexOf(_juzs[i].startSurah, _juzs[i].startAyah) <= currentGlobal) {
        juzIndex = i;
      } else {
        break;
      }
    }
    final juz = _juzs[juzIndex];
    final juzStartGlobal = globalIndexOf(juz.startSurah, juz.startAyah);
    final nextJuzStartGlobal = juzIndex + 1 < _juzs.length
        ? globalIndexOf(_juzs[juzIndex + 1].startSurah, _juzs[juzIndex + 1].startAyah)
        : totalAyahCount;
    final versesInJuz = nextJuzStartGlobal - juzStartGlobal;
    final versesDoneInJuz = currentGlobal - juzStartGlobal + 1;
    return JuzProgress(
      juzNumber: juz.number,
      versesLeftInJuz: nextJuzStartGlobal - currentGlobal - 1,
      percentComplete: versesInJuz == 0 ? 0 : versesDoneInJuz / versesInJuz,
    );
  }

  List<Surah> get surahs => _surahs;

  List<Juz> get juzs => _juzs;

  Surah surahByNumber(int number) => _surahs.firstWhere((s) => s.number == number);

  List<Ayah> ayahsForSurah(int surahNumber) => _ayahsBySurah[surahNumber] ?? const [];

  int get totalAyahCount => _allAyahs.length;

  /// Curated for comfort, hope and reassurance rather than picked from the
  /// full text at random (which can just as easily land on a legal or
  /// narrative passage with no reassuring register on its own).
  static const _comfortingVerses = [
    (2, 255), // Ayat al-Kursi
    (2, 286), // Allah does not burden a soul beyond what it can bear
    (94, 5), (94, 6), // With hardship comes ease
    (13, 28), // Hearts find rest in remembrance of Allah
    (39, 53), // Do not despair of Allah's mercy
    (65, 3), // Whoever relies on Allah, He is sufficient for them
    (3, 159), // Gentleness and forgiveness
    (20, 25), (20, 26), // Ease my task
    (24, 35), // Allah is the Light of the heavens and earth
    (2, 152), // Remember Me, I will remember you
    (16, 97), // Whoever does good will have a good life
    (21, 87), // There is no deity except You, exalted are You
    (29, 69), // Those who strive, We guide
    (30, 21), // Spouses: mercy and affection between you
    (35, 2), // Whatever mercy Allah opens, none can withhold
    (42, 19), // Allah is Most Gentle with His servants
    (57, 4), // He is with you wherever you are
    (64, 11), // Whoever believes, He guides their heart
    (93, 3), (93, 4), (93, 5), // Your Lord has not abandoned you
    (12, 87), // Do not despair of relief from Allah
    (41, 30), // Do not fear, do not grieve
    (17, 82), // The Quran as healing and mercy
    (10, 57), // Healing, guidance and mercy for believers
    (89, 27), (89, 28), // Return to your Lord, well pleased
    (2, 186), // I am near, I respond to the call of the caller
  ];

  Ayah _ayahAt(int surahNumber, int ayahNumber) =>
      _ayahsBySurah[surahNumber]!.firstWhere((a) => a.ayahNumber == ayahNumber);

  /// Same ayah for everyone on a given calendar day, changes daily.
  Ayah verseOfTheDay(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final (surah, ayah) = _comfortingVerses[dayOfYear % _comfortingVerses.length];
    return _ayahAt(surah, ayah);
  }
}
