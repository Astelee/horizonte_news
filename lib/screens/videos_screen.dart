import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../config/app_colors.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';

// ─────────────────────────────────────────────────────────────────
// UTILITÁRIO: extrai ID do YouTube do conteúdo HTML do post
// ─────────────────────────────────────────────────────────────────
class _YtHelper {
  static String? extractId(String content) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(content);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static bool hasVideo(PostModel post) {
    final hasLabel = post.categories.any(
      (c) => c.name.toLowerCase() == 'vídeo' ||
             c.name.toLowerCase() == 'video',
    );
    return hasLabel && extractId(post.content) != null;
  }
}

// ─────────────────────────────────────────────────────────────────
// TELA PRINCIPAL — REELS
// ─────────────────────────────────────────────────────────────────
class VideosScreen extends StatefulWidget {
  const VideosScreen({Key? key}) : super(key: key);

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<PostModel> _videoPosts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  Future<void> _loadVideos() async {
    final provider = Provider.of<PostsProvider>(context, listen: false);
    await provider.loadPostsByLabel('Vídeo');
    if (!mounted) return;
    final all = provider.posts;
    setState(() {
      _videoPosts = all.where((p) => _YtHelper.hasVideo(p)).toList();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.orangeGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_filled_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'REELS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Horizonte News',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _videoPosts.isEmpty
          ? _buildLoading()
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videoPosts.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) {
                return _VideoReelItem(
                  post: _videoPosts[i],
                  isActive: i == _currentPage,
                );
              },
            ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Carregando vídeos...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ITEM DO REEL — cada página do PageView
// ─────────────────────────────────────────────────────────────────
class _VideoReelItem extends StatefulWidget {
  final PostModel post;
  final bool isActive;

  const _VideoReelItem({
    required this.post,
    required this.isActive,
  });

  @override
  State<_VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<_VideoReelItem> {
  YoutubePlayerController? _controller;
  bool _showCaption = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final videoId = _YtHelper.extractId(widget.post.content);
    if (videoId == null) return;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        enableCaption: false,
        controlsVisibleAtStart: false,
        hideControls: true,
        disableDragSeek: false,
      ),
    );
  }

  @override
  void didUpdateWidget(_VideoReelItem old) {
    super.didUpdateWidget(old);
    if (!widget.isActive) {
      _controller?.pause();
    } else {
      _controller?.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_isMuted) {
      _controller?.mute();
    } else {
      _controller?.unMute();
    }
  }

  void _toggleCaption() {
    setState(() => _showCaption = !_showCaption);
  }

  String _cleanCaption(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  // Remove a URL do YouTube da legenda
  String _buildCaption() {
    final raw = _cleanCaption(widget.post.content);
    final cleaned = raw
        .replaceAll(RegExp(r'https?://[^\s]+'), '')
        .trim();
    return cleaned.isEmpty ? widget.post.title : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: Text(
          'Vídeo indisponível',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final caption = _buildCaption();
    final category = widget.post.categories.isNotEmpty
        ? widget.post.categories
            .firstWhere(
              (c) =>
                  c.name.toLowerCase() != 'vídeo' &&
                  c.name.toLowerCase() != 'video',
              orElse: () => widget.post.categories.first,
            )
            .name
        : '';

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primaryOrange,
        progressColors: const ProgressBarColors(
          playedColor: AppColors.primaryOrange,
          handleColor: AppColors.primaryOrangeLight,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
      ),
      builder: (context, player) {
        return Stack(
          children: [
            // ── Vídeo em tela cheia ──
            SizedBox(
              width: size.width,
              height: size.height,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.width * 16 / 9,
                  child: player,
                ),
              ),
            ),

            // ── Gradiente inferior para legenda ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: size.height * 0.45,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC000000),
                      Colors.black,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // ── Botões laterais ──
            Positioned(
              right: 12,
              bottom: 120,
              child: Column(
                children: [
                  _SideButton(
                    icon: _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    label: _isMuted ? 'Mudo' : 'Som',
                    onTap: _toggleMute,
                    active: !_isMuted,
                  ),
                  const SizedBox(height: 20),
                  _SideButton(
                    icon: _showCaption
                        ? Icons.subtitles_rounded
                        : Icons.subtitles_off_rounded,
                    label: 'Legenda',
                    onTap: _toggleCaption,
                    active: _showCaption,
                  ),
                  const SizedBox(height: 20),
                  _SideButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'YouTube',
                    onTap: () {
                      final id = _YtHelper.extractId(widget.post.content);
                      if (id != null) {
                        _controller?.pause();
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Legenda + título ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              bottom: _showCaption ? 24 : -200,
              left: 16,
              right: 72,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showCaption ? 1.0 : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge categoria
                    if (category.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: AppColors.orangeGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryOrange.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                    // Título
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Legenda (texto do post sem HTML e sem URL)
                    if (caption != widget.post.title &&
                        caption.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        caption,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          height: 1.5,
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Data
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppColors.primaryOrange.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(widget.post.publishedAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Indicador de scroll ──
            Positioned(
              right: 0,
              left: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Arraste para o próximo',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────
// BOTÃO LATERAL ESTILO REELS
// ─────────────────────────────────────────────────────────────────
class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.5),
              border: Border.all(
                color: active
                    ? AppColors.primaryOrange.withOpacity(0.6)
                    : Colors.white.withOpacity(0.2),
                width: 1.2,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: active ? AppColors.primaryOrange : Colors.white54,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
