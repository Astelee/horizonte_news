import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_model.dart';

/// Status de publicação de uma notícia.
enum PostStatus { draft, published, unpublished }

PostStatus _statusFromString(String? raw) {
  switch (raw) {
    case 'publicado':
      return PostStatus.published;
    case 'despublicado':
      return PostStatus.unpublished;
    case 'rascunho':
    default:
      return PostStatus.draft;
  }
}

String statusToFirestoreString(PostStatus status) {
  switch (status) {
    case PostStatus.published:
      return 'publicado';
    case PostStatus.unpublished:
      return 'despublicado';
    case PostStatus.draft:
      return 'rascunho';
  }
}

/// Representa uma notícia. A partir da migração do Blogger, a fonte de
/// dados é a coleção `noticias` no Firestore — [fromFirestore] é o
/// construtor principal. [fromJson] (formato do Blogger) é mantido só
/// para compatibilidade com o acervo antigo/import, mas não é mais o
/// caminho usado pelo app em produção.
class PostModel {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String url;
  final DateTime publishedAt;
  final DateTime? updatedAt;
  final String thumbnailUrl;
  final List<String> gallery;
  final String? videoUrl;
  final List<CategoryModel> categories;
  final String replyCount;
  final PostStatus status;
  final String? authorUid;
  final String? authorName;

  PostModel({
    required this.id,
    required this.title,
    this.summary = '',
    required this.content,
    this.url = '',
    required this.publishedAt,
    this.updatedAt,
    required this.thumbnailUrl,
    this.gallery = const [],
    this.videoUrl,
    required this.categories,
    this.replyCount = '0',
    this.status = PostStatus.published,
    this.authorUid,
    this.authorName,
  });

  bool get isPublished => status == PostStatus.published;

  PostModel copyWithAuthor({String? authorUid, String? authorName}) {
    return PostModel(
      id: id,
      title: title,
      summary: summary,
      content: content,
      url: url,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      thumbnailUrl: thumbnailUrl,
      gallery: gallery,
      videoUrl: videoUrl,
      categories: categories,
      replyCount: replyCount,
      status: status,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
    );
  }

  /// Constrói o modelo a partir de um documento da coleção `noticias`
  /// no Firestore.
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    List<CategoryModel> parsedCategories = [];
    final categoriaRaw = data['categoria'];
    if (categoriaRaw is String && categoriaRaw.trim().isNotEmpty) {
      parsedCategories = [CategoryModel.fromString(categoriaRaw)];
    } else if (data['categorias'] is List) {
      parsedCategories = (data['categorias'] as List)
          .map((c) => CategoryModel.fromString(c.toString()))
          .toList();
    }

    List<String> gallery = [];
    if (data['galeria'] is List) {
      gallery = (data['galeria'] as List).map((e) => e.toString()).toList();
    }

    final publishedAt = (data['publicadoEm'] as Timestamp?)?.toDate() ??
        (data['criadoEm'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final updatedAt = (data['atualizadoEm'] as Timestamp?)?.toDate();

    return PostModel(
      id: doc.id,
      title: (data['titulo'] as String?) ?? '',
      summary: (data['resumo'] as String?) ?? '',
      content: (data['conteudo'] as String?) ?? '',
      url: (data['url'] as String?) ?? '',
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      thumbnailUrl: (data['capaUrl'] as String?) ?? '',
      gallery: gallery,
      videoUrl: data['videoUrl'] as String?,
      categories: parsedCategories,
      replyCount: (data['replyCount'] ?? '0').toString(),
      status: _statusFromString(data['status'] as String?),
      authorUid: data['autorUid'] as String?,
      authorName: data['autorNome'] as String?,
    );
  }

  /// Converte o modelo em um mapa pronto para gravar em `noticias`.
  /// [forCreate] adiciona `criadoEm` (server timestamp), usado só ao
  /// criar o documento pela primeira vez.
  Map<String, dynamic> toFirestoreMap({bool forCreate = false}) {
    final map = <String, dynamic>{
      'titulo': title,
      'resumo': summary,
      'conteudo': content,
      'categoria': categories.isNotEmpty ? categories.first.name : '',
      'capaUrl': thumbnailUrl,
      'galeria': gallery,
      'videoUrl': videoUrl,
      'status': statusToFirestoreString(status),
      'autorUid': authorUid,
      'autorNome': authorName,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
    if (forCreate) {
      map['criadoEm'] = FieldValue.serverTimestamp();
    }
    if (status == PostStatus.published) {
      map['publicadoEm'] = Timestamp.fromDate(publishedAt);
    }
    return map;
  }

  /// Serialização usada para persistência local (ex.: favoritos salvos
  /// em SharedPreferences). Independente do formato do Blogger — é só
  /// um snapshot dos campos que a UI de favoritos precisa exibir.
  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'url': url,
      'publishedAt': publishedAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'categories': categories.map((c) => c.name).toList(),
      'replyCount': replyCount,
    };
  }

  factory PostModel.fromLocalJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? '',
      url: json['url'] ?? '',
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'])
          : DateTime.now(),
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      categories: ((json['categories'] as List?) ?? [])
          .map((c) => CategoryModel.fromString(c.toString()))
          .toList(),
      replyCount: (json['replyCount'] ?? '0').toString(),
      status: PostStatus.published,
    );
  }

  /// Mantido para compatibilidade com o acervo antigo do Blogger
  /// (import único) e com testes existentes. Não é mais usado no
  /// fluxo principal do app.
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
      status: PostStatus.published,
    );
  }
}