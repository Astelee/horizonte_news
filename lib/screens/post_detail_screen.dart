import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/user_xp_provider.dart';
import '../config/app_colors.dart';
import '../widgets/comments_section.dart';
import '../widgets/post_video_player.dart';
import '../features/admin/services/admin_views_service.dart';

// ─────────────────────────────────────────────────────────────────
// UTILITÁRIO DE DATA
// ─────────────────────────────────────────────────────────────────
class DateFormatter {
  static String formatTimeAgo(DateTime postDate) {
    final now = DateTime.now();
    final difference = now.difference(postDate);

    if (difference.inSeconds < 60) return 'Agora';
    if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    }
    if (difference.inHours < 24) {
      return 'Há ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (difference.inDays < 7) {
      return 'Há ${difference.inDays} ${difference.inDays == 1 ? 'dia' : 'dias'}';
    }
    return DateFormat('dd/MM/yyyy · HH:mm').format(postDate);
  }
}

/// Argumentos de navegação para PostDetailScreen quando, além de
/// abrir a notícia, é preciso já abrir a área de comentários e
/// destacar um comentário/resposta específico — caso de notificações
/// de "respondeu ao seu comentário" / "curtiu seu comentário" (ver
/// NotificationService._openPost).
///
/// Continua compatível com o uso normal da tela: quem só passa um
/// PostModel puro como argument (news_card, carrossel, mais lidos,
/// deep link de compartilhamento etc.) não precisa mudar nada — ver
/// _routeArgs, que aceita os dois formatos.
class PostDetailArgs {
  final PostModel post;
  final String? highlightCommentId;
  final String? highlightReplyId;

  const PostDetailArgs({
    required this.post,
    this.highlightCommentId,
    this.highlightReplyId,
  });
}

