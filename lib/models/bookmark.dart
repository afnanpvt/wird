class Bookmark {
  final String id;
  final String name;
  final int surahNumber;
  final int ayahNumber;
  final DateTime updatedAt;

  /// Exactly one bookmark is the default at any time. It's the one shown on
  /// the home screen's Continue Reading card, and the one that auto-advances
  /// as you read through it. Every other bookmark is a static save-point:
  /// it stays put until you explicitly resave it from a reading session.
  final bool isDefault;

  const Bookmark({
    required this.id,
    required this.name,
    required this.surahNumber,
    required this.ayahNumber,
    required this.updatedAt,
    required this.isDefault,
  });

  Bookmark copyWith({
    String? name,
    int? surahNumber,
    int? ayahNumber,
    DateTime? updatedAt,
    bool? isDefault,
  }) =>
      Bookmark(
        id: id,
        name: name ?? this.name,
        surahNumber: surahNumber ?? this.surahNumber,
        ayahNumber: ayahNumber ?? this.ayahNumber,
        updatedAt: updatedAt ?? this.updatedAt,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'surahNumber': surahNumber,
        'ayahNumber': ayahNumber,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'isDefault': isDefault,
      };

  factory Bookmark.fromMap(Map<dynamic, dynamic> map) => Bookmark(
        id: map['id'] as String,
        name: map['name'] as String,
        surahNumber: map['surahNumber'] as int,
        ayahNumber: map['ayahNumber'] as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        isDefault: map['isDefault'] as bool? ?? false,
      );
}
