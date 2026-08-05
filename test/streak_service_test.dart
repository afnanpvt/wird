import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wird/services/hive_service.dart';
import 'package:wird/services/streak_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('wird_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveBoxes.streak);
    await Hive.openBox(HiveBoxes.dailyLogs);
    await Hive.openBox(HiveBoxes.readAyahs);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  test('first ever read on a fresh install advances the streak to 1, not 0', () async {
    final service = StreakService();
    await service.recordAyahRead(1, 1);
    expect(service.getState().currentStreak, 1);
  });

  test('reading multiple times on the first day only counts the streak once', () async {
    final service = StreakService();
    await service.recordAyahRead(1, 1);
    await service.recordAyahRead(1, 1);
    await service.recordAyahRead(1, 1);

    expect(service.getState().currentStreak, 1);
    expect(service.ayahsReadToday(), 3);
  });

  test('reconcileToYesterday on a brand-new install does not touch the streak', () async {
    final service = StreakService();
    await service.reconcileToYesterday();
    expect(service.getState().currentStreak, 0);

    await service.recordAyahRead(1, 1);
    expect(service.getState().currentStreak, 1, reason: 'today should still be countable after reconciling');
  });
}
