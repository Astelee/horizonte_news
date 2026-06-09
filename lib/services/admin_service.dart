import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;

  // ── Comentários ──────────────────────────────────────────────────

  Stream<QuerySnapshot> allCommentsStream() {
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

  // ── Suspensões / Banimentos ──────────────────────────────────────

  /// Bane um usuário de comentar.
  /// [days] = 0 significa banimento permanente.
  Future<void> suspendUser(String userId, int days, String reason) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'suspended': true,
      'reason': reason,
      'suspendedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'suspendedAt': FieldValue.serverTimestamp(),
    };

    // days == 0 → permanente (sem campo 'until')
    if (days > 0) {
      data['until'] = Timestamp.fromDate(now.add(Duration(days: days)));
    }

    await _db.collection('suspensions').doc(userId).set(data);
    await _logAction('suspend_user', userId,
        extra: {'days': days, 'reason': reason});
  }

  Future<void> unsuspendUser(String userId) async {
    await _db.collection('suspensions').doc(userId).delete();
    await _logAction('unsuspend_user', userId);
  }

  /// Verifica se o usuário está banido e retorna os dados do ban.
  /// Retorna null se não estiver banido.
  Future<Map<String, dynamic>?> getBanData(String userId) async {
    final doc = await _db.collection('suspensions').doc(userId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final until = (data['until'] as Timestamp?)?.toDate();

    // Se tem 'until' e já expirou, considera como não banido
    if (until != null && DateTime.now().isAfter(until)) return null;

    return data;
  }

  /// Verifica apenas se está banido (bool simples).
  Future<bool> isUserSuspended(String userId) async {
    return (await getBanData(userId)) != null;
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

  // ── Log de ações ─────────────────────────────────────────────────

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