// ─────────────────────────────────────────────────────────────────
// TELA PRINCIPAL
// ─────────────────────────────────────────────────────────────────
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({Key? key}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _articleReadRegistered = false;
  bool _viewRegistered = false;
  Timer? _articleReadTimer;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  // ── Barra de comentário/resposta fixa no rodapé (estilo Instagram) ──
  // A CommentsSection não desenha mais sua própria barra dentro do
  // scroll do artigo — ela só constrói o widget pronto sob pedido
  // (buildFixedInputBar) e avisa esta tela sempre que os comentários
  // abrem/fecham (onExpandedChanged). Esta tela é quem decide ONDE
  // esse widget aparece: um Positioned fora do CustomScrollView,
  // preso ao rodapé real da tela, que sobe sozinho junto com o
  // teclado porque soma MediaQuery.viewInsets.bottom à sua posição.
  final GlobalKey<CommentsSectionState> _commentsKey =
      GlobalKey<CommentsSectionState>();
  bool _commentsExpanded = false;

  // Chave só do CONTEÚDO da barra fixa (não do Positioned em si) —
  // usada para medir a altura real dela depois de renderizada, e
  // então reservar esse tanto de espaço extra no fim do scroll do
  // artigo/comentários. Sem isso, o último comentário da lista (e o
  // botão "Responder" dele) não conseguem subir alto o suficiente
  // para escapar de trás da barra fixa + do teclado quando abertos
  // perto do fim da lista — a barra cobre por cima e o toque não
  // alcança o que está atrás dela.
  final GlobalKey _fixedBarKey = GlobalKey();
  // Chute inicial plausível para o respiro no fim do scroll, usado
  // só até a primeira medição real da barra chegar (_measureFixedBarHeight
  // roda um frame depois dela aparecer). Sem esse fallback, o respiro
  // começa em 0 no exato momento em que o usuário toca em "Responder"
  // — janela pequena, mas suficiente para o botão tocado ficar preso
  // atrás da barra que acabou de surgir por cima dele. O valor abaixo
  // é generoso de propósito (a barra real costuma ficar bem menor que
  // isso quando não está respondendo) — melhor sobrar um pouco de
  // espaço em branco por uma fração de segundo do que faltar.
  double _fixedBarHeight = 160;

  void _measureFixedBarHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _fixedBarKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if (height > 0 && (height - _fixedBarHeight).abs() > 1) {
        setState(() => _fixedBarHeight = height);
      }
    });
  }

  /// Normaliza os argumentos de rota: aceita tanto um PostModel puro
  /// (uso normal, vindo de news_card/carrossel/deep link/etc.) quanto
  /// um PostDetailArgs (uso vindo de notificação de comentário, que
  /// também carrega qual comentário/resposta destacar).
  PostDetailArgs? get _routeArgs {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is PostDetailArgs) return args;
    if (args is PostModel) return PostDetailArgs(post: args);
    return null;
  }

  late AnimationController _authorPulseController;
  late Animation<double> _authorPulseAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _authorPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _authorPulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _authorPulseController, curve: Curves.easeInOut),
    );

    _scrollController.addListener(_handleScroll);

    // Fallback por tempo: cobre matérias curtas (que cabem na tela
    // sem precisar rolar 300px) e leitores que ficam parados lendo
    // sem rolar. Sem isso, quem lê uma notícia curta nunca disparava
    // onArticleRead — só o gatilho de scroll existia antes.
    _articleReadTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _articleReadRegistered) return;
      _registerArticleRead();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerView();
    });
  }

  void _handleScroll() {
    if (!_articleReadRegistered && _scrollController.offset > 300) {
      _registerArticleRead();
    }
  }

  void _registerArticleRead() {
    if (_articleReadRegistered) return;
    _articleReadRegistered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final post = _routeArgs?.post;
      if (post == null) return;
      Provider.of<UserXpProvider>(context, listen: false)
          .onArticleRead(post.id);
    });
  }

  @override
  void dispose() {
    _articleReadTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _animController.dispose();
    _authorPulseController.dispose();
    super.dispose();
  }

  Future<void> _registerView() async {
    if (_viewRegistered) return;
    _viewRegistered = true;

    final post = _routeArgs?.post;
    if (post == null) return;

    await AdminViewsService().recordUniqueView(
      postId: post.id,
      postTitle: post.title,
    );
  }

  String _normalizeContent(String raw) {
    String html = raw;
    html = html.replaceAllMapped(
      RegExp(r'(<br\s*/?>){1,}', caseSensitive: false),
      (m) => '</p><p>',
    );
    html = html.replaceAll(
      RegExp(r'<p>\s*(&nbsp;)?\s*</p>', caseSensitive: false),
      '',
    );
    if (!html.contains('<p')) html = '<p>$html</p>';
    return html;
  }

  Future<void> _sharePost(PostModel post) async {
    // Link do app (Firebase Hosting) em vez do link do Blogger: quem
    // já tem o app abre a matéria direto (App Link); quem não tem cai
    // numa página que leva à Play Store e, após instalar, abre nessa
    // mesma matéria (deferred deep link via Play Install Referrer).
    final shareUrl =
        'https://horizontenews-6b48f.web.app/noticia/${post.id}';
    await Share.share('${post.title}\n\nLeia a matéria completa em: $shareUrl');
    if (!mounted) return;
    Provider.of<UserXpProvider>(context, listen: false)
        .onShare(postId: post.id, postTitle: post.title);
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = _routeArgs!;
    final PostModel post = routeArgs.post;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(post.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Conteúdo vindo do Firestore já não tem a imagem de capa embutida
    // no HTML (ela fica em post.thumbnailUrl), então o BloggerCleaner
    // — que existe para remover essa duplicação do formato antigo do
    // Blogger — não é mais necessário aqui.
    final String normalizedContent = _normalizeContent(post.content);
    final String category = post.categories.isNotEmpty
        ? post.categories.first.name
        : 'Notícia';
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Sem statusBarColor: descontinuado a partir do Android 15
      // (edge-to-edge obrigatório). Controlamos só o brilho dos ícones.
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // Explícito (é o padrão, mas deixamos claro aqui de propósito):
        // o body precisa encolher quando o teclado abre para que o
        // CustomScrollView saiba até onde pode rolar o campo de
        // comentário para cima do teclado.
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: FadeTransition(
          opacity: _fadeIn,
          child: Stack(
            children: [
              RefreshIndicator(
                color: AppColors.primaryOrange,
                backgroundColor: isDark
                    ? AppColors.backgroundElevated
                    : Colors.white,
                onRefresh: () async {
                  await Provider.of<PostsProvider>(context,
                          listen: false)
                      .loadInitialPosts();
                },
                child: SelectionArea(
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      _buildSliverAppBar(post),
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _buildCategoryBadge(category),
                              _buildTitle(context, post),
                              _buildMeta(context, post),
                              _buildGlowDivider(),
                              if (post.videoUrl != null &&
                                  post.videoUrl!.trim().isNotEmpty)
                                PostVideoPlayer(
                                  videoUrl: post.videoUrl!,
                                  frameConfig: post.videoFrameConfig,
                                ),
                              _buildHtmlContent(
                                  context, normalizedContent, isDark),
                              _buildAuthorFooter(),
                              _buildGlowDivider(),
                              CommentsSection(
                                key: _commentsKey,
                                postId: post.id,
                                postTitle: post.title,
                                highlightCommentId:
                                    routeArgs.highlightCommentId,
                                highlightReplyId:
                                    routeArgs.highlightReplyId,
                                onExpandedChanged: (expanded) {
                                  if (mounted) {
                                    setState(
                                        () => _commentsExpanded = expanded);
                                  }
                                },
                              ),
                              // Respiro no fim do artigo/lista de
                              // comentários. Precisa ser pelo menos do
                              // tamanho da barra fixa (ver
                              // _fixedBarHeight, medida de verdade em
                              // _measureFixedBarHeight) — senão o
                              // último comentário da lista (e o botão
                              // "Responder" dele) não consegue subir
                              // alto o suficiente para escapar de trás
                              // da barra fixa quando ela aparece por
                              // cima do fim do scroll. Não soma
                              // viewInsets.bottom aqui: com
                              // resizeToAvoidBottomInset: true o body
                              // inteiro (logo, este SizedBox também)
                              // já vive numa área que o Flutter já
                              // encolheu para caber acima do teclado,
                              // então viewInsets.bottom já é 0 dentro
                              // deste contexto — somar de novo aqui
                              // não teria efeito nenhum com o teclado
                              // aberto (e daria um respiro exagerado à
                              // toa quando fechado).
                              SizedBox(
                                height: (_commentsExpanded
                                        ? _fixedBarHeight
                                        : 0) +
                                    24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Botões glass (sobre a capa, no topo da matéria).
              // Ficam sempre visíveis e fixos aqui — a barra colapsada
              // que antes deslizava por baixo dela ao rolar foi
              // removida por duplicar os mesmos botões (causava o
              // "piscar" ao trocar de uma para a outra durante o
              // scroll).
              Positioned(
                top: topPadding + 8,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _glassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        _glassButton(
                          icon: isFav
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          onTap: () =>
                              favoritesProvider.toggleFavorite(post),
                          active: isFav,
                        ),
                        const SizedBox(width: 8),
                        _glassButton(
                          icon: Icons.share_rounded,
                          onTap: () => _sharePost(post),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Barra de comentário/resposta, fixa fora do scroll —
              // padrão Instagram: enquanto os comentários estiverem
              // abertos (_commentsExpanded), ela fica presa ao rodapé
              // da TELA (não do artigo). bottom: 0 (sem somar
              // viewInsets.bottom aqui) é intencional: como o Scaffold
              // já tem resizeToAvoidBottomInset: true, o `body` inteiro
              // — e portanto este Stack — já encolhe sozinho para caber
              // acima do teclado quando ele abre; se somássemos
              // viewInsets.bottom de novo aqui, a barra subiria alto
              // demais (a altura do teclado seria descontada duas
              // vezes). Com os comentários fechados, nenhuma barra é
              // desenhada aqui — a única coisa visível nesse estado é o
              // botão "Comentários (N)" dentro do próprio scroll, como
              // antes.
              //
              // O ListenableBuilder escuta o FocusNode do campo (por
              // dentro de CommentsSectionState) porque buildFixedInputBar
              // recalcula seu padding inferior conforme o campo está ou
              // não focado — e um setState dentro de CommentsSection
              // não alcançaria este Positioned, que vive numa subtree
              // irmã aqui no Stack, então escutamos o FocusNode
              // diretamente para saber quando reconstruir.
              if (_commentsExpanded)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: KeyedSubtree(
                    key: _fixedBarKey,
                    child: ListenableBuilder(
                      listenable:
                          _commentsKey.currentState?.inputFocusNode ??
                              ValueNotifier(null),
                      builder: (context, _) {
                        // Remedida a cada rebuild da barra (foco muda,
                        // banner "Respondendo a" aparece/some — a
                        // altura real varia entre esses estados) para
                        // o respiro reservado no fim do scroll (ver
                        // SizedBox logo após CommentsSection) sempre
                        // bater com o tamanho atual da barra.
                        _measureFixedBarHeight();
                        return _commentsKey.currentState
                                ?.buildFixedInputBar(context) ??
                            const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SLIVER APP BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(PostModel post) {
    // Quando não há capa própria e a matéria tem vídeo, o hero do topo
    // é dispensado — o player de verdade (com controles) já aparece
    // no conteúdo logo abaixo do título, e duplicar a prévia aqui em
    // cima (sem poder tocar) só confunde, parecendo um segundo vídeo.
    final bool hasOwnThumbnail = post.thumbnailUrl.trim().isNotEmpty;
    final double expandedHeight = hasOwnThumbnail ? 280 : 0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      title: null,
      flexibleSpace: expandedHeight == 0
          ? null
          : FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _buildHeroImage(post),
            ),
    );
  }

  Widget _buildHeroImage(PostModel post) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: post.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.backgroundElevated,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: AppColors.primaryOrange, strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.backgroundElevated,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_rounded,
                    color: AppColors.primaryOrange, size: 40),
                SizedBox(height: 8),
                Text('Sem imagem',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xFF000000)],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BADGE DE CATEGORIA
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategoryBadge(String category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: AppColors.orangeGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          category.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TÍTULO
  // ─────────────────────────────────────────────────────────────
  Widget _buildTitle(BuildContext context, PostModel post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text(
        post.title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.3,
          letterSpacing: -0.3,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // METADADOS (data + views + comentários)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMeta(BuildContext context, PostModel post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.primaryOrange),
              const SizedBox(width: 5),
              Text(
                DateFormatter.formatTimeAgo(post.publishedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('post_views')
                .doc(post.id)
                .snapshots(),
            builder: (context, snap) {
              final views = (snap.data?.data()
                          as Map<String, dynamic>?)?['uniqueViewers']
                      as int? ??
                  0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_rounded,
                      size: 14, color: AppColors.primaryOrange),
                  const SizedBox(width: 5),
                  Text(
                    _formatCount(views),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('comments')
                .doc(post.id)
                .collection('postComments')
                .snapshots(),
            builder: (context, snap) {
              // Mesmo cuidado do contador "Comentários (N)" dentro da
              // seção de comentários (ver comments_section.dart): esta
              // é uma contagem SEPARADA e independente daquela, então
              // precisava do mesmo ajuste aqui também — contar só
              // docs.length ignora as respostas, que ficam guardadas
              // numa subcoleção replies à parte de cada comentário-
              // raiz. repliesCount já é mantido corretamente em tempo
              // real a cada resposta criada/excluída, então soma-lo
              // aqui dá o total real (comentários-raiz + respostas)
              // sem precisar de uma segunda query nas subcoleções.
              final docs = snap.data?.docs ?? const [];
              final rootCount = docs.length;
              final repliesTotal = docs.fold<int>(0, (sum, doc) {
                final data = doc.data() as Map<String, dynamic>;
                return sum + ((data['repliesCount'] as num?)?.toInt() ?? 0);
              });
              final count = rootCount + repliesTotal;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_rounded,
                      size: 14, color: AppColors.primaryOrange),
                  const SizedBox(width: 5),
                  Text(
                    _formatCount(count),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ─────────────────────────────────────────────────────────────
  // AUTOR (rodapé da matéria, após o texto)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAuthorFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: AnimatedBuilder(
        animation: _authorPulseAnim,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_rounded,
                size: 14,
                color: AppColors.primaryOrange
                    .withOpacity(_authorPulseAnim.value),
              ),
              const SizedBox(width: 6),
              const Text(
                'Redator: ',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Text(
                'Diego Magno',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIVISÓRIA COM GLOW
  // ─────────────────────────────────────────────────────────────
  Widget _buildGlowDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Container(
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.primaryOrange,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTEÚDO HTML
  // ─────────────────────────────────────────────────────────────
  Widget _buildHtmlContent(
      BuildContext context, String content, bool isDark) {
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    String colorToCss(Color c) =>
        'rgba(${c.red}, ${c.green}, ${c.blue}, ${c.opacity})';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: HtmlWidget(
        content,
        textStyle: const TextStyle(fontFamily: 'Roboto'),
        customStylesBuilder: (element) {
          switch (element.localName) {
            case 'p':
              return {
                'font-size': '14.5px',
                'line-height': '1.85',
                'color': colorToCss(secondaryColor),
                'font-weight': 'normal',
                'margin': '0 0 20px 0',
                'display': 'block',
              };
            case 'br':
              return {'display': 'none'};
            case 'h1':
              return {
                'font-size': '22px',
                'font-weight': '800',
                'color': colorToCss(AppColors.primaryOrange),
                'margin': '24px 0 10px 0',
                'display': 'block',
              };
            case 'h2':
              return {
                'font-size': '20px',
                'font-weight': '700',
                'color': colorToCss(AppColors.primaryOrangeLight),
                'margin': '20px 0 8px 0',
                'display': 'block',
              };
            case 'h3':
              return {
                'font-size': '18px',
                'font-weight': '700',
                'color': colorToCss(AppColors.primaryOrangeLight),
                'margin': '16px 0 6px 0',
                'display': 'block',
              };
            case 'a':
              return {
                'color': colorToCss(AppColors.primaryOrange),
                'text-decoration': 'underline',
              };
            case 'strong':
            case 'b':
              return {
                'font-weight': '700',
                'color': colorToCss(textColor),
              };
            case 'em':
              return {
                'font-style': 'italic',
                'color': colorToCss(secondaryColor),
              };
            case 'blockquote':
              return {
                'border-left':
                    '3px solid ${colorToCss(AppColors.primaryOrange)}',
                'padding-left': '16px',
                'margin': '16px 0 20px 0',
                'font-style': 'italic',
                'color': colorToCss(secondaryColor),
                'font-size': '14.5px',
              };
            case 'ul':
            case 'ol':
              return {
                'margin': '0 0 16px 4px',
                'padding': '0',
              };
            case 'li':
              return {
                'font-size': '14.5px',
                'line-height': '1.8',
                'color': colorToCss(secondaryColor),
                'font-weight': 'normal',
                'margin': '0 0 8px 0',
              };
            case 'img':
              return {
                'margin': '16px 0',
                'padding': '0',
                'display': 'block',
              };
            case 'div':
            case 'span':
              return {'margin': '0', 'padding': '0'};
            case 'mark':
              return {
                'background-color': 'transparent',
                'color': colorToCss(AppColors.primaryOrange),
                'font-weight': '800',
                'padding': '0',
                'margin': '0',
              };
            default:
              return null;
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTÃO GLASS
  // ─────────────────────────────────────────────────────────────
  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? AppColors.primaryOrange
                : Colors.white.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: active ? AppColors.primaryOrange : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}