import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/posts_provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../widgets/category_bar.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/breaking_news_banner.dart';
import '../widgets/news_card.dart';
import '../widgets/app_drawer.dart';
import 'chat_screen.dart';
import 'amigos_modelos.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeCtrl;
  late AnimationController _headerParticleCtrl;
  late AnimationController _sectionLineCtrl;
  late Animation<double> _fadeAnim;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _headerParticleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _sectionLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
    });

    _scrollController.addListener(() {
      final provider = Provider.of<PostsProvider>(context, listen: false);
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        provider.loadMorePosts();
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
    _fadeCtrl.dispose();
    _headerParticleCtrl.dispose();
    _sectionLineCtrl.dispose();
    super.dispose();
  }

  bool _isVideoPost(post) => post.categories.any(
        (c) =>
            c.name.toLowerCase() == 'vídeo' ||
            c.name.toLowerCase() == 'video',
      );

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      drawer: const AppDrawer(),
      // Sem floatingActionButton — botão Reels removido
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
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
                    return _buildSkeletonState();
                  }
                  if (provider.errorMessage.isNotEmpty &&
                      provider.posts.isEmpty) {
                    return _buildErrorState(context, provider);
                  }

                  final feedPosts =
                      provider.posts.where((p) => !_isVideoPost(p)).toList();
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
                        child: SizedBox(height: kToolbarHeight + 50),
                      ),
                      const SliverToBoxAdapter(child: CategoryBar()),
                      if (urgentPost != null)
                        SliverToBoxAdapter(
                          child: BreakingNewsBanner(urgentPost: urgentPost),
                        ),
                      SliverToBoxAdapter(
                        child: FeaturedCarousel(featuredPosts: featuredPosts),
                      ),
                      SliverToBoxAdapter(
                        child: _buildSectionTitle('ÚLTIMAS NOTÍCIAS'),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _AnimatedCardWrapper(
                            index: index,
                            child: NewsCard(post: recentPosts[index]),
                          ),
                          childCount: recentPosts.length,
                        ),
                      ),
                      if (provider.hasMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: _NeoLoader()),
                          ),
                        ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 80)),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Bolha flutuante de mensagem nova ──────────────────
          if (myUid.isNotEmpty)
            _BolhaMensagem(myUid: myUid),
        ],
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
              ? AppColors.backgroundDark.withOpacity(0.96)
              : Colors.transparent,
          border: _isScrolled
              ? const Border(
                  bottom:
                      BorderSide(color: AppColors.borderGlow, width: 1))
              : null,
          boxShadow: _isScrolled
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            if (!_isScrolled)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _headerParticleCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _HeaderParticlePainter(
                      progress: _headerParticleCtrl.value,
                    ),
                  ),
                ),
              ),
            AppBar(
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
            child: AnimatedBuilder(
              animation: _sectionLineCtrl,
              builder: (_, __) {
                final progress = _sectionLineCtrl.value;
                return Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryOrange.withOpacity(0.6),
                        AppColors.primaryOrangeLight.withOpacity(0.8),
                        AppColors.primaryOrange.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      stops: [
                        (progress - 0.3).clamp(0.0, 1.0),
                        progress.clamp(0.0, 1.0),
                        (progress + 0.1).clamp(0.0, 1.0),
                        (progress + 0.3).clamp(0.0, 1.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonState() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: kToolbarHeight + 40),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 6,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 10),
                width: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF111111),
                  border: Border.all(color: const Color(0xFF1E1E1E)),
                ),
                child: const _SkeletonShimmer(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            height: 218,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF0F0F0F),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              child: _SkeletonShimmer(),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _SkeletonCard(delay: i * 80),
            childCount: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, PostsProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                  width: 1,
                ),
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
                  fontWeight: FontWeight.bold),
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

// ═══════════════════════════════════════════════════════════════════
// BOLHA FLUTUANTE DE MENSAGEM NOVA
// ═══════════════════════════════════════════════════════════════════
class _BolhaMensagem extends StatefulWidget {
  final String myUid;
  const _BolhaMensagem({required this.myUid});

  @override
  State<_BolhaMensagem> createState() => _BolhaMensagemState();
}

