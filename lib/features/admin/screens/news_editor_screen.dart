import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/post_model.dart';
import '../../../services/cloudinary_upload_service.dart';
import '../services/admin_news_service.dart';
import '../services/push_notification_service.dart';
import '../../../utils/plain_text_html_converter.dart';

/// Formulário de criação/edição de notícia, usado pela aba NOTÍCIAS
/// do painel ADM. Cobre: título, resumo, conteúdo, categoria, capa,
/// galeria de imagens, vídeo, e os três estados de publicação
/// (rascunho, publicada, despublicada).
///
/// ATENÇÃO: este arquivo é puramente visual. Todo o fluxo de salvar,
/// publicar e disparar a notificação push continua idêntico —
/// _buildPost, _save, createNews/updateNews e o tratamento de
/// PushNotificationResult não foram alterados. Só o visual (cores,
/// layout, animações) foi refeito para seguir a identidade do resto
/// do app: fundo preto, partículas de fogo, glow laranja e gradientes.
class NewsEditorScreen extends StatefulWidget {
  final AdminNewsService newsService;
  final PostModel? existingPost;

  const NewsEditorScreen({
    required this.newsService,
    this.existingPost,
    Key? key,
  }) : super(key: key);

  @override
  State<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends State<NewsEditorScreen>
    with TickerProviderStateMixin {
  final _cloudinary = CloudinaryUploadService();
  final _picker = ImagePicker();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _summaryCtrl;
  late final _RichTextEditingController _contentCtrl;
  late final TextEditingController _categoryCtrl;

  String _coverUrl = '';
  List<String> _gallery = [];
  String? _videoUrl;

  bool _uploadingCover = false;
  bool _uploadingGallery = false;
  bool _uploadingVideo = false;
  bool _saving = false;

  bool get _isEditing => widget.existingPost != null;

  final FocusNode _contentFocusNode = FocusNode();

  late final AnimationController _particleCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    final post = widget.existingPost;
    _titleCtrl = TextEditingController(text: post?.title ?? '');
    _summaryCtrl = TextEditingController(text: post?.summary ?? '');
    _contentCtrl = _RichTextEditingController(text: post?.content ?? '');
    _categoryCtrl = TextEditingController(
      text: post != null && post.categories.isNotEmpty
          ? post.categories.first.name
          : '',
    );
    _coverUrl = post?.thumbnailUrl ?? '';
    _gallery = List<String>.from(post?.gallery ?? []);
    _videoUrl = post?.videoUrl;

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
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    _contentFocusNode.dispose();
    _particleCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── Toolbar de formatação do campo "Conteúdo completo" ──────────────────
  // Envolve (ou converte) o trecho selecionado do texto com a tag/efeito
  // escolhido. Se nada estiver selecionado, mostra um aviso.
  void _wrapSelection({required String openTag, required String closeTag}) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      _showError('Selecione um trecho do texto para formatar.');
      return;
    }
    final selected = text.substring(sel.start, sel.end);
    final newText = text.replaceRange(
      sel.start,
      sel.end,
      '$openTag$selected$closeTag',
    );
    final newCursor = sel.start + openTag.length + selected.length + closeTag.length;
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  void _applyBold() =>
      _wrapSelection(openTag: '<b>', closeTag: '</b>');

  void _applyHighlight() =>
      _wrapSelection(openTag: '<mark>', closeTag: '</mark>');

