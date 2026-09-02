import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class FeaturedCarousel extends StatefulWidget {
  final List<PostModel> featuredPosts;
  const FeaturedCarousel({Key? key, required this.featuredPosts})
      : super(key: key);

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl =
      PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  // Animação de partículas do card ativo
  late AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 236,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.featuredPosts.length,
            itemBuilder: (context, index) {
              final post = widget.featuredPosts[index];
              final isActive = index == _currentPage;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: isActive ? 4 : 14,
                  bottom: isActive ? 4 : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primaryOrange
                                .withOpacity(0.30),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.postDetail,
                      arguments: post,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ── Imagem de fundo ───────────────────────
                        post.thumbnailUrl.trim().isEmpty
                            ? _CarouselNoImage(hasVideo: post.videoUrl != null &&
                                post.videoUrl!.trim().isNotEmpty)
                            : CachedNetworkImage(
                                imageUrl: post.thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const _CarouselShimmer(),
                                errorWidget: (_, __, ___) =>
                                    _CarouselNoImage(
                                        hasVideo: post.videoUrl != null &&
                                            post.videoUrl!
                                                .trim()
                                                .isNotEmpty),
                              ),

                        // ── Selo de "play" quando há vídeo ────────
                        if (post.videoUrl != null &&
                            post.videoUrl!.trim().isNotEmpty)
                          const Center(
                            child: _CarouselPlayBadge(),
                          ),

                        // ── Gradiente escurecendo de baixo ────────
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.cardOverlay,
                          ),
                        ),

                        // ── Partículas orbitais (só no ativo) ─────
                        if (isActive)
                          AnimatedBuilder(
                            animation: _particleCtrl,
                            builder: (_, __) => CustomPaint(
                              painter: _CarouselParticlePainter(
                                progress: _particleCtrl.value,
                              ),
                            ),
                          ),

                        // ── Borda laranja no card ativo ───────────
                        if (isActive)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryOrange
                                    .withOpacity(0.55),
                                width: 1.5,
                              ),
                            ),
                          ),

                        // ── Conteúdo textual ──────────────────────
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Badge DESTAQUE
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.orangeGradient,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'DESTAQUE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Título
                              Text(
                                post.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Categoria
                              if (post.categories.isNotEmpty)
                                Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      post.categories.first.name
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.primaryOrangeLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── Indicadores de página ─────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.featuredPosts.length,
            (i) => _PageDot(isActive: i == _currentPage),
          ),
        ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Sem imagem de capa (com indicação de vídeo, se houver) ───────────────────

class _CarouselNoImage extends StatelessWidget {
  final bool hasVideo;
  const _CarouselNoImage({required this.hasVideo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundElevated,
      child: Center(
        child: Icon(
          hasVideo
              ? Icons.videocam_rounded
              : Icons.image_not_supported_rounded,
          size: 40,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Selo de "play" central para destaques com vídeo ───────────────────────────

class _CarouselPlayBadge extends StatelessWidget {
  const _CarouselPlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.85), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.35),
            blurRadius: 14,
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

// ── Shimmer do carousel ───────────────────────────────────────────────────────

class _CarouselShimmer extends StatefulWidget {
  const _CarouselShimmer();

  @override
  State<_CarouselShimmer> createState() => _CarouselShimmerState();
}

class _CarouselShimmerState extends State<_CarouselShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
            begin: Alignment(_anim.value - 1, 0.3),
            end: Alignment(_anim.value, 0.3),
            colors: const [
              Color(0xFF0D0D0D),
              Color(0xFF181818),
              Color(0xFF222222),
              Color(0xFF181818),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Partículas flutuantes do carousel ────────────────────────────────────────

class _CarouselParticlePainter extends CustomPainter {
  final double progress;
  _CarouselParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42); // semente fixa = posições consistentes

    for (int i = 0; i < 10; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final radius = 1.2 + rng.nextDouble() * 1.8;

      final offsetY = math.sin((progress + i * 0.3) * 2 * math.pi * speed) * 6;
      final offsetX = math.cos((progress + i * 0.2) * 2 * math.pi * speed) * 3;
      final opacity = 0.2 + math.sin((progress + i * 0.15) * math.pi) * 0.35;

      paint
        ..color = (i % 3 == 0
                ? AppColors.primaryOrange
                : i % 3 == 1
                    ? AppColors.primaryOrangeLight
                    : Colors.white)
            .withOpacity(opacity.clamp(0.0, 0.7))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(
        Offset(baseX + offsetX, baseY + offsetY),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CarouselParticlePainter old) =>
      old.progress != progress;
}

// ── Dot indicador de página ───────────────────────────────────────────────────

class _PageDot extends StatelessWidget {
  final bool isActive;
  const _PageDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 22 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: isActive ? AppColors.orangeGradient : null,
        color: isActive ? null : AppColors.borderSubtle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }
}