import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../providers/posts_provider.dart';
import '../config/app_colors.dart';

// Classe utilitária interna para evitar erros de importação
class DateFormatter {
  static String formatTimeAgo(DateTime postDate) {
    final now = DateTime.now();
    final difference = now.difference(postDate);

    if (difference.inSeconds < 60) {
      return 'Agora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'} atrás';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'} atrás';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'dia' : 'dias'} atrás';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(postDate);
    }
  }
}

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
          await Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
        },
        child: SelectionArea( // Envolve o conteúdo para permitir a seleção de texto
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                          // Regra universal para forçar o tamanho correto e ignorar formatação do Blogger
                          "*": Style(
                            fontSize: FontSize(16.5),
                            lineHeight: LineHeight.em(1.5),
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          "p": Style(
                            margin: Margins.only(bottom: 16),
                          ),
                          "a": Style(
                            color: AppColors.primaryOrange,
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
      ),
    );
  }
}