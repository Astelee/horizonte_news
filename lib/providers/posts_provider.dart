import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/news_service.dart';

class PostsProvider with ChangeNotifier {
  final NewsService _newsService = NewsService();

  // ── Topo do feed em tempo real ───────────────────────────────────
  // Notícias novas aparecem sozinhas na Home, sem precisar de
  // pull-to-refresh, pois esse trecho da lista é um stream do
  // Firestore em vez de uma leitura única (.get()).
  static const int _liveFeedSize = 12;
  StreamSubscription<List<PostModel>>? _liveFeedSub;
  List<PostModel> _livePosts = [];

  // ── Posts carregados via "carregar mais" (paginação por cursor) ─
  // O Firestore não permite combinar stream com startAfterDocument,
  // então a paginação continua sendo busca única (.get()) e é
  // concatenada depois do trecho ao vivo.
  List<PostModel> _morePosts = [];

  List<PostModel> _categoryPosts = [];
  List<PostModel> _searchResults = [];
  List<PostModel> _videoPosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingVideos = false;
  DocumentSnapshot? _lastDoc;
  String _errorMessage = '';

  /// Feed combinado: topo ao vivo (stream) + páginas carregadas via
  /// "carregar mais", sem duplicar notícias que apareçam nos dois.
  List<PostModel> get posts {
    final seen = <String>{};
    final combined = <PostModel>[];
    for (final p in [..._livePosts, ..._morePosts]) {
      if (seen.add(p.id)) combined.add(p);
    }
    return combined;
  }

  List<PostModel> get categoryPosts => _categoryPosts;
  List<PostModel> get searchResults => _searchResults;
  List<PostModel> get videoPosts => _videoPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingVideos => _isLoadingVideos;
  bool get hasMore => _lastDoc != null;
  String get errorMessage => _errorMessage;

  List<PostModel> get featuredPosts {
    return posts.take(3).toList();
  }

  List<PostModel> get recentPosts {
    return posts.skip(3).toList();
  }

  /// Liga (ou religa) o stream do topo do feed. Chamado ao abrir a
  /// Home e também pelo pull-to-refresh (que força uma nova conexão,
  /// útil se o stream anterior tiver caído por perda de rede).
  Future<void> loadInitialPosts() async {
    _setLoading(true);
    _errorMessage = '';
    _lastDoc = null;
    _morePosts = [];

    await _liveFeedSub?.cancel();

    final completer = Completer<void>();
    _liveFeedSub = _newsService
        .streamLatestPosts(maxResults: _liveFeedSize)
        .listen(
      (incoming) {
        _livePosts = incoming;
        _errorMessage = '';
        if (!completer.isCompleted) {
          _setLoading(false);
          completer.complete();
        } else {
          notifyListeners();
        }
      },
      onError: (e) {
        _errorMessage = e.toString();
        if (!completer.isCompleted) {
          _setLoading(false);
          completer.complete();
        } else {
          notifyListeners();
        }
      },
    );

    // O pull-to-refresh espera essa future: resolve assim que o
    // primeiro snapshot chegar (dados do cache local ou do servidor).
    return completer.future;
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || _isLoadingMore) return;

    // Cursor de paginação: continua a partir do último post já
    // exibido (topo ao vivo + páginas anteriores), não apenas do
    // stream, para não pular nem repetir notícias.
    final lastDoc = _lastDoc ?? await _lastDocOfLivePosts();
    if (lastDoc == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _newsService.fetchPosts(
        startAfter: lastDoc,
        maxResults: 10,
      );

      final List<PostModel> incoming = result['posts'];
      final existingIds = posts.map((p) => p.id).toSet();
      final newPosts =
          incoming.where((p) => !existingIds.contains(p.id)).toList();

      _morePosts.addAll(newPosts);
      _lastDoc = result['lastDoc'];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Busca o DocumentSnapshot do último post ao vivo, para servir de
  /// cursor inicial do "carregar mais" na primeira vez (o stream não
  /// expõe DocumentSnapshot, só os dados já convertidos em PostModel).
  Future<DocumentSnapshot?> _lastDocOfLivePosts() async {
    if (_livePosts.isEmpty) return null;
    return _newsService.fetchDocSnapshotById(_livePosts.last.id);
  }

  @override
  void dispose() {
    _liveFeedSub?.cancel();
    super.dispose();
  }

  Future<void> loadPostsByCategory(String categoryName) async {
    _setLoading(true);
    _errorMessage = '';
    _categoryPosts = [];
    try {
      _categoryPosts = await _newsService.fetchPostsByCategory(categoryName);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── carrega posts pela categoria/label (usado pela tela de Vídeos/Reels) ──
  Future<void> loadPostsByLabel(String label) async {
    if (_isLoadingVideos) return;

    _isLoadingVideos = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await _newsService.fetchPostsByCategory(label);

      final seen = <String>{};
      _videoPosts = results.where((p) => seen.add(p.id)).toList();
    } catch (e) {
      _errorMessage = e.toString();
      _videoPosts = [];
    } finally {
      _isLoadingVideos = false;
      notifyListeners();
    }
  }

  Future<void> refreshVideos() async {
    _videoPosts = [];
    await loadPostsByLabel('Vídeo');
  }

  Future<void> search(String query) async {
    _setLoading(true);
    _errorMessage = '';
    try {
      _searchResults = await _newsService.searchPosts(query);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Busca uma notícia específica por id — usado ao abrir o app a
  /// partir de uma notificação push (deep link).
  Future<PostModel?> fetchById(String postId) {
    return _newsService.fetchById(postId);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}