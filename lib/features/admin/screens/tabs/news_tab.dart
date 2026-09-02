import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../models/post_model.dart';
import '../../services/admin_news_service.dart';
import '../../widgets/admin_shared_widgets.dart';
import '../news_editor_screen.dart';

class NewsTab extends StatefulWidget {
  final AdminNewsService newsService;
  const NewsTab({required this.newsService, Key? key}) : super(key: key);

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  String _search = '';

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
    await widget.newsService.setStatus(post.id, newStatus);
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
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder(
        stream: widget.newsService.allNewsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange),
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

          var posts = snapshot.data!.docs
              .map((d) => PostModel.fromFirestore(d))
              .toList();

          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            posts = posts
                .where((p) => p.title.toLowerCase().contains(q))
                .toList();
          }

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar por título...',
                        hintStyle: const TextStyle(
                            color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.backgroundElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: posts.length,
                      itemBuilder: (context, i) {
                        final post = posts[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.borderDark),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: post.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        post.thumbnailUrl,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _placeholderThumb(),
                                      )
                                    : _placeholderThumb(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.title.isEmpty
                                          ? '(sem título)'
                                          : post.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(post.status)
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(post.status),
                                        style: TextStyle(
                                          color: _statusColor(post.status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded,
                                    color: AppColors.textSecondary),
                                color: const Color(0xFF111111),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openEditor(post: post);
                                  } else if (value == 'toggle') {
                                    _togglePublish(post);
                                  } else if (value == 'delete') {
                                    _delete(post);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar',
                                        style: TextStyle(
                                            color: Colors.white)),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      post.status == PostStatus.published
                                          ? 'Despublicar'
                                          : 'Publicar',
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Excluir',
                                        style: TextStyle(
                                            color: Color(0xFFEF5350))),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
    );
  }

  Widget _placeholderThumb() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.backgroundDark,
      child: const Icon(Icons.image_not_supported_rounded,
          color: AppColors.textSecondary, size: 20),
    );
  }

  Widget _buildFab() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova notícia',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}