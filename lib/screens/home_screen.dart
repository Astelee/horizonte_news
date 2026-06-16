import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/posts_provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../widgets/category_bar.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/breaking_news_banner.dart';
import '../widgets/news_card.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
    });

    _scrollController.addListener(() {
      final postsProvider =
          Provider.of<PostsProvider>(context, listen: false);
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        postsProvider.loadMorePosts();
      }
      final scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Filtra posts que são vídeos para não aparecerem no feed
  bool _isVideoPost(post) {
    return post.categories.any(
      (c) =>
          c.name.toLowerCase() == 'vídeo' ||
          c.name.toLowerCase() == 'video',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      drawer: const AppDrawer(),

      // ── Botão flutuante de Reels ──────────────────────────────
      floatingActionButton: _ReelsFloatingButton(
        onTap: () => Navigator.pushNamed(context, AppRoutes.videos),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          color: AppColors.primaryOrange,
          backgroundColor: AppColors.backgroundElevated,
          strokeWidth: 2.5,
          onRefresh: () async {
            await Provider.of<PostsProvider>(context, listen: false)
                .loadInitialPosts();
          },
          child: Consumer<PostsProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.posts.isEmpty) {
                return _buildLoadingState();
              }
              if (provider.errorMessage.isNotEmpty &&
                  provider.posts.isEmpty) {
                return _buildErrorState(context, provider);
              }

              // ── Filtra vídeos fora do feed ──────────────────
              final feedPosts = provider.posts
                  .where((p) => !_isVideoPost(p))
                  .toList();

              final featuredPosts = feedPosts.take(3).toList();
              final recentPosts =
                  feedPosts.length > 3 ? feedPosts.skip(3).toList() : [];

              final urgentPost = feedPosts.any((p) => p.categories.any(
                      (c) =>
                          c.name.toLowerCase() == 'urgente' ||
                          c.name.toLowerCase() == 'plantão'))
                  ? feedPosts.firstWhere((p) => p.categories.any((c) =>
                      c.name.toLowerCase() == 'urgente' ||
                      c.name.toLowerCase() == 'plantão'))
                  : null;

              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                      child: SizedBox(height: kToolbarHeight + 40)),
                  const SliverToBoxAdapter(child: CategoryBar()),
                  if (urgentPost != null)
                    SliverToBoxAdapter(
                        child:
                            BreakingNewsBanner(urgentPost: urgentPost)),
                  SliverToBoxAdapter(
                    child: FeaturedCarousel(featuredPosts: featuredPosts),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSectionTitle('ÚLTIMAS NOTÍCIAS'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = recentPosts[index];
                        return _AnimatedCardWrapper(
                          index: index,
                          child: NewsCard(post: post),
                        );
                      },
                      childCount: recentPosts.length,
                    ),
                  ),
                  if (provider.hasMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: _NeoLoader()),
                      ),
                    ),
                  // Espaço extra para o botão flutuante não cobrir conteúdo
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _isScrolled
              ? AppColors.backgroundDark.withOpacity(0.95)
              : Colors.transparent,
          border: _isScrolled
              ? const Border(
                  bottom: BorderSide(
                      color: AppColors.borderGlow, width: 1))
              : null,
          boxShadow: _isScrolled
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (context) => _NeoIconButton(
              icon: Icons.menu_rounded,
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 34,
                    errorBuilder: (_, __, ___) => Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.orangeGradient,
                      ),
                      child: const Icon(Icons.public,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.orangeGradient.createShader(bounds),
                child: const Text(
                  'HORIZONTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Text(
                ' NEWS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            _NeoIconButton(
              icon: Icons.search_rounded,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.search),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppColors.orangeVertical,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.borderGlow, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NeoLoader(),
          SizedBox(height: 20),
          Text(
            'Carregando notícias...',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, PostsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.emergencyRed.withOpacity(0.4),
                    width: 1),
                color: AppColors.emergencyRed.withOpacity(0.08),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 36, color: AppColors.emergencyRed),
            ),
            const SizedBox(height: 24),
            const Text(
              'Conexão Indisponível',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Não foi possível atualizar o feed.\nVerifique sua conexão.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => provider.loadInitialPosts(),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'TENTAR NOVAMENTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão flutuante de Reels ─────────────────────────────────────────────────

class _ReelsFloatingButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ReelsFloatingButton({required this.onTap});

  @override
  State<_ReelsFloatingButton> createState() => _ReelsFloatingButtonState();
}

class _ReelsFloatingButtonState extends State<_ReelsFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFBF360C), Color(0xFFE65100), Color(0xFFF57C00)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange
                    .withOpacity(0.5 * _glowAnim.value),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_filled_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'REELS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botão de ícone Neo UI ────────────────────────────────────────────────────

class _NeoIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NeoIconButton({required this.icon, required this.onTap});

  @override
  State<_NeoIconButton> createState() => _NeoIconButtonState();
}

class _NeoIconButtonState extends State<_NeoIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _pressed
              ? AppColors.primaryOrange.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: _pressed
                ? AppColors.primaryOrange.withOpacity(0.5)
                : Colors.transparent,
          ),
        ),
        child: Icon(widget.icon,
            color: _pressed ? AppColors.primaryOrange : Colors.white,
            size: 22),
      ),
    );
  }
}

// ── Loader Neo UI ────────────────────────────────────────────────────────────

class _NeoLoader extends StatefulWidget {
  const _NeoLoader();

  @override
  State<_NeoLoader> createState() => _NeoLoaderState();
}

class _NeoLoaderState extends State<_NeoLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.rotate(
          angle: _ctrl.value * 2 * 3.14159,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  AppColors.primaryOrange,
                  AppColors.primaryOrange.withOpacity(0.0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.backgroundDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wrapper de animação dos cards ────────────────────────────────────────────

class _AnimatedCardWrapper extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCardWrapper(
      {Key? key, required this.index, required this.child})
      : super(key: key);

  @override
  State<_AnimatedCardWrapper> createState() => _AnimatedCardWrapperState();
}

class _AnimatedCardWrapperState extends State<_AnimatedCardWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    final delay = (widget.index * 60).clamp(0, 300);
    Future.delayed(Duration(milliseconds: delay),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
