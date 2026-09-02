import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../models/post_model.dart';
import '../../services/admin_news_service.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/admin_shared_widgets.dart';
import '../news_editor_screen.dart';

/// Aba "NOTÍCIAS" do painel administrativo.
///
/// ATENÇÃO: este arquivo é puramente visual. Toda a lógica de dados e
/// de notificações continua vindo de [AdminNewsService] exatamente
/// como antes (allNewsStream, setStatus, deleteNews) — nada nessa
/// camada foi alterado. Só a apresentação (cores, layout, animações)
/// foi refeita para seguir a identidade visual do resto do app
/// (fundo preto, partículas de fogo subindo, glow laranja, gradientes),
/// no mesmo padrão usado em telas como o Ranking.
class NewsTab extends StatefulWidget {
  final AdminNewsService newsService;
  const NewsTab({required this.newsService, Key? key}) : super(key: key);

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> with TickerProviderStateMixin {
  String _search = '';
  PostStatus? _filterStatus; // null = "todas"

  late final AnimationController _particleCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(PostStatus status) {
    switch (status) {
      case PostStatus.published:
        return const Color(0xFF4CAF50);
      case PostStatus.draft:
        return const Color(0xFFFFC107);
      case PostStatus.unpublished:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(PostStatus status) {
    switch (status) {
      case PostStatus.published:
        return Icons.check_circle_rounded;
      case PostStatus.draft:
        return Icons.edit_note_rounded;
      case PostStatus.unpublished:
        return Icons.visibility_off_rounded;
    }
  }

  String _statusLabel(PostStatus status) {
    switch (status) {
      case PostStatus.published:
        return 'PUBLICADA';
      case PostStatus.draft:
        return 'RASCUNHO';
      case PostStatus.unpublished:
        return 'DESPUBLICADA';
    }
  }

  // ── Ações (idênticas à versão anterior — só a UI ao redor mudou) ───────
  Future<void> _openEditor({PostModel? post}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsEditorScreen(
          newsService: widget.newsService,
          existingPost: post,
        ),
      ),
    );
  }

  Future<void> _togglePublish(PostModel post) async {
    final newStatus = post.status == PostStatus.published
        ? PostStatus.unpublished
        : PostStatus.published;
    final pushResult = await widget.newsService.setStatus(post.id, newStatus);
    if (mounted && pushResult != null && !pushResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pushResult.message ?? 'Falha ao enviar notificação push.'),
          backgroundColor: Colors.red[900],
        ),
      );
    }
  }

  Future<void> _delete(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Excluir notícia?',
        message:
            'Esta ação não pode ser desfeita. "${post.title}" será excluída permanentemente.',
        confirmLabel: 'Excluir',
        confirmColor: const Color(0xFFEF5350),
      ),
    );
    if (confirmed == true) {
      await widget.newsService.deleteNews(post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Fundo: preto + partículas de fogo subindo (mesmo padrão do Ranking) ──
        Positioned.fill(
          child: Container(color: Colors.black),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _NewsParticlePainter(_particleCtrl.value),
            ),
          ),
        ),
        StreamBuilder(
          stream: widget.newsService.allNewsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              );
            }
            if (snapshot.hasError) {
              return AdminErrorState(message: '${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Stack(
                children: [
                  const AdminEmptyState(
                    icon: Icons.article_outlined,
                    message: 'Nenhuma notícia cadastrada ainda',
                  ),
                  _buildFab(),
                ],
              );
            }

            var posts =
                snapshot.data!.docs.map((d) => PostModel.fromFirestore(d)).toList();

            // Contagens por status calculadas sobre a lista completa,
            // antes de aplicar busca/filtro — para os chips do topo
            // sempre refletirem o total real.
            final total = posts.length;
            final publishedCount =
                posts.where((p) => p.status == PostStatus.published).length;
            final draftCount =
                posts.where((p) => p.status == PostStatus.draft).length;
            final unpublishedCount =
                posts.where((p) => p.status == PostStatus.unpublished).length;

            if (_filterStatus != null) {
              posts = posts.where((p) => p.status == _filterStatus).toList();
            }
            if (_search.isNotEmpty) {
              final q = _search.toLowerCase();
              posts = posts.where((p) => p.title.toLowerCase().contains(q)).toList();
            }

            return Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(total, publishedCount, draftCount, unpublishedCount),
                    Expanded(
                      child: posts.isEmpty
                          ? const AdminEmptyState(
                              icon: Icons.search_off_rounded,
                              message: 'Nenhuma notícia encontrada',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: posts.length,
                              itemBuilder: (context, i) {
                                return _NewsCard(
                                  post: posts[i],
                                  statusColor: _statusColor(posts[i].status),
                                  statusIcon: _statusIcon(posts[i].status),
                                  statusLabel: _statusLabel(posts[i].status),
                                  glowAnim: _glowAnim,
                                  onEdit: () => _openEditor(post: posts[i]),
                                  onTogglePublish: () => _togglePublish(posts[i]),
                                  onDelete: () => _delete(posts[i]),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                _buildFab(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(
      int total, int published, int draft, int unpublished) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.55)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppColors.orangeVertical,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'GERENCIAR NOTÍCIAS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                '$total no total',
                style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Todas',
                  count: total,
                  color: AppColors.primaryOrange,
                  selected: _filterStatus == null,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Publicadas',
                  count: published,
                  color: const Color(0xFF4CAF50),
                  selected: _filterStatus == PostStatus.published,
                  onTap: () => setState(() => _filterStatus = PostStatus.published),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Rascunhos',
                  count: draft,
                  color: const Color(0xFFFFC107),
                  selected: _filterStatus == PostStatus.draft,
                  onTap: () => setState(() => _filterStatus = PostStatus.draft),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Despublicadas',
                  count: unpublished,
                  color: AppColors.textSecondary,
                  selected: _filterStatus == PostStatus.unpublished,
                  onTap: () => setState(() => _filterStatus = PostStatus.unpublished),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por título...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.primaryOrange, size: 20),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 18),
                      onPressed: () => setState(() => _search = ''),
                    ),
              filled: true,
              fillColor: const Color(0xFF141414),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF262626)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF262626)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryOrange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.45 * _glowAnim.value),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: AppColors.primaryOrange,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nova notícia',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHIP DE FILTRO
