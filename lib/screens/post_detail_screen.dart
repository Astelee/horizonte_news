import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/posts_provider.dart';
import '../config/app_colors.dart';
import '../utils/blogger_cleaner.dart';
import '../widgets/comments_section.dart';

// ─────────────────────────────────────────────────────────────────
// UTILITÁRIO DE DATA
// ─────────────────────────────────────────────────────────────────
class DateFormatter {
  static String formatTimeAgo(DateTime postDate) {
    final now = DateTime.now();
    final difference = now.difference(postDate);

    if (difference.inSeconds < 60) return 'Agora';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'} atrás';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'} atrás';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'dia' : 'dias'} atrás';
    }
    return DateFormat('dd/MM/yyyy · HH:mm').format(postDate);
  }
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
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingTitle = false;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();

    _scrollController.addListener(() {
      final show = _scrollController.offset > 220;
      if (show != _showFloatingTitle) {
        setState(() => _showFloatingTitle = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _readingTime(String content) {
    final text = content.replaceAll(RegExp(r'<[^>]*>'), '');
    final words = text.trim().split(RegExp(r'\s+'));
    final minutes = (words.length / 200).ceil();
    return '$minutes min de leitura';
  }

  @override
  Widget build(BuildContext context) {
    final PostModel post =
        ModalRoute.of(context)!.settings.arguments as PostModel;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(post.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String cleanedContent = BloggerCleaner.clean(post.content);
    final String category = post.categories.isNotEmpty
        ? post.categories.first.name
        : 'Notícia';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: FadeTransition(
          opacity: _fadeIn,
          child: Stack(
            children: [
              // ── CONTEÚDO SCROLLÁVEL ────────────────────────────
              RefreshIndicator(
                color: AppColors.primaryOrange,
                backgroundColor: isDark
                    ? AppColors.backgroundElevated
                    : Colors.white,
                onRefresh: () async {
                  await Provider.of<PostsProvider>(context, listen: false)
                      .loadInitialPosts();
                },
                child: SelectionArea(
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // ── HERO + APPBAR ──────────────────────────
                      _buildSliverAppBar(
                          context, post, isFav, favoritesProvider),

                      // ── CORPO ──────────────────────────────────
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCategoryBadge(category),
                              _buildTitle(context, post),
                              _buildMeta(context, post, cleanedContent),
                              _buildGlowDivider(),
                              _buildHtmlContent(
                                  context, cleanedContent, isDark),
                              _buildGlowDivider(),
                              CommentsSection(
                                postId: post.id,
                                postTitle: post.title,
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── BARRA FLUTUANTE ────────────────────────────────
              _buildFloatingBar(
                  context, post, isFav, favoritesProvider),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SLIVER APP BAR — SEM título, apenas botões glass sobre a imagem
  // ─────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(
    BuildContext context,
    PostModel post,
    bool isFav,
    FavoritesProvider favoritesProvider,
  ) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,   // ← desativa o back padrão
      title: null,                         // ← nunca mostra título aqui
      // ── Substituímos leading + actions por um Row no bottom ──
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: const SizedBox.shrink(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: _buildHeroImage(post),
      ),
    );
  }

  // Overlay de botões glass posicionados sobre a imagem
  // (renderizado no Stack pai, sempre visível enquanto AppBar expandida)
  // Os botões ficam no topo fixo via Stack — veja _buildFloatingBar que
  // já cuida do estado colapsado. Para o estado EXPANDIDO usamos o
  // posicionamento abaixo no Stack principal do build():
  //
  // NOTA: adicionamos os botões diretamente no Stack do build() como
  // _buildExpandedButtons(). Veja abaixo.

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
                  color: AppColors.primaryOrange,
                  strokeWidth: 2,
                ),
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
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
        // Overlay superior
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
        ),
        // Overlay inferior
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
  // METADADOS
  // ─────────────────────────────────────────────────────────────
  Widget _buildMeta(
      BuildContext context, PostModel post, String content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded,
              size: 15, color: AppColors.primaryOrange),
          const SizedBox(width: 5),
          Text(
            DateFormatter.formatTimeAgo(post.publishedAt),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('·',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 16)),
          ),
          const Icon(Icons.menu_book_rounded,
              size: 15, color: AppColors.primaryOrange),
          const SizedBox(width: 5),
          Text(
            _readingTime(content),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Html(
        data: content,
        style: {
          '*': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontFamily: 'Roboto',
          ),
          'p': Style(
            fontSize: FontSize(17),
            lineHeight: LineHeight(1.8),
            color: textColor,
            margin: Margins.only(bottom: 18),
            padding: HtmlPaddings.zero,
          ),
          'br': Style(
            height: Height(0),
            display: Display.none,
          ),
          'h1': Style(
            fontSize: FontSize(22),
            fontWeight: FontWeight.w800,
            color: AppColors.primaryOrange,
            margin: Margins.only(top: 24, bottom: 10),
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.w700,
            color: AppColors.primaryOrangeLight,
            margin: Margins.only(top: 20, bottom: 8),
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w700,
            color: AppColors.primaryOrangeLight,
            margin: Margins.only(top: 16, bottom: 6),
          ),
          'a': Style(
            color: AppColors.primaryOrange,
            textDecoration: TextDecoration.underline,
          ),
          'strong': Style(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          'b': Style(
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          'em': Style(
            fontStyle: FontStyle.italic,
            color: secondaryColor,
          ),
          'blockquote': Style(
            border: Border(
              left: BorderSide(
                color: AppColors.primaryOrange,
                width: 3,
              ),
            ),
            padding: HtmlPaddings.only(left: 16),
            margin: Margins.only(
                left: 0, right: 0, top: 16, bottom: 16),
            fontStyle: FontStyle.italic,
            color: secondaryColor,
            fontSize: FontSize(16),
          ),
          'ul': Style(
            margin: Margins.only(bottom: 16, left: 4),
            padding: HtmlPaddings.zero,
          ),
          'ol': Style(
            margin: Margins.only(bottom: 16, left: 4),
            padding: HtmlPaddings.zero,
          ),
          'li': Style(
            fontSize: FontSize(17),
            lineHeight: LineHeight(1.8),
            color: textColor,
            margin: Margins.only(bottom: 6),
          ),
          'img': Style(
            margin: Margins.symmetric(vertical: 16),
            padding: HtmlPaddings.zero,
          ),
          'div': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'span': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BARRA FLUTUANTE — aparece ao rolar (colapsada) E cobre o
  // estado expandido com botões glass no topo
  // ─────────────────────────────────────────────────────────────
  Widget _buildFloatingBar(
    BuildContext context,
    PostModel post,
    bool isFav,
    FavoritesProvider favoritesProvider,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Botões glass sobre a imagem (sempre visíveis no topo) ──
        Positioned(
          top: topPadding + 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botão Voltar
              _glassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              // Botões direita
              Row(
                children: [
                  _glassButton(
                    icon: isFav
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    onTap: () => favoritesProvider.toggleFavorite(post),
                    active: isFav,
                  ),
                  const SizedBox(width: 8),
                  _glassButton(
                    icon: Icons.share_rounded,
                    onTap: () => Share.share(
                      '${post.title}\n\nLeia a matéria completa em: ${post.url}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Barra sólida ao colapsar (scroll > 220) ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          top: _showFloatingTitle ? 0 : -80,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: topPadding + 8,
              bottom: 8,
              left: 8,
              right: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.95),
              border: const Border(
                bottom: BorderSide(color: AppColors.borderDark, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _glassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _glassButton(
                  icon: isFav
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onTap: () => favoritesProvider.toggleFavorite(post),
                  active: isFav,
                ),
                const SizedBox(width: 8),
                _glassButton(
                  icon: Icons.share_rounded,
                  onTap: () => Share.share(
                    '${post.title}\n\nLeia a matéria completa em: ${post.url}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
