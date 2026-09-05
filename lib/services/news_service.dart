import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

/// Serviço de leitura pública de notícias, a partir da coleção
/// `noticias` no Firestore. Só devolve notícias com
/// status == 'publicado' — rascunhos e despublicadas nunca aparecem
/// aqui (essas só são visíveis dentro do painel ADM).
///
/// Substitui o BloggerService como fonte de dados do PostsProvider.
class NewsService {
  final _db = FirebaseFirestore.instance;
  static const String _collection = 'noticias';
  static const String _publishedStatus = 'publicado';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  /// Busca as notícias publicadas mais recentes, paginado por cursor
  /// do último documento (mesmo papel que o pageToken do Blogger).
  Future<Map<String, dynamic>> fetchPosts({
    DocumentSnapshot? startAfter,
    int maxResults = 10,
  }) async {
    Query<Map<String, dynamic>> query = _col
        .where('status', isEqualTo: _publishedStatus)
        .orderBy('publicadoEm', descending: true)
        .limit(maxResults);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final posts = snap.docs.map((d) => PostModel.fromFirestore(d)).toList();

    // Só há mais páginas se essa veio "cheia" (== maxResults).
    // Se veio incompleta, é a última página, mesmo que não-vazia.
    final bool hasMore = snap.docs.length == maxResults;

    return {
      'posts': posts,
      'lastDoc': hasMore && snap.docs.isNotEmpty ? snap.docs.last : null,
    };
  }

  /// Stream em tempo real do topo do feed (as [maxResults] notícias
  /// publicadas mais recentes). Usado pela Home para que uma notícia
  /// nova apareça sozinha, sem precisar de pull-to-refresh.
  ///
  /// Cobre apenas o "topo" do feed — a paginação de "carregar mais"
  /// continua usando [fetchPosts] com cursor, pois misturar stream
  /// com paginação por cursor não é suportado pelo Firestore.
  Stream<List<PostModel>> streamLatestPosts({int maxResults = 12}) {
    return _col
        .where('status', isEqualTo: _publishedStatus)
        .orderBy('publicadoEm', descending: true)
        .limit(maxResults)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PostModel.fromFirestore(d)).toList());
  }

  /// Busca notícias publicadas de uma categoria específica.
  Future<List<PostModel>> fetchPostsByCategory(
    String categoryName, {
    int maxResults = 30,
  }) async {
    final snap = await _col
        .where('status', isEqualTo: _publishedStatus)
        .where('categoria', isEqualTo: categoryName)
        .orderBy('publicadoEm', descending: true)
        .limit(maxResults)
        .get();
    return snap.docs.map((d) => PostModel.fromFirestore(d)).toList();
  }

  /// Busca textual simples por título. Para buscas mais robustas
  /// (full-text) seria necessário um serviço externo (Algolia/
  /// Typesense) — fora do escopo desta etapa.
  Future<List<PostModel>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final snap = await _col
        .where('status', isEqualTo: _publishedStatus)
        .orderBy('titulo')
        .startAt([q]).endAt(['$q\uf8ff']).limit(30).get();
    return snap.docs.map((d) => PostModel.fromFirestore(d)).toList();
  }

  /// Busca uma notícia específica por id (ex.: ao abrir via
  /// notificação push).
  Future<PostModel?> fetchById(String postId) async {
    final doc = await _col.doc(postId).get();
    if (!doc.exists) return null;
    final post = PostModel.fromFirestore(doc);
    return post.isPublished ? post : null;
  }

  /// Busca o DocumentSnapshot bruto de uma notícia pelo id — usado
  /// como cursor de paginação quando a lista atual veio de um
  /// stream (que só expõe PostModel, não o snapshot original).
  Future<DocumentSnapshot<Map<String, dynamic>>?> fetchDocSnapshotById(
      String postId) async {
    final doc = await _col.doc(postId).get();
    return doc.exists ? doc : null;
  }
}