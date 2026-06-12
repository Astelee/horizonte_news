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

class _PostEditorScreenState extends State<PostEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _labelsController = TextEditingController();
  final _bloggerService = BloggerService();

  bool _isPublishing = false;
  bool _previewMode = false;

  // Categorias rápidas pré-definidas
  final List<String> _quickLabels = [
    'Política',
    'Economia',
    'Esportes',
    'Tecnologia',
    'Saúde',
    'Educação',
    'Cultura',
    'Segurança',
  ];
  final List<String> _selectedLabels = [];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  List<String> get _allLabels {
    final fromField = _labelsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return {..._selectedLabels, ...fromField}.toList();
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // ── Validação ──────────────────────────────────────────────
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
      // ── Publica no Blogger ─────────────────────────────────
      final post = await _bloggerService.createPost(
        title: title,
        content: content,
        labels: _allLabels,
      );

      // ── Dispara notificação via OneSignal ──────────────────
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
      if (mounted) {
        _showSnack('Erro ao publicar: $e', isError: true);
      }
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
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFEF5350)
            : const Color(0xFF66BB6A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showPublishConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.publish_rounded, color: AppColors.primaryOrange, size: 20),
            SizedBox(width: 8),
            Text('Publicar notícia?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A notícia será publicada no Blogger e todos os usuários receberão uma notificação.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                _titleController.text.trim(),
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
              _publish();
            },
            child: const Text(
              'Publicar',
              style: TextStyle(
                  color: AppColors.primaryOrange, fontWeight: FontWeight.w800),
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
        body: _previewMode ? _buildPreview() : _buildEditor(),
      ),
    );
  }

  Widget _buildAppBar() {
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
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'NOVA NOTÍCIA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
      actions: [
        // Botão preview
        TextButton.icon(
          onPressed: () => setState(() => _previewMode = !_previewMode),
          icon: Icon(
            _previewMode ? Icons.edit_rounded : Icons.preview_rounded,
            size: 16,
            color: _previewMode ? AppColors.primaryOrange : AppColors.textSecondary,
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
        // Botão publicar
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _isPublishing ? null : _showPublishConfirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: _isPublishing ? null : AppColors.orangeGradient,
                color: _isPublishing ? AppColors.backgroundElevated : null,
                boxShadow: _isPublishing
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.35),
                          blurRadius: 10,
                        ),
                      ],
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.publish_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'PUBLICAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título ──────────────────────────────────────────
          _SectionLabel(label: 'TÍTULO', icon: Icons.title_rounded),
          const SizedBox(height: 8),
          _EditorField(
            controller: _titleController,
            hintText: 'Ex: Prefeitura anuncia novo projeto para...',
            maxLines: 2,
            maxLength: 200,
            fontSize: 16,
          ),
          const SizedBox(height: 20),

          // ── Categorias rápidas ───────────────────────────────
          _SectionLabel(
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
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
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
          const SizedBox(height: 10),
          _EditorField(
            controller: _labelsController,
            hintText: 'Outras categorias separadas por vírgula...',
            maxLines: 1,
            fontSize: 13,
          ),
          const SizedBox(height: 20),

          // ── Conteúdo HTML ────────────────────────────────────
          _SectionLabel(
              label: 'CONTEÚDO (HTML)', icon: Icons.code_rounded),
          const SizedBox(height: 4),
          const Text(
            'Você pode usar tags HTML: <b>, <i>, <p>, <h2>, <ul>, <li>, <a href="">',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _EditorField(
            controller: _contentController,
            hintText:
                '<p>Escreva o conteúdo da notícia aqui...</p>\n\n<p>Segundo parágrafo...</p>',
            maxLines: 20,
            minLines: 12,
            fontSize: 13,
            monospace: true,
          ),
          const SizedBox(height: 20),

          // ── Dicas de HTML ────────────────────────────────────
          _HtmlCheatSheet(),
          const SizedBox(height: 32),

          // ── Botão publicar (bottom) ──────────────────────────
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _isPublishing ? null : _showPublishConfirm,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient:
                      _isPublishing ? null : AppColors.orangeGradient,
                  color: _isPublishing
                      ? AppColors.backgroundElevated
                      : null,
                  boxShadow: _isPublishing
                      ? null
                      : [
                          BoxShadow(
                            color:
                                AppColors.primaryOrange.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isPublishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.publish_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'PUBLICAR NOTÍCIA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

          // Categorias
          if (_allLabels.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              children: _allLabels
                  .map((l) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.12),
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

          // Título
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

          // Conteúdo
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
                          color: AppColors.primaryOrange.withOpacity(0.2)),
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
