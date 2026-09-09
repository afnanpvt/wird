// ignore_for_file: type=lint
// PLACEHOLDER - regenerate this file for real before using the Friends
// feature. Run `flutterfire configure` from the project root once you've
// created a Firebase project and are logged in to the Firebase CLI; it
// overwrites this file with your project's real values. Nothing else in
// the app needs to change - this is the only file that command touches.
//
// Until then, these dummy values mean Firebase.initializeApp() will fail
// at runtime (not at compile time) if FRIENDS_ENABLED is ever turned on,
// which only ever happens in dev/test builds - see lib/config/feature_flags.dart.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ${defaultTargetPlatform.name} - '
          'run `flutterfire configure` to generate real options for this platform.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'PLACEHOLDER-run-flutterfire-configure',
    appId: 'PLACEHOLDER-run-flutterfire-configure',
    messagingSenderId: 'PLACEHOLDER-run-flutterfire-configure',
    projectId: 'PLACEHOLDER-run-flutterfire-configure',
  );
}
