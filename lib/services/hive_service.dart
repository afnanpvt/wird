import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const progress = 'progress';
  static const streak = 'streak';
  static const dailyLogs = 'dailyLogs';
  static const dailyReadingSeconds = 'dailyReadingSeconds';
  static const readAyahs = 'readAyahs';
  static const settings = 'settings';
  static const favoriteAyahs = 'favoriteAyahs';
  static const bookmarks = 'bookmarks';
  static const dailyHasanat = 'dailyHasanat';
}

Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox(HiveBoxes.progress);
  await Hive.openBox(HiveBoxes.streak);
  await Hive.openBox(HiveBoxes.dailyLogs);
  await Hive.openBox(HiveBoxes.dailyReadingSeconds);
  await Hive.openBox(HiveBoxes.readAyahs);
  await Hive.openBox(HiveBoxes.settings);
  await Hive.openBox(HiveBoxes.favoriteAyahs);
  await Hive.openBox(HiveBoxes.bookmarks);
  await Hive.openBox(HiveBoxes.dailyHasanat);
}
