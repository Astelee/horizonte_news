import 'category_model.dart';

class PostModel {
  final String id;
  final String title;
  final String content;
  final String url;
  final DateTime publishedAt;
  final String thumbnailUrl;
  final List<CategoryModel> categories;
  final String replyCount; // ← NOVO: total de comentários vindo do Blogger

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.url,
    required this.publishedAt,
    required this.thumbnailUrl,
    required this.categories,
    this.replyCount = '0',
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    List<CategoryModel> parsedCategories = [];
    if (json['labels'] != null) {
      parsedCategories = (json['labels'] as List)
          .map((label) => CategoryModel.fromString(label.toString()))
          .toList();
    }

    String extractedThumbnail = '';
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      extractedThumbnail = json['images'][0]['url'];
    } else {
      final RegExp regExp = RegExp(r'<img[^>]+src="([^">]+)"');
      final match = regExp.firstMatch(json['content'] ?? '');
      if (match != null && match.groupCount >= 1) {
        extractedThumbnail = match.group(1)!;
      }
    }

    // Extrai o total de comentários de replies.totalItems
    String replyCount = '0';
    if (json['replies'] != null && json['replies']['totalItems'] != null) {
      replyCount = json['replies']['totalItems'].toString();
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
          : 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=600',
      categories: parsedCategories,
      replyCount: replyCount,
    );
  }
}