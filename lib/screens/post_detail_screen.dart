import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/posts_provider.dart'; // Import necessário para o refresh
import '../config/app_colors.dart';
import '../utils/date_formatter.dart'; // Import da nossa nova classe de utilitário

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final PostModel post = ModalRoute.of(context)!.settings.arguments as PostModel;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(post.id);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryOrange,
        onRefresh: () async {
          // Lógica para recarregar esta notícia específica se necessário
          await Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Necessário para o RefreshIndicator
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              actions: [
                IconButton(
                  icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () => favoritesProvider.toggleFavorite(post),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    Share.share('${post.title}\n\nLeia a matéria completa em: ${post.url}');
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        // AQUI usamos a nossa nova função de data amigável
                        Text(
                          DateFormatter.formatTimeAgo(post.publishedAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    Html(
                      data: post.content,
                      style: {
                        "p": Style(
                          fontSize: FontSize(16.5),
                          lineHeight: LineHeight.em(1.5),
                          margin: Margins.only(bottom: 16),
                        ),
                        "a": Style(
                          color: AppColors.primaryOrange, // Cor laranja atualizada
                          textDecoration: TextDecoration.underline,
                        ),
                      },
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