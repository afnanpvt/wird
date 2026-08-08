/// Persisted values are the enum name - do not rename existing entries.
enum QuranScript { indoPakNastaleeq, uthmaniNaskh, uthmaniTajweed }

extension QuranScriptInfo on QuranScript {
  String get displayName => switch (this) {
        QuranScript.indoPakNastaleeq => 'Indo-Pak Nastaleeq',
        QuranScript.uthmaniNaskh => 'Uthmani Naskh',
        QuranScript.uthmaniTajweed => 'Uthmani Tajweed',
      };

  String get description => switch (this) {
        QuranScript.indoPakNastaleeq => 'The diagonal, cursive script used in South Asian Mushafs',
        QuranScript.uthmaniNaskh => 'The upright script used in most Mushafs worldwide',
        QuranScript.uthmaniTajweed => 'Uthmani script with recitation rules color-coded',
      };

  String get fontFamily => switch (this) {
        QuranScript.indoPakNastaleeq => 'QuranNastaleeq',
        QuranScript.uthmaniNaskh => 'AmiriQuran',
        QuranScript.uthmaniTajweed => 'AmiriQuranColored',
      };

  String get dataAsset => switch (this) {
        QuranScript.indoPakNastaleeq => 'assets/data/quran_ar_indopak.json',
        QuranScript.uthmaniNaskh => 'assets/data/quran_ar_uthmani.json',
        QuranScript.uthmaniTajweed => 'assets/data/quran_ar_uthmani.json',
      };

  /// The Bismillah, copied verbatim from this script's own [dataAsset], to
  /// preview the script in onboarding and Settings.
  ///
  /// It has to be this script's real text, not a generic Arabic string: the
  /// point of the preview is to show what you will actually be reading, and
  /// the recensions genuinely differ. An earlier hardcoded approximation even
  /// ordered shadda and fatha the other way round, so it previewed something
  /// the app never renders.
  ///
  /// Literal rather than read from the asset so the picker does not parse
  /// multi-megabyte files just to draw three cards. Do not retype these by
  /// hand; copy them from the asset. quran_ar_indopak_asset_test.dart asserts
  /// they match, so they cannot silently drift.
  String get previewText => switch (this) {
        QuranScript.indoPakNastaleeq => 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِیْمِ',
        QuranScript.uthmaniNaskh || QuranScript.uthmaniTajweed => 'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
      };

  // No per-script spacing overrides: every bundled font spaces words correctly
  // on its own. See _ArabicText in reading_screen.dart for why the old
  // split-on-spaces approach was removed.
}
