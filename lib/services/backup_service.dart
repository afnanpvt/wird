import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/backup_snapshot.dart';

enum BackupSignInOutcome { signedIn, cancelled }

/// Google Sign-In-backed backup/restore, entirely separate from
/// [FriendsService] even though both sit on the same free Firebase project -
/// a device may have Backup on without ever touching Friends, or vice versa.
/// Only ever constructed behind FeatureFlags.backupEnabled - see that flag's
/// doc for why (Google Sign-In needs Firebase-console setup this repo can't
/// do on its own before it can work at all).
///
/// Deliberately narrow in what it stores: reading streak/hasanat/day-by-day
/// stats/bookmarks/saved verses - never which specific ayahs were read when,
/// and never anything from the Friends feature (name/avatar/friend graph
/// stay local to that feature's own Firestore documents).
class BackupService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  /// True once this device is signed in with an actual Google account - not
  /// just the plain anonymous session Friends might already have created.
  bool get isSignedIn => _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  String? get accountEmail => _auth.currentUser?.email;

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('BackupService used before a successful signInWithGoogle()');
    return _firestore.collection('backups').doc(uid);
  }

  /// Signs in with Google and attaches it to this device's Firebase Auth
  /// user. If this device already has an anonymous session (e.g. Friends is
  /// also enabled here), the Google credential is *linked* to it rather than
  /// replacing it - same uid before and after, so nothing already synced
  /// under that uid (a Friends profile, an earlier backup) gets orphaned.
  ///
  /// If that Google account already has a Firebase user from signing in
  /// elsewhere (a second device, or a reinstall after the first device's
  /// local data - but not its backup - was lost), linking fails with
  /// `credential-already-in-use`: this signs in AS that existing account
  /// instead, on purpose - that's the whole point of backup, recovering the
  /// account a previous device already created.
  Future<BackupSignInOutcome> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return BackupSignInOutcome.cancelled;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final current = _auth.currentUser;
    try {
      if (current != null && current.isAnonymous) {
        await current.linkWithCredential(credential);
      } else {
        await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') rethrow;
      await _auth.signInWithCredential(credential);
    }
    return BackupSignInOutcome.signedIn;
  }

  /// Signs out of both Google and Firebase. The backup itself is untouched -
  /// signing back in with the same Google account picks up right where this
  /// left off. Local reading data on this device is never touched either.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Deletes the Firestore backup document, then signs out - the in-app half
  /// of the account/data-deletion path Google Play's account-deletion policy
  /// requires alongside the privacy policy's web-based request option. Local
  /// reading data on this device is untouched; this only removes the copy
  /// that was uploaded.
  Future<void> deleteBackupAndSignOut() async {
    if (_auth.currentUser != null) {
      try {
        await _doc.delete();
      } catch (_) {
        // Best-effort: if this fails offline, signing out still stops any
        // further sync, and the doc can be deleted on next sign-in retry.
      }
    }
    await signOut();
  }

  /// Best-effort, fire-and-forget push - never awaited by callers, never
  /// throws into the reading flow. Matches FriendsService.syncStats.
  Future<void> pushBackup(BackupSnapshot snapshot) async {
    if (_auth.currentUser == null) return;
    try {
      await _doc.set(snapshot.toMap());
    } catch (_) {
      // Best-effort: next read/backup-triggering event retries.
    }
  }

  Future<BackupSnapshot?> fetchBackup() async {
    final snap = await _doc.get();
    if (!snap.exists) return null;
    return BackupSnapshot.fromMap(snap.data()!);
  }
}
