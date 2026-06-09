import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Importe o seu widget de tempo relativo (ajuste o caminho se necessário)
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

class _NewsCardState extends State<NewsCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  bool _isUrgent() => widget.post.categories.any((c) =>
      c.name.toLowerCase() == 'urgente' || c.name.toLowerCase() == 'plantão');

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(widget.post.id);
    final bool urgent = _isUrgent();

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _scaleCtrl.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _scaleCtrl.forward();
        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: widget.post);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _scaleCtrl.forward();
      },
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) => Transform.scale(scale: _scaleCtrl.value, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.backgroundCard,
            border: Border.all(
              color: urgent ? AppColors.emergencyRed.withOpacity(0.40) : (_pressed ? AppColors.borderOrange : AppColors.borderSubtle),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: urgent ? AppColors.emergencyRed.withOpacity(0.07) : AppColors.primaryOrange.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: urgent
                          ? const LinearGradient(
                              colors: [AppColors.emergencyRed, Color(0xFFFF5252)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : AppColors.orangeVertical,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.post.categories.isNotEmpty)
                                _CategoryTag(label: widget.post.categories.first.name, urgent: urgent),
                              const Spacer(),
                              Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              // AQUI É A MUDANÇA: O widget que se atualiza sozinho
                              RelativeTimeText(
                                timestamp: widget.post.publishedAt,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
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
                                onTap: () => favoritesProvider.toggleFavorite(widget.post),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: widget.post.thumbnailUrl,
                        width: 88, height: 88, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 88, height: 88, color: AppColors.backgroundElevated, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange)))),
                        errorWidget: (_, __, ___) => Container(width: 88, height: 88, color: AppColors.backgroundElevated, child: const Icon(Icons.image_not_supported_rounded, color: AppColors.textMuted, size: 24)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final bool urgent;
  const _CategoryTag({required this.label, required this.urgent});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: urgent ? AppColors.emergencyRed.withOpacity(0.14) : AppColors.primaryOrange.withOpacity(0.12),
        border: Border.all(color: urgent ? AppColors.emergencyRed.withOpacity(0.35) : AppColors.primaryOrange.withOpacity(0.28), width: 1),
      ),
      child: Text(label.toUpperCase(), style: TextStyle(color: urgent ? AppColors.emergencyRed : AppColors.primaryOrange, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    );
  }
}

class _FavButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _FavButton({required this.isFav, required this.onTap});
  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
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
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.isFav ? AppColors.primaryOrange.withOpacity(0.15) : AppColors.backgroundElevated,
            border: Border.all(color: widget.isFav ? AppColors.primaryOrange.withOpacity(0.4) : AppColors.borderSubtle, width: 1),
          ),
          child: Icon(widget.isFav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, size: 16, color: widget.isFav ? AppColors.primaryOrange : AppColors.textMuted),
        ),
      ),
    );
  }
}
