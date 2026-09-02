import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/news_service.dart';

class PostsProvider with ChangeNotifier {
  final NewsService _newsService = NewsService();

  List<PostModel> _posts = [];
  List<PostModel> _categoryPosts = [];
  List<PostModel> _searchResults = [];
  List<PostModel> _videoPosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoadingVideos = false;
  DocumentSnapshot? _lastDoc;
  String _errorMessage = '';

  List<PostModel> get posts => _posts;
  List<PostModel> get categoryPosts => _categoryPosts;
  List<PostModel> get searchResults => _searchResults;
  List<PostModel> get videoPosts => _videoPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingVideos => _isLoadingVideos;
  bool get hasMore => _lastDoc != null;
  String get errorMessage => _errorMessage;

  List<PostModel> get featuredPosts {
    return _posts.take(3).toList();
  }

  List<PostModel> get recentPosts {
    return _posts.skip(3).toList();
  }

  Future<void> loadInitialPosts() async {
    _setLoading(true);
    _errorMessage = '';
    _lastDoc = null;
    try {
      final result = await _newsService.fetchPosts(maxResults: 12);
      final List<PostModel> incoming = result['posts'];
      final seen = <String>{};
      _posts = incoming.where((p) => seen.add(p.id)).toList();
      _lastDoc = result['lastDoc'];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || _isLoadingMore || _lastDoc == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _newsService.fetchPosts(
        startAfter: _lastDoc,
        maxResults: 10,
      );

      final List<PostModel> incoming = result['posts'];
      final existingIds = _posts.map((p) => p.id).toSet();
      final newPosts =
          incoming.where((p) => !existingIds.contains(p.id)).toList();

      _posts.addAll(newPosts);
      _lastDoc = result['lastDoc'];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
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