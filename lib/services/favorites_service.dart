import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';

class FavoritesService {
  static const String _favoritesKey = 'horizonte_news_favorites';

  /// Obtém a lista completa de notícias salvas localmente
  Future<List<PostModel>> getFavorites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson == null) return [];

    try {
      final List<dynamic> decodedList = json.decode(favoritesJson);
      return decodedList
          .map((item) => PostModel.fromLocalJson(item))
          .toList();
    } catch (e) {
      // Se houver dados corrompidos ou alteração de formato, reinicializa de forma segura
      return [];
    }
  }

  /// Salva uma lista inteira de favoritos atualizada no armazenamento local
  Future<void> saveFavorites(List<PostModel> favorites) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        favorites.map((post) => post.toLocalJson()).toList();

    await prefs.setString(_favoritesKey, json.encode(jsonList));
  }
}