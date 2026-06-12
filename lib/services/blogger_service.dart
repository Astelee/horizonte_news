import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/blogger_config.dart';
import '../models/post_model.dart';
import '../services/notification_service.dart'; // Import necessário para disparar a notificação

class BloggerService {
  final http.Client _client = http.Client();

  /// Busca as notícias mais recentes do blog de forma paginada.
  Future<Map<String, dynamic>> fetchPosts({String pageToken = '', int maxResults = 10}) async {
    try {
      final String tokenQuery = pageToken.isNotEmpty ? '&pageToken=$pageToken' : '';
      final Uri url = Uri.parse(
        '${BloggerConfig.baseUrl}/${BloggerConfig.blogId}/posts?key=${BloggerConfig.apiKey}&maxResults=$maxResults$tokenQuery&fetchImages=true'
      );

      final http.Response response = await _client.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        
        List<PostModel> posts = items.map((item) => PostModel.fromJson(item)).toList();
        String nextPageToken = data['nextPageToken'] ?? '';

        return {
          'posts': posts,
          'nextPageToken': nextPageToken,
        };
      } else {
        throw Exception('Falha ao carregar notícias do Blogger. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar notícias: $e');
    }
  }

  /// Busca postagens filtradas por uma categoria específica.
  Future<List<PostModel>> fetchPostsByCategory(String categoryName) async {
    try {
      final Uri url = Uri.parse(
        '${BloggerConfig.baseUrl}/${BloggerConfig.blogId}/posts?key=${BloggerConfig.apiKey}&labels=$categoryName&fetchImages=true'
      );

      final http.Response response = await _client.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((item) => PostModel.fromJson(item)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Erro ao filtrar categoria. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar categorias: $e');
    }
  }

  /// Realiza uma busca textual por palavras-chave.
  Future<List<PostModel>> searchPosts(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final Uri url = Uri.parse(
        '${BloggerConfig.baseUrl}/${BloggerConfig.blogId}/posts/search?key=${BloggerConfig.apiKey}&q=$query'
      );

      final http.Response response = await _client.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((item) => PostModel.fromJson(item)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Erro na busca de notícias. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao realizar busca: $e');
    }
  }
}
