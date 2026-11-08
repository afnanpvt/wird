import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;

import 'settings_service.dart';
import 'streak_service.dart';

/// Quran reminders at each real prayer time for wherever the reader is.
///
/// Times are computed on-device from a one-time coarse location (adhan_dart,
/// no network) and scheduled as local notifications for the next week, so
/// they arrive on the prayer itself rather than at a fixed clock hour. The
/// copy deliberately never mentions the time of day, since a notification
/// can land a little late under battery saver.
///
/// Today's remaining reminders are dropped the moment you read something
/// ([onReadToday]), so nobody gets nagged after they've already read.
class ReminderService {
  static const _channelId = 'com.afnan.wird.channel.reminders';
  static const _horizonDays = 7;
  static const _idBase = 7100000;
  static const _prayers = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  // Generalized on purpose: no "morning"/"tonight"/"before bed" - any of
  // these has to read fine whenever it actually shows up.
  static const _titles = [
    'Quick pause? 🌙',
    'Got a sec? 📖',
    'Main character moment',
    'Streak check 🔥',
    'Two minutes, that is it',
    'Psst, your Quran is open',
    'Tiny habit, big glow-up',
    'No pressure, just ayahs',
  ];

  static const _bodies = [
    'your Quran is right there. a few ayahs, then back to scrolling.',
    "small streak maintenance. one page and you're done 🔥",
    'the main character reads Quran. no pressure, just a few ayahs.',
    'two minutes. your future self is clapping 👏',
    "your wird is calling. low effort, high reward.",
    'keep it alive, even with one ayah.',
    'a little Quran goes a long way ✨',
    'No cap, this is the BEST use of the next two minutes.',
  ];

  static bool _askedThisSession = false;

  /// Android 13+ hides a media player's lock-screen/notification controls
  /// until notifications are allowed, so playback asks (once per launch -
  /// the OS itself stops showing the prompt after repeated denials).
  static Future<void> ensureNotificationPermission() async {
    if (_askedThisSession) return;
    _askedThisSession = true;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('drawable/ic_launcher_foreground'),
        ),
      );
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.areNotificationsEnabled() == false) await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  final _settings = SettingsService();
  final _streak = StreakService();

  bool get enabled => _settings.getRemindersEnabled();

  Future<void> _init() => _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('drawable/ic_launcher_foreground'),
        ),
      );

  /// Asks for notification + coarse location permission, remembers where
  /// the reader is, and schedules. Returns false (and stays off) if either
  /// permission is refused or no location can be found.
  Future<bool> enable() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (await android?.requestNotificationsPermission() == false) return false;
    if (!await _refreshLocation()) return false;
    await android?.requestExactAlarmsPermission();
    await _settings.saveRemindersEnabled(true);
    await reschedule();
    return true;
  }

  Future<void> disable() async {
    await _settings.saveRemindersEnabled(false);
    await _init();
    await _cancelAll();
  }

  Future<bool> _refreshLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return _settings.getReminderCoords() != null;
      }
      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
          );
      await _settings.saveReminderCoords(position.latitude, position.longitude);
      return true;
    } catch (_) {
      // Location off / timed out: fall back to the last place we knew.
      return _settings.getReminderCoords() != null;
    }
  }

  Future<void> _cancelAll() async {
    for (var i = 0; i < _horizonDays * 10; i++) {
      await _plugin.cancel(id: _idBase + i);
    }
  }

  /// Rebuilds the next week of reminders. Safe to call as often as needed
  /// (app start, resume, after the first read of the day).
  Future<void> reschedule() async {
    if (!enabled) return;
    try {
      final coords = _settings.getReminderCoords();
      if (coords == null) return;
      await _init();
      await _cancelAll();

      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final exact = await android?.canScheduleExactNotifications() ?? false;
      final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

      final coordinates = Coordinates(coords.$1, coords.$2);
      final params = CalculationMethodParameters.muslimWorldLeague();
      final now = DateTime.now();
      final readToday = _streak.ayahsReadToday() > 0;

      for (var day = 0; day < _horizonDays; day++) {
        final date = DateTime.utc(now.year, now.month, now.day + day, 12);
        final times = PrayerTimes(coordinates: coordinates, date: date, calculationParameters: params);
        for (var p = 0; p < _prayers.length; p++) {
          final at = times.timeForPrayer(_prayers[p]);
          if (!at.isAfter(now)) continue;
          // Already read today: no more reminders until tomorrow.
          if (readToday && day == 0) continue;
          final id = _idBase + day * 10 + p;
          await _plugin.zonedSchedule(
            id: id,
            scheduledDate: tz.TZDateTime.from(at, tz.UTC),
            title: _titles[(id ~/ 3) % _titles.length],
            body: _bodies[id % _bodies.length],
            androidScheduleMode: mode,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'Prayer-time reminders',
                channelDescription: 'A nudge to read Quran at each prayer time',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        }
      }
    } catch (_) {
      // Reminders are a convenience: never let a scheduling failure
      // reach the reading flow.
    }
  }

  String? _clearedFor;

  /// Call after any ayah is recorded - drops today's remaining reminders
  /// once per day, and is a cheap no-op after that.
  Future<void> onReadToday() async {
    final today = dateKey(DateTime.now());
    if (_clearedFor == today || !enabled) return;
    _clearedFor = today;
    await reschedule();
  }
}
