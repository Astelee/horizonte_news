import 'package:cloud_firestore/cloud_firestore.dart';
import 'category_model.dart';
import '../utils/search_normalizer.dart';

/// Status de publicação de uma notícia.
enum PostStatus { draft, published, unpublished }

/// Como o player deve exibir o vídeo da matéria.
///
/// [original] mantém a proporção real do arquivo (nada é cortado, mas
/// pode ficar bem alto em vídeos verticais). Os presets fixos
/// ([ratio16x9], [ratio1x1], [ratio4x5], [ratio9x16]) cortam o vídeo
/// (cover) para caber numa caixa com essa proporção — o enquadramento
/// (o que fica visível dentro do corte) é controlado por [offsetX] e
/// [offsetY]. [custom] é o modo de recorte livre: usa [aspectRatio],
/// [zoom], [offsetX] e [offsetY] definidos manualmente no editor.
enum VideoFramePreset { original, ratio16x9, ratio1x1, ratio4x5, ratio9x16, custom }

/// Configuração completa de como o vídeo deve ser enquadrado/cortado
/// ao ser exibido. [offsetX]/[offsetY] vão de -1.0 a 1.0 e representam
/// o quanto o enquadramento é deslocado a partir do centro (0,0) do
/// vídeo original, nas direções horizontal e vertical. [zoom] é o
/// fator de ampliação aplicado antes do corte (1.0 = sem zoom extra).
class VideoFrameConfig {
  final VideoFramePreset preset;
  final double customAspectRatio; // usado só quando preset == custom
  final double zoom;
  final double offsetX;
  final double offsetY;

  const VideoFrameConfig({
    this.preset = VideoFramePreset.original,
    this.customAspectRatio = 16 / 9,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  static const original = VideoFrameConfig(preset: VideoFramePreset.original);

  /// A proporção (largura/altura) da caixa de exibição para presets
  /// fixos. Para [VideoFramePreset.original] e [VideoFramePreset.custom]
  /// a proporção depende do vídeo ou da escolha livre do usuário, então
  /// retorna null (quem chama decide o que usar nesses casos).
  double? get fixedAspectRatio {
    switch (preset) {
      case VideoFramePreset.ratio16x9:
        return 16 / 9;
      case VideoFramePreset.ratio1x1:
        return 1.0;
      case VideoFramePreset.ratio4x5:
        return 4 / 5;
      case VideoFramePreset.ratio9x16:
        return 9 / 16;
      case VideoFramePreset.original:
      case VideoFramePreset.custom:
        return null;
    }
  }

  bool get isCropped => preset != VideoFramePreset.original;

  VideoFrameConfig copyWith({
    VideoFramePreset? preset,
    double? customAspectRatio,
    double? zoom,
    double? offsetX,
    double? offsetY,
  }) {
    return VideoFrameConfig(
      preset: preset ?? this.preset,
      customAspectRatio: customAspectRatio ?? this.customAspectRatio,
      zoom: zoom ?? this.zoom,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  factory VideoFrameConfig.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return VideoFrameConfig.original;
    return VideoFrameConfig(
      preset: _videoFramePresetFromString(raw['preset'] as String?),
      customAspectRatio:
          (raw['customAspectRatio'] as num?)?.toDouble() ?? 16 / 9,
      zoom: (raw['zoom'] as num?)?.toDouble() ?? 1.0,
      offsetX: (raw['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (raw['offsetY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preset': _videoFramePresetToString(preset),
      'customAspectRatio': customAspectRatio,
      'zoom': zoom,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
  }
}

VideoFramePreset _videoFramePresetFromString(String? raw) {
  switch (raw) {
    case 'ratio16x9':
      return VideoFramePreset.ratio16x9;
    case 'ratio1x1':
      return VideoFramePreset.ratio1x1;
    case 'ratio4x5':
      return VideoFramePreset.ratio4x5;
    case 'ratio9x16':
      return VideoFramePreset.ratio9x16;
    case 'custom':
      return VideoFramePreset.custom;
    // Compatibilidade com o campo antigo `videoAspectMode`, que só
    // tinha "compact" (equivalente ao preset 16:9) e "original".
    case 'compact':
      return VideoFramePreset.ratio16x9;
    case 'original':
    default:
      return VideoFramePreset.original;
  }
}

String _videoFramePresetToString(VideoFramePreset preset) {
  switch (preset) {
    case VideoFramePreset.ratio16x9:
      return 'ratio16x9';
    case VideoFramePreset.ratio1x1:
      return 'ratio1x1';
    case VideoFramePreset.ratio4x5:
      return 'ratio4x5';
    case VideoFramePreset.ratio9x16:
      return 'ratio9x16';
    case VideoFramePreset.custom:
      return 'custom';
    case VideoFramePreset.original:
      return 'original';
  }
}

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
  final VideoFrameConfig videoFrameConfig;
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
    this.videoFrameConfig = VideoFrameConfig.original,
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
      videoFrameConfig: videoFrameConfig,
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
      videoFrameConfig: data['videoFrameConfig'] is Map
          ? VideoFrameConfig.fromMap(
              Map<String, dynamic>.from(data['videoFrameConfig'] as Map))
          // Posts antigos só tinham o campo `videoAspectMode` (string
          // "compact"/"original"); o parser do preset já sabe convertê-lo.
          : VideoFrameConfig(
              preset:
                  _videoFramePresetFromString(data['videoAspectMode'] as String?),
            ),
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
      'videoFrameConfig': videoFrameConfig.toMap(),
      // Mantido por compatibilidade com versões antigas do app que só
      // leem `videoAspectMode` (string). Ignorado pelo app atual.
      'videoAspectMode':
          videoFrameConfig.preset == VideoFramePreset.original
              ? 'original'
              : 'compact',
      'status': statusToFirestoreString(status),
      'autorUid': authorUid,
      'autorNome': authorName,
      'atualizadoEm': FieldValue.serverTimestamp(),
      // Campos auxiliares só para busca (não exibidos na UI):
      // - tituloBusca: só o título, normalizado — usado na busca por
      //   prefixo (útil quando o usuário digita o começo do título).
      // - palavrasBusca: tokens de título + resumo + categoria, usados
      //   na busca por qualquer palavra (array-contains-any). Inclui a
      //   categoria para que buscar, por ex., "Política" encontre toda
      //   notícia dessa categoria, mesmo que a palavra não apareça no
      //   título.
      'tituloBusca': SearchNormalizer.normalize(title),
      'palavrasBusca': SearchNormalizer.tokenize(
        [
          title,
          summary,
          categories.isNotEmpty ? categories.first.name : '',
        ].join(' '),
      ),
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