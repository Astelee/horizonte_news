import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_colors.dart';
import '../providers/posts_provider.dart';
import '../models/post_model.dart';
import '../config/app_routes.dart';
import '../widgets/app_drawer.dart';
import '../services/sound_service.dart';
import '../utils/cloudinary_url_utils.dart';

// ─────────────────────────────────────────────────────────────────
// MODELO AUXILIAR: post + métricas reais vindas do Firestore
// ─────────────────────────────────────────────────────────────────
class _RankedPost {
  final PostModel post;
  final int views;
  final int comments;

  _RankedPost({
    required this.post,
    required this.views,
    required this.comments,
  });

  // Critério de ranking: visualizações pesam mais, comentários desempatam.
  int get score => (views * 10) + comments;

  bool get hasEngagement => views > 0 || comments > 0;
}

class MostReadScreen extends StatefulWidget {
  const MostReadScreen({Key? key}) : super(key: key);

  @override
  State<MostReadScreen> createState() => _MostReadScreenState();
}

class _MostReadScreenState extends State<MostReadScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _db = FirebaseFirestore.instance;

  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PostsProvider>();
      if (provider.posts.isEmpty) {
        provider.loadInitialPosts();
      }
    });
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  // ── Busca views únicas + comentários reais de cada post no Firestore ──
  Future<List<_RankedPost>> _loadRankedPosts(List<PostModel> posts) async {
    final futures = posts.map((post) async {
      final viewsDoc = await _db.collection('post_views').doc(post.id).get();
      final views =
          (viewsDoc.data()?['uniqueViewers'] as num?)?.toInt() ?? 0;

      final commentsSnap = await _db
          .collection('comments')
          .doc(post.id)
          .collection('postComments')
          .count()
          .get();
      final comments = commentsSnap.count ?? 0;

      return _RankedPost(post: post, views: views, comments: comments);
    });

    final results = await Future.wait(futures);

    // Só entram no ranking posts com pelo menos 1 view OU 1 comentário.
    final withEngagement = results.where((r) => r.hasEngagement).toList();

    withEngagement.sort((a, b) => b.score.compareTo(a.score));

    return withEngagement;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0A0A0A),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Row(
          children: [
            _PulsingFireIcon(controller: _ambientCtrl),
            const SizedBox(width: 8),
            const Text(
              'Mais Lidas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                AppColors.borderGlow,
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
      drawer: AppDrawer(scaffoldKey: _scaffoldKey),
      body: Stack(
        children: [
          // ── Fundo com glow ambiente + partículas sutis ─────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ambientCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _AmbientBackgroundPainter(
                    progress: _ambientCtrl.value,
                  ),
                ),
              ),
            ),
          ),

          Consumer<PostsProvider>(
            builder: (context, provider, _) {
              // ── Carregando posts (Blogger) ────────────────────────
              if (provider.isLoading && provider.posts.isEmpty) {
                return const _LoadingState();
              }

              // ── Erro ao carregar posts ────────────────────────────
              if (provider.errorMessage.isNotEmpty && provider.posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white24, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Não foi possível carregar as notícias.',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => provider.loadInitialPosts(),
                        child: const Text(
                          'Tentar novamente',
                          style: TextStyle(color: AppColors.primaryOrange),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (provider.posts.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma notícia encontrada.',
                    style: TextStyle(color: Colors.white38),
                  ),
                );
              }

              // ── Busca métricas reais (views + comentários) no Firestore ──
              return FutureBuilder<List<_RankedPost>>(
                future: _loadRankedPosts(provider.posts),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _LoadingState();
                  }

                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.white24, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Erro ao calcular o ranking.',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  final ranked = snap.data ?? [];

                  // Nenhum post teve visualização ou comentário ainda.
                  if (ranked.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_rounded,
                              color: AppColors.primaryOrange.withOpacity(0.2),
                              size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Ainda não há leituras suficientes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'O ranking aparece assim que alguém\nler ou comentar uma notícia',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: ranked.length,
                    itemBuilder: (context, index) {
                      return _MostReadTile(
                        key: ValueKey(ranked[index].post.id),
                        ranked: ranked[index],
                        rank: index + 1,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LOADING STATE — shimmer de esqueleto em vez do spinner puro
// ═══════════════════════════════════════════════════════════════════
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: _ShimmerSweep(borderRadius: 18),
      ),
    );
  }
}

class _ShimmerSweep extends StatefulWidget {
  final double borderRadius;
  const _ShimmerSweep({this.borderRadius = 0});

  @override
  State<_ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<_ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_ctrl.value * 3 - 1.5, 0),
              end: Alignment(_ctrl.value * 3 - 0.5, 0),
              colors: const [
                Colors.transparent,
                Color(0x14FFFFFF),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ÍCONE DE CHAMA PULSANTE (AppBar)
// ═══════════════════════════════════════════════════════════════════
class _PulsingFireIcon extends StatelessWidget {
  final AnimationController controller;
  const _PulsingFireIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (math.sin(controller.value * 2 * math.pi) + 1) / 2;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.25 + t * 0.25),
                blurRadius: 8 + t * 6,
              ),
            ],
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: Color.lerp(
              AppColors.primaryOrange,
              AppColors.primaryOrangeLight,
              t,
            ),
            size: 20,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FUNDO AMBIENTE — glow radial suave + partículas flutuantes discretas
