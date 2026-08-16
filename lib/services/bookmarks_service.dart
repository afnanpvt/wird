import 'package:hive/hive.dart';

import '../models/bookmark.dart';
import '../models/reading_progress.dart';
import 'hive_service.dart';

class BookmarksService {
  Box get _box => Hive.box(HiveBoxes.bookmarks);

  /// One-time carry-over from the old single "continue reading" position,
  /// which predates named bookmarks. Only runs while no bookmarks exist yet,
  /// so it can never clobber anything a user has actually created.
  Future<void> migrateLegacyPosition(ReadingProgress legacyPosition) async {
    if (_box.isNotEmpty) return;
    final bookmark = Bookmark(
      id: 'default',
      name: 'Continue Reading',
      surahNumber: legacyPosition.surahNumber,
      ayahNumber: legacyPosition.ayahNumber,
      updatedAt: DateTime.now(),
      isDefault: true,
    );
    await _box.put(bookmark.id, bookmark.toMap());
  }

  /// Default first, then most recently updated.
  List<Bookmark> getAll() {
    final bookmarks = _box.values.map((e) => Bookmark.fromMap(e as Map)).toList();
    bookmarks.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return bookmarks;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<Bookmark> create({
    required String name,
    required int surahNumber,
    required int ayahNumber,
    required bool isDefault,
  }) async {
    final bookmark = Bookmark(
      id: _newId(),
      name: name,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      updatedAt: DateTime.now(),
      isDefault: isDefault,
    );
    if (isDefault) await _clearDefault();
    await _box.put(bookmark.id, bookmark.toMap());
    return bookmark;
  }

  Future<void> updatePosition(String id, int surahNumber, int ayahNumber) async {
    final map = _box.get(id) as Map?;
    if (map == null) return;
    final bookmark = Bookmark.fromMap(map).copyWith(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      updatedAt: DateTime.now(),
    );
    await _box.put(id, bookmark.toMap());
  }

  Future<void> rename(String id, String name) async {
    final map = _box.get(id) as Map?;
    if (map == null) return;
    await _box.put(id, Bookmark.fromMap(map).copyWith(name: name).toMap());
  }

  Future<void> setDefault(String id) async {
    await _clearDefault();
    final map = _box.get(id) as Map?;
    if (map == null) return;
    await _box.put(id, Bookmark.fromMap(map).copyWith(isDefault: true).toMap());
  }

  Future<void> _clearDefault() async {
    for (final key in _box.keys.toList()) {
      final map = _box.get(key) as Map;
      if (map['isDefault'] == true) {
        await _box.put(key, Bookmark.fromMap(map).copyWith(isDefault: false).toMap());
      }
    }
  }

  Future<void> delete(String id) => _box.delete(id);
}