class _BolhaMensagemState extends State<_BolhaMensagem>
    with TickerProviderStateMixin {
  // Animações
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _sairCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _entryAnim;
  late Animation<double> _sairAnim;

  // Dados da mensagem
  _DadosBolha? _dadosAtual;
  bool _visivel = false;
  bool _dispensada = false;

  // Guarda o último chatId lido para não reaparecer
  String? _ultimoChatAberto;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _sairCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entryAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.elasticOut,
    );

    _sairAnim = CurvedAnimation(
      parent: _sairCtrl,
      curve: Curves.easeInBack,
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _entryCtrl.dispose();
    _sairCtrl.dispose();
    super.dispose();
  }

  // Chamado pelo StreamBuilder quando chega mensagem nova
  void _mostrar(_DadosBolha dados) {
    if (!mounted) return;
    if (_dadosAtual?.chatId == dados.chatId &&
        _dadosAtual?.ultimaMsgId == dados.ultimaMsgId) return;
    if (_ultimoChatAberto == dados.chatId) return;

    setState(() {
      _dadosAtual = dados;
      _visivel = true;
      _dispensada = false;
    });
    _sairCtrl.reset();
    _entryCtrl.forward(from: 0);

    // Auto-dispensa após 6 segundos
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _visivel && !_dispensada) _dispensar();
    });
  }

  void _dispensar() {
    if (!mounted || !_visivel) return;
    setState(() => _dispensada = true);
    _sairCtrl.forward().then((_) {
      if (mounted) setState(() => _visivel = false);
    });
  }

  void _abrirChat() {
    if (_dadosAtual == null) return;
    HapticFeedback.mediumImpact();
    _ultimoChatAberto = _dadosAtual!.chatId;
    _dispensar();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(friend: _dadosAtual!.remetente),
      ),
    ).then((_) {
      // Ao voltar do chat, libera para aparecer novamente se chegar msg nova
      _ultimoChatAberto = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.myUid)
          .snapshots(),
      builder: (context, snapChats) {
        if (!snapChats.hasData) return const SizedBox.shrink();

        // Encontra o chat com mais mensagens não lidas e msg nova
        return StreamBuilder<_DadosBolha?>(
          stream: _streamMensagemNova(snapChats.data!.docs),
          builder: (context, snapMsg) {
            if (snapMsg.hasData && snapMsg.data != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mostrar(snapMsg.data!);
              });
            }

            if (!_visivel || _dadosAtual == null) {
              return const SizedBox.shrink();
            }

            return Positioned(
              bottom: 24,
              right: 16,
              left: 16,
              child: _dispensada
                  ? ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 0.0)
                          .animate(_sairAnim),
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1.0, end: 0.0)
                            .animate(_sairCtrl),
                        child: _conteudoBolha(),
                      ),
                    )
                  : ScaleTransition(
                      scale: _entryAnim,
                      child: _conteudoBolha(),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _conteudoBolha() {
    final dados = _dadosAtual!;
    final initial = dados.remetente.displayName.isNotEmpty
        ? dados.remetente.displayName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _abrirChat,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity!.abs() > 200) {
          _dispensar();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _particleCtrl]),
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF0C0C0C),
            border: Border.all(
              color: const Color(0xFFFF6B00).withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00)
                    .withOpacity(0.25 * _pulseCtrl.value),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Partículas de fundo
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BolhaParticlePainter(
                      _particleCtrl.value,
                    ),
                  ),
                ),

                // Linha laranja no topo
                Positioned(
                  top: 0,
                  left: 40,
                  right: 40,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFFF6B00)
                              .withOpacity(0.8 * _pulseCtrl.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Conteúdo
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Avatar pulsante
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: Stack(
                          children: [
                            // Glow atrás do avatar
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B00)
                                        .withOpacity(
                                            0.5 * _pulseCtrl.value),
                                    blurRadius: 16,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            // Avatar
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6B00),
                                    Color(0xFFCC4400),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFF6B00),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            // Ponto verde online
                            Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF43B581),
                                  border: Border.all(
                                      color: Colors.black, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Texto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFF6B00),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'NOVA MENSAGEM',
                                  style: TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dados.remetente.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dados.ultimaMensagem,
                              style: const TextStyle(
                                color: Color(0xFF9E9E9E),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão fechar
                      GestureDetector(
                        onTap: _dispensar,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A1A1A),
                            border: Border.all(
                                color: const Color(0xFF2A2A2A)),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stream que monitora mensagens não lidas em todos os chats
  Stream<_DadosBolha?> _streamMensagemNova(
      List<QueryDocumentSnapshot> chatDocs) async* {
    final db = FirebaseFirestore.instance;

    for (final chatDoc in chatDocs) {
      final data = chatDoc.data() as Map<String, dynamic>;
      final unread =
          (data['unreadCount_${widget.myUid}'] as num?)?.toInt() ?? 0;
      if (unread == 0) continue;

      final lastMsgBy = data['lastMessageBy'] as String? ?? '';
      if (lastMsgBy == widget.myUid) continue;

      final lastMsg = data['lastMessage'] as String? ?? '';
      final participants =
          List<String>.from(data['participants'] ?? []);
      final friendUid =
          participants.firstWhere((p) => p != widget.myUid, orElse: () => '');
      if (friendUid.isEmpty) continue;

      // Busca perfil do remetente
      final userDoc =
          await db.collection('users_xp').doc(friendUid).get();
      if (!userDoc.exists) continue;

      final remetente = FriendModel.fromDoc(userDoc);

      // Busca o ID da última mensagem para detectar novidade
      final msgSnap = await db
          .collection('chats')
          .doc(chatDoc.id)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(1)
          .get();

      final ultimaMsgId =
          msgSnap.docs.isNotEmpty ? msgSnap.docs.first.id : '';

      yield _DadosBolha(
        chatId: chatDoc.id,
        remetente: remetente,
        ultimaMensagem: lastMsg,
        ultimaMsgId: ultimaMsgId,
      );
      return; // Mostra só o mais recente com msg não lida
    }

    yield null;
  }
}

