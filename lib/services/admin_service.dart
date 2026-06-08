import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;

  // ── Comentários ──────────────────────────────────────────────────

  // CORRIGIDO: busca tudo sem filtro no Firestore, filtra em memória no widget
  Stream<QuerySnapshot> allCommentsStream({
    bool onlyReported = false,
    bool onlyHidden = false,
  }) {
    // Sem where nem orderBy — evita qualquer exigência de índice
    return _db
        .collectionGroup('postComments')
        .limit(200)
        .snapshots();
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

  // ── Suspensões ───────────────────────────────────────────────────

  Future<void> suspendUser(String userId, int days, String reason) async {
    final until = DateTime.now().add(Duration(days: days));
    await _db.collection('suspensions').doc(userId).set({
      'suspended': true,
      'until': Timestamp.fromDate(until),
      'reason': reason,
      'suspendedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'suspendedAt': FieldValue.serverTimestamp(),
    });
    await _logAction('suspend_user', userId,
        extra: {'days': days, 'reason': reason});
  }

  Future<void> unsuspendUser(String userId) async {
    await _db.collection('suspensions').doc(userId).delete();
    await _logAction('unsuspend_user', userId);
  }

  Future<bool> isUserSuspended(String userId) async {
    final doc = await _db.collection('suspensions').doc(userId).get();
    if (!doc.exists) return false;
    final until = (doc.data()?['until'] as Timestamp?)?.toDate();
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  // ── Estatísticas ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    try {
      final usersSnap = await _db.collection('users_xp').get();
      final logsSnap = await _db
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final commentsSnap =
          await _db.collectionGroup('postComments').count().get();
      final reportedSnap = await _db
          .collectionGroup('postComments')
          .where('reportCount', isGreaterThan: 0)
          .count()
          .get();

      final topUsersSnap = await _db
          .collection('users_xp')
          .orderBy('totalXp', descending: true)
          .limit(5)
          .get();

      return {
        'totalUsers': usersSnap.docs.length,
        'totalComments': commentsSnap.count ?? 0,
        'reportedComments': reportedSnap.count ?? 0,
        'recentLogs': logsSnap.docs,
        'topUsers': topUsersSnap.docs,
      };
    } catch (e) {
      return {
        'totalUsers': 0,
        'totalComments': 0,
        'reportedComments': 0,
        'recentLogs': [],
        'topUsers': [],
      };
    }
  }

  Future<void> _logAction(
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
        'postId': postId,
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}