import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/posts_provider.dart';
import '../models/post_model.dart';
import '../config/app_routes.dart';
import '../widgets/app_drawer.dart';

class MostReadScreen extends StatefulWidget {
  const MostReadScreen({Key? key}) : super(key: key);

  @override
  State<MostReadScreen> createState() => _MostReadScreenState();
}

class _MostReadScreenState extends State<MostReadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PostsProvider>();
      if (provider.posts.isEmpty) {
        provider.loadInitialPosts();
      }
    });
  }

  List<PostModel> _getSortedPosts(List<PostModel> posts) {
    final sorted = List<PostModel>.from(posts);
    sorted.sort((a, b) {
      final aCount = int.tryParse(a.replyCount) ?? 0;
      final bCount = int.tryParse(b.replyCount) ?? 0;
      return bCount.compareTo(aCount);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.primaryOrange,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Mais Lidas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
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
      drawer: const AppDrawer(),
      body: Consumer<PostsProvider>(
        builder: (context, provider, _) {
          // ── Carregando ───────────────────────────────────────────
          if (provider.isLoading && provider.posts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2,
              ),
            );
          }

          // ── Erro ─────────────────────────────────────────────────
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

          // ── Lista vazia ──────────────────────────────────────────
          if (provider.posts.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma notícia encontrada.',
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          final sortedPosts = _getSortedPosts(provider.posts);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: sortedPosts.length,
            itemBuilder: (context, index) {
              return _MostReadTile(
                post: sortedPosts[index],
                rank: index + 1,
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE DE CADA NOTÍCIA
// ═══════════════════════════════════════════════════════════════════
class _MostReadTile extends StatelessWidget {
  final PostModel post;
  final int rank;

  const _MostReadTile({
    Key? key,
    required this.post,
    required this.rank,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isTop3 = rank <= 3;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.postDetail,
          arguments: post,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: const Color(0xFF141414),
          border: Border.all(
            color: isTop3
                ? AppColors.primaryOrange.withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: isTop3
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.07),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Número do ranking ──────────────────────────────────
            SizedBox(
              width: 52,
              child: Center(
                child: isTop3
                    ? ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.orangeGradient.createShader(b),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      )
                    : Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            // ── Imagem da notícia ──────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.network(
                post.thumbnailUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white12, size: 28),
                ),
              ),
            ),

            // ── Conteúdo textual ───────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categoria
                    if (post.categories.isNotEmpty) ...[
                      Text(
                        post.categories.first.name.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Título
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isTop3 ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: isTop3
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Data e comentários
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: Colors.white24, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(post.publishedAt),
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.comment_rounded,
                            color: Colors.white24, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          '${post.replyCount} comentários',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Seta ───────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded,
                  color: Colors.white12, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}