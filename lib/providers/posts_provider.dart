import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/blogger_service.dart';

class PostsProvider with ChangeNotifier {
  final BloggerService _bloggerService = BloggerService();

  List<PostModel> _posts = [];
  List<PostModel> _categoryPosts = [];
  List<PostModel> _searchResults = [];
  bool _isLoading = false;
  bool _isLoadingMore = false; // ← proteção contra chamadas duplicadas
  String _nextPageToken = '';
  String _errorMessage = '';

  List<PostModel> get posts => _posts;
  List<PostModel> get categoryPosts => _categoryPosts;
  List<PostModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _nextPageToken.isNotEmpty;
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
    _nextPageToken = '';
    try {
      final Map<String, dynamic> result =
          await _bloggerService.fetchPosts(maxResults: 12);
      // Deduplica por ID ao carregar inicial
      final List<PostModel> incoming = result['posts'];
      final seen = <String>{};
      _posts = incoming.where((p) => seen.add(p.id)).toList();
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMorePosts() async {
    // Bloqueia se já está carregando mais ou se não há próxima página
    if (_isLoading || _isLoadingMore || _nextPageToken.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final Map<String, dynamic> result = await _bloggerService.fetchPosts(
        pageToken: _nextPageToken,
        maxResults: 10,
      );

      final List<PostModel> incoming = result['posts'];

      // Deduplica: só adiciona posts que ainda não existem na lista
      final existingIds = _posts.map((p) => p.id).toSet();
      final newPosts =
          incoming.where((p) => !existingIds.contains(p.id)).toList();

      _posts.addAll(newPosts);
      _nextPageToken = result['nextPageToken'];
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
      _categoryPosts =
          await _bloggerService.fetchPostsByCategory(categoryName);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> search(String query) async {
    _setLoading(true);
    _errorMessage = '';
    try {
      _searchResults = await _bloggerService.searchPosts(query);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}