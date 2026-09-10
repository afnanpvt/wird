/// A friend's public profile fields (users/{uid} in Firestore) - the
/// settings and identity half of what a leaderboard row needs. Activity
/// numbers live separately in [FriendStats], since those are read from a
/// different document and refresh far more often.
class FriendProfile {
  final String uid;
  final String displayName;
  final String friendCode;
  final String avatarSeed;
  final bool friendsEnabled;
  final bool showStreak;
  final bool showAyahs;
  final bool showHasanat;

  const FriendProfile({
    required this.uid,
    required this.displayName,
    required this.friendCode,
    required this.avatarSeed,
    required this.friendsEnabled,
    required this.showStreak,
    required this.showAyahs,
    required this.showHasanat,
  });

  factory FriendProfile.fromMap(String uid, Map<String, dynamic> map) => FriendProfile(
        uid: uid,
        displayName: map['displayName'] as String? ?? '',
        friendCode: map['friendCode'] as String? ?? '',
        avatarSeed: map['avatarSeed'] as String? ?? '',
        friendsEnabled: map['friendsEnabled'] as bool? ?? false,
        showStreak: map['showStreak'] as bool? ?? true,
        showAyahs: map['showAyahs'] as bool? ?? true,
        showHasanat: map['showHasanat'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'friendCode': friendCode,
        'avatarSeed': avatarSeed,
        'friendsEnabled': friendsEnabled,
        'showStreak': showStreak,
        'showAyahs': showAyahs,
        'showHasanat': showHasanat,
      };

  FriendProfile copyWith({bool? friendsEnabled, bool? showStreak, bool? showAyahs, bool? showHasanat}) => FriendProfile(
        uid: uid,
        displayName: displayName,
        friendCode: friendCode,
        avatarSeed: avatarSeed,
        friendsEnabled: friendsEnabled ?? this.friendsEnabled,
        showStreak: showStreak ?? this.showStreak,
        showAyahs: showAyahs ?? this.showAyahs,
        showHasanat: showHasanat ?? this.showHasanat,
      );
}

/// A friend's synced activity numbers (stats/{uid} in Firestore) - see
/// FriendProfile for the identity/settings half of a leaderboard row.
class FriendStats {
  final int currentStreak;
  final int longestStreak;
  final int ayahsToday;
  final int hasanatToday;
  final int ayahsThisWeek;
  final int hasanatThisWeek;
  final String? lastActiveDate; // yyyy-MM-dd

  const FriendStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.ayahsToday,
    required this.hasanatToday,
    required this.ayahsThisWeek,
    required this.hasanatThisWeek,
    required this.lastActiveDate,
  });

  static const zero = FriendStats(
    currentStreak: 0,
    longestStreak: 0,
    ayahsToday: 0,
    hasanatToday: 0,
    ayahsThisWeek: 0,
    hasanatThisWeek: 0,
    lastActiveDate: null,
  );

  factory FriendStats.fromMap(Map<String, dynamic> map) => FriendStats(
        currentStreak: map['currentStreak'] as int? ?? 0,
        longestStreak: map['longestStreak'] as int? ?? 0,
        ayahsToday: map['ayahsToday'] as int? ?? 0,
        hasanatToday: map['hasanatToday'] as int? ?? 0,
        ayahsThisWeek: map['ayahsThisWeek'] as int? ?? 0,
        hasanatThisWeek: map['hasanatThisWeek'] as int? ?? 0,
        lastActiveDate: map['lastActiveDate'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'ayahsToday': ayahsToday,
        'hasanatToday': hasanatToday,
        'ayahsThisWeek': ayahsThisWeek,
        'hasanatThisWeek': hasanatThisWeek,
        'lastActiveDate': lastActiveDate,
      };
}

/// One row on the leaderboard: a friend's identity plus their stats, with
/// any field they've hidden already nulled out so the UI never has to
/// re-check a show* flag - it just renders a dash wherever the value is null.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String avatarSeed;
  final int? streak;
  final int? ayahsThisWeek;
  final int? hasanatThisWeek;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatarSeed,
    required this.streak,
    required this.ayahsThisWeek,
    required this.hasanatThisWeek,
  });

  factory LeaderboardEntry.from(FriendProfile profile, FriendStats stats) => LeaderboardEntry(
        uid: profile.uid,
        displayName: profile.displayName,
        avatarSeed: profile.avatarSeed,
        streak: profile.showStreak ? stats.currentStreak : null,
        ayahsThisWeek: profile.showAyahs ? stats.ayahsThisWeek : null,
        hasanatThisWeek: profile.showHasanat ? stats.hasanatThisWeek : null,
      );
}

/// An incoming friend request, shown so the recipient can accept/decline.
class FriendRequest {
  final String fromUid;
  final String fromDisplayName;

  const FriendRequest({required this.fromUid, required this.fromDisplayName});

  factory FriendRequest.fromMap(String fromUid, Map<String, dynamic> map) =>
      FriendRequest(fromUid: fromUid, fromDisplayName: map['fromDisplayName'] as String? ?? '');
}
