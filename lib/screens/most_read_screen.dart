import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../providers/posts_provider.dart';
import '../models/post_model.dart';
import '../config/app_routes.dart';
import '../widgets/app_drawer.dart';

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

class _MostReadScreenState extends State<MostReadScreen> {
  final _db = FirebaseFirestore.instance;

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
    final withEngagement =
        results.where((r) => r.hasEngagement).toList();

    withEngagement.sort((a, b) => b.score.compareTo(a.score));

    return withEngagement;
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
          // ── Carregando posts (Blogger) ────────────────────────────
          if (provider.isLoading && provider.posts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2,
              ),
            );
          }

          // ── Erro ao carregar posts ────────────────────────────────
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
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryOrange,
                    strokeWidth: 2,
                  ),
                );
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
                        style: TextStyle(color: Colors.white38, fontSize: 14),
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
                    ranked: ranked[index],
                    rank: index + 1,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE REDESENHADO — CARD PREMIUM COM GLOW NO TOP 3
// ═══════════════════════════════════════════════════════════════════
class _MostReadTile extends StatelessWidget {
  final _RankedPost ranked;
  final int rank;

  const _MostReadTile({
    Key? key,
    required this.ranked,
    required this.rank,
  }) : super(key: key);

  PostModel get post => ranked.post;

  bool get _isTop3 => rank <= 3;

  // Cores de destaque para os 3 primeiros lugares (ouro/prata/bronze).
  List<Color> get _rankColors {
    switch (rank) {
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

  @override
  Widget build(BuildContext context) {
    final rankGradientColors = _rankColors;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.postDetail,
          arguments: post,
        );
      },
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Selo de ranking ──────────────────────────────────
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: rankGradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: _isTop3
                          ? [
                              BoxShadow(
                                color: rankGradientColors[0]
                                    .withOpacity(0.45),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: _isTop3 && rank == 1
                          ? const Text('🏆', style: TextStyle(fontSize: 18))
                          : Text(
                              '$rank',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // ── Imagem ───────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.thumbnailUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 76,
                    height: 76,
                    color: Colors.white.withOpacity(0.04),
                    child: const Icon(Icons.broken_image_rounded,
                        color: Colors.white12, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Texto ────────────────────────────────────────────
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
                          color: AppColors.primaryOrange.withOpacity(0.12),
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
                            color: AppColors.primaryOrange.withOpacity(0.8),
                            size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(ranked.views),
                          style: TextStyle(
                            color: AppColors.primaryOrange.withOpacity(0.9),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_rounded,
                            color: Colors.white30, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(ranked.comments),
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
    );
  }
}