  void _applyUppercase() {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) {
      _showError('Selecione um trecho do texto para colocar em maiúsculas.');
      return;
    }
    final selected = text.substring(sel.start, sel.end);
    final upper = selected.toUpperCase();
    final newText = text.replaceRange(sel.start, sel.end, upper);
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: sel.start,
        extentOffset: sel.start + upper.length,
      ),
    );
  }

  // ── Lógica de dados: idêntica à versão anterior ─────────────────────────
  PostModel _buildPost(PostStatus status) {
    final categories = _categoryCtrl.text.trim().isEmpty
        ? <CategoryModel>[]
        : [CategoryModel.fromString(_categoryCtrl.text.trim())];

    return PostModel(
      id: widget.existingPost?.id ?? '',
      title: _titleCtrl.text.trim(),
      summary: _summaryCtrl.text.trim(),
      content: PlainTextHtmlConverter.ensureHtml(_contentCtrl.text.trim()),
      thumbnailUrl: _coverUrl,
      gallery: _gallery,
      videoUrl: _videoUrl,
      categories: categories,
      publishedAt: widget.existingPost?.publishedAt ?? DateTime.now(),
      status: status,
      authorUid: widget.existingPost?.authorUid,
      authorName: widget.existingPost?.authorName,
    );
  }

  Future<void> _pickAndUploadCover() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await _cloudinary.uploadImage(File(picked.path));
      setState(() => _coverUrl = url);
    } catch (e) {
      _showError('Falha ao enviar imagem de capa: $e');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickAndUploadGalleryImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingGallery = true);
    try {
      final url = await _cloudinary.uploadImage(File(picked.path));
      setState(() => _gallery = [..._gallery, url]);
    } catch (e) {
      _showError('Falha ao enviar imagem da galeria: $e');
    } finally {
      if (mounted) setState(() => _uploadingGallery = false);
    }
  }

  Future<void> _pickAndUploadVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploadingVideo = true);
    try {
      final url = await _cloudinary.uploadVideo(File(picked.path));
      setState(() => _videoUrl = url);
    } catch (e) {
      _showError('Falha ao enviar vídeo: $e');
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[900]),
    );
  }

  bool _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('O título é obrigatório.');
      return false;
    }
    if (_contentCtrl.text.trim().isEmpty) {
      _showError('O conteúdo é obrigatório.');
      return false;
    }
    if (_uploadingCover || _uploadingVideo) {
      _showError(
          'Aguarde o envio da ${_uploadingCover ? 'imagem' : 'vídeo'} '
          'terminar antes de publicar.');
      return false;
    }
    return true;
  }

  Future<void> _save(PostStatus status) async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final post = _buildPost(status);
      PushNotificationResult? pushResult;
      if (_isEditing) {
        pushResult =
            await widget.newsService.updateNews(widget.existingPost!.id, post);
      } else {
        final (_, result) = await widget.newsService.createNews(post);
        pushResult = result;
      }

      // Exibe um SnackBar discreto e elegante com a identidade visual do app.
      //
      // pushResult == null significa que nenhum push foi tentado — caso
      // normal ao editar uma notícia que já estava publicada (o push só
      // dispara na transição para "publicado", não a cada edição). Isso
      // não é uma falha, então não deve ser tratado como aviso/erro.
      if (status == PostStatus.published && mounted) {
        final bool pushAttempted = pushResult != null;
        final bool success = pushResult?.success ?? false;

        final String message;
        final IconData icon;
        final Color iconColor;
        if (!pushAttempted) {
          message = 'Notícia atualizada.';
          icon = Icons.check_circle_rounded;
          iconColor = AppColors.primaryOrange;
        } else if (success) {
          message = 'Notícia publicada e notificação enviada!';
          icon = Icons.check_circle_rounded;
          iconColor = AppColors.primaryOrange;
        } else {
          message =
              'Publicado, mas o push falhou: ${pushResult.message ?? "Erro desconhecido"}';
          icon = Icons.warning_rounded;
          iconColor = Colors.orangeAccent;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.backgroundElevated,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(
                color: AppColors.primaryOrange,
                width: 1,
              ),
            ),
          ),
        );
      }

      if (pushResult != null && !pushResult.success) {
        // Não fecha a tela: o ADM precisa ver o erro do push antes de sair.
        // A notícia já foi salva/publicada normalmente; só o push falhou.
        return;
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black)),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _EditorParticlePainter(_particleCtrl.value),
              ),
            ),
          ),
          SafeArea(
            child: _saving
                ? _buildSavingState()
                : Column(
                    children: [
                      _buildAppBar(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            _sectionCard(
                              title: 'Conteúdo',
                              icon: Icons.article_rounded,
                              children: [
                                _label('Título'),
                                _textField(_titleCtrl, hint: 'Título da notícia'),
                                const SizedBox(height: 14),
                                _label('Subtítulo / Resumo'),
                                _textField(_summaryCtrl,
                                    hint: 'Resumo curto que aparece na listagem',
                                    maxLines: 2),
                                const SizedBox(height: 14),
                                _label('Categoria'),
                                _textField(_categoryCtrl,
                                    hint: 'Ex.: Cidade, Esporte...'),
                                const SizedBox(height: 14),
                                _label('Conteúdo completo'),
                                _buildFormatToolbar(),
                                const SizedBox(height: 8),
                                _textField(_contentCtrl,
                                    hint:
                                        'Texto da notícia. Pode conter HTML simples (<p>, <b>, <h2>...).',
                                    maxLines: 10,
                                    focusNode: _contentFocusNode),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _sectionCard(
                              title: 'Mídia',
                              icon: Icons.perm_media_rounded,
                              children: [
                                _buildCoverSection(),
                                const SizedBox(height: 18),
                                _buildVideoSection(),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.orangeGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.5 * _glowAnim.value),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Salvando notícia...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: AppColors.orangeGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              _isEditing ? Icons.edit_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'EDITAR NOTÍCIA' : 'NOVA NOTÍCIA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _isEditing ? 'Atualize os dados da matéria' : 'Preencha os dados da matéria',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF161616).withOpacity(0.82),
                const Color(0xFF0D0D0D).withOpacity(0.82),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFF232323)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      );

  // Barra de formatação: negrito, MAIÚSCULAS e destaque laranja (<mark>),
  // aplicados sobre o trecho selecionado no campo "Conteúdo completo".
  Widget _buildFormatToolbar() {
    return Row(
      children: [
        _formatButton(
          icon: Icons.format_bold_rounded,
          label: 'Negrito',
          onTap: _applyBold,
        ),
        const SizedBox(width: 8),
        _formatButton(
          icon: Icons.text_fields_rounded,
          label: 'MAIÚSC.',
          onTap: _applyUppercase,
        ),
        const SizedBox(width: 8),
        _formatButton(
          icon: Icons.border_color_rounded,
          label: 'Destacar',
          onTap: _applyHighlight,
          highlighted: true,
        ),
      ],
    );
  }

  Widget _formatButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Expanded(
      child: Material(
        color: highlighted
            ? AppColors.primaryOrange.withOpacity(0.14)
            : const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: highlighted
                    ? AppColors.primaryOrange.withOpacity(0.5)
                    : const Color(0xFF262626),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: highlighted
                        ? AppColors.primaryOrange
                        : Colors.white70),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: highlighted
                        ? AppColors.primaryOrange
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller,
      {String? hint, int maxLines = 1, FocusNode? focusNode}) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: AppColors.primaryOrange,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF262626)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF262626)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _uploadButton({
    required VoidCallback? onPressed,
    required bool loading,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryOrange,
          side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.primaryOrange.withOpacity(0.06),
        ),
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryOrange),
              )
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Imagem de capa'),
        if (_coverUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.network(_coverUrl,
                      height: 150, width: double.infinity, fit: BoxFit.cover),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _coverUrl = ''),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black87,
                        child: Icon(Icons.close_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        _uploadButton(
          onPressed: _uploadingCover ? null : _pickAndUploadCover,
          loading: _uploadingCover,
          icon: Icons.image_rounded,
          label: _coverUrl.isEmpty ? 'Escolher capa' : 'Trocar capa',
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Vídeo (opcional)'),
        if (_videoUrl != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded,
                    color: AppColors.primaryOrange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_videoUrl!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _videoUrl = null),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 18),
                ),
              ],
            ),
          ),
        _uploadButton(
          onPressed: _uploadingVideo ? null : _pickAndUploadVideo,
          loading: _uploadingVideo,
          icon: Icons.video_call_rounded,
          label: _videoUrl == null ? 'Adicionar vídeo' : 'Trocar vídeo',
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.3 * _glowAnim.value),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_uploadingCover || _uploadingVideo)
                  ? null
                  : () => _save(PostStatus.published),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publicar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _save(PostStatus.draft),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF333333)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar como rascunho',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DE FOGO DE FUNDO (mesmo padrão visual do Ranking / Notícias)
