import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCommentService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> allCommentsStream() {
    return _db
        .collectionGroup('postComments')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Future<void> hideComment(String postId, String commentId) async {
    await _db
        .collection('comments')
        .doc(postId)
        .collection('postComments')
        .doc(commentId)
        .update({
      'hidden': true,
      'hiddenAt': FieldValue.serverTimestamp(),
    });
    await _log('hide_comment', commentId, postId: postId);
  }

  Future<void> restoreComment(String postId, String commentId) async {
    await _db
        .collection('comments')
        .doc(postId)
        .collection('postComments')
        .doc(commentId)
        .update({
      'hidden': false,
      'hiddenAt': FieldValue.delete(),
    });
    await _log('restore_comment', commentId, postId: postId);
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _db
        .collection('comments')
        .doc(postId)
        .collection('postComments')
        .doc(commentId)
        .delete();
    await _log('delete_comment', commentId, postId: postId);
  }

  // ── Reset geral de comentários ─────────────────────────────────────
  // Apaga TODOS os comentários (todos os posts em 'comments') e zera o
  // contador 'stats.commentsPosted' de todo mundo em 'users_xp',
  // incluindo o admin. Isso evita que o painel continue mostrando um
  // número de comentários que não existe mais.
  Future<void> resetAllComments() async {
    final postsSnap = await _db.collection('comments').get();
    int totalDeleted = 0;

    for (final postDoc in postsSnap.docs) {
      QuerySnapshot commentsSnap;
      do {
        commentsSnap = await postDoc.reference
            .collection('postComments')
            .limit(400)
            .get();
        if (commentsSnap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final c in commentsSnap.docs) {
          batch.delete(c.reference);
        }
        await batch.commit();
        totalDeleted += commentsSnap.docs.length;
      } while (commentsSnap.docs.length == 400);

      await postDoc.reference.delete();
    }

    // Zera o contador de comentários no perfil de cada usuário.
    final usersSnap = await _db.collection('users_xp').get();
    for (var i = 0; i < usersSnap.docs.length; i += 400) {
      final chunk = usersSnap.docs.skip(i).take(400);
      final batch = _db.batch();
      for (final userDoc in chunk) {
        batch.set(
          userDoc.reference,
          {
            'stats': {'commentsPosted': 0},
            'dailyMissions': {'commentsPosted': 0},
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }

    await _log('reset_all_comments', 'all', extra: {
      'commentsDeleted': totalDeleted,
      'usersReset': usersSnap.docs.length,
    });
  }

  Future<void> _log(
    String action,
    String targetId, {
    String? postId,
    Map<String, dynamic>? extra,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('admin_logs').add({
        'adminUid': user.uid,
        'adminName': user.displayName ?? user.email ?? 'Admin',
        'action': action,
        'targetId': targetId,
        'targetType': 'comment',
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}