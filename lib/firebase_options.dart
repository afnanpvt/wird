// ignore_for_file: type=lint
// Hand-maintained for the wird-dev Firebase project's 3 Android apps (see
// android/app/build.gradle.kts's flavor block for the matching
// applicationId per flavor). All 3 share one apiKey/projectId/storageBucket
// - only appId (the per-package Firebase app registration) actually
// differs, which is also the one field that has to be right: Firebase Auth
// ties a signed-in session to the app that initialized it, so running the
// prod build against the dev app's identity (the bug this file used to
// have - see git history) works for anonymous auth, which doesn't check
// package/certificate at all, but breaks real Google Sign-In, which does.
//
// Which of the 3 below gets used is picked at build time via
// --dart-define=APP_FLAVOR=prod|dev|dev2 (see .github/workflows/release.yml
// for the prod build; falls back to 'dev' so a plain `flutter run --flavor
// dev` with no dart-define, the common local case, still gets the right one
// without anyone needing to remember the flag).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

const _appFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev');

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ${defaultTargetPlatform.name} - '
          'run `flutterfire configure` again to add that platform.',
        );
    }
  }

  static FirebaseOptions get android => switch (_appFlavor) {
        'prod' => androidProd,
        'dev2' => androidDev2,
        _ => androidDev,
      };

  static const androidProd = FirebaseOptions(
    apiKey: 'AIzaSyD6zrM7Zs9eZ4_pgXwEZ1X-k1HJHP38Ev0',
    appId: '1:327002593542:android:8fe02ae2a777b952b36687',
    messagingSenderId: '327002593542',
    projectId: 'wird-dev',
    storageBucket: 'wird-dev.firebasestorage.app',
  );

  static const androidDev = FirebaseOptions(
    apiKey: 'AIzaSyD6zrM7Zs9eZ4_pgXwEZ1X-k1HJHP38Ev0',
    appId: '1:327002593542:android:17bc43cee3f10beeb36687',
    messagingSenderId: '327002593542',
    projectId: 'wird-dev',
    storageBucket: 'wird-dev.firebasestorage.app',
  );

  static const androidDev2 = FirebaseOptions(
    apiKey: 'AIzaSyD6zrM7Zs9eZ4_pgXwEZ1X-k1HJHP38Ev0',
    appId: '1:327002593542:android:80a51052babf87b4b36687',
    messagingSenderId: '327002593542',
    projectId: 'wird-dev',
    storageBucket: 'wird-dev.firebasestorage.app',
  );
}
