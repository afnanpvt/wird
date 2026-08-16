import 'package:hive/hive.dart';

import '../models/favorite_ayah.dart';
import 'hive_service.dart';

class FavoritesService {
  Box get _box => Hive.box(HiveBoxes.favoriteAyahs);

  String _key(int surahNumber, int ayahNumber) => '$surahNumber:$ayahNumber';

  Future<void> add(int surahNumber, int ayahNumber) {
    final favorite = FavoriteAyah(surahNumber: surahNumber, ayahNumber: ayahNumber, savedAt: DateTime.now());
    return _box.put(_key(surahNumber, ayahNumber), favorite.toMap());
  }

  Future<void> remove(int surahNumber, int ayahNumber) => _box.delete(_key(surahNumber, ayahNumber));

  /// Most recently saved first.
  List<FavoriteAyah> getAll() {
    final favorites = _box.values.map((e) => FavoriteAyah.fromMap(e as Map)).toList();
    favorites.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return favorites;
  }
}
