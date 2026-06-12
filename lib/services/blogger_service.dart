import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import '../config/blogger_config.dart';
import '../models/post_model.dart';

class BloggerService {
  final http.Client _client = http.Client();

  // ── Escopos necessários para leitura e escrita no Blogger ──────
  static const _scopes = [
    'https://www.googleapis.com/auth/blogger',
  ];

  // ── Carrega o JSON da conta de serviço e retorna client autenticado
  static Future<http.Client> _serviceAccountClient() async {
    final jsonString = await rootBundle
        .loadString('assets/credentials/service_account.json');
    final credentials = ServiceAccountCredentials.fromJson(
      json.decode(jsonString),
    );
    return clientViaServiceAccount(credentials, _scopes);
  }

  // ── ESCRITA — Criar post no Blogger ───────────────────────────

  Future<PostModel> createPost({
    required String title,
    required String content,
    List<String> labels = const [],
  }) async {
    final authClient = await _serviceAccountClient();

    try {
      final Uri url = Uri.parse(
        'https://www.googleapis.com/blogger/v3/blogs'
        '/${BloggerConfig.blogId}/posts/',
      );

      final body = json.encode({
        'kind': 'blogger#post',
        'title': title,
        'content': content,
        if (labels.isNotEmpty) 'labels': labels,
      });

      final response = await authClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return PostModel.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(
          'Erro ao publicar: '
          '${error['error']?['message'] ?? response.statusCode}',
        );
      }
    } finally {
      authClient.close();
    }
  }

  // ── LEITURA — métodos existentes sem alteração ─────────────────

  Future<Map<String, dynamic>> fetchPosts({
    String pageToken = '',
    int maxResults = 10,
  }) async {
    try {
      final String tokenQuery =
          pageToken.isNotEmpty ? '&pageToken=$pageToken' : '';
      final Uri url = Uri.parse(
        '${BloggerConfig.baseUrl}/${BloggerConfig.blogId}/posts'
        '?key=${BloggerConfig.apiKey}'
        '&maxResults=$maxResults$tokenQuery'
        '&fetchImages=true',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        return {
          'posts': items.map((i) => PostModel.fromJson(i)).toList(),
          'nextPageToken': data['nextPageToken'] ?? '',
        };
      } else {
        throw Exception(
            'Falha ao carregar notícias. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar notícias: $e');
    }
  }

  Future<List<PostModel>> fetchPostsByCategory(String categoryName) async {
    try {
      final Uri url = Uri.parse(
        '${BloggerConfig.baseUrl}/${BloggerConfig.blogId}/posts'
        '?key=${BloggerConfig.apiKey}'
        '&labels=$categoryName'
        '&fetchImages=true',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.map((i) => PostModel.fromJson(i)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(
            'Erro ao filtrar categoria. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar categorias: $e');
    }
  }

  Future<List<PostModel>> searchPosts(String query) async {
    try {
      if (query.isEmpty) return [];

      final Uri url = Uri.parse(
        '${BloggerConfig.baseUrl}/${BloggerConfig.blogId}/posts/search'
        '?key=${BloggerConfig.apiKey}'
        '&q=$query',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        return items.map((i) => PostModel.fromJson(i)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(
            'Erro na busca de notícias. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao realizar busca: $e');
    }
  }
}