// ═══════════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.16) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.7) : const Color(0xFF262626),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? color : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE NOTÍCIA
// ═══════════════════════════════════════════════════════════════════
class _NewsCard extends StatelessWidget {
  final PostModel post;
  final Color statusColor;
  final IconData statusIcon;
  final String statusLabel;
  final Animation<double> glowAnim;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onDelete;

  const _NewsCard({
    required this.post,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.glowAnim,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = post.status == PostStatus.published;
    final categoryName = post.categories.isNotEmpty ? post.categories.first.name : null;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [const Color(0xFF161616), const Color(0xFF0D0D0D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isPublished
                ? AppColors.primaryOrange.withOpacity(0.28)
                : const Color(0xFF232323),
          ),
          boxShadow: isPublished
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: post.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            post.thumbnailUrl,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderThumb(),
                          )
                        : _placeholderThumb(),
                  ),
                  if (isPublished)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: AnimatedBuilder(
                        animation: glowAnim,
                        builder: (_, __) => Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(glowAnim.value),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title.isEmpty ? '(sem título)' : post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 11, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (categoryName != null && categoryName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryName,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      color: const Color(0xFF161616),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF262626)),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'toggle') {
          onTogglePublish();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: Colors.white),
              SizedBox(width: 10),
              Text('Editar', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                post.status == PostStatus.published
                    ? Icons.visibility_off_rounded
                    : Icons.publish_rounded,
                size: 16,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 10),
              Text(
                post.status == PostStatus.published ? 'Despublicar' : 'Publicar',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, size: 16, color: Color(0xFFEF5350)),
              SizedBox(width: 10),
              Text('Excluir', style: TextStyle(color: Color(0xFFEF5350))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_not_supported_rounded,
          color: AppColors.textSecondary, size: 20),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DE FOGO DE FUNDO (mesmo padrão visual do Ranking)
// ═══════════════════════════════════════════════════════════════════
class _NewsParticlePainter extends CustomPainter {
  final double t;
  _NewsParticlePainter(this.t);

  static final _rng = math.Random(41);
  static final _particles = List.generate(
    28,
    (i) => _NPData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 0.5 + _rng.nextDouble() * 1.5,
      speed: 0.015 + _rng.nextDouble() * 0.03,
      opacity: 0.05 + _rng.nextDouble() * 0.18,
      phase: _rng.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B00).withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.05),
        radius: size.width * 0.7,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.05),
      size.width * 0.7,
      orbPaint,
    );

    for (final p in _particles) {
      final dy = 1.0 - ((p.y + t * p.speed + p.phase) % 1.0);
      final dx = p.x + 0.02 * math.sin((t * 2 * math.pi * 0.6) + p.phase * 6.28);
      final fireRatio = 1.0 - dy;
      final color = Color.lerp(
        const Color(0xFFFF6B00),
        const Color(0xFFFF2200),
        fireRatio,
      )!;
      final opacity = p.opacity *
          (0.5 + 0.5 * math.sin(t * 2 * math.pi * p.speed * 10 + p.phase));

      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.size,
        Paint()..color = color.withOpacity(opacity.clamp(0.0, 0.25)),
      );
    }
  }

  @override
  bool shouldRepaint(_NewsParticlePainter old) => old.t != t;
}

class _NPData {
  final double x, y, size, speed, opacity, phase;
  const _NPData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}