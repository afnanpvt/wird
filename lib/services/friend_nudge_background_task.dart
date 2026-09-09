import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import 'friend_nudge_checker.dart';
import 'friends_service.dart';
import 'hive_service.dart';

const _taskName = 'friendNudgeCheck';

/// [Workmanager] runs its callback in a fresh background isolate - none of
/// the running app's state (Hive boxes, the Firebase app instance, Provider)
/// carries over, so this dispatcher has to initialize just enough of it
/// itself before delegating to the same [FriendNudgeChecker] the foreground
/// path uses (see root_screen.dart's _checkFriendNudges). Registered only
/// from [registerPeriodicNudgeCheck], which is only ever called when
/// FeatureFlags.friendsEnabled is true.
@pragma('vm:entry-point')
void friendNudgeCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;
    await Hive.initFlutter();
    await Hive.openBox(HiveBoxes.friendNudgeThrottle);
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FriendNudgeChecker.checkAndNotify(FriendsService());
    return true;
  });
}

/// Schedules the periodic background check - the "app isn't open" half of
/// the notification flow. Android's WorkManager enforces a practical
/// minimum of ~15 minutes for periodic tasks regardless of what's asked
/// for; a few hours is plenty for a once-a-day nudge and is friendlier to
/// battery. Call once, e.g. from main() after Firebase.initializeApp().
Future<void> registerPeriodicNudgeCheck() async {
  await Workmanager().initialize(friendNudgeCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: const Duration(hours: 3),
  );
}
