import 'package:hive/hive.dart';

import '../models/reading_progress.dart';
import 'hive_service.dart';

class ProgressService {
  Box get _box => Hive.box(HiveBoxes.progress);

  ReadingProgress getLastPosition() {
    final map = _box.get('lastPosition');
    if (map == null) return ReadingProgress.start;
    return ReadingProgress.fromMap(map as Map);
  }

  Future<void> saveLastPosition(ReadingProgress progress) {
    return _box.put('lastPosition', progress.toMap());
  }
}
