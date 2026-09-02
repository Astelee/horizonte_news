import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_colors.dart';
import '../../../models/category_model.dart';
import '../../../models/post_model.dart';
import '../../../services/cloudinary_upload_service.dart';
import '../services/admin_news_service.dart';
import '../services/push_notification_service.dart';

/// Formulário de criação/edição de notícia, usado pela aba NOTÍCIAS
/// do painel ADM. Cobre: título, resumo, conteúdo, categoria, capa,
/// galeria de imagens, vídeo, e os três estados de publicação
/// (rascunho, publicada, despublicada).
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

class _NewsEditorScreenState extends State<NewsEditorScreen> {
  final _cloudinary = CloudinaryUploadService();
  final _picker = ImagePicker();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _categoryCtrl;

  String _coverUrl = '';
  List<String> _gallery = [];
  String? _videoUrl;

  bool _uploadingCover = false;
  bool _uploadingGallery = false;
  bool _uploadingVideo = false;
  bool _saving = false;

  bool get _isEditing => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    final post = widget.existingPost;
    _titleCtrl = TextEditingController(text: post?.title ?? '');
    _summaryCtrl = TextEditingController(text: post?.summary ?? '');
    _contentCtrl = TextEditingController(text: post?.content ?? '');
    _categoryCtrl = TextEditingController(
      text: post != null && post.categories.isNotEmpty
          ? post.categories.first.name
          : '',
    );
    _coverUrl = post?.thumbnailUrl ?? '';
    _gallery = List<String>.from(post?.gallery ?? []);
    _videoUrl = post?.videoUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  PostModel _buildPost(PostStatus status) {
    final categories = _categoryCtrl.text.trim().isEmpty
        ? <CategoryModel>[]
        : [CategoryModel.fromString(_categoryCtrl.text.trim())];

    return PostModel(
      id: widget.existingPost?.id ?? '',
      title: _titleCtrl.text.trim(),
      summary: _summaryCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
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
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
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
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
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
      // DIAGNÓSTICO TEMPORÁRIO: mostra sempre o resultado do push num
      // diálogo que exige toque para fechar, para descartar de vez
      // qualquer dúvida sobre o que está acontecendo (sucesso, erro,
      // ou nem chegou a tentar). Remover depois de identificar a causa.
      if (status == PostStatus.published && mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Diagnóstico do push'),
            content: Text(
              pushResult == null
                  ? 'pushResult veio NULO — a função de notificar nem '
                    'foi chamada (verifique se o status realmente virou '
                    '"published" nesta ação).'
                  : pushResult.success
                      ? 'Push retornou SUCESSO (a API do OneSignal aceitou '
                        'o envio com status 200).'
                      : 'Push FALHOU: ${pushResult.message}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_isEditing ? 'Editar notícia' : 'Nova notícia'),
      ),
      body: _saving
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryOrange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _label('Título'),
                _textField(_titleCtrl, hint: 'Título da notícia'),
                const SizedBox(height: 16),
                _label('Subtítulo / Resumo'),
                _textField(_summaryCtrl,
                    hint: 'Resumo curto que aparece na listagem',
                    maxLines: 2),
                const SizedBox(height: 16),
                _label('Categoria'),
                _textField(_categoryCtrl, hint: 'Ex.: Cidade, Esporte...'),
                const SizedBox(height: 16),
                _label('Conteúdo completo'),
                _textField(_contentCtrl,
                    hint:
                        'Texto da notícia. Pode conter HTML simples (<p>, <b>, <h2>...).',
                    maxLines: 10),
                const SizedBox(height: 20),
                _buildCoverSection(),
                const SizedBox(height: 20),
                _buildGallerySection(),
                const SizedBox(height: 20),
                _buildVideoSection(),
                const SizedBox(height: 28),
                _buildActionButtons(),
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

  Widget _textField(TextEditingController controller,
      {String? hint, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.backgroundElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Imagem de capa'),
        if (_coverUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(_coverUrl,
                height: 140, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploadingCover ? null : _pickAndUploadCover,
          icon: _uploadingCover
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_rounded),
          label:
              Text(_coverUrl.isEmpty ? 'Escolher capa' : 'Trocar capa'),
        ),
      ],
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Galeria de imagens'),
        if (_gallery.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _gallery.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_gallery[i],
                        width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _gallery = [..._gallery]..removeAt(i)),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black87,
                        child: Icon(Icons.close_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploadingGallery ? null : _pickAndUploadGalleryImage,
          icon: _uploadingGallery
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_rounded),
          label: const Text('Adicionar imagem'),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploadingVideo ? null : _pickAndUploadVideo,
          icon: _uploadingVideo
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.video_call_rounded),
          label: Text(_videoUrl == null ? 'Adicionar vídeo' : 'Trocar vídeo'),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _save(PostStatus.published),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.publish_rounded),
            label: const Text('Publicar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _save(PostStatus.draft),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar como rascunho'),
          ),
        ),
      ],
    );
  }
}
