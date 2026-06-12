import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'xp_service.dart';

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
    await _logAction('suspend_user', userId,
        extra: {'days': days, 'reason': reason});
  }

  Future<void> unsuspendUser(String userId) async {
    await _db.collection('suspensions').doc(userId).delete();
    await _logAction('unsuspend_user', userId);
  }

  Future<Map<String, dynamic>?> getBanData(String userId) async {
    final doc = await _db.collection('suspensions').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final until = (data['until'] as Timestamp?)?.toDate();
    if (until != null && DateTime.now().isAfter(until)) return null;
    return data;
  }

  Future<bool> isUserSuspended(String userId) async {
    return (await getBanData(userId)) != null;
  }

  Future<void> syncAllUserLevels() async {
    final snap = await _db.collection('users_xp').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final xp = (doc.data()['totalXp'] as num?)?.toInt() ?? 0;
      final correctLevel = XpService.levelFromXp(xp);
      batch.update(doc.reference, {'level': correctLevel});
    }
    await batch.commit();
  }

  // ── Visualizações ────────────────────────────────────────────────

  /// Registra que um usuário visualizou uma matéria.
  /// Salva em: post_views/{postId}/viewers/{userId}
  Future<void> recordPostView({
    required String postId,
    required String postTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final viewRef = _db
          .collection('post_views')
          .doc(postId)
          .collection('viewers')
          .doc(user.uid);

      final existing = await viewRef.get();

      if (existing.exists) {
        // Já visualizou antes — apenas atualiza o contador e timestamp
        await viewRef.update({
          'viewCount': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Primeira visualização deste usuário nesta matéria
        await viewRef.set({
          'userId': user.uid,
          'userName': user.displayName ?? user.email?.split('@').first ?? 'Leitor',
          'userEmail': user.email ?? '',
          'postId': postId,
          'postTitle': postTitle,
          'viewCount': 1,
          'firstViewedAt': FieldValue.serverTimestamp(),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });

        // Incrementa contador total da matéria
        await _db.collection('post_views').doc(postId).set({
          'postId': postId,
          'postTitle': postTitle,
          'totalViews': FieldValue.increment(1),
          'uniqueViewers': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Sempre incrementa o total de views (mesmo visitante voltando)
      await _db.collection('post_views').doc(postId).update({
        'totalViews': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Busca todos os visualizadores de uma matéria específica.
  Stream<QuerySnapshot> postViewersStream(String postId) {
    return _db
        .collection('post_views')
        .doc(postId)
        .collection('viewers')
        .orderBy('lastViewedAt', descending: true)
        .snapshots();
  }

  /// Busca as matérias mais visualizadas (para o painel admin).
  Stream<QuerySnapshot> mostViewedPostsStream() {
    return _db
        .collection('post_views')
        .orderBy('totalViews', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Busca total de visualizações de uma matéria.
  Future<Map<String, dynamic>?> getPostViewStats(String postId) async {
    final doc = await _db.collection('post_views').doc(postId).get();
    if (!doc.exists) return null;
    return doc.data();
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
