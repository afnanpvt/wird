/// Compile-time feature gates. Set via --dart-define, e.g.:
/// flutter run --flavor dev --dart-define=FRIENDS_ENABLED=true
///
/// Defaults to false so a plain `flutter build apk --flavor prod` (no
/// dart-define) never includes gated features in the public build.
class FeatureFlags {
  static const bool friendsEnabled = bool.fromEnvironment('FRIENDS_ENABLED');

  /// Google Sign-In backup/restore (see lib/services/backup_service.dart).
  /// Off until the Firebase console side is actually set up - Google Sign-In
  /// needs a provider enabled and SHA-1 fingerprints registered per Android
  /// flavor before it can work at all, so this must stay false until that's
  /// done, independently of whether Friends is enabled.
  static const bool backupEnabled = bool.fromEnvironment('BACKUP_ENABLED');
}
