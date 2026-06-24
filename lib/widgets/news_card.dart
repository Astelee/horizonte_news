import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../widgets/relative_time_text.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class NewsCard extends StatefulWidget {
  final PostModel post;
  const NewsCard({Key? key, required this.post}) : super(key: key);

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool _isUrgent() => widget.post.categories.any(
        (c) =>
            c.name.toLowerCase() == 'urgente' ||
            c.name.toLowerCase() == 'plantão',
      );

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(widget.post.id);
    final bool urgent = _isUrgent();
    final Color accentColor =
        urgent ? AppColors.emergencyRed : AppColors.primaryOrange;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _pressCtrl.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _pressCtrl.reverse();
        Navigator.pushNamed(
          context,
          AppRoutes.postDetail,
          arguments: widget.post,
        );
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _pressCtrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.backgroundCard,
                border: Border.all(
                  color: urgent
                      ? AppColors.emergencyRed
                          .withOpacity(0.35 + _glowAnim.value * 0.25)
                      : AppColors.primaryOrange
                          .withOpacity(0.10 + _glowAnim.value * 0.30),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(
                        urgent ? 0.08 : 0.04 + _glowAnim.value * 0.10),
                    blurRadius: 16 + _glowAnim.value * 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Barra lateral ──────────────────────────────────
                urgent
                    ? _UrgentSideBar()
                    : _GlowingSideBar(),

                // ── Conteúdo ───────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.post.categories.isNotEmpty)
                              _CategoryTag(
                                label: widget.post.categories.first.name,
                                urgent: urgent,
                              ),
                            const Spacer(),
                            Icon(Icons.access_time_rounded,
                                size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            RelativeTimeText(
                              timestamp: widget.post.publishedAt,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _FavButton(
                              isFav: isFav,
                              onTap: () =>
                                  favoritesProvider.toggleFavorite(widget.post),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Thumbnail ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: _NewsThumb(
                    url: widget.post.thumbnailUrl,
                    categoryName: widget.post.categories.isNotEmpty
                        ? widget.post.categories.first.name
                        : null,
                    urgent: urgent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barra lateral com glow pulsante ──────────────────────────────────────────

class _GlowingSideBar extends StatefulWidget {
  @override
  State<_GlowingSideBar> createState() => _GlowingSideBarState();
}

class _GlowingSideBarState extends State<_GlowingSideBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
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
        width: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryOrange.withOpacity(_anim.value),
              AppColors.primaryOrangeLight.withOpacity(_anim.value * 0.7),
              AppColors.primaryOrange.withOpacity(_anim.value * 0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.5 * _anim.value),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barra lateral urgente com pulso vermelho ──────────────────────────────────

class _UrgentSideBar extends StatefulWidget {
  @override
  State<_UrgentSideBar> createState() => _UrgentSideBarState();
}

class _UrgentSideBarState extends State<_UrgentSideBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
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
        width: 3,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.emergencyRed.withOpacity(_anim.value),
              const Color(0xFFFF5252).withOpacity(_anim.value * 0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emergencyRed.withOpacity(0.7 * _anim.value),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail com shimmer de loading ─────────────────────────────────────────

class _NewsThumb extends StatelessWidget {
  final String url;
  final String? categoryName;
  final bool urgent;

  const _NewsThumb({
    required this.url,
    this.categoryName,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const _ShimmerBox(
                width: 88,
                height: 88,
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.backgroundElevated,
                child: const Icon(
                  Icons.image_not_supported_rounded,
                  color: AppColors.textMuted,
                  size: 24,
                ),
              ),
            ),
            // Gradiente sutil sobre a imagem
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0x55000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer box reutilizável ──────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [
              Color(0xFF111111),
              Color(0xFF1E1E1E),
              Color(0xFF2A2A2A),
              Color(0xFF1E1E1E),
              Color(0xFF111111),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category tag ─────────────────────────────────────────────────────────────

class _CategoryTag extends StatelessWidget {
  final String label;
  final bool urgent;
  const _CategoryTag({required this.label, required this.urgent});

  @override
  Widget build(BuildContext context) {
    final color =
        urgent ? AppColors.emergencyRed : AppColors.primaryOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Botão de favorito animado ─────────────────────────────────────────────────

class _FavButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _FavButton({required this.isFav, required this.onTap});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward().then((_) => _ctrl.reverse());
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.isFav
                ? AppColors.primaryOrange.withOpacity(0.15)
                : AppColors.backgroundElevated,
            border: Border.all(
              color: widget.isFav
                  ? AppColors.primaryOrange.withOpacity(0.5)
                  : AppColors.borderSubtle,
              width: 1,
            ),
            boxShadow: widget.isFav
                ? [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.25),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
          child: Icon(
            widget.isFav
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            size: 16,
            color: widget.isFav
                ? AppColors.primaryOrange
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
