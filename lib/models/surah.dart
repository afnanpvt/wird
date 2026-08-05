class Surah {
  final int number;
  final String name;
  final String englishName;
  final String arabicName;
  final String revelationType;
  final int ayahCount;

  const Surah({
    required this.number,
    required this.name,
    required this.englishName,
    required this.arabicName,
    required this.revelationType,
    required this.ayahCount,
  });

  factory Surah.fromJson(Map<String, dynamic> json) => Surah(
        number: json['number'] as int,
        name: json['name'] as String,
        englishName: json['englishName'] as String,
        arabicName: json['arabicName'] as String,
        revelationType: json['revelationType'] as String,
        ayahCount: json['ayahCount'] as int,
      );
}
