import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../services/blogger_service.dart';
import '../services/notification_service.dart';
import '../providers/admin_provider.dart';

class PostEditorScreen extends StatefulWidget {
  const PostEditorScreen({Key? key}) : super(key: key);

  @override
  State<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends State<PostEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Notícia ──────────────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _labelsController = TextEditingController();

  // ── Vídeo ────────────────────────────────────────────────────────
  final _videoTitleController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _videoCaptionController = TextEditingController();
  final _videoLabelsController = TextEditingController();

  final _bloggerService = BloggerService();
  bool _isPublishing = false;
  bool _previewMode = false;

  final List<String> _quickLabels = [
    'Política', 'Economia', 'Esportes',
    'Tecnologia', 'Saúde', 'Educação',
    'Cultura', 'Segurança',
  ];
  final List<String> _selectedLabels = [];

  final List<String> _videoQuickLabels = [
    'Esportes', 'Política', 'Economia',
    'Cultura', 'Saúde', 'Educação',
  ];
  final List<String> _selectedVideoLabels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _labelsController.dispose();
    _videoTitleController.dispose();
    _videoUrlController.dispose();
    _videoCaptionController.dispose();
    _videoLabelsController.dispose();
    super.dispose();
  }

  // ── Labels da notícia ────────────────────────────────────────────
  List<String> get _allLabels {
    final fromField = _labelsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return {..._selectedLabels, ...fromField}.toList();
  }

  // ── Labels do vídeo (sempre inclui "Vídeo") ──────────────────────
  List<String> get _allVideoLabels {
    final fromField = _videoLabelsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return {'Vídeo', ..._selectedVideoLabels, ...fromField}.toList();
  }

  // ── Extrai ID do YouTube ─────────────────────────────────────────
  String? _extractYtId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  // ── Publica NOTÍCIA ──────────────────────────────────────────────
  Future<void> _publishNews() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      _showSnack('Informe o título da notícia.', isError: true);
      return;
    }
    if (title.length < 10) {
      _showSnack('Título muito curto. Mínimo 10 caracteres.', isError: true);
      return;
    }
    if (content.isEmpty) {
      _showSnack('Informe o conteúdo da notícia.', isError: true);
      return;
    }
    if (content.length < 50) {
      _showSnack('Conteúdo muito curto. Mínimo 50 caracteres.', isError: true);
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final post = await _bloggerService.createPost(
        title: title,
        content: content,
        labels: _allLabels,
      );
      await NotificationService.sendAutoNotification(
        '📰 ${post.title}',
        'Nova notícia publicada no Horizonte News. Confira agora!',
      );
      if (mounted) {
        _showSnack('Notícia publicada com sucesso!', isError: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao publicar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ── Publica VÍDEO ────────────────────────────────────────────────
  Future<void> _publishVideo() async {
    final title = _videoTitleController.text.trim();
    final url = _videoUrlController.text.trim();
    final caption = _videoCaptionController.text.trim();

    if (title.isEmpty) {
      _showSnack('Informe o título do vídeo.', isError: true);
      return;
    }
    if (url.isEmpty) {
      _showSnack('Cole a URL do YouTube.', isError: true);
      return;
    }
    final ytId = _extractYtId(url);
    if (ytId == null) {
      _showSnack('URL do YouTube inválida. Use um link válido.', isError: true);
      return;
    }

    // Monta o conteúdo HTML com a URL do vídeo e a legenda
    final thumbUrl = 'https://img.youtube.com/vi/$ytId/maxresdefault.jpg';
    final content = '''
<p><a href="$url">$url</a></p>
${caption.isNotEmpty ? '<p>$caption</p>' : ''}
<img src="$thumbUrl" alt="$title"/>
''';

    setState(() => _isPublishing = true);
    try {
      final post = await _bloggerService.createPost(
        title: title,
        content: content,
        labels: _allVideoLabels,
      );
      await NotificationService.sendAutoNotification(
        '🎬 ${post.title}',
        'Novo vídeo publicado no Horizonte News. Assista agora!',
      );
      if (mounted) {
        _showSnack('Vídeo publicado com sucesso!', isError: false);
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Erro ao publicar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showPublishConfirm() {
    final isVideo = _tabController.index == 1;
    final title = isVideo
        ? _videoTitleController.text.trim()
        : _titleController.text.trim();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isVideo
                  ? Icons.videocam_rounded
                  : Icons.publish_rounded,
              color: AppColors.primaryOrange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isVideo ? 'Publicar vídeo?' : 'Publicar notícia?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVideo
                  ? 'O vídeo será publicado no Blogger com label "Vídeo" e aparecerá na aba Reels do app.'
                  : 'A notícia será publicada no Blogger e os usuários receberão uma notificação.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.2)),
              ),
              child: Text(
                title.isEmpty ? '(sem título)' : title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isVideo) {
                _publishVideo();
              } else {
                _publishNews();
              }
            },
            child: const Text(
              'Publicar',
              style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    if (!admin.isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Text('Acesso negado.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabController,
          children: [
            _previewMode ? _buildNewsPreview() : _buildNewsEditor(),
            _buildVideoEditor(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final isVideo = _tabController.index == 1;
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: AppColors.orangeGradient,
            ),
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.edit_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isVideo ? 'PUBLICAR VÍDEO' : 'NOVA NOTÍCIA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
      actions: [
        if (!isVideo)
          TextButton.icon(
            onPressed: () =>
                setState(() => _previewMode = !_previewMode),
            icon: Icon(
              _previewMode
                  ? Icons.edit_rounded
                  : Icons.preview_rounded,
              size: 16,
              color: _previewMode
                  ? AppColors.primaryOrange
                  : AppColors.textSecondary,
            ),
            label: Text(
              _previewMode ? 'EDITAR' : 'PREVIEW',
              style: TextStyle(
                color: _previewMode
                    ? AppColors.primaryOrange
                    : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _isPublishing
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _showPublishConfirm,
                  icon: const Icon(Icons.rocket_launch_rounded,
                      size: 16, color: AppColors.primaryOrange),
                  label: const Text(
                    'PUBLICAR',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryOrange,
        indicatorWeight: 2,
        labelColor: AppColors.primaryOrange,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.article_rounded, size: 18),
            text: 'NOTÍCIA',
          ),
          Tab(
            icon: Icon(Icons.videocam_rounded, size: 18),
            text: 'VÍDEO',
          ),
        ],
      ),
    );
  }

  // ── EDITOR DE NOTÍCIA ────────────────────────────────────────────
  Widget _buildNewsEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'TÍTULO', icon: Icons.title_rounded),
          const SizedBox(height: 8),
          _EditorField(
            controller: _titleController,
            hintText: 'Título da notícia...',
            maxLines: 3,
            minLines: 1,
            maxLength: 200,
            fontSize: 18,
          ),
          const SizedBox(height: 20),
          const _SectionLabel(
              label: 'CATEGORIAS', icon: Icons.label_rounded),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickLabels.map((label) {
              final selected = _selectedLabels.contains(label);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedLabels.remove(label);
                  } else {
                    _selectedLabels.add(label);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryOrange.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.borderDark,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _EditorField(
            controller: _labelsController,
            hintText: 'Outras categorias separadas por vírgula...',
            maxLines: 1,
            fontSize: 13,
          ),
          const SizedBox(height: 20),
          const _SectionLabel(
              label: 'CONTEÚDO (HTML)', icon: Icons.code_rounded),
          const SizedBox(height: 4),
          Text(
            'Você pode usar tags HTML: <b>, <i>, <p>, <h2>, <ul>, <li>, <a href="">',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _EditorField(
            controller: _contentController,
            hintText: 'Escreva o conteúdo da notícia...',
            maxLines: 999,
            minLines: 12,
            monospace: true,
          ),
          const SizedBox(height: 16),
          const _HtmlCheatSheet(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── EDITOR DE VÍDEO ──────────────────────────────────────────────
  Widget _buildVideoEditor() {
    final urlText = _videoUrlController.text.trim();
    String? ytId;
    if (urlText.isNotEmpty) ytId = _extractYtId(urlText);
    final thumbUrl = ytId != null
        ? 'https://img.youtube.com/vi/$ytId/maxresdefault.jpg'
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primaryOrange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O vídeo será publicado com o label "Vídeo" e aparecerá automaticamente na aba Reels do app.',
                    style: TextStyle(
                      color: AppColors.primaryOrange.withOpacity(0.9),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Título
          const _SectionLabel(
              label: 'TÍTULO DO VÍDEO', icon: Icons.title_rounded),
          const SizedBox(height: 8),
          _EditorField(
            controller: _videoTitleController,
            hintText: 'Ex: Reportagem especial sobre...',
            maxLines: 2,
            minLines: 1,
            maxLength: 200,
            fontSize: 16,
          ),
          const SizedBox(height: 20),

          // URL YouTube
          const _SectionLabel(
              label: 'URL DO YOUTUBE', icon: Icons.link_rounded),
          const SizedBox(height: 4),
          Text(
            'Cole o link do vídeo do YouTube (normal, shorts ou youtu.be)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditorField(
                    controller: _videoUrlController,
                    hintText:
                        'https://www.youtube.com/watch?v=...',
                    maxLines: 1,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 8),

                  // Botão validar
                  GestureDetector(
                    onTap: () => setState(() {}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primaryOrange
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.primaryOrange, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Validar URL',
                            style: TextStyle(
                              color: AppColors.primaryOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Preview thumbnail
                  if (thumbUrl != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            thumbUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: AppColors.backgroundElevated,
                              child: const Center(
                                child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.textMuted,
                                    size: 40),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF66BB6A), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'URL válida — ID: $ytId',
                          style: const TextStyle(
                            color: Color(0xFF66BB6A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else if (urlText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFEF5350), size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'URL inválida. Use um link do YouTube.',
                          style: TextStyle(
                            color: Color(0xFFEF5350),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Legenda
          const _SectionLabel(
              label: 'LEGENDA / DESCRIÇÃO',
              icon: Icons.subtitles_rounded),
          const SizedBox(height: 4),
          Text(
            'Texto que aparece abaixo do título no Reel',
            style:
                TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _EditorField(
            controller: _videoCaptionController,
            hintText:
                'Descreva o vídeo em até 3 linhas...',
            maxLines: 5,
            minLines: 3,
            maxLength: 300,
            fontSize: 14,
          ),
          const SizedBox(height: 20),

          // Categorias do vídeo
          const _SectionLabel(
              label: 'CATEGORIA DO VÍDEO',
              icon: Icons.label_rounded),
          const SizedBox(height: 4),
          Text(
            'O label "Vídeo" é adicionado automaticamente',
            style:
                TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _videoQuickLabels.map((label) {
              final selected = _selectedVideoLabels.contains(label);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedVideoLabels.remove(label);
                  } else {
                    _selectedVideoLabels.add(label);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryOrange.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.borderDark,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── PREVIEW DA NOTÍCIA ───────────────────────────────────────────
  Widget _buildNewsPreview() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            child: const Text(
              'PRÉ-VISUALIZAÇÃO',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_allLabels.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              children: _allLabels
                  .map((l) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(l,
                            style: const TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title.isEmpty ? 'Título da notícia aparecerá aqui' : title,
            style: TextStyle(
              color: title.isEmpty ? AppColors.textMuted : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.borderDark),
          const SizedBox(height: 16),
          Text(
            content.isEmpty
                ? 'O conteúdo da notícia aparecerá aqui...'
                : content.replaceAll(RegExp(r'<[^>]*>'), ''),
            style: TextStyle(
              color: content.isEmpty
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
              fontSize: 15,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primaryOrange),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final double fontSize;
  final bool monospace;

  const _EditorField({
    required this.controller,
    required this.hintText,
    required this.maxLines,
    this.minLines,
    this.maxLength,
    this.fontSize = 14,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.6,
          fontFamily: monospace ? 'monospace' : null,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: fontSize,
            fontFamily: monospace ? 'monospace' : null,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          counterStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _HtmlCheatSheet extends StatelessWidget {
  final _tags = const [
    {'tag': '<b>texto</b>', 'desc': 'Negrito'},
    {'tag': '<i>texto</i>', 'desc': 'Itálico'},
    {'tag': '<p>texto</p>', 'desc': 'Parágrafo'},
    {'tag': '<h2>título</h2>', 'desc': 'Subtítulo'},
    {'tag': '<br>', 'desc': 'Quebra de linha'},
    {'tag': '<ul><li>item</li></ul>', 'desc': 'Lista'},
  ];

  const _HtmlCheatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 13, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'REFERÊNCIA HTML',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._tags.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                              AppColors.primaryOrange.withOpacity(0.2)),
                    ),
                    child: Text(
                      t['tag']!,
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t['desc']!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
