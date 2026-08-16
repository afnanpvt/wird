import 'package:hive/hive.dart';

import '../models/reading_progress.dart';
import 'hive_service.dart';

/// Reads the pre-bookmarks single "continue reading" position, kept only so
/// [BookmarksService.migrateLegacyPosition] can carry it forward once.
class ProgressService {
  Box get _box => Hive.box(HiveBoxes.progress);

  ReadingProgress getLastPosition() {
    final map = _box.get('lastPosition');
    if (map == null) return ReadingProgress.start;
    return ReadingProgress.fromMap(map as Map);
  }
}
