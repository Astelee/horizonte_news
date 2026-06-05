import 'category_model.dart';

class PostModel {
  final String id;
  final String title;
  final String content;
  final String url;
  final DateTime publishedAt;
  final String thumbnailUrl;
  final List<CategoryModel> categories;

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.url,
    required this.publishedAt,
    required this.thumbnailUrl,
    required this.categories,
  });

  // Mapeia o JSON nativo retornado pela Blogger API v3 para o nosso modelo Flutter
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Processamento das categorias (labels) vindo do Blogger
    List<CategoryModel> parsedCategories = [];
    if (json['labels'] != null) {
      parsedCategories = (json['labels'] as List)
          .map((label) => CategoryModel.fromString(label.toString()))
          .toList();
    }

    // Extração inteligente de imagem de destaque de dentro do conteúdo HTML ou mídia
    String extractedThumbnail = '';
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      extractedThumbnail = json['images'][0]['url'];
    } else {
      // Fallback: Tenta buscar a primeira tag <img> dentro do próprio HTML se a chave images falhar
      final RegExp regExp = RegExp(r'<img[^>]+src="([^">]+)"');
      final match = regExp.firstMatch(json['content'] ?? '');
      if (match != null && match.groupCount >= 1) {
        extractedThumbnail = match.group(1)!;
      }
    }

    return PostModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      url: json['url'] ?? '',
      publishedAt: json['published'] != null 
          ? DateTime.parse(json['published']) 
          : DateTime.now(),
      thumbnailUrl: extractedThumbnail.isNotEmpty 
          ? extractedThumbnail 
          : 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=600', // Imagem padrão caso o post seja apenas texto
      categories: parsedCategories,
    );
  }
}
