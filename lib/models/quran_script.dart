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

  /// Whether ayah text should be split into per-word Text widgets with real
  /// gaps between them (needed for dense Nastaleeq; Naskh scripts already
  /// have enough natural word-spacing without it).
  bool get needsWordSpacing => this == QuranScript.indoPakNastaleeq;
}
