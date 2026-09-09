/// Compile-time feature gates. Set via --dart-define, e.g.:
/// flutter run --flavor dev --dart-define=FRIENDS_ENABLED=true
///
/// Defaults to false so a plain `flutter build apk --flavor prod` (no
/// dart-define) never includes gated features in the public build.
class FeatureFlags {
  static const bool friendsEnabled = bool.fromEnvironment('FRIENDS_ENABLED');
}