// ═══════════════════════════════════════════════════════════════════
class _EditorParticlePainter extends CustomPainter {
  final double t;
  _EditorParticlePainter(this.t);

  static final _rng = math.Random(19);
  static final _particles = List.generate(
    36,
    (i) => _EPData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 1.2 + _rng.nextDouble() * 2.6,
      speed: 0.02 + _rng.nextDouble() * 0.05,
      opacity: 0.25 + _rng.nextDouble() * 0.45,
      phase: _rng.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Dois glows radiais bem mais fortes e visíveis, cantos opostos.
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B00).withOpacity(0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.12, size.height * 0.04),
        radius: size.width * 0.85,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.04),
      size.width * 0.85,
      orbPaint,
    );

    final orbPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF2200).withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.92, size.height * 0.85),
        radius: size.width * 0.75,
      ));
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.85),
      size.width * 0.75,
      orbPaint2,
    );

    for (final p in _particles) {
      final dy = 1.0 - ((p.y + t * p.speed + p.phase) % 1.0);
      final dx = p.x + 0.025 * math.sin((t * 2 * math.pi * 0.6) + p.phase * 6.28);
      final fireRatio = 1.0 - dy;
      final color = Color.lerp(
        const Color(0xFFFFA040),
        const Color(0xFFFF2200),
        fireRatio,
      )!;
      final opacity = p.opacity *
          (0.5 + 0.5 * math.sin(t * 2 * math.pi * p.speed * 10 + p.phase));

      final center = Offset(dx * size.width, dy * size.height);
      final finalOpacity = opacity.clamp(0.0, 0.7);

      // Halo suave em volta de cada partícula para dar sensação de brilho/fogo.
      canvas.drawCircle(
        center,
        p.size * 3,
        Paint()..color = color.withOpacity(finalOpacity * 0.15),
      );
      canvas.drawCircle(
        center,
        p.size,
        Paint()..color = color.withOpacity(finalOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_EditorParticlePainter old) => old.t != t;
}

class _EPData {
  final double x, y, size, speed, opacity, phase;
  const _EPData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

// ═══════════════════════════════════════════════════════════════════
// CONTROLLER COM PRÉVIA VISUAL DE FORMATAÇÃO
// ═══════════════════════════════════════════════════════════════════
// Faz o campo "Conteúdo completo" mostrar, em tempo real, o efeito da
// formatação inserida pela toolbar: o trecho entre <mark>...</mark>
// aparece já em laranja/negrito, e entre <b>...</b> já em negrito —
// sem esconder as tags (elas continuam visíveis e editáveis como
// texto), só coloridas, para o ADM ver de imediato o que vai virar
// destaque quando a notícia for publicada.
class _RichTextEditingController extends TextEditingController {
  _RichTextEditingController({String? text}) : super(text: text);

  static final RegExp _tagPattern = RegExp(
    r'<(/?)(mark|b|strong)>',
    caseSensitive: false,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    final baseStyle = style ?? const TextStyle();

    // Sem nenhuma tag de formatação no texto: usa o comportamento padrão
    // do Flutter, que trata corretamente composição do teclado (IME) e
    // seleção. É o caminho mais comum (a maior parte do texto digitado
    // não tem tag nenhuma), e evita qualquer risco de quebrar o gesto
    // de selecionar/colar.
    if (!_tagPattern.hasMatch(source)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final children = <InlineSpan>[];

    final tagStyle = baseStyle.copyWith(
      color: const Color(0xFF555555),
      fontWeight: FontWeight.w400,
    );
    final markStyle = baseStyle.copyWith(
      color: AppColors.primaryOrange,
      fontWeight: FontWeight.w800,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w800);

    int cursor = 0;
    final List<String> stack = [];

    TextStyle currentStyle() {
      if (stack.isEmpty) return baseStyle;
      return stack.last == 'mark' ? markStyle : boldStyle;
    }

    for (final match in _tagPattern.allMatches(source)) {
      if (match.start > cursor) {
        children.add(TextSpan(
          text: source.substring(cursor, match.start),
          style: currentStyle(),
        ));
      }
      // A tag em si aparece discreta (cinza), pra não poluir, mas
      // continua editável normalmente como parte do texto.
      children.add(TextSpan(text: match.group(0), style: tagStyle));

      final isClosing = match.group(1) == '/';
      final tagName = match.group(2)!.toLowerCase();
      final normalized = tagName == 'strong' ? 'b' : tagName;
      if (isClosing) {
        if (stack.isNotEmpty && stack.last == normalized) stack.removeLast();
      } else {
        stack.add(normalized);
      }
      cursor = match.end;
    }

    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: currentStyle()));
    }

    return TextSpan(style: baseStyle, children: children);
  }
}