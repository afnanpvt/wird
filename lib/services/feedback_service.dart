import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FeedbackCategory { bug, suggestion, other }

/// Feedback submission - completely separate from the Friends feature,
/// though it shares the same Firebase project and (for now) the same
/// FeatureFlags.friendsEnabled gate, since both need Firebase and neither
/// is wired into the public build yet. See FriendsService's class doc for
/// why anonymous auth is used instead of email/password: same reasoning
/// applies here - this needs no identity, just a way to write to
/// Firestore under the current security rules (which require
/// request.auth != null for any write).
class FeedbackService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> submit({required String message, required FeedbackCategory category}) async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    await _firestore.collection('feedback').add({
      'message': message,
      'category': category.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }
}
