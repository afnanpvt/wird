import 'bookmark.dart';
import 'favorite_ayah.dart';
import 'streak_state.dart';

/// A full snapshot of the locally-tracked reading data that Google backup
/// carries to Firestore and back - everything [BackupService] needs to push
/// or restore in one document (backups/{uid}). Deliberately narrow: reading
/// position/streak/hasanat/bookmarks/saved verses, never which specific
/// ayahs were read when - see the in-app consent copy this mirrors.
class BackupSnapshot {
  final StreakState streakState;
  final int longestStreak;
  final int totalHasanat;
  final int totalReadingSeconds;
  final Map<String, int> dailyLogs;
  final Map<String, int> dailyHasanat;
  final Map<String, int> dailyReadingSeconds;
  final List<Bookmark> bookmarks;
  final List<FavoriteAyah> favorites;

  /// When this snapshot was written, as an ISO date-time string set by the
  /// backing-up device's clock - not a Firestore server timestamp, so it's
  /// readable straight back off the same document without a second round
  /// trip. Null only for a snapshot not yet pushed anywhere.
  final String? backedUpAt;

  const BackupSnapshot({
    required this.streakState,
    required this.longestStreak,
    required this.totalHasanat,
    required this.totalReadingSeconds,
    required this.dailyLogs,
    required this.dailyHasanat,
    required this.dailyReadingSeconds,
    required this.bookmarks,
    required this.favorites,
    required this.backedUpAt,
  });

  Map<String, dynamic> toMap() => {
        'streakState': streakState.toMap(),
        'longestStreak': longestStreak,
        'totalHasanat': totalHasanat,
        'totalReadingSeconds': totalReadingSeconds,
        'dailyLogs': dailyLogs,
        'dailyHasanat': dailyHasanat,
        'dailyReadingSeconds': dailyReadingSeconds,
        'bookmarks': bookmarks.map((b) => b.toMap()).toList(),
        'favorites': favorites.map((f) => f.toMap()).toList(),
        'backedUpAt': backedUpAt,
      };

  factory BackupSnapshot.fromMap(Map<String, dynamic> map) => BackupSnapshot(
        streakState: StreakState.fromMap((map['streakState'] as Map?) ?? const {}),
        longestStreak: map['longestStreak'] as int? ?? 0,
        totalHasanat: map['totalHasanat'] as int? ?? 0,
        totalReadingSeconds: map['totalReadingSeconds'] as int? ?? 0,
        dailyLogs: Map<String, int>.from((map['dailyLogs'] as Map?) ?? const {}),
        dailyHasanat: Map<String, int>.from((map['dailyHasanat'] as Map?) ?? const {}),
        dailyReadingSeconds: Map<String, int>.from((map['dailyReadingSeconds'] as Map?) ?? const {}),
        bookmarks: ((map['bookmarks'] as List?) ?? const [])
            .map((b) => Bookmark.fromMap(Map<String, dynamic>.from(b as Map)))
            .toList(),
        favorites: ((map['favorites'] as List?) ?? const [])
            .map((f) => FavoriteAyah.fromMap(Map<String, dynamic>.from(f as Map)))
            .toList(),
        backedUpAt: map['backedUpAt'] as String?,
      );
}
