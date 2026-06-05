import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/favorites_service.dart';

class FavoritesProvider with ChangeNotifier {
  final FavoritesService _favoritesService = FavoritesService();
  List<PostModel> _favorites = [];

  List<PostModel> get favorites => _favorites;

  FavoritesProvider() {
    _loadFavorites();
  }

  /// Carrega os dados salvos do cache para a memória
  Future<void> _loadFavorites() async {
    _favorites = await _favoritesService.getFavorites();
    notifyListeners();
  }

  /// Verifica se uma determinada notícia já foi favoritada pelo leitor
  bool isFavorite(String postId) {
    return _favorites.any((post) => post.id == postId);
  }

  /// Alterna o estado de favorito de um post (Adiciona ou Remove)
  Future<void> toggleFavorite(PostModel post) async {
    final bool exists = isFavorite(post.id);
    
    if (exists) {
      _favorites.removeWhere((item) => item.id == post.id);
    } else {
      _favorites.add(post);
    }
    
    notifyListeners();
    await _favoritesService.saveFavorites(_favorites);
  }
}
