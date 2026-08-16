class FavoriteAyah {
  final int surahNumber;
  final int ayahNumber;
  final DateTime savedAt;

  const FavoriteAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() => {
        'surahNumber': surahNumber,
        'ayahNumber': ayahNumber,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory FavoriteAyah.fromMap(Map<dynamic, dynamic> map) => FavoriteAyah(
        surahNumber: map['surahNumber'] as int,
        ayahNumber: map['ayahNumber'] as int,
        savedAt: DateTime.fromMillisecondsSinceEpoch(map['savedAt'] as int),
      );
}
