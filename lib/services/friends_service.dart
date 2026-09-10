import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import '../models/friend_profile.dart';
import 'hive_service.dart';

/// Firebase-backed friends graph, profile, and stats sync. Every method is
/// a no-op-safe wrapper around Firestore/Auth calls - see the design spec
/// (docs/superpowers/specs/2026-09-09-friends-social-design.md) for the
/// data model and the reasoning behind staying on the free Spark plan (no
/// Cloud Functions, no FCM: friend-accept is a rules-gated client write,
/// and nudges are detected client-side rather than pushed).
///
/// Only ever constructed/used behind FeatureFlags.friendsEnabled - nothing
/// here runs, and no Firebase project is contacted, unless that flag (and
/// the user's own Friends opt-in, see [hasProfile]) is true.
class FriendsService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _rng = Random.secure();
  static const _friendCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Box get _throttleBox => Hive.box(HiveBoxes.friendNudgeThrottle);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('FriendsService used before ensureSignedIn()');
    return user.uid;
  }

  /// Anonymous sign-in - no email/password, no UI. Safe to call repeatedly;
  /// Firebase Auth returns the same persisted anonymous user on every call
  /// after the first, so this is also how every other method gets its uid.
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  DocumentReference<Map<String, dynamic>> get _ownProfileDoc => _firestore.collection('users').doc(_uid);
  DocumentReference<Map<String, dynamic>> get _ownStatsDoc => _firestore.collection('stats').doc(_uid);

  /// Whether this device has ever completed profile setup (picked an
  /// avatar). This - not any separate on/off flag - is what "opted in"
  /// means: see the design spec's "Feature entry point" section.
  Future<bool> hasProfile() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _ownProfileDoc.get();
    return doc.exists;
  }

  Future<FriendProfile?> getOwnProfile() async {
    final doc = await _ownProfileDoc.get();
    if (!doc.exists) return null;
    return FriendProfile.fromMap(_uid, doc.data()!);
  }

  String _generateFriendCode() =>
      'WIRD-${List.generate(5, (_) => _friendCodeChars[_rng.nextInt(_friendCodeChars.length)]).join()}';

  // A modest, pleasant word-pair rather than "reader_4821" - still fully
  // anonymous (no PII), just nicer to look at on a leaderboard.
  static const _usernameAdjectives = ['noble', 'quiet', 'gentle', 'humble', 'steady', 'patient', 'sincere', 'devoted'];
  static const _usernameNouns = ['seeker', 'reader', 'listener', 'traveler', 'reciter', 'companion'];

  /// A candidate username the setup screen shows before the profile is
  /// actually created, so the user can reroll it (see [generateUsername])
  /// until they like one, rather than it being silently assigned. Purely
  /// client-side/local until [createProfile] actually writes it.
  String generateUsername() {
    final adjective = _usernameAdjectives[_rng.nextInt(_usernameAdjectives.length)];
    final noun = _usernameNouns[_rng.nextInt(_usernameNouns.length)];
    return '$adjective-$noun-${10 + _rng.nextInt(90)}';
  }

  /// One-time profile creation - publishes this device's already-chosen
  /// local avatar (see AppState.avatarSeed / models/avatar_seeds.dart) and
  /// the username the user confirmed on the setup screen (see
  /// [generateUsername]) to Firestore under a freshly generated friend
  /// code. This is what "opting in to Friends" actually does now:
  /// avatar/name already exist locally regardless of Friends (see the
  /// design spec's "Feature entry point" section, revised) - this call
  /// just publishes them. Retries friend-code generation on the
  /// (practically negligible) chance of a collision with an existing code.
  Future<FriendProfile> createProfile({required String avatarSeed, required String username}) async {
    await ensureSignedIn();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateFriendCode();
      final existing = await _firestore.collection('users').where('friendCode', isEqualTo: code).limit(1).get();
      if (existing.docs.isNotEmpty) continue;

      final profile = FriendProfile(
        uid: _uid,
        username: username,
        friendCode: code,
        avatarSeed: avatarSeed,
        friendsEnabled: true,
        showStreak: true,
        showAyahs: true,
        showHasanat: true,
      );
      await _ownProfileDoc.set({...profile.toMap(), 'createdAt': FieldValue.serverTimestamp()});
      return profile;
    }
    throw StateError('Could not generate a unique friend code after 5 attempts');
  }

  /// Keeps the published avatar in sync if the user changes it later from
  /// the Profile screen, after Friends is already enabled.
  Future<void> updateAvatarSeed(String avatarSeed) async {
    if (_auth.currentUser == null) return;
    final doc = await _ownProfileDoc.get();
    if (!doc.exists) return;
    await _ownProfileDoc.update({'avatarSeed': avatarSeed});
  }

  Future<void> setOnline(bool online) => _ownProfileDoc.update({'friendsEnabled': online});

  Future<void> setFieldVisibility({bool? showStreak, bool? showAyahs, bool? showHasanat}) {
    final updates = <String, dynamic>{};
    if (showStreak != null) updates['showStreak'] = showStreak;
    if (showAyahs != null) updates['showAyahs'] = showAyahs;
    if (showHasanat != null) updates['showHasanat'] = showHasanat;
    if (updates.isEmpty) return Future.value();
    return _ownProfileDoc.update(updates);
  }

  /// Pushes this device's local stats up to Firestore. Best-effort and
  /// fire-and-forget by design (see design spec's error-handling section):
  /// callers should not await failures blocking the reading UI, so this
  /// swallows network errors rather than throwing.
  Future<void> syncStats({
    required int currentStreak,
    required int longestStreak,
    required int ayahsToday,
    required int hasanatToday,
    required int ayahsThisWeek,
    required int hasanatThisWeek,
    required String lastActiveDate,
  }) async {
    // No-op until this device has opted in (see hasProfile) - never
    // provisions an account or touches the network on its own.
    if (_auth.currentUser == null) return;
    try {
      await _ownStatsDoc.set({
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'ayahsToday': ayahsToday,
        'hasanatToday': hasanatToday,
        'ayahsThisWeek': ayahsThisWeek,
        'hasanatThisWeek': hasanatThisWeek,
        'lastActiveDate': lastActiveDate,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort: next sync opportunity (app resume, next read) retries.
    }
  }

  /// Sends a friend request by code. Throws [ArgumentError] if no user has
  /// that code (surfaced to the UI as "code not found").
  Future<void> sendFriendRequestByCode(String friendCode) async {
    final normalized = friendCode.trim().toUpperCase();
    final matches = await _firestore.collection('users').where('friendCode', isEqualTo: normalized).limit(1).get();
    if (matches.docs.isEmpty) throw ArgumentError('No user with that friend code');
    final targetUid = matches.docs.first.id;
    if (targetUid == _uid) throw ArgumentError("That's your own code");

    final myProfile = await getOwnProfile();
    await _firestore.collection('friendRequests').doc(targetUid).collection('incoming').doc(_uid).set({
      'fromUsername': myProfile?.username ?? '',
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<FriendRequest>> incomingRequests() => _firestore
      .collection('friendRequests')
      .doc(_uid)
      .collection('incoming')
      .snapshots()
      .map((snap) => snap.docs.map((d) => FriendRequest.fromMap(d.id, d.data())).toList());

  /// One-shot fetch, for contexts that just need a snapshot (the periodic
  /// background check) rather than a live stream.
  Future<List<FriendRequest>> incomingRequestsOnce() async {
    final snap = await _firestore.collection('friendRequests').doc(_uid).collection('incoming').get();
    return snap.docs.map((d) => FriendRequest.fromMap(d.id, d.data())).toList();
  }

  /// Accepts an incoming request: writes the friends/{uid} entry symmetrically
  /// on both sides in one batch, then removes the request. Firestore
  /// Security Rules constrain this so a client can only ever write a
  /// friends/{myUid}/... entry for itself and for the specific uid it holds
  /// a pending incoming request from - see the design spec's "Adding
  /// friends" section for why this needs no Cloud Function.
  Future<void> acceptFriendRequest(String fromUid) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(_firestore.collection('users').doc(_uid).collection('friends').doc(fromUid), {'since': now});
    batch.set(_firestore.collection('users').doc(fromUid).collection('friends').doc(_uid), {'since': now});
    batch.delete(_firestore.collection('friendRequests').doc(_uid).collection('incoming').doc(fromUid));
    await batch.commit();
  }

  Future<void> declineFriendRequest(String fromUid) =>
      _firestore.collection('friendRequests').doc(_uid).collection('incoming').doc(fromUid).delete();

  Stream<List<String>> friendUids() => _firestore
      .collection('users')
      .doc(_uid)
      .collection('friends')
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toList());

  /// Removes a friend on both sides - a plain relationship-management
  /// action, not a privacy setting (see design spec's "Privacy model").
  Future<void> removeFriend(String friendUid) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('users').doc(_uid).collection('friends').doc(friendUid));
    batch.delete(_firestore.collection('users').doc(friendUid).collection('friends').doc(_uid));
    await batch.commit();
  }

  Future<FriendProfile?> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return FriendProfile.fromMap(uid, doc.data()!);
  }

  Future<FriendStats> getStats(String uid) async {
    final doc = await _firestore.collection('stats').doc(uid).get();
    if (!doc.exists) return FriendStats.zero;
    return FriendStats.fromMap(doc.data()!);
  }

  /// Once-per-friend-per-day nudge throttle, kept locally (Hive) rather than
  /// synced - only this device ever needs to know whether it has already
  /// shown itself a nudge about a given friend today. See design spec's
  /// "Notification flow".
  bool alreadyNotifiedToday(String friendUid, String today) => _throttleBox.get(friendUid) == today;

  Future<void> markNotifiedToday(String friendUid, String today) => _throttleBox.put(friendUid, today);

  // Same throttle box, a distinct key prefix - a friend-request notification
  // should fire once ever per request, not once per day, so this is a
  // simple seen/not-seen flag rather than a date comparison.
  String _requestNotifiedKey(String fromUid) => 'request_notified_$fromUid';

  bool alreadyNotifiedOfRequest(String fromUid) => _throttleBox.get(_requestNotifiedKey(fromUid)) == true;

  Future<void> markNotifiedOfRequest(String fromUid) => _throttleBox.put(_requestNotifiedKey(fromUid), true);
}
