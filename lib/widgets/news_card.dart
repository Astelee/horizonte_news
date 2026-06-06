import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class NewsCard extends StatelessWidget {
  final PostModel post;

  const NewsCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(post.id);
    final String formattedDate = DateFormat('dd/MM/yyyy • HH:mm').format(post.publishedAt);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.postDetail,
            arguments: post,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem de capa com carregamento suave em cache
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: post.thumbnailUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? AppColors.surfaceDark 
                        : AppColors.borderLight,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: AppColors.accentBlue,
                    child: const Icon(Icons.broken_image, size: 50, color: Colors.white),
                  ),
                ),
                // Etiqueta da primeira categoria encontrada
                if (post.categories.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      // CORREÇÃO: py substituído por vertical
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.categories.first.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Detalhes textuais da notícia
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          height: 1.3,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time, 
                            size: 14, 
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? AppColors.textSecondaryDark 
                                : AppColors.textSecondaryLight
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      // Ícone Reativo de Favoritar
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.bookmark : Icons.bookmark_border,
                          color: isFav ? AppColors.primaryBlue : null,
                        ),
                        onPressed: () {
                          favoritesProvider.toggleFavorite(post);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}