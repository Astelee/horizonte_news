import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCommentService {
  final _db = FirebaseFirestore.instance;

  // ── Comentários-raiz ─────────────────────────────────────────────
  // Mantido com o mesmo tipo de retorno (Stream<QuerySnapshot>) porque
  // o contador do dashboard (overview_tab) também consome este stream.
  Stream<QuerySnapshot> allCommentsStream() {
    return _db
        .collectionGroup('postComments')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  // ── Respostas ────────────────────────────────────────────────────
  // As respostas ficam em comments/{postId}/postComments/{commentId}/
  // replies/{replyId} — uma subcoleção À PARTE, que o collectionGroup
  // ('postComments') acima nunca enxerga. Por isso a aba de
  // comentários só mostrava os comentários-raiz.
  //
  // Sem orderBy de propósito: ordenar um collectionGroup exige um
  // índice de escopo "collection group" criado à mão no console do
  // Firebase, e sem ele a query falha com erro. A ordenação é feita
  // no cliente (ver AdminCommentThreads.merge). O limit protege o
  // plano gratuito (Spark) de leituras demais.
  Stream<QuerySnapshot> allRepliesStream() {
    return _db.collectionGroup('replies').limit(300).snapshots();
  }

  // ── Referência de um comentário-raiz ou de uma resposta ─────────
  // parentCommentId != null  → é uma resposta (subcoleção replies).
  DocumentReference _ref(
    String postId,
    String commentId, {
    String? parentCommentId,
  }) {
    final base =
        _db.collection('comments').doc(postId).collection('postComments');
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      return base
          .doc(parentCommentId)
          .collection('replies')
          .doc(commentId);
    }
    return base.doc(commentId);
  }

  Future<void> hideComment(
    String postId,
    String commentId, {
    String? parentCommentId,
  }) async {
    await _ref(postId, commentId, parentCommentId: parentCommentId).update({
      'hidden': true,
      'hiddenAt': FieldValue.serverTimestamp(),
    });
    await _log('hide_comment', commentId,
        postId: postId, parentCommentId: parentCommentId);
  }

  Future<void> restoreComment(
    String postId,
    String commentId, {
    String? parentCommentId,
  }) async {
    await _ref(postId, commentId, parentCommentId: parentCommentId).update({
      'hidden': false,
      'hiddenAt': FieldValue.delete(),
    });
    await _log('restore_comment', commentId,
        postId: postId, parentCommentId: parentCommentId);
  }

  // Excluir uma RESPOSTA também precisa decrementar o repliesCount do
  // comentário-pai (igual ao app faz em _deleteReply) — senão o
  // contador "N respostas" do app público fica maior que o real.
  // Excluir um comentário-RAIZ leva junto as respostas dele: no
  // Firestore, apagar o documento pai NÃO apaga a subcoleção, e as
  // respostas ficariam órfãs (invisíveis no app, mas ainda aparecendo
  // aqui no painel e ocupando espaço).
  Future<void> deleteComment(
    String postId,
    String commentId, {
    String? parentCommentId,
  }) async {
    // Checagem direta de `!= null` (e não via uma variável booleana):
    // só assim o Dart promove `parentCommentId` de String? para String
    // dentro do bloco.
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      await _ref(postId, commentId, parentCommentId: parentCommentId)
          .delete();
      try {
        await _ref(postId, parentCommentId).update({
          'repliesCount': FieldValue.increment(-1),
        });
      } catch (_) {
        // Pai já não existe mais (ex.: excluído em paralelo) — nada a
        // corrigir.
      }
    } else {
      await _deleteAllReplies(_ref(postId, commentId));
      await _ref(postId, commentId).delete();
    }

    await _log('delete_comment', commentId,
        postId: postId, parentCommentId: parentCommentId);
  }

  // ── Título da publicação onde o comentário foi feito ────────────
  // Notícias novas ficam em noticias/{postId}.titulo. Posts do
  // acervo antigo (Blogger) não existem lá, mas o título deles foi
  // guardado em post_views/{postId}.postTitle quando alguém os leu.
  // O resultado é cacheado por postId: uma notícia com 30 comentários
  // faz UMA leitura, não 30.
  final Map<String, Future<PostRef>> _postCache = {};

  Future<PostRef> resolvePost(String postId) {
    if (postId.isEmpty) return Future.value(PostRef.unknown(postId));
    return _postCache.putIfAbsent(postId, () async {
      final ref = await _fetchPost(postId);
      // Não "cola" um resultado desconhecido no cache: pode ter sido
      // só uma falha de rede momentânea, e o admin ficaria vendo
      // "Publicação indisponível" até fechar o painel.
      if (!ref.exists) _postCache.remove(postId);
      return ref;
    });
  }

  Future<PostRef> _fetchPost(String postId) async {
    try {
      final news = await _db.collection('noticias').doc(postId).get();
      if (news.exists) {
        final t = (news.data()?['titulo'] as String?)?.trim();
        if (t != null && t.isNotEmpty) {
          return PostRef(id: postId, title: t, exists: true);
        }
      }
    } catch (_) {}
    try {
      final views = await _db.collection('post_views').doc(postId).get();
      if (views.exists) {
        final t = (views.data()?['postTitle'] as String?)?.trim();
        if (t != null && t.isNotEmpty) {
          return PostRef(id: postId, title: t, exists: true);
        }
      }
    } catch (_) {}
    return PostRef.unknown(postId);
  }

  // ── Perfil do autor ──────────────────────────────────────────────
  // Uma leitura (Future) por uid, compartilhada entre todos os tiles
  // do mesmo autor: um usuário com 20 comentários faz UMA leitura de
  // users_xp/{uid}, não 20.
  //
  // Por que Future e não stream ao vivo: um snapshots() "broadcast"
  // não repete o último valor para quem se inscreve depois, então um
  // tile que surge ao rolar a lista ficaria preso em "carregando". E
  // abrir um listener por autor gastaria leituras do plano Spark sem
  // necessidade — o painel já é atualizado quando a lista muda.
  // Puxar para atualizar (ver comments_tab) limpa este cache.
  final Map<String, Future<Map<String, dynamic>?>> _authorCache = {};

  Future<Map<String, dynamic>?> authorProfile(String uid) {
    return _authorCache.putIfAbsent(uid, () async {
      try {
        final doc = await _db.collection('users_xp').doc(uid).get();
        if (doc.exists) return doc.data();
      } catch (_) {}
      // Falha ou perfil inexistente: não cacheia, para tentar de novo
      // na próxima vez que o tile for montado.
      _authorCache.remove(uid);
      return null;
    });
  }

  /// Descarta os caches de perfil e de título de publicação — chamado
  /// pelo "puxar para atualizar" para o admin ver dados recém-editados
  /// (nível novo, foto aprovada etc.).
  void clearCaches() {
    _authorCache.clear();
    _postCache.clear();
  }

  // ── Reset geral de comentários e contadores de leitura ──────────────
  // Apaga TODOS os comentários (todos os posts em 'comments') e zera,
  // no perfil de cada usuário em 'users_xp' (incluindo o admin):
  //  - stats.commentsPosted
  //  - stats.articlesRead / stats.articlesReadIds
  //  - stats.articlesShared / stats.articlesSharedIds
  // Os arrays *Ids precisam ser zerados junto com o contador: eles são
  // a trava de unicidade que o app usa pra não dar XP duas vezes pelo
  // mesmo artigo (ver XpService._alreadyAwarded). Se só o número fosse
  // zerado, o contador nunca mais subiria para artigos já lidos antes
  // do reset.
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

        // Apagar o documento pai NÃO apaga a subcoleção `replies`: sem
        // este passo, as respostas ficariam órfãs no Firestore — e,
        // como a aba de comentários agora lista respostas, elas
        // continuariam aparecendo no painel mesmo após o reset.
        for (final c in commentsSnap.docs) {
          totalDeleted += await _deleteAllReplies(c.reference);
        }

        final batch = _db.batch();
        for (final c in commentsSnap.docs) {
          batch.delete(c.reference);
        }
        await batch.commit();
        totalDeleted += commentsSnap.docs.length;
      } while (commentsSnap.docs.length == 400);

      await postDoc.reference.delete();
    }

    // Zera os contadores de comentários, artigos lidos e artigos
    // compartilhados no perfil de cada usuário — junto com os arrays
    // de IDs que travam a contagem (articlesReadIds/articlesSharedIds).
    // Sem zerar os arrays, o app nunca voltaria a contar uma leitura
    // ou compartilhamento de um artigo que o usuário já tinha lido
    // antes do reset (ver XpService._alreadyAwarded).
    final usersSnap = await _db.collection('users_xp').get();
    for (var i = 0; i < usersSnap.docs.length; i += 400) {
      final chunk = usersSnap.docs.skip(i).take(400);
      final batch = _db.batch();
      for (final userDoc in chunk) {
        batch.set(
          userDoc.reference,
          {
            'stats': {
              'commentsPosted': 0,
              'articlesRead': 0,
              'articlesReadIds': <String>[],
              'articlesShared': 0,
              'articlesSharedIds': <String>[],
            },
            'dailyMissions': {
              'commentsPosted': 0,
              'articlesRead': 0,
              'articlesShared': 0,
            },
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

  /// Apaga TODAS as respostas de um comentário-raiz, em lotes de 400
  /// (limite do Firestore é 500 operações por batch). Devolve quantas
  /// respostas foram apagadas.
  Future<int> _deleteAllReplies(DocumentReference commentRef) async {
    int deleted = 0;
    QuerySnapshot snap;
    do {
      snap = await commentRef.collection('replies').limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final r in snap.docs) {
        batch.delete(r.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
    } while (snap.docs.length == 400);
    return deleted;
  }

  Future<void> _log(
    String action,
    String targetId, {
    String? postId,
    String? parentCommentId,
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
        'targetType': parentCommentId != null ? 'reply' : 'comment',
        'postId': postId,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}

/// Publicação (notícia) onde um comentário foi feito.
class PostRef {
  final String id;
  final String title;

  /// false quando não foi possível descobrir o título (notícia
  /// removida ou nunca visualizada por ninguém).
  final bool exists;

  const PostRef({
    required this.id,
    required this.title,
    required this.exists,
  });

  factory PostRef.unknown(String id) =>
      PostRef(id: id, title: '', exists: false);
}

/// Um item da lista de moderação: um comentário-raiz OU uma resposta,
/// já com os dados necessários para exibir e moderar.
class AdminCommentItem {
  final String id;
  final String postId;

  /// Preenchido só quando o item é uma resposta.
  final String? parentCommentId;
  final Map<String, dynamic> data;

  /// Texto do comentário-pai (só para respostas, quando conhecido).
  final String? parentText;
  final String? parentAuthorName;

  const AdminCommentItem({
    required this.id,
    required this.postId,
    required this.data,
    this.parentCommentId,
    this.parentText,
    this.parentAuthorName,
  });

  bool get isReply => parentCommentId != null;
  bool get isHidden => data['hidden'] == true;

  DateTime get createdAt =>
      (data['createdAt'] as Timestamp?)?.toDate() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// Junta comentários-raiz e respostas numa única lista cronológica.
class AdminCommentThreads {
  AdminCommentThreads._();

  static List<AdminCommentItem> merge({
    required List<QueryDocumentSnapshot> roots,
    required List<QueryDocumentSnapshot> replies,
  }) {
    // Índice dos comentários-raiz por id, para as respostas
    // mostrarem "em resposta a <fulano>: <trecho>".
    final rootById = <String, Map<String, dynamic>>{};
    final items = <AdminCommentItem>[];

    for (final doc in roots) {
      final data = doc.data() as Map<String, dynamic>;
      rootById[doc.id] = data;
      // .../comments/{postId}/postComments/{commentId}
      final parts = doc.reference.path.split('/');
      final postId = parts.length >= 2 ? parts[1] : '';
      items.add(AdminCommentItem(id: doc.id, postId: postId, data: data));
    }

    for (final doc in replies) {
      final data = doc.data() as Map<String, dynamic>;
      // .../comments/{postId}/postComments/{parentId}/replies/{replyId}
      final parts = doc.reference.path.split('/');
      // Só aceita o caminho exato de uma resposta de comentário;
      // qualquer outra coleção que um dia se chame "replies" no
      // projeto é ignorada em vez de virar item falso na lista.
      if (parts.length != 6 ||
          parts[0] != 'comments' ||
          parts[2] != 'postComments' ||
          parts[4] != 'replies') {
        continue;
      }
      final postId = parts[1];
      final parentId = parts[3];
      final parent = rootById[parentId];
      items.add(AdminCommentItem(
        id: doc.id,
        postId: postId,
        parentCommentId: parentId,
        data: data,
        parentText: parent == null
            ? null
            : (parent['text'] ?? '').toString(),
        parentAuthorName: parent == null
            ? null
            : (parent['userName'] ?? '').toString(),
      ));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}