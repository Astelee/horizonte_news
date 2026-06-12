import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'xp_service.dart';
import 'notification_service.dart'; // Import para disparar notificações

class AdminService {
  final _db = FirebaseFirestore.instance;

  // ── Comentários ──────────────────────────────────────────────────
  Stream<QuerySnapshot> allCommentsStream() {
    return _db.collectionGroup('postComments').limit(200).snapshots();
  }

  Future<void> hideComment(String postId, String commentId) async {
    await _db
        .collection('comments')
        .doc(postId)
        .collection('postComments')
        .doc(commentId)
        .update({'hidden': true, 'hiddenAt': FieldValue.serverTimestamp()});
    await _logAction('hide_comment', commentId, postId: postId);
  }

  Future<void> restoreComment(String postId, String commentId) async {
    await _db
        .collection('comments')
        .doc(postId)
        .collection('postComments')
        .doc(commentId)
        .update({'hidden': false, 'hiddenAt': FieldValue.delete()});
    await _logAction('restore_comment', commentId, postId: postId);
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _db
        .collection('comments')
        .doc(postId)
        .collection('postComments')
        .doc(commentId)
        .delete();
    await _logAction('delete_comment', commentId, postId: postId);
  }

  // ── Suspensões / Banimentos ──────────────────────────────────────
  Future<void> suspendUser(String userId, int days, String reason) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'suspended': true,
      'reason': reason,
      'suspendedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'suspendedAt': FieldValue.serverTimestamp(),
    };

    if (days > 0) {
      data['until'] = Timestamp.fromDate(now.add(Duration(days: days)));
    }

    await _db.collection('suspensions').doc(userId).set(data);
    await _logAction('suspend_user', userId, extra: {'days': days, 'reason': reason});

    // Opcional: Notificar o usuário que ele foi suspenso
    await NotificationService.sendAutoNotification(
      "Aviso Horizonte News", 
      "Sua conta foi suspensa por: $reason"
    );
  }

  Future<void> unsuspendUser(String userId) async {
    await _db.collection('suspensions').doc(userId).delete();
    await _logAction('unsuspend_user', userId);
  }

  // ── Visualizações e Stats ────────────────────────────────────────

  Future<void> recordPostView({required String postId, required String postTitle}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final viewRef = _db.collection('post_views').doc(postId).collection('viewers').doc(user.uid);
      final existing = await viewRef.get();

      if (existing.exists) {
        await viewRef.update({
          'viewCount': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await viewRef.set({
          'userId': user.uid,
          'userName': user.displayName ?? 'Leitor',
          'postId': postId,
          'postTitle': postTitle,
          'viewCount': 1,
          'firstViewedAt': FieldValue.serverTimestamp(),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
        await _db.collection('post_views').doc(postId).set({
          'postId': postId,
          'postTitle': postTitle,
          'totalViews': FieldValue.increment(1),
          'uniqueViewers': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
      await _db.collection('post_views').doc(postId).update({
        'totalViews': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final usersSnap = await _db.collection('users_xp').get();
      final commentsSnap = await _db.collectionGroup('postComments').count().get();
      return {
        'totalUsers': usersSnap.docs.length,
        'totalComments': commentsSnap.count ?? 0,
      };
    } catch (e) {
      return {'totalUsers': 0, 'totalComments': 0};
    }
  }

  // ── Log de ações ─────────────────────────────────────────────────
  Future<void> _logAction(String action, String targetId, {String? postId, Map<String, dynamic>? extra}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('admin_logs').add({
        'adminUid': user.uid,
        'action': action,
        'targetId': targetId,
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}
