class Juz {
  final int number;
  final int startSurah;
  final int startAyah;
  final String name;
  final String arabicName;

  const Juz({
    required this.number,
    required this.startSurah,
    required this.startAyah,
    required this.name,
    required this.arabicName,
  });

  /// Traditional names, one per Juz (1-30) — each Juz is conventionally named
  /// after its own opening words. Juz 1 is the sole exception: convention
  /// names it after "Alif Lam Meem" (the start of Al-Baqara, which makes up
  /// almost all of Juz 1) rather than the literal Bismillah that opens it.
  static const _names = [
    ('Alif Lam Meem', 'الٓمٓ'),
    ('Sayaqool', 'سَيَقُوۡلُ السُّفَهَآءُ'),
    ('Tilkar Rusul', 'تِلۡكَ الرُّسُلُ'),
    ('Lan Tana Lu', 'لَنۡ تَنَالُوا'),
    ('Wal Muhsanat', 'وَّالۡمُحۡصَنٰتُ مِنَ'),
    ('La Yuhibbullah', 'لَا يُحِبُّ'),
    ('Latajidanna', 'لَتَجِدَنَّ اَشَدَّ'),
    ('Wa Lau Annana', 'وَلَوۡ اَنَّنَا'),
    ('Qalal Malau', 'قَالَ الۡمَلَاُ'),
    ("Wa'lamu Annama", 'وَاعۡلَمُوۡا اَنَّمَا'),
    ('Innamas Sabeel', 'اِنَّمَا السَّبِيۡلُ'),
    ('Wa Ma Min Dabbah', 'وَمَا مِنۡ'),
    ("Wa Ma Ubarri'u", 'وَمَا اُبَرِّئُ'),
    ('Alif Lam Ra', 'الٓرٰ تِلۡكَ'),
    ('Subhanal Lazi', 'سُبۡحٰنَ الَّذِيۡ'),
    ('Qala Alam', 'قَالَ اَلَمۡ'),
    ('Iqtaraba', 'اِقۡتَرَبَ لِلنَّاسِ'),
    ('Qad Aflaha', 'قَدۡ اَفۡلَحَ'),
    ('Wa Qalal Lazina', 'وَقَالَ الَّذِيۡنَ'),
    ('Fama Kana', 'فَمَا كَانَ'),
    ('Wala Tujadilu', 'وَلَا تُجَادِلُوۡا'),
    ('Wa Man Yaqnut', 'وَمَنۡ يَّقۡنُتۡ'),
    ('Wa Ma Anzalna', 'وَمَا اَنۡزَلۡنَا'),
    ('Faman Azlamu', 'فَمَنۡ اَظۡلَمُ'),
    ('Ilayhi Yuraddu', 'اِلَيۡهِ يُرَدُّ'),
    ('Ha Meem', 'حٰمٓ'),
    ('Qala Fama', 'قَالَ فَمَا'),
    ('Qad Sami Allah', 'قَدۡ سَمِعَ'),
    ('Tabarakal Lazi', 'تَبٰرَكَ الَّذِيۡ'),
    ("Amma Yatasa'alun", 'عَمَّ يَتَسَآءَلُوۡنَ'),
  ];

  factory Juz.fromJson(Map<String, dynamic> json) {
    final number = json['juz'] as int;
    final (name, arabicName) = _names[number - 1];
    return Juz(
      number: number,
      startSurah: json['surah'] as int,
      startAyah: json['ayah'] as int,
      name: name,
      arabicName: arabicName,
    );
  }
}
