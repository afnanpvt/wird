import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'friends_service.dart';
import 'hive_service.dart';

/// The client-side stand-in for a push notification (see design spec's
/// "Notification flow" - staying on Firebase's free plan rules out FCM, so
/// each friend's own device has to notice "did someone read today" for
/// itself). Runs from two different call sites which both need this exact
/// same logic:
///   1. App foreground/resume ([WirdApp]/root screen), where Hive and
///      Firebase are already initialized as part of the normal app.
///   2. The workmanager background isolate (see registerPeriodicNudgeCheck
///      below), which is a *fresh* isolate with none of the app's state -
///      it must initialize Hive and Firebase itself before this can run.
class FriendNudgeChecker {
  static const _channelId = 'com.afnan.wird.channel.friend_nudge';
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  static Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('drawable/ic_launcher_foreground'),
      ),
    );
    _notificationsInitialized = true;
  }

  /// Requests the runtime notification permission (Android 13+ requires
  /// this explicitly; earlier versions grant it automatically at install).
  /// Call this from a UI moment that has already explained *why*, not cold
  /// - the OS prompt itself carries no context, so a friendly explainer
  /// screen belongs immediately before this, not after.
  static Future<bool> requestPermission() async {
    await _ensureNotificationsInitialized();
    final granted = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Shown the moment someone sends you a friend request - this is worth
  /// notifying about immediately (unlike the daily nudge, it needs action),
  /// so it bypasses the once-a-day throttle entirely.
  static Future<void> notifyFriendRequestReceived(String fromDisplayName) async {
    await _ensureNotificationsInitialized();
    await _notifications.show(
      id: 'friend_request_$fromDisplayName'.hashCode,
      title: 'New friend request',
      body: '$fromDisplayName sent you a friend request',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Friend activity',
          channelDescription: 'Lets you know when a friend reads Qur’an or sends a request',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Checks every friend's [FriendStats.lastActiveDate] against today, and
  /// shows one local notification per friend who read today and hasn't
  /// already been nudged-about today on this device - see
  /// FriendsService.alreadyNotifiedToday for the once-per-day-per-friend
  /// throttle. Safe to call whether or not this device has ever opted into
  /// Friends: it's a no-op if there's no signed-in Friends profile yet.
  static Future<void> checkAndNotify(FriendsService service) async {
    if (FirebaseAuth.instance.currentUser == null) return;

    final today = _todayKey();
    final friendUids = await service.friendUids().first;
    for (final friendUid in friendUids) {
      if (service.alreadyNotifiedToday(friendUid, today)) continue;
      final stats = await service.getStats(friendUid);
      if (stats.lastActiveDate != today) continue;
      final profile = await service.getProfile(friendUid);
      if (profile == null || !profile.friendsEnabled) continue;

      await _ensureNotificationsInitialized();
      await _notifications.show(
        id: friendUid.hashCode,
        title: 'Time to read?',
        body: '${profile.displayName} just read Qur’an today — your turn?',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Friend activity',
            channelDescription: 'Lets you know when a friend reads Qur’an',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
      await service.markNotifiedToday(friendUid, today);
    }

    // New incoming friend requests - checked here too so this fires even
    // when the app is closed (the Friends screen's own live listener
    // already handles the in-app case; this is the "app not open" half).
    final requests = await service.incomingRequestsOnce();
    for (final request in requests) {
      if (service.alreadyNotifiedOfRequest(request.fromUid)) continue;
      await notifyFriendRequestReceived(request.fromDisplayName);
      await service.markNotifiedOfRequest(request.fromUid);
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Hive box name used by [FriendNudgeChecker]/[FriendsService] - re-exported
/// here so the background isolate entry point (main.dart's
/// friendNudgeCallbackDispatcher) can open just this one box without
/// pulling in the rest of the app's initHive() box list, which it has no
/// use for.
const friendNudgeThrottleBoxName = HiveBoxes.friendNudgeThrottle;
