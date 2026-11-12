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
        .limit(300) // posts muito vistos: não baixa milhares de leitores
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

      // Primeira visita deste usuário a este post: o documento do leitor
      // e os contadores vão no MESMO batch (atômico). As regras do
      // Firestore só aceitam +1 nos contadores junto da CRIAÇÃO do
      // documento do leitor — que só pode existir uma vez. Assim:
      //   • duas aberturas simultâneas não contam duas vezes (a segunda
      //     tenta "criar" um documento que já existe e o batch todo é
      //     recusado);
      //   • se uma das escritas falhar, nenhuma é aplicada (antes o leitor
      //     ficava marcado sem o contador subir, ou o contrário).
      final batch = _db.batch();
      batch.set(viewerRef, {
        'userId': user.uid,
        'userName':
            user.displayName ?? user.email?.split('@').first ?? 'Leitor',
        'userEmail': user.email ?? '',
        'postId': postId,
        'postTitle': postTitle,
        'firstViewedAt': FieldValue.serverTimestamp(),
        'lastViewedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        postRef,
        {
          'postId': postId,
          'postTitle': postTitle,
          'totalViews': FieldValue.increment(1),
          'uniqueViewers': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
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

  // ── Reset geral de visualizações ──────────────────────────────────
  // Apaga TODOS os posts em post_views, incluindo a subcoleção
  // 'viewers' de cada um. É necessário apagar 'viewers' antes do
  // documento pai: se sobrar algum viewer órfão, aquele usuário nunca
  // mais vai incrementar totalViews de novo (recordUniqueView só
  // incrementa na primeira vez que o doc do viewer é criado).
  Future<void> resetAllViews() async {
    final postsSnap = await _db.collection('post_views').get();

    for (final postDoc in postsSnap.docs) {
      // Apaga a subcoleção 'viewers' em lotes de 400 (limite de 500
      // operações por batch do Firestore, com margem de segurança).
      QuerySnapshot viewersSnap;
      do {
        viewersSnap = await postDoc.reference
            .collection('viewers')
            .limit(400)
            .get();
        if (viewersSnap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final v in viewersSnap.docs) {
          batch.delete(v.reference);
        }
        await batch.commit();
      } while (viewersSnap.docs.length == 400);

      await postDoc.reference.delete();
    }

    await _log('reset_all_views', postsSnap.docs.length);
  }

  Future<void> _log(String action, int affectedCount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('admin_logs').add({
        'adminUid': user.uid,
        'adminName': user.displayName ?? user.email ?? 'Admin',
        'action': action,
        'targetType': 'post_views',
        'affectedCount': affectedCount,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}