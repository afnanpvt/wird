class ReadingProgress {
  final int surahNumber;
  final int ayahNumber;

  const ReadingProgress({required this.surahNumber, required this.ayahNumber});

  static const ReadingProgress start = ReadingProgress(surahNumber: 1, ayahNumber: 1);

  Map<String, dynamic> toMap() => {'surahNumber': surahNumber, 'ayahNumber': ayahNumber};

  factory ReadingProgress.fromMap(Map<dynamic, dynamic> map) => ReadingProgress(
        surahNumber: map['surahNumber'] as int? ?? 1,
        ayahNumber: map['ayahNumber'] as int? ?? 1,
      );
}
