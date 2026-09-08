import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/post_model.dart';
import '../../../utils/search_normalizer.dart';
import 'push_notification_service.dart';

/// Serviço de gerenciamento de notícias usado pela aba "NOTÍCIAS" do
/// painel ADM. Cobre o CRUD completo — a leitura pública (só notícias
/// publicadas) é feita por NewsService, não por este serviço.
class AdminNewsService {
  final _db = FirebaseFirestore.instance;
  static const String _collection = 'noticias';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  /// Lista todas as notícias (qualquer status), mais recentes
  /// primeiro — usado na listagem do painel ADM.
  Stream<QuerySnapshot<Map<String, dynamic>>> allNewsStream() {
    return _col.orderBy('atualizadoEm', descending: true).snapshots();
  }

  Future<PostModel?> getById(String postId) async {
    final doc = await _col.doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromFirestore(doc);
  }

  /// Cria uma nova notícia. Se [status] for [PostStatus.published],
  /// dispara a notificação via OneSignal logo em seguida. Retorna o
  /// resultado do push (null se não publicou agora) junto do id, para
  /// a tela poder avisar o ADM em caso de falha.
  Future<(String id, PushNotificationResult? pushResult)> createNews(
      PostModel post) async {
    final user = FirebaseAuth.instance.currentUser;
    final postWithAuthor = post.copyWithAuthor(
      authorUid: user?.uid,
      authorName: user?.displayName ?? user?.email,
    );
    final data = postWithAuthor.toFirestoreMap(forCreate: true);
    final doc = await _col.add(data);

    PushNotificationResult? pushResult;
    if (post.status == PostStatus.published) {
      pushResult = await PushNotificationService.notifyPostPublished(
        PostModel(
          id: doc.id,
          title: postWithAuthor.title,
          summary: postWithAuthor.summary,
          content: postWithAuthor.content,
          publishedAt: postWithAuthor.publishedAt,
          thumbnailUrl: postWithAuthor.thumbnailUrl,
          videoUrl: postWithAuthor.videoUrl,
          categories: postWithAuthor.categories,
          status: postWithAuthor.status,
        ),
      );
    }

    return (doc.id, pushResult);
  }

  /// Atualiza uma notícia existente. Se o status mudar para
  /// 'publicado' (e não estava publicado antes), dispara a
  /// notificação via OneSignal. Retorna o resultado do push (null se
  /// não disparou) para a tela poder avisar o ADM em caso de falha.
  Future<PushNotificationResult?> updateNews(
      String postId, PostModel post) async {
    final user = FirebaseAuth.instance.currentUser;
    final data = post.copyWithAuthor(
      authorUid: post.authorUid ?? user?.uid,
      authorName: post.authorName ?? user?.displayName ?? user?.email,
    );

    bool wasPublished = false;
    if (post.status == PostStatus.published) {
      final before = await getById(postId);
      wasPublished = before?.status == PostStatus.published;
    }

    await _col.doc(postId).update(data.toFirestoreMap());

    if (post.status == PostStatus.published && !wasPublished) {
      return PushNotificationService.notifyPostPublished(data);
    }
    return null;
  }

  Future<PushNotificationResult?> setStatus(
      String postId, PostStatus status) async {
    final wasPublished = status == PostStatus.published
        ? (await getById(postId))?.status == PostStatus.published
        : true; // não relevante se não estamos publicando agora

    final data = <String, dynamic>{
      'status': statusToFirestoreString(status),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
    if (status == PostStatus.published) {
      data['publicadoEm'] = FieldValue.serverTimestamp();
    }
    await _col.doc(postId).update(data);

    if (status == PostStatus.published && !wasPublished) {
      final post = await getById(postId);
      if (post != null) {
        return PushNotificationService.notifyPostPublished(post);
      }
    }
    return null;
  }

  Future<void> deleteNews(String postId) async {
    await _col.doc(postId).delete();
  }

  /// Preenche `tituloBusca`/`palavrasBusca` em notícias salvas antes
  /// da busca normalizada existir (esses campos passaram a ser
  /// gravados automaticamente em toda criação/edição a partir de
  /// agora — este método é só para o acervo antigo). Roda uma vez
  /// via botão "Reindexar busca" no painel ADM (Configurações) e
  /// pode ser rodado de novo a qualquer momento sem risco: só
  /// atualiza esses dois campos, nunca o resto da notícia.
  ///
  /// Retorna quantas notícias foram atualizadas.
  Future<int> reindexSearchFields() async {
    final snap = await _col.get();

    var batch = _db.batch();
    var pending = 0;
    var updated = 0;

    for (final doc in snap.docs) {
      final titulo = (doc.data()['titulo'] as String?) ?? '';
      batch.update(doc.reference, {
        'tituloBusca': SearchNormalizer.normalize(titulo),
        'palavrasBusca': SearchNormalizer.tokenize(titulo),
      });
      pending++;
      updated++;

      // Firestore permite no máximo 500 operações por batch.
      if (pending >= 450) {
        await batch.commit();
        batch = _db.batch();
        pending = 0;
      }
    }

    if (pending > 0) {
      await batch.commit();
    }

    return updated;
  }
}