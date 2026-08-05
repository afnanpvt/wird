import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const progress = 'progress';
  static const streak = 'streak';
  static const dailyLogs = 'dailyLogs';
  static const readAyahs = 'readAyahs';
  static const settings = 'settings';
}

Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox(HiveBoxes.progress);
  await Hive.openBox(HiveBoxes.streak);
  await Hive.openBox(HiveBoxes.dailyLogs);
  await Hive.openBox(HiveBoxes.readAyahs);
  await Hive.openBox(HiveBoxes.settings);
}