// Dados que a bolha exibe
class _DadosBolha {
  final String chatId;
  final FriendModel remetente;
  final String ultimaMensagem;
  final String ultimaMsgId;

  _DadosBolha({
    required this.chatId,
    required this.remetente,
    required this.ultimaMensagem,
    required this.ultimaMsgId,
  });
}

// ═══════════════════════════════════════════════════════════════════
// PAINTER DE PARTÍCULAS DA BOLHA
// ═══════════════════════════════════════════════════════════════════
class _BolhaParticlePainter extends CustomPainter {
  final double t;
  _BolhaParticlePainter(this.t);

  static final _rng = math.Random(13);
  static final _particles = List.generate(12, (i) => [
        _rng.nextDouble(), // x
        _rng.nextDouble(), // y
        0.5 + _rng.nextDouble() * 1.0, // size
        0.02 + _rng.nextDouble() * 0.04, // speed
        _rng.nextDouble(), // phase
      ]);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final dx = p[0] * size.width;
      final dy = ((p[1] - t * p[3] + p[4]) % 1.0) * size.height;
      final opacity = 0.06 +
          0.08 *
              math.sin((t + p[4]) * 2 * math.pi);

      paint.color =
          const Color(0xFFFF6B00).withOpacity(opacity.clamp(0.0, 0.2));
      canvas.drawCircle(Offset(dx, dy), p[2], paint);
    }
  }

  @override
  bool shouldRepaint(_BolhaParticlePainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DO HEADER
// ═══════════════════════════════════════════════════════════════════
class _HeaderParticlePainter extends CustomPainter {
  final double progress;
  _HeaderParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(7);

    for (int i = 0; i < 8; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.4 + rng.nextDouble() * 0.6;
      final radius = 0.8 + rng.nextDouble() * 1.4;
      final offsetY =
          math.sin((progress + i * 0.25) * 2 * math.pi * speed) * 4;
      final opacity =
          0.15 + math.sin((progress + i * 0.2) * math.pi) * 0.20;

      paint
        ..color = AppColors.primaryOrange
            .withOpacity(opacity.clamp(0.0, 0.45))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x, baseY + offsetY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_HeaderParticlePainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════
// SKELETON CARD
// ═══════════════════════════════════════════════════════════════════
class _SkeletonCard extends StatefulWidget {
  final int delay;
  const _SkeletonCard({required this.delay});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        height: 108,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.backgroundCard,
          border: Border.all(color: const Color(0xFF1A1A1A)),
        ),
        child: const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: _SkeletonShimmer(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SHIMMER GENÉRICO
// ═══════════════════════════════════════════════════════════════════
class _SkeletonShimmer extends StatefulWidget {
  const _SkeletonShimmer();

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [
              Color(0xFF0F0F0F),
              Color(0xFF191919),
              Color(0xFF252525),
              Color(0xFF191919),
              Color(0xFF0F0F0F),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NEO ICON BUTTON
// ═══════════════════════════════════════════════════════════════════
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
        child: Icon(
          widget.icon,
          color: _pressed ? AppColors.primaryOrange : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NEO LOADER
// ═══════════════════════════════════════════════════════════════════
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
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
          angle: _ctrl.value * 2 * math.pi,
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

// ═══════════════════════════════════════════════════════════════════
// ANIMATED CARD WRAPPER
// ═══════════════════════════════════════════════════════════════════
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
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
            .animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    final delay = (widget.index * 55).clamp(0, 320);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
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
