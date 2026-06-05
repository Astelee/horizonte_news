import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/blogger_service.dart';

class PostsProvider with ChangeNotifier {
  final BloggerService _bloggerService = BloggerService();

  List<PostModel> _posts = [];
  List<PostModel> _categoryPosts = [];
  List<PostModel> _searchResults = [];
  bool _isLoading = false;
  String _nextPageToken = '';
  String _errorMessage = '';

  // Getters para expor os estados de forma segura para as telas
  List<PostModel> get posts => _posts;
  List<PostModel> get categoryPosts => _categoryPosts;
  List<PostModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get hasMore => _nextPageToken.isNotEmpty;
  String get errorMessage => _errorMessage;

  // Filtra as 3 postagens mais recentes para o Carrossel de Destaques
  List<PostModel> get featuredPosts {
    return _posts.take(3).toList();
  }

  // Filtra o restante das postagens para a lista de Últimas Notícias
  List<PostModel> get recentPosts {
    return _posts.skip(3).toList();
  }

  /// Carrega as notícias iniciais do feed principal do Horizonte News
  Future<void> loadInitialPosts() async {
    _setLoading(true);
    _errorMessage = '';
    try {
      final Map<String, dynamic> result = await _bloggerService.fetchPosts(maxResults: 12);
      _posts = result['posts'];
      _nextPageToken = result['nextPageToken'];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega a próxima página de notícias do feed (Scroll Infinito)
  Future<void> loadMorePosts() async {
    if (_isLoading || _nextPageToken.isEmpty) return;

    try {
      final Map<String, dynamic> result = await _bloggerService.fetchPosts(
        pageToken: _nextPageToken,
        maxResults: 10,
      );
      _posts.addAll(result['posts']);
      _nextPageToken = result['nextPageToken'];
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Carrega notícias associadas a uma categoria (marcador) específica
  Future<void> loadPostsByCategory(String categoryName) async {
    _setLoading(true);
    _errorMessage = '';
    _categoryPosts = [];
    try {
      _categoryPosts = await _bloggerService.fetchPostsByCategory(categoryName);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Realiza pesquisa de notícias
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
