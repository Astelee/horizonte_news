import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class FeaturedCarousel extends StatelessWidget {
  final List<PostModel> featuredPosts;

  const FeaturedCarousel({Key? key, required this.featuredPosts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (featuredPosts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: featuredPosts.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, index) {
          final post = featuredPosts[index];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.postDetail,
                    arguments: post,
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Imagem de Fundo
                    CachedNetworkImage(
                      imageUrl: post.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.accentBlue,
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
                    ),
                    // Gradiente Escuro sobreposto para contraste do texto
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                    // Texto do Título em Destaque
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            // CORREÇÃO: py substituído por vertical
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DESTAQUE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}