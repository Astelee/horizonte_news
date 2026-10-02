import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/post_model.dart';
import '../../../services/cloudinary_upload_service.dart';
import '../services/admin_news_service.dart';
import '../services/push_notification_service.dart';
import '../../../utils/plain_text_html_converter.dart';
import '../widgets/video_frame_editor.dart';
import '../widgets/news_image_crop_screen.dart';
import '../../../widgets/app_messenger.dart';

/// Formulário de criação/edição de notícia, usado pela aba NOTÍCIAS
/// do painel ADM. Cobre: título, resumo, conteúdo, categoria, capa,
/// galeria de imagens, vídeo, e os três estados de publicação
/// (rascunho, publicada, despublicada).
///
/// ATENÇÃO: este arquivo é puramente visual/estrutural. Todo o fluxo de
/// salvar, publicar e disparar a notificação push continua idêntico —
/// _buildPost, _save, createNews/updateNews e o tratamento de
/// PushNotificationResult não foram alterados. O que mudou foi a
/// apresentação: seções mais claras, contadores de caracteres, seletor
/// de categoria visual (reaproveitando exatamente as categorias já
/// usadas em CategoryBar), galeria de imagens com interface própria,
/// selo de status, preview da matéria e estados de erro/carregamento
/// padronizados — sempre em cima da mesma lógica de dados e dos mesmos
/// serviços (Cloudinary, AdminNewsService, PushNotificationService,
/// PlainTextHtmlConverter, VideoFrameEditor, AppMessenger).
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

/// Categoria disponível para seleção no editor. Mantém exatamente os
/// mesmos rótulos, ícones e cores já usados em [CategoryBar] (a barra
/// de categorias da Home), para que a categoria escolhida aqui seja a
/// mesma categoria que o usuário final vê filtrada no app.
class _EditorCategoryOption {
  final String label;
  final IconData icon;
  final Color color;
  const _EditorCategoryOption(this.label, this.icon, this.color);
}

const List<_EditorCategoryOption> _kEditorCategories = [
  _EditorCategoryOption(
      'Horizonte', FontAwesomeIcons.buildingColumns, Color(0xFFFF6B00)),
  _EditorCategoryOption('Pacajus', FontAwesomeIcons.tree, Color(0xFF43A047)),
  _EditorCategoryOption(
      'Itaitinga', FontAwesomeIcons.water, Color(0xFF1E88E5)),
  _EditorCategoryOption(
      'Chorozinho', FontAwesomeIcons.wheatAwn, Color(0xFFFFB300)),
  _EditorCategoryOption(
      'Ceará', FontAwesomeIcons.mapLocationDot, Color(0xFF00ACC1)),
  _EditorCategoryOption('Brasil', FontAwesomeIcons.flag, Color(0xFF43A047)),
  _EditorCategoryOption(
      'Mundo', FontAwesomeIcons.earthAmericas, Color(0xFF5C6BC0)),
  _EditorCategoryOption('Esportes', FontAwesomeIcons.futbol, Color(0xFF26C6DA)),
  _EditorCategoryOption('Saúde', FontAwesomeIcons.heartPulse, Color(0xFFEF5350)),
  _EditorCategoryOption(
      'Entretenimento', FontAwesomeIcons.film, Color(0xFFAB47BC)),
];

/// Limite recomendado (não bloqueante) de caracteres do resumo. O
/// título não tem limite nenhum.
const int _kSummarySoftLimit = 180;

class _NewsEditorScreenState extends State<NewsEditorScreen>
    with TickerProviderStateMixin {
  final _cloudinary = CloudinaryUploadService();
  final _picker = ImagePicker();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _summaryCtrl;
  late final _RichTextEditingController _contentCtrl;
  late final TextEditingController _categoryCtrl;

  String _coverUrl = '';
  double? _coverAspectRatio; // proporção definida no recorte da capa
  bool _customCategory = false; // "Outra categoria" selecionada
  bool _coverLoadError = false;
  List<String> _gallery = [];
  String? _videoUrl;
  File? _pendingVideoFile; // arquivo local só enquanto ajusta o enquadramento
  VideoFrameConfig _videoFrameConfig = VideoFrameConfig.original;

  bool _uploadingCover = false;
  bool _uploadingGallery = false;
  bool _uploadingVideo = false;
  bool _saving = false;

  // Rótulo do estado de salvamento em andamento, exibido na tela de
  // loading (ex.: "Publicando...", "Enviando notificação..."). Não
  // altera nenhuma lógica — é só o texto mostrado durante _save().
  String _savingLabel = 'Salvando notícia...';

  // Status "de trabalho" mostrado no selo do topo: por padrão segue o
  // status do post existente (ou rascunho, para um post novo). Os
  // botões de publicar/rascunho continuam sendo quem decide de fato o
  // PostStatus gravado — este campo é só para o selo visual reagir
  // imediatamente ao que o usuário está prestes a fazer.
  late PostStatus _displayStatus;

  bool get _isEditing => widget.existingPost != null;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _summaryFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

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
    _coverAspectRatio = post?.coverAspectRatio;
    final initialCategory = _categoryCtrl.text.trim();
    _customCategory = initialCategory.isNotEmpty &&
        !_kEditorCategories
            .any((c) => c.label.toLowerCase() == initialCategory.toLowerCase());
    _gallery = List<String>.from(post?.gallery ?? []);
    _videoUrl = post?.videoUrl;
    _videoFrameConfig = post?.videoFrameConfig ?? VideoFrameConfig.original;
    _displayStatus = post?.status ?? PostStatus.draft;

    // Reconstrói a tela quando os campos com contador mudam, para os
    // contadores de caracteres atualizarem em tempo real.
    _titleCtrl.addListener(_onCounterFieldChanged);
    _summaryCtrl.addListener(_onCounterFieldChanged);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  void _onCounterFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onCounterFieldChanged);
    _summaryCtrl.removeListener(_onCounterFieldChanged);
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    _titleFocusNode.dispose();
    _summaryFocusNode.dispose();
    _contentFocusNode.dispose();
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
    final newCursor =
        sel.start + openTag.length + selected.length + closeTag.length;
    _contentCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  void _applyBold() => _wrapSelection(openTag: '<b>', closeTag: '</b>');

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
      coverAspectRatio: _coverUrl.isEmpty ? null : _coverAspectRatio,
      gallery: _gallery,
      videoUrl: _videoUrl,
      videoFrameConfig: _videoFrameConfig,
      categories: categories,
      publishedAt: widget.existingPost?.publishedAt ?? DateTime.now(),
      status: status,
      authorUid: widget.existingPost?.authorUid,
      authorName: widget.existingPost?.authorName,
    );
  }

  /// Escolhe uma foto, abre o recorte e devolve o arquivo já recortado
  /// (temporário) junto da proporção escolhida. Null se cancelar.
  Future<({File file, double ratio})?> _pickAndCropImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (!mounted) return null;
    final result = await Navigator.of(context).push<NewsCropResult>(
      MaterialPageRoute(
        builder: (_) => NewsImageCropScreen(imageBytes: bytes),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return null;
    final file = File(
        '${Directory.systemTemp.path}/news_crop_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(result.bytes, flush: true);
    return (file: file, ratio: result.aspectRatio);
  }

  Future<void> _pickAndUploadCover() async {
    final cropped = await _pickAndCropImage();
    if (cropped == null) return;
    setState(() {
      _uploadingCover = true;
      _coverLoadError = false;
    });
    try {
      final url = await _cloudinary.uploadImage(cropped.file);
      setState(() {
        _coverUrl = url;
        _coverAspectRatio = cropped.ratio;
      });
    } catch (e) {
      _showError('Falha ao enviar imagem de capa. Verifique sua conexão '
          'e tente novamente.');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  void _removeCover() {
    setState(() {
      _coverUrl = '';
      _coverAspectRatio = null;
      _coverLoadError = false;
    });
  }

  Future<void> _pickAndUploadGalleryImage() async {
    final cropped = await _pickAndCropImage();
    if (cropped == null) return;
    setState(() => _uploadingGallery = true);
    try {
      final url = await _cloudinary.uploadImage(cropped.file);
      setState(() => _gallery = [..._gallery, url]);
    } catch (e) {
      _showError('Falha ao enviar imagem da galeria. Verifique sua conexão '
          'e tente novamente.');
    } finally {
      if (mounted) setState(() => _uploadingGallery = false);
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      final updated = List<String>.from(_gallery);
      updated.removeAt(index);
      _gallery = updated;
    });
  }

  void _moveGalleryImage(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _gallery.length) return;
    setState(() {
      final updated = List<String>.from(_gallery);
      final item = updated.removeAt(index);
      updated.insert(newIndex, item);
      _gallery = updated;
    });
  }

  Future<void> _pickAndUploadVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);

    // Antes de subir, abre o editor de enquadramento com o próprio
    // arquivo local — assim o preview é instantâneo (não depende do
    // upload terminar) e o usuário já escolhe o corte/zoom/proporção
    // com o vídeo real, vendo exatamente como vai ficar publicado.
    final config = await Navigator.of(context).push<VideoFrameConfig>(
      MaterialPageRoute(
        builder: (_) => VideoFrameEditor(
          videoFile: file,
          initialConfig: _videoFrameConfig,
        ),
        fullscreenDialog: true,
      ),
    );
    if (config == null) return; // usuário cancelou o ajuste

    setState(() {
      _pendingVideoFile = file;
      _videoFrameConfig = config;
      _uploadingVideo = true;
    });
    try {
      final url = await _cloudinary.uploadVideo(file);
      setState(() => _videoUrl = url);
    } catch (e) {
      _showError('Falha ao enviar vídeo. Verifique sua conexão e tente '
          'novamente.');
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
      // _pendingVideoFile é mantido (não zerado) para permitir reabrir
      // o editor de enquadramento depois, sem pedir o arquivo de novo.
    }
  }

  void _removeVideo() {
    setState(() {
      _videoUrl = null;
      _pendingVideoFile = null;
      _videoFrameConfig = VideoFrameConfig.original;
    });
  }

  /// Reabre o editor de enquadramento para um vídeo já enviado (ou em
  /// preview), sem precisar escolher o arquivo de novo.
  Future<void> _adjustVideoFrame() async {
    final file = _pendingVideoFile;
    if (file == null) return;
    final config = await Navigator.of(context).push<VideoFrameConfig>(
      MaterialPageRoute(
        builder: (_) => VideoFrameEditor(
          videoFile: file,
          initialConfig: _videoFrameConfig,
        ),
        fullscreenDialog: true,
      ),
    );
    if (config != null) setState(() => _videoFrameConfig = config);
  }

  void _showError(String message) {
    AppMessenger.error(message);
  }

  bool _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('O título é obrigatório.');
      FocusScope.of(context).requestFocus(_titleFocusNode);
      return false;
    }
    if (_contentCtrl.text.trim().isEmpty) {
      _showError('O conteúdo é obrigatório.');
      FocusScope.of(context).requestFocus(_contentFocusNode);
      return false;
    }
    if (_customCategory && _categoryCtrl.text.trim().isEmpty) {
      _showError('Digite o nome da categoria.');
      return false;
    }
    if (_uploadingCover || _uploadingVideo || _uploadingGallery) {
      final what = _uploadingCover
          ? 'da imagem de capa'
          : _uploadingVideo
              ? 'do vídeo'
              : 'da imagem da galeria';
      _showError('Aguarde o envio $what terminar antes de continuar.');
      return false;
    }
    return true;
  }

  Future<void> _save(PostStatus status) async {
    if (_saving) return; // trava contra duplo toque/salvamento simultâneo
    if (!_validate()) return;
    final previousDisplayStatus = _displayStatus;
    setState(() {
      _saving = true;
      _savingLabel = status == PostStatus.published
          ? 'Publicando notícia...'
          : 'Salvando rascunho...';
      _displayStatus = status;
    });
    try {
      final post = _buildPost(status);
      PushNotificationResult? pushResult;
      if (_isEditing) {
        if (status == PostStatus.published && mounted) {
          setState(() => _savingLabel = 'Publicando e enviando notificação...');
        }
        pushResult =
            await widget.newsService.updateNews(widget.existingPost!.id, post);
      } else {
        if (status == PostStatus.published && mounted) {
          setState(() => _savingLabel = 'Publicando e enviando notificação...');
        }
        final (_, result) = await widget.newsService.createNews(post);
        pushResult = result;
      }

      // Feedback padronizado via AppMessenger (identidade visual do app).
      if (status == PostStatus.published && mounted) {
        final bool pushAttempted = pushResult != null;
        final bool success = pushResult?.success ?? false;

        if (!pushAttempted) {
          AppMessenger.success('Notícia atualizada.');
        } else if (success) {
          AppMessenger.success('Notícia publicada e notificação enviada!');
        } else {
          AppMessenger.warning(
            'Publicado, mas o push falhou: ${pushResult.message ?? "Erro desconhecido"}',
          );
        }
      } else if (mounted) {
        AppMessenger.success('Rascunho salvo.');
      }

      if (pushResult != null && !pushResult.success) {
        // Não fecha a tela: o ADM precisa ver o erro do push antes de sair.
        // A notícia já foi salva/publicada normalmente; só o push falhou.
        return;
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _displayStatus = previousDisplayStatus);
      _showError('Falha ao salvar a notícia. Tente novamente em instantes.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Preview ──────────────────────────────────────────────────────────
  void _openPreview() {
    final categoryOption = _categoryOptionFor(_categoryCtrl.text.trim());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewsPreviewSheet(
        title: _titleCtrl.text.trim(),
        summary: _summaryCtrl.text.trim(),
        contentHtml:
            PlainTextHtmlConverter.ensureHtml(_contentCtrl.text.trim()),
        coverUrl: _coverUrl,
        coverAspectRatio: _coverAspectRatio,
        gallery: _gallery,
        videoUrl: _videoUrl,
        categoryLabel:
            _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        categoryColor: categoryOption?.color ?? AppColors.primaryOrange,
      ),
    );
  }

  _EditorCategoryOption? _categoryOptionFor(String label) {
    if (label.isEmpty) return null;
    for (final c in _kEditorCategories) {
      if (c.label.toLowerCase() == label.toLowerCase()) return c;
    }
    return null;
  }

  void _selectCategory(String label) {
    setState(() {
      _customCategory = false;
      _categoryCtrl.text = label;
    });
  }

  void _selectCustomCategory() {
    setState(() {
      // Se havia uma categoria da lista selecionada, limpa o campo para
      // o ADM digitar a nova; se já era personalizada, mantém o texto.
      if (!_customCategory) _categoryCtrl.text = '';
      _customCategory = true;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black)),
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _EditorStaticBackgroundPainter()),
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
                          padding: EdgeInsets.fromLTRB(
                              16, 12, 16, 32 + bottomInset * 0.0),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            _StatusBadgeBar(
                              status: _displayStatus,
                              isEditing: _isEditing,
                              onPreview: _openPreview,
                            ),
                            const SizedBox(height: 14),
                            _SectionCard(
                              title: 'Informações da notícia',
                              icon: Icons.info_outline_rounded,
                              children: [
                                _label('Título'),
                                _CounterTextField(
                                  controller: _titleCtrl,
                                  focusNode: _titleFocusNode,
                                  hint: 'Título chamativo e direto da notícia',
                                  maxLines: null,
                                  minLines: 1,
                                ),
                                const SizedBox(height: 14),
                                _label('Resumo / linha fina'),
                                _CounterTextField(
                                  controller: _summaryCtrl,
                                  focusNode: _summaryFocusNode,
                                  hint:
                                      'Resumo curto que aparece na listagem e no compartilhamento',
                                  maxLines: 3,
                                  minLines: 2,
                                  softLimit: _kSummarySoftLimit,
                                ),
                                const SizedBox(height: 14),
                                _label('Categoria'),
                                _CategorySelector(
                                  controller: _categoryCtrl,
                                  customMode: _customCategory,
                                  onSelected: _selectCategory,
                                  onCustomSelected: _selectCustomCategory,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Conteúdo',
                              icon: Icons.article_rounded,
                              children: [
                                Row(
                                  children: [
                                    _label('Conteúdo completo'),
                                    const Spacer(),
                                    _WordCountBadge(text: _contentCtrl.text),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _EditorToolbar(
                                  onBold: _applyBold,
                                  onUppercase: _applyUppercase,
                                  onHighlight: _applyHighlight,
                                ),
                                const SizedBox(height: 8),
                                _textField(
                                  _contentCtrl,
                                  hint:
                                      'Texto da notícia. Selecione um trecho e use a barra acima para formatar.',
                                  maxLines: 14,
                                  minLines: 8,
                                  focusNode: _contentFocusNode,
                                  quietSelectionHaptics: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Mídia',
                              icon: Icons.perm_media_rounded,
                              children: [
                                _CoverSection(
                                  coverUrl: _coverUrl,
                                  aspectRatio: _coverAspectRatio,
                                  uploading: _uploadingCover,
                                  loadError: _coverLoadError,
                                  onPick: _pickAndUploadCover,
                                  onRemove: _removeCover,
                                  onLoadError: () =>
                                      setState(() => _coverLoadError = true),
                                ),
                                const SizedBox(height: 20),
                                _GallerySection(
                                  images: _gallery,
                                  uploading: _uploadingGallery,
                                  onAdd: _pickAndUploadGalleryImage,
                                  onRemove: _removeGalleryImage,
                                  onMove: _moveGalleryImage,
                                ),
                                const SizedBox(height: 20),
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
                    color:
                        AppColors.primaryOrange.withOpacity(0.5 * _glowAnim.value),
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
          Text(
            _savingLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Não feche o app durante o envio.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
            tooltip: 'Voltar',
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
                  _isEditing
                      ? 'Atualize os dados da matéria'
                      : 'Preencha os dados da matéria',
                  style:
                      const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Pré-visualizar',
            child: IconButton(
              icon: const Icon(Icons.visibility_outlined, color: Colors.white70),
              onPressed: _openPreview,
            ),
          ),
        ],
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

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    int? minLines,
    FocusNode? focusNode,
    bool quietSelectionHaptics = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      minLines: minLines,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
      cursorColor: AppColors.primaryOrange,
      // Some Android keyboards fire a strong haptic pulse on every
      // character the selection handle passes over while dragging.
      // That's controlled by the system keyboard, not this widget —
      // but Flutter's own selection-handle-drag haptic (a separate,
      // smaller pulse) can be turned off here for fields where quick,
      // repeated re-selecting is common (ex.: the long content field,
      // used to select snippets to wrap with formatting tags).
      selectionControls: quietSelectionHaptics
          ? _QuietSelectionControls(materialTextSelectionControls)
          : null,
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
    String? loadingLabel,
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
        label: Text(
          loading ? (loadingLabel ?? 'Enviando...') : label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: AppColors.primaryOrange, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vídeo anexado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _videoUrl!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Remover vídeo',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _uploadingVideo ? null : _removeVideo,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_videoUrl != null && _pendingVideoFile != null) ...[
          _buildVideoFrameSummary(),
          const SizedBox(height: 8),
        ] else if (_videoUrl != null) ...[
          // Editando um post já existente: o arquivo local não está
          // disponível (só a URL já publicada), então não dá pra reabrir
          // o editor com preview ao vivo. Mostra o enquadramento salvo
          // como informação, e orienta a trocar o vídeo para poder
          // ajustar de novo.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                const Icon(Icons.crop_rounded, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_videoFramePresetLabel · para ajustar, troque o vídeo',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        _uploadButton(
          onPressed: _uploadingVideo ? null : _pickAndUploadVideo,
          loading: _uploadingVideo,
          loadingLabel: 'Processando vídeo...',
          icon: Icons.video_call_rounded,
          label: _videoUrl == null ? 'Adicionar vídeo' : 'Trocar vídeo',
        ),
      ],
    );
  }

  // ── Enquadramento de exibição do vídeo ────────────────────────────────
  // Mostra o preset/proporção atualmente escolhidos e permite reabrir o
  // editor de enquadramento (VideoFrameEditor) a qualquer momento antes
  // de publicar, com preview ao vivo do próprio vídeo selecionado.
  String get _videoFramePresetLabel {
    switch (_videoFrameConfig.preset) {
      case VideoFramePreset.original:
        return 'Tamanho original';
      case VideoFramePreset.ratio16x9:
        return 'Proporção 16:9';
      case VideoFramePreset.ratio1x1:
        return 'Proporção 1:1';
      case VideoFramePreset.ratio4x5:
        return 'Proporção 4:5';
      case VideoFramePreset.ratio9x16:
        return 'Proporção 9:16';
      case VideoFramePreset.custom:
        return 'Enquadramento livre';
    }
  }

  Widget _buildVideoFrameSummary() {
    return GestureDetector(
      onTap: _adjustVideoFrame,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            const Icon(Icons.crop_rounded, color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _videoFramePresetLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const Text(
              'Ajustar',
              style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primaryOrange, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool uploadingAny =
        _uploadingCover || _uploadingVideo || _uploadingGallery;
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
              onPressed:
                  uploadingAny ? null : () => _save(PostStatus.published),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.publish_rounded),
              label: Text(
                _isEditing ? 'Salvar alterações e publicar' : 'Publicar',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: uploadingAny ? null : () => _save(PostStatus.draft),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF333333)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _isEditing ? 'Salvar como rascunho' : 'Salvar rascunho',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEÇÃO / CARD — agrupa um bloco do formulário (Informações, Conteúdo,
// Mídia) num cartão com título, ícone e o mesmo estilo visual usado em
// toda a tela.
// ═══════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ═══════════════════════════════════════════════════════════════════
// SELO DE STATUS — mostra o status atual da notícia (rascunho,
// publicada, despublicada) e um atalho para pré-visualizar. Puramente
// visual: não altera o PostStatus, que continua decidido pelos botões
// de ação no rodapé da tela.
// ═══════════════════════════════════════════════════════════════════
class _StatusBadgeBar extends StatelessWidget {
  final PostStatus status;
  final bool isEditing;
  final VoidCallback onPreview;

  const _StatusBadgeBar({
    required this.status,
    required this.isEditing,
    required this.onPreview,
  });

  ({String label, Color color, IconData icon}) get _style {
    switch (status) {
      case PostStatus.published:
        return (
          label: 'PUBLICADA',
          color: const Color(0xFF43B581),
          icon: Icons.check_circle_rounded,
        );
      case PostStatus.unpublished:
        return (
          label: 'DESPUBLICADA',
          color: const Color(0xFFFFB300),
          icon: Icons.visibility_off_rounded,
        );
      case PostStatus.draft:
        return (
          label: 'RASCUNHO',
          color: const Color(0xFF9E9E9E),
          icon: Icons.edit_note_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: s.color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: s.color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(s.icon, size: 13, color: s.color),
              const SizedBox(width: 6),
              Text(
                s.label,
                style: TextStyle(
                  color: s.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPreview,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.white70),
                SizedBox(width: 6),
                Text(
                  'Pré-visualizar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CAMPO COM CONTADOR DE CARACTERES — usado no título e no resumo.
// Mostra "usados/limite sugerido" e muda de cor quando passa do limite
// recomendado. O limite é apenas visual/orientativo: o campo continua
// aceitando texto além dele, sem travar a digitação.
// ═══════════════════════════════════════════════════════════════════
class _CounterTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final int? maxLines;
  final int minLines;
  final int? softLimit;

  const _CounterTextField({
    required this.controller,
    required this.hint,
    this.softLimit,
    this.focusNode,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final length = controller.text.runes.length;
    final limit = softLimit; // null = sem limite (ex.: título)
    final overLimit = limit != null && length > limit;
    final nearLimit =
        limit != null && !overLimit && length >= (limit * 0.85).round();
    final counterColor = overLimit
        ? const Color(0xFFEF5350)
        : nearLimit
            ? const Color(0xFFFFB300)
            : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          minLines: minLines,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
          cursorColor: AppColors.primaryOrange,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0A0A0A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: overLimit
                    ? const Color(0xFFEF5350).withOpacity(0.6)
                    : const Color(0xFF262626),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: overLimit
                    ? const Color(0xFFEF5350).withOpacity(0.6)
                    : const Color(0xFF262626),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: overLimit
                    ? const Color(0xFFEF5350)
                    : AppColors.primaryOrange,
                width: 1.3,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (limit != null) const SizedBox(height: 4),
        if (limit != null)
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            overLimit
                ? '$length caracteres · acima do recomendado ($limit)'
                : '$length / $limit caracteres',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: counterColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Contador de palavras/caracteres do conteúdo completo — só
// informativo, ao lado do label da seção.
// ═══════════════════════════════════════════════════════════════════
class _WordCountBadge extends StatelessWidget {
  final String text;
  const _WordCountBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    final words =
        trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    final chars = text.runes.length;
    return Text(
      '$words palavras · $chars caracteres',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SELETOR DE CATEGORIA — chips horizontais com as mesmas categorias,
// ícones e cores usados em CategoryBar (Home). Ao tocar, preenche o
// mesmo _categoryCtrl que _buildPost já lê — nenhuma mudança na forma
// como a categoria é salva (continua sendo uma string simples,
// convertida por CategoryModel.fromString).
// ═══════════════════════════════════════════════════════════════════
class _CategorySelector extends StatelessWidget {
  final TextEditingController controller;
  final bool customMode;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustomSelected;

  const _CategorySelector({
    required this.controller,
    required this.customMode,
    required this.onSelected,
    required this.onCustomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedLabel = controller.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kEditorCategories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final bool isOther = index == _kEditorCategories.length;
                  final cat = isOther
                      ? const _EditorCategoryOption('Outra categoria',
                          FontAwesomeIcons.plus, AppColors.primaryOrange)
                      : _kEditorCategories[index];
                  final isSelected = isOther
                      ? customMode
                      : (!customMode &&
                          selectedLabel.toLowerCase() ==
                              cat.label.toLowerCase());
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () =>
                        isOther ? onCustomSelected() : onSelected(cat.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color.withOpacity(0.16)
                            : const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? cat.color.withOpacity(0.7)
                              : const Color(0xFF262626),
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(cat.icon,
                              size: 12,
                              color: isSelected ? cat.color : Colors.white54),
                          const SizedBox(width: 7),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? cat.color : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (customMode)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: AppColors.primaryOrange,
                  decoration: InputDecoration(
                    hintText: 'Nome da categoria (ex.: Fortaleza)',
                    hintStyle:
                        const TextStyle(color: Color(0xFF666666), fontSize: 13),
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
                      borderSide: const BorderSide(
                          color: AppColors.primaryOrange, width: 1.3),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BARRA DE FORMATAÇÃO — negrito, MAIÚSCULAS e destaque (<mark>),
// aplicados sobre o trecho selecionado no campo "Conteúdo completo".
// Mesmas três ações de sempre; só o visual (labels com tooltip) foi
// reforçado.
// ═══════════════════════════════════════════════════════════════════
class _EditorToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onUppercase;
  final VoidCallback onHighlight;

  const _EditorToolbar({
    required this.onBold,
    required this.onUppercase,
    required this.onHighlight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FormatButton(
          icon: Icons.format_bold_rounded,
          label: 'Negrito',
          tooltip: 'Aplicar negrito ao trecho selecionado',
          onTap: onBold,
        ),
        const SizedBox(width: 8),
        _FormatButton(
          icon: Icons.text_fields_rounded,
          label: 'MAIÚSC.',
          tooltip: 'Colocar o trecho selecionado em maiúsculas',
          onTap: onUppercase,
        ),
        const SizedBox(width: 8),
        _FormatButton(
          icon: Icons.border_color_rounded,
          label: 'Destacar',
          tooltip: 'Destacar o trecho selecionado em laranja',
          onTap: onHighlight,
          highlighted: true,
        ),
      ],
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  const _FormatButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: highlighted
              ? AppColors.primaryOrange.withOpacity(0.14)
              : const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
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
                      color: highlighted ? AppColors.primaryOrange : Colors.white70),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: highlighted ? AppColors.primaryOrange : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CAPA — preview grande, estado de carregamento, tratamento de erro
// amigável (em vez de deixar o Image.network quebrar visualmente) e
// botões de trocar/remover.
// ═══════════════════════════════════════════════════════════════════
class _CoverSection extends StatelessWidget {
  final String coverUrl;
  final double? aspectRatio;
  final bool uploading;
  final bool loadError;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onLoadError;

  const _CoverSection({
    required this.coverUrl,
    required this.aspectRatio,
    required this.uploading,
    required this.loadError,
    required this.onPick,
    required this.onRemove,
    required this.onLoadError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Imagem de capa',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _CoverFrame(
            aspectRatio: aspectRatio,
            child: coverUrl.isEmpty
                    ? const _EmptyMediaPlaceholder(
                        icon: Icons.image_outlined,
                        label: 'Nenhuma capa selecionada',
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (loadError)
                            const _EmptyMediaPlaceholder(
                              icon: Icons.broken_image_outlined,
                              label: 'Não foi possível carregar esta imagem',
                              isError: true,
                            )
                          else
                            Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) => onLoadError());
                                return const _EmptyMediaPlaceholder(
                                  icon: Icons.broken_image_outlined,
                                  label: 'Não foi possível carregar esta imagem',
                                  isError: true,
                                );
                              },
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const _MediaLoadingIndicator(
                                    label: 'Carregando...');
                              },
                            ),
                          if (!loadError)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.35)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Tooltip(
                              message: 'Remover capa',
                              child: GestureDetector(
                                onTap: onRemove,
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black87,
                                  child: Icon(Icons.close_rounded,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onPick,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppColors.primaryOrange.withOpacity(0.06),
            ),
            icon: uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryOrange),
                  )
                : Icon(coverUrl.isEmpty ? Icons.image_rounded : Icons.sync_alt_rounded,
                    size: 18),
            label: Text(
              uploading
                  ? 'Enviando imagem...'
                  : (coverUrl.isEmpty ? 'Escolher capa' : 'Trocar capa'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// Moldura da capa: usa a proporção escolhida no recorte (a imagem
/// aparece inteira, sem corte) ou altura fixa para capas antigas.
class _CoverFrame extends StatelessWidget {
  final double? aspectRatio;
  final Widget child;
  const _CoverFrame({required this.aspectRatio, required this.child});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      height: aspectRatio == null ? 170 : null,
      color: const Color(0xFF0A0A0A),
      child: child,
    );
    return aspectRatio == null
        ? box
        : AspectRatio(aspectRatio: aspectRatio!, child: box);
  }
}

class _MediaLoadingIndicator extends StatelessWidget {
  final String label;
  const _MediaLoadingIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AppColors.primaryOrange),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isError;
  const _EmptyMediaPlaceholder({
    required this.icon,
    required this.label,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFEF5350) : Colors.white24;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isError ? color.withOpacity(0.4) : const Color(0xFF262626),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isError ? color : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
// GALERIA DE IMAGENS — o código de galeria já existia no modelo/serviço
// (PostModel.gallery, AdminNewsService salva 'galeria'), mas não tinha
// interface própria: era só uma List<String> preenchida em initState e
// devolvida em _buildPost. Esta seção passa a mostrar essas imagens de
// verdade (thumbnails), permite adicionar, remover e reordenar — sem
// mudar o formato de dados (continua List<String> de URLs Cloudinary).
// ═══════════════════════════════════════════════════════════════════
class _GallerySection extends StatelessWidget {
  final List<String> images;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, int delta) onMove;

  const _GallerySection({
    required this.images,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Galeria de imagens (opcional)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            if (images.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${images.length}',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (images.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _GalleryThumb(
                  url: images[index],
                  canMoveLeft: index > 0,
                  canMoveRight: index < images.length - 1,
                  onRemove: () => onRemove(index),
                  onMoveLeft: () => onMove(index, -1),
                  onMoveRight: () => onMove(index, 1),
                );
              },
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: const Center(
              child: Text(
                'Nenhuma imagem na galeria ainda',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: AppColors.primaryOrange.withOpacity(0.06),
            ),
            icon: uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryOrange),
                  )
                : const Icon(Icons.add_photo_alternate_rounded, size: 18),
            label: Text(
              uploading ? 'Enviando imagem...' : 'Adicionar imagem à galeria',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  final String url;
  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback onRemove;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;

  const _GalleryThumb({
    required this.url,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onRemove,
    required this.onMoveLeft,
    required this.onMoveRight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            color: const Color(0xFF0A0A0A),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white24,
                size: 22,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryOrange),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Tooltip(
              message: 'Remover imagem',
              child: GestureDetector(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.black87,
                  child: Icon(Icons.close_rounded, size: 13, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 3,
            left: 3,
            right: 3,
            child: Row(
              children: [
                _ThumbArrow(
                  icon: Icons.chevron_left_rounded,
                  enabled: canMoveLeft,
                  onTap: onMoveLeft,
                  tooltip: 'Mover para a esquerda',
                ),
                const Spacer(),
                _ThumbArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: canMoveRight,
                  onTap: onMoveRight,
                  tooltip: 'Mover para a direita',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  const _ThumbArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox(width: 20, height: 20);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRÉ-VISUALIZAÇÃO — bottom sheet somente leitura mostrando como a
// notícia deve aparecer: capa, categoria, título, resumo, conteúdo
// (renderizado a partir das tags <b>/<mark> já usadas pelo restante do
// app), galeria e indicação de vídeo anexado. Não lê nem grava nada;
// é só uma projeção do estado atual do formulário.
// ═══════════════════════════════════════════════════════════════════
class _NewsPreviewSheet extends StatelessWidget {
  final String title;
  final String summary;
  final String contentHtml;
  final String coverUrl;
  final double? coverAspectRatio;
  final List<String> gallery;
  final String? videoUrl;
  final String? categoryLabel;
  final Color categoryColor;

  const _NewsPreviewSheet({
    required this.title,
    required this.summary,
    required this.contentHtml,
    required this.coverUrl,
    required this.coverAspectRatio,
    required this.gallery,
    required this.videoUrl,
    required this.categoryLabel,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0B0B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF232323))),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        color: AppColors.primaryOrange, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'PRÉ-VISUALIZAÇÃO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, 24 + mq.viewPadding.bottom),
                  children: [
                    if (coverUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          coverUrl,
                          height: coverAspectRatio == null ? 190 : null,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _EmptyMediaPlaceholder(
                            icon: Icons.broken_image_outlined,
                            label: 'Não foi possível carregar a capa',
                            isError: true,
                          ),
                        ),
                      )
                    else
                      const _EmptyMediaPlaceholder(
                        icon: Icons.image_outlined,
                        label: 'Sem imagem de capa',
                      ),
                    const SizedBox(height: 14),
                    if (categoryLabel != null)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: categoryColor.withOpacity(0.6)),
                        ),
                        child: Text(
                          categoryLabel!.toUpperCase(),
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      title.isEmpty ? 'Sem título' : title,
                      style: TextStyle(
                        color: title.isEmpty ? Colors.white38 : Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (videoUrl != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF262626)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.play_circle_fill_rounded,
                                color: AppColors.primaryOrange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Esta notícia inclui um vídeo',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    _PreviewHtmlContent(html: contentHtml),
                    if (gallery.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'GALERIA',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: gallery.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              gallery[index],
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                width: 90,
                                height: 90,
                                color: const Color(0xFF0A0A0A),
                                child: const Icon(Icons.broken_image_outlined,
                                    color: Colors.white24, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Renderiza, de forma bem simples e só para preview, o HTML já usado
/// pelo restante do app (<p>, <br>, <b>/<strong>, <mark>). Não é um
/// parser de HTML completo — é suficiente para o conteúdo que o
/// próprio editor produz via PlainTextHtmlConverter e a toolbar de
/// formatação, então não introduz nenhuma dependência nova nem altera
/// como o conteúdo é salvo.
class _PreviewHtmlContent extends StatelessWidget {
  final String html;
  const _PreviewHtmlContent({required this.html});

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) {
      return const Text(
        'Sem conteúdo ainda.',
        style: TextStyle(color: Colors.white38, fontSize: 13),
      );
    }

    final baseStyle = const TextStyle(
      color: Colors.white70,
      fontSize: 14.5,
      height: 1.55,
    );

    final paragraphs = html.split(RegExp(r'</p>', caseSensitive: false));
    final widgets = <Widget>[];
    for (final raw in paragraphs) {
      final withoutOpenTag =
          raw.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
      if (withoutOpenTag.trim().isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildInlineSpan(withoutOpenTag, baseStyle),
      ));
    }

    if (widgets.isEmpty) {
      widgets.add(_buildInlineSpan(html, baseStyle));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildInlineSpan(String source, TextStyle baseStyle) {
    final tagPattern =
        RegExp(r'<(/?)(mark|b|strong)>|<br\s*/?>', caseSensitive: false);
    final children = <InlineSpan>[];
    final markStyle =
        baseStyle.copyWith(color: AppColors.primaryOrange, fontWeight: FontWeight.w800);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w800);

    int cursor = 0;
    final stack = <String>[];
    TextStyle current() =>
        stack.isEmpty ? baseStyle : (stack.last == 'mark' ? markStyle : boldStyle);

    for (final match in tagPattern.allMatches(source)) {
      if (match.start > cursor) {
        children.add(TextSpan(
          text: _unescape(source.substring(cursor, match.start)),
          style: current(),
        ));
      }
      final full = match.group(0)!.toLowerCase();
      if (full.startsWith('<br')) {
        children.add(const TextSpan(text: '\n'));
      } else {
        final isClosing = match.group(1) == '/';
        final tagName = match.group(2)!.toLowerCase();
        final normalized = tagName == 'strong' ? 'b' : tagName;
        if (isClosing) {
          if (stack.isNotEmpty && stack.last == normalized) stack.removeLast();
        } else {
          stack.add(normalized);
        }
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      children.add(TextSpan(text: _unescape(source.substring(cursor)), style: current()));
    }
    return RichText(text: TextSpan(style: baseStyle, children: children));
  }

  String _unescape(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

// ═══════════════════════════════════════════════════════════════════
// FUNDO ESTÁTICO (sem animação) — apenas os dois glows radiais fixos.
// Trocado por não-animado porque esta é a tela de formulário (editor de
// notícia): antes tinha um AnimationController rodando em loop
// infinito repintando partículas a 60fps, o que pesava bastante ao
// sair/voltar do app nesta tela (ex.: puxar notificações). Como é uma
// tela de digitação/upload, não precisa de fogo se movendo atrás —
// aqui é só um CustomPaint pintado uma única vez, sem custo por frame.
class _EditorStaticBackgroundPainter extends CustomPainter {
  const _EditorStaticBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

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
  }

  @override
  bool shouldRepaint(_EditorStaticBackgroundPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════
// CONTROLLER COM PRÉVIA VISUAL DE FORMATAÇÃO
// Envolve os TextSelectionControls padrão do Material só para remover
// o retorno háptico que o Flutter dispara ao arrastar as alças de
// seleção (início/fim do trecho selecionado). Em campos longos, onde
// o ADM fica selecionando e reselecionando trechos várias vezes para
// aplicar negrito/destaque, esse pulso constante incomoda. O resto do
// comportamento (alças, menu de copiar/colar, toque duplo) continua
// idêntico ao padrão — só o handleHaptic vira um no-op.
class _QuietSelectionControls extends TextSelectionControls {
  _QuietSelectionControls(this._base);

  final TextSelectionControls _base;

  @override
  void handleHaptic() {
    // Sem feedback tátil próprio do Flutter aqui. A vibração mais forte
    // que pode aparecer ao arrastar a seleção normalmente vem do
    // teclado do Android (Gboard), não deste widget, e não tem como
    // ser controlada pelo app.
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) =>
      _base.buildHandle(context, type, textLineHeight, onTap);

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) =>
      _base.buildToolbar(
        context,
        globalEditableRegion,
        textLineHeight,
        selectionMidpoint,
        endpoints,
        delegate,
        clipboardStatus,
        lastSecondaryTapDownPosition,
      );

  @override
  Size getHandleSize(double textLineHeight) => _base.getHandleSize(textLineHeight);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      _base.getHandleAnchor(type, textLineHeight);

  @override
  bool canCut(TextSelectionDelegate delegate) => _base.canCut(delegate);

  @override
  bool canCopy(TextSelectionDelegate delegate) => _base.canCopy(delegate);

  @override
  bool canPaste(TextSelectionDelegate delegate) => _base.canPaste(delegate);

  @override
  bool canSelectAll(TextSelectionDelegate delegate) => _base.canSelectAll(delegate);

  @override
  void handleCut(TextSelectionDelegate delegate) => _base.handleCut(delegate);

  @override
  void handleCopy(TextSelectionDelegate delegate) => _base.handleCopy(delegate);

  @override
  Future<void> handlePaste(TextSelectionDelegate delegate) => _base.handlePaste(delegate);

  @override
  void handleSelectAll(TextSelectionDelegate delegate) => _base.handleSelectAll(delegate);
}

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

  // Cache do último resultado: buildTextSpan é chamado pelo Flutter não só
  // quando o texto muda, mas também a cada toque/arrasto de seleção (ex.:
  // ao selecionar um trecho para copiar). Sem esse cache, cada um desses
  // toques recalculava e recriava todos os spans do zero, fazendo o menu
  // de copiar/colar "tremer"/reposicionar. Agora só reprocessa quando o
  // texto realmente muda; seleção sozinha reaproveita o resultado.
  String? _cachedSource;
  TextStyle? _cachedBaseStyle;
  TextSpan? _cachedSpan;

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
      _cachedSource = null;
      _cachedSpan = null;
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    if (_cachedSource == source &&
        _cachedBaseStyle == baseStyle &&
        _cachedSpan != null) {
      return _cachedSpan!;
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

    final span = TextSpan(style: baseStyle, children: children);
    _cachedSource = source;
    _cachedBaseStyle = baseStyle;
    _cachedSpan = span;
    return span;
  }
}