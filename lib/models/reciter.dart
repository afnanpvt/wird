/// Persisted values are the enum name - do not rename existing entries.
enum Reciter { yasserAlDosari, abdulRahmanAlSudais, mahmoudKhalilAlHusary, abdulBasit }

extension ReciterInfo on Reciter {
  String get displayName => switch (this) {
        Reciter.yasserAlDosari => 'Yasser Al-Dosari',
        Reciter.abdulRahmanAlSudais => 'Abdul Rahman Al-Sudais',
        Reciter.mahmoudKhalilAlHusary => 'Mahmoud Khalil Al-Husary',
        Reciter.abdulBasit => 'Abdul Basit',
      };

  /// Folder name on everyayah.com - each reciter's per-ayah recordings are
  /// only available at one bitrate there, hence the mismatched suffixes.
  String get _folder => switch (this) {
        Reciter.yasserAlDosari => 'Yasser_Ad-Dussary_128kbps',
        Reciter.abdulRahmanAlSudais => 'Abdurrahmaan_As-Sudais_192kbps',
        Reciter.mahmoudKhalilAlHusary => 'Husary_128kbps',
        Reciter.abdulBasit => 'Abdul_Basit_Murattal_192kbps',
      };

  /// Builds the streaming URL for a single ayah's recitation audio.
  ///
  /// Source: everyayah.com. Chosen over an API-based source (e.g. quran.com's)
  /// because the URL is fully predictable from the surah/ayah numbers alone -
  /// no network round-trip just to find out where the audio lives, matching
  /// the rest of this app never needing a backend for anything. Every folder
  /// below was verified reachable before wiring in.
  String audioUrlFor(int surahNumber, int ayahNumber) {
    final surah = surahNumber.toString().padLeft(3, '0');
    final ayah = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$_folder/$surah$ayah.mp3';
  }
}
