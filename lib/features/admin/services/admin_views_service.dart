import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminViewsService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> mostViewedPostsStream() {
    return _db
        .collection('post_views')
        .orderBy('totalViews', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot> postViewersStream(String postId) {
    return _db
        .collection('post_views')
        .doc(postId)
        .collection('viewers')
        .orderBy('lastViewedAt', descending: true)
        .snapshots();
  }

  Future<void> recordUniqueView({
    required String postId,
    required String postTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final viewerRef = _db
          .collection('post_views')
          .doc(postId)
          .collection('viewers')
          .doc(user.uid);

      final postRef = _db.collection('post_views').doc(postId);
      final existing = await viewerRef.get();

      if (existing.exists) {
        await viewerRef.update({
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      await Future.wait([
        viewerRef.set({
          'userId': user.uid,
          'userName': user.displayName ??
              user.email?.split('@').first ??
              'Leitor',
          'userEmail': user.email ?? '',
          'postId': postId,
          'postTitle': postTitle,
          'firstViewedAt': FieldValue.serverTimestamp(),
          'lastViewedAt': FieldValue.serverTimestamp(),
        }),
        postRef.set({
          'postId': postId,
          'postTitle': postTitle,
          'totalViews': FieldValue.increment(1),
          'uniqueViewers': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);
    } catch (e) {
      // ignore: avoid_print
      print('[AdminViewsService.recordUniqueView] erro: $e');
    }
  }

  Future<Map<String, dynamic>?> getPostViewStats(String postId) async {
    final doc = await _db.collection('post_views').doc(postId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Stream<DocumentSnapshot> postViewStatsStream(String postId) {
    return _db.collection('post_views').doc(postId).snapshots();
  }
}
