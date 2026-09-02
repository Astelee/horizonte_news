import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/post_model.dart';

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
  /// a Cloud Function notifyNewPost dispara automaticamente a
  /// notificação via OneSignal.
  Future<String> createNews(PostModel post) async {
    final user = FirebaseAuth.instance.currentUser;
    final data = post
        .copyWithAuthor(
          authorUid: user?.uid,
          authorName: user?.displayName ?? user?.email,
        )
        .toFirestoreMap(forCreate: true);
    final doc = await _col.add(data);
    return doc.id;
  }

  /// Atualiza uma notícia existente. Se o status mudar de rascunho/
  /// despublicada para 'publicado', a Cloud Function
  /// notifyPostPublished dispara a notificação.
  Future<void> updateNews(String postId, PostModel post) async {
    final user = FirebaseAuth.instance.currentUser;
    final data = post.copyWithAuthor(
      authorUid: post.authorUid ?? user?.uid,
      authorName: post.authorName ?? user?.displayName ?? user?.email,
    );
    await _col.doc(postId).update(data.toFirestoreMap());
  }

  Future<void> setStatus(String postId, PostStatus status) async {
    final data = <String, dynamic>{
      'status': statusToFirestoreString(status),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
    if (status == PostStatus.published) {
      data['publicadoEm'] = FieldValue.serverTimestamp();
    }
    await _col.doc(postId).update(data);
  }

  Future<void> deleteNews(String postId) async {
    await _col.doc(postId).delete();
  }
}