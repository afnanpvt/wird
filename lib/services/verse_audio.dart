/// Builds the streaming URL for a single ayah's recitation audio.
///
/// Source: everyayah.com, reciter Mishary Alafasy at 128kbps. Chosen over an
/// API-based source (e.g. quran.com's) because the URL is fully predictable
/// from the surah/ayah numbers alone - no network round-trip just to find out
/// where the audio lives, matching the rest of this app never needing a
/// backend for anything. Verified reachable and CORS-open at
/// https://everyayah.com/data/Alafasy_128kbps/001001.mp3 before wiring in.
String verseAudioUrl(int surahNumber, int ayahNumber) {
  final surah = surahNumber.toString().padLeft(3, '0');
  final ayah = ayahNumber.toString().padLeft(3, '0');
  return 'https://everyayah.com/data/Alafasy_128kbps/$surah$ayah.mp3';
}
