import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/user_xp_provider.dart';
import '../config/app_colors.dart';
import '../utils/blogger_cleaner.dart';
import '../widgets/comments_section.dart';
// ✅ CORRIGIDO: AdminService → AdminViewsService
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
  bool _showFloatingTitle = false;
  bool _articleReadRegistered = false;
  bool _viewRegistered = false;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

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

    _scrollController.addListener(() {
      final show = _scrollController.offset > 220;
      if (show != _showFloatingTitle) {
        setState(() => _showFloatingTitle = show);
      }
      if (!_articleReadRegistered && _scrollController.offset > 300) {
        _articleReadRegistered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Provider.of<UserXpProvider>(context, listen: false)
              .onArticleRead();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerView();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    _authorPulseController.dispose();
    super.dispose();
  }

  Future<void> _registerView() async {
    if (_viewRegistered) return;
    _viewRegistered = true;

    final post =
        ModalRoute.of(context)?.settings.arguments as PostModel?;
    if (post == null) return;

    // ✅ CORRIGIDO: AdminService → AdminViewsService
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
    await Share.share(
        '${post.title}\n\nLeia a matéria completa em: ${post.url}');
    if (!mounted) return;
    Provider.of<UserXpProvider>(context, listen: false)
        .onShare(postId: post.id, postTitle: post.title);
  }

  @override
  Widget build(BuildContext context) {
    final PostModel post =
        ModalRoute.of(context)!.settings.arguments as PostModel;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(post.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String cleanedContent = BloggerCleaner.clean(post.content);
    final String normalizedContent = _normalizeContent(cleanedContent);
    final String category = post.categories.isNotEmpty
        ? post.categories.first.name
        : 'Notícia';
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
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
                              _buildHtmlContent(
                                  context, normalizedContent, isDark),
                              _buildAuthorFooter(),
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

              // Botões glass (visíveis quando imagem está expandida)
              if (!_showFloatingTitle)
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

              // Barra colapsada (aparece ao rolar)
              _buildCollapsedBar(
                  context, post, isFav, favoritesProvider),
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
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      title: null,
      flexibleSpace: FlexibleSpaceBar(
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
  // BARRA COLAPSADA
  // ─────────────────────────────────────────────────────────────
  Widget _buildCollapsedBar(
    BuildContext context,
    PostModel post,
    bool isFav,
    FavoritesProvider favoritesProvider,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: _showFloatingTitle ? 0 : -(topPadding + 80),
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
            top: topPadding + 8, bottom: 8, left: 8, right: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: const Border(
              bottom:
                  BorderSide(color: AppColors.borderDark, width: 1)),
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                post.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
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
              onTap: () => _sharePost(post),
            ),
          ],
        ),
      ),
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
              final count = snap.data?.docs.length ?? 0;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Html(
        data: content,
        style: {
          '*': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: 'Roboto'),
          'body':
              Style(margin: Margins.zero, padding: HtmlPaddings.zero),
          'p': Style(
            fontSize: FontSize(17),
            lineHeight: LineHeight(1.85),
            color: textColor,
            margin: Margins.only(top: 0, bottom: 20),
            padding: HtmlPaddings.zero,
            display: Display.block,
          ),
          'br': Style(
            display: Display.none,
            height: Height(0),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          'h1': Style(
            fontSize: FontSize(22),
            fontWeight: FontWeight.w800,
            color: AppColors.primaryOrange,
            margin: Margins.only(top: 24, bottom: 10),
            display: Display.block,
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.w700,
            color: AppColors.primaryOrangeLight,
            margin: Margins.only(top: 20, bottom: 8),
            display: Display.block,
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w700,
            color: AppColors.primaryOrangeLight,
            margin: Margins.only(top: 16, bottom: 6),
            display: Display.block,
          ),
          'a': Style(
              color: AppColors.primaryOrange,
              textDecoration: TextDecoration.underline),
          'strong':
              Style(fontWeight: FontWeight.w700, color: textColor),
          'b': Style(fontWeight: FontWeight.w700, color: textColor),
          'em': Style(
              fontStyle: FontStyle.italic, color: secondaryColor),
          'blockquote': Style(
            border: Border(
                left: BorderSide(
                    color: AppColors.primaryOrange, width: 3)),
            padding: HtmlPaddings.only(left: 16),
            margin:
                Margins.only(left: 0, right: 0, top: 16, bottom: 20),
            fontStyle: FontStyle.italic,
            color: secondaryColor,
            fontSize: FontSize(16),
          ),
          'ul': Style(
              margin: Margins.only(bottom: 16, left: 4),
              padding: HtmlPaddings.zero),
          'ol': Style(
              margin: Margins.only(bottom: 16, left: 4),
              padding: HtmlPaddings.zero),
          'li': Style(
            fontSize: FontSize(17),
            lineHeight: LineHeight(1.8),
            color: textColor,
            margin: Margins.only(bottom: 8),
          ),
          'img': Style(
            margin: Margins.symmetric(vertical: 16),
            padding: HtmlPaddings.zero,
            display: Display.block,
          ),
          'div':
              Style(margin: Margins.zero, padding: HtmlPaddings.zero),
          'span':
              Style(margin: Margins.zero, padding: HtmlPaddings.zero),
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