// ═══════════════════════════════════════════════════════════════════
class _AmbientBackgroundPainter extends CustomPainter {
  final double progress;
  _AmbientBackgroundPainter({required this.progress});

  static final List<_Particle> _particles = List.generate(14, (i) {
    final rnd = math.Random(i * 97);
    return _Particle(
      dx: rnd.nextDouble(),
      dy: rnd.nextDouble(),
      radius: 0.6 + rnd.nextDouble() * 1.4,
      speed: 0.3 + rnd.nextDouble() * 0.7,
      phase: rnd.nextDouble() * 2 * math.pi,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Glow radial fixo no topo, tom laranja muito sutil.
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryOrange.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.05),
          radius: size.width * 0.9,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    // Partículas flutuando lentamente para cima, com leve brilho.
    for (final p in _particles) {
      final t = (progress * p.speed + p.phase / (2 * math.pi)) % 1.0;
      final dy = (p.dy - t) % 1.0;
      final x = size.width * p.dx +
          math.sin((t * 2 * math.pi) + p.phase) * 10;
      final y = size.height * dy;
      final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.12;

      final paint = Paint()
        ..color = AppColors.primaryOrangeLight.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Particle {
  final double dx;
  final double dy;
  final double radius;
  final double speed;
  final double phase;
  _Particle({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}

// ═══════════════════════════════════════════════════════════════════
// TILE PREMIUM — glow no top 3, entrada animada, microinterações
// ═══════════════════════════════════════════════════════════════════
class _MostReadTile extends StatefulWidget {
  final _RankedPost ranked;
  final int rank;

  const _MostReadTile({
    Key? key,
    required this.ranked,
    required this.rank,
  }) : super(key: key);

  @override
  State<_MostReadTile> createState() => _MostReadTileState();
}

class _MostReadTileState extends State<_MostReadTile>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  PostModel get post => widget.ranked.post;
  bool get _isTop3 => widget.rank <= 3;

  @override
  void initState() {
    super.initState();

    // Entrada escalonada por posição — efeito de "cascata" sutil.
    final delay = Duration(milliseconds: 40 * math.min(widget.rank, 10));
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    Future.delayed(delay, () {
      if (mounted) _entryCtrl.forward();
    });

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  // Cores de destaque para os 3 primeiros lugares (ouro/prata/bronze).
  List<Color> get _rankColors {
    switch (widget.rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFB8860B)];
      case 2:
        return [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)];
      case 3:
        return [const Color(0xFFFF8C3A), const Color(0xFFCC4400)];
      default:
        return [AppColors.primaryOrange, AppColors.primaryOrange];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 24 && diff.inHours >= 0) {
      if (diff.inHours < 1) return 'Há ${diff.inMinutes}min';
      return 'Há ${diff.inHours}h';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  bool get _hasVideo =>
      post.videoUrl != null && post.videoUrl!.trim().isNotEmpty;

  // Resolve a URL de capa com fallback para frame extraído do vídeo,
  // garantindo que matérias em vídeo nunca fiquem sem thumbnail.
  String get _resolvedThumbUrl {
    final direct = post.thumbnailUrl.trim();
    if (direct.isNotEmpty) return direct;

    final videoFrame = CloudinaryUrlUtils.videoThumbnail(post.videoUrl);
    if (videoFrame != null) return videoFrame;

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final rankGradientColors = _rankColors;

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: GestureDetector(
          onTapDown: (_) {
            _pressCtrl.forward();
            HapticFeedback.selectionClick();
          },
          onTapUp: (_) {
            _pressCtrl.reverse();
            SoundService.instance.playSystemClick();
            Navigator.pushNamed(
              context,
              AppRoutes.postDetail,
              arguments: post,
            );
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: AnimatedBuilder(
            animation: _pressScale,
            builder: (context, child) => Transform.scale(
              scale: _pressScale.value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isTop3
                      ? [
                          const Color(0xFF161310),
                          const Color(0xFF0E0C0A),
                        ]
                      : [
                          const Color(0xFF131313),
                          const Color(0xFF101010),
                        ],
                ),
                border: Border.all(
                  color: _isTop3
                      ? rankGradientColors[0].withOpacity(0.35)
                      : Colors.white.withOpacity(0.06),
                  width: _isTop3 ? 1.3 : 1,
                ),
                boxShadow: _isTop3
                    ? [
                        BoxShadow(
                          color: rankGradientColors[0].withOpacity(0.18),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Selo de ranking (sem emoji) ─────────────────
                      _RankBadge(
                        rank: widget.rank,
                        colors: rankGradientColors,
                        isTop3: _isTop3,
                      ),
                      const SizedBox(width: 12),

                      // ── Imagem / thumbnail de vídeo com fallback ────
                      _ThumbWithVideoFallback(
                        url: _resolvedThumbUrl,
                        hasVideo: _hasVideo,
                      ),
                      const SizedBox(width: 12),

                      // ── Texto ────────────────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post.categories.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color:
                                      AppColors.primaryOrange.withOpacity(0.12),
                                ),
                                child: Text(
                                  post.categories.first.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _isTop3 ? Colors.white : Colors.white70,
                                fontSize: 13.5,
                                fontWeight:
                                    _isTop3 ? FontWeight.w700 : FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    color: Colors.white30, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(post.publishedAt),
                                  style: const TextStyle(
                                      color: Colors.white30, fontSize: 10),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.visibility_rounded,
                                    color:
                                        AppColors.primaryOrange.withOpacity(0.8),
                                    size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(widget.ranked.views),
                                  style: TextStyle(
                                    color:
                                        AppColors.primaryOrange.withOpacity(0.9),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.chat_bubble_rounded,
                                    color: Colors.white30, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(widget.ranked.comments),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white24, size: 18),
                    ],
                  ),
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
// SELO DE RANKING — substitui o emoji 🏆 por um elemento vetorial
// próprio do app: coroa desenhada + brilho pulsante para o 1º lugar.
// ═══════════════════════════════════════════════════════════════════
class _RankBadge extends StatefulWidget {
  final int rank;
  final List<Color> colors;
  final bool isTop3;

  const _RankBadge({
    required this.rank,
    required this.colors,
    required this.isTop3,
  });

  @override
  State<_RankBadge> createState() => _RankBadgeState();
}

class _RankBadgeState extends State<_RankBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.rank == 1) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pulse = widget.rank == 1 ? _ctrl.value : 0.0;
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: widget.isTop3
                ? [
                    BoxShadow(
                      color: widget.colors[0]
                          .withOpacity(0.45 + pulse * 0.25),
                      blurRadius: 10 + pulse * 6,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.rank == 1
                ? CustomPaint(
                    size: const Size(18, 16),
                    painter: _CrownPainter(color: Colors.white),
                  )
                : Text(
                    '${widget.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Desenha uma coroa vetorial simples e limpa — usada no 1º lugar do
/// ranking no lugar do emoji 🏆, mantendo a identidade visual do app.
class _CrownPainter extends CustomPainter {
  final Color color;
  _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.35)
      ..lineTo(w * 0.22, h * 0.6)
      ..lineTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.78, h * 0.6)
      ..lineTo(w, h * 0.35)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, paint);

    // Base da coroa.
    final basePaint = Paint()..color = color.withOpacity(0.9);
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// THUMBNAIL COM FALLBACK DE VÍDEO
// Garante que matérias em vídeo sempre mostrem uma prévia visual:
// 1) usa a capa cadastrada, se existir;
// 2) senão, extrai um frame do próprio vídeo (Cloudinary);
// 3) se nada disso existir, mostra um placeholder com ícone de vídeo
//    — nunca uma área vazia ou preta.
// Sempre exibe o selo de play quando a matéria tem vídeo.
// ═══════════════════════════════════════════════════════════════════
class _ThumbWithVideoFallback extends StatelessWidget {
  final String url;
  final bool hasVideo;

  const _ThumbWithVideoFallback({
    required this.url,
    required this.hasVideo,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _ShimmerSweep(),
                errorWidget: (_, __, ___) => _FallbackThumb(hasVideo: hasVideo),
              )
            else
              _FallbackThumb(hasVideo: hasVideo),

            // Leve vinheta para dar profundidade e contraste ao ícone de play.
            if (hasVideo)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0x66000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

            if (hasVideo)
              Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.85), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  final bool hasVideo;
  const _FallbackThumb({required this.hasVideo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.04),
      child: Icon(
        hasVideo ? Icons.videocam_rounded : Icons.broken_image_rounded,
        color: Colors.white12,
        size: 26,
      ),
    );
  }
}