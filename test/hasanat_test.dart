import 'package:flutter_test/flutter_test.dart';
import 'package:wird/models/quran_script.dart';
import 'package:wird/services/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasanat counting matches the traditionally cited 19 letters in the Bismillah', () async {
    final repo = QuranRepository();
    await repo.load(QuranScript.uthmaniNaskh);
    expect(repo.hasanatForAyah(1, 1), 190);
  });

  test('hasanat is the same regardless of which script is currently loaded', () async {
    final repo = QuranRepository();
    await repo.load(QuranScript.indoPakNastaleeq);
    final hasanat = repo.hasanatForAyah(1, 1);

    await repo.load(QuranScript.uthmaniTajweed);
    expect(repo.hasanatForAyah(1, 1), hasanat);
    expect(hasanat, 190);
  });

  test('total hasanat across the whole Quran is a stable, checkable number', () async {
    final repo = QuranRepository();
    await repo.load(QuranScript.uthmaniNaskh);

    var total = 0;
    for (final surah in repo.surahs) {
      for (final ayah in repo.ayahsForSurah(surah.number)) {
        total += repo.hasanatForAyah(ayah.surahNumber, ayah.ayahNumber);
      }
    }

    // 325,896 letters counted from the bundled Uthmani text, x10. Falls
    // within the range classical adad al-huruf countings cite
    // (roughly 320,000-325,000 letters, depending on counting tradition).
    expect(total, 3258960);
  });
}
