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

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final PageController _pageCtrl =
      PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featuredPosts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 230,
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
                  left: 8, right: 8,
                  top: isActive ? 4 : 12,
                  bottom: isActive ? 4 : 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primaryOrange.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.postDetail,
                        arguments: post),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: post.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            decoration: const BoxDecoration(
                                gradient: AppColors.drawerGradient),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryOrange,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.backgroundElevated,
                            child: const Icon(Icons.broken_image_rounded,
                                size: 48, color: AppColors.textMuted),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: AppColors.cardOverlay),
                        ),
                        if (isActive)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primaryOrange
                                    .withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 16, left: 16, right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AppColors.orangeGradient,
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryOrange
                                          .withOpacity(0.4),
                                      blurRadius: 8,
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
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                              if (post.categories.isNotEmpty)
                                Row(
                                  children: [
                                    Container(
                                      width: 5, height: 5,
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
        const SizedBox(height: 10),
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

class _PageDot extends StatelessWidget {
  final bool isActive;
  const _PageDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: isActive ? AppColors.orangeGradient : null,
        color: isActive ? null : AppColors.borderSubtle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.5),
                  blurRadius: 6,
                )
              ]
            : null,
      ),
    );
  }
}
