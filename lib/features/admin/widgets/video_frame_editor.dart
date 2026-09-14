import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../config/app_colors.dart';
import '../../../models/post_model.dart';

/// Tela de ajuste de enquadramento do vídeo, aberta a partir do editor
/// de notícia logo depois que o usuário escolhe o arquivo de vídeo.
///
/// Mostra o próprio vídeo (pausado num frame, ou tocando) como preview
/// ao vivo dentro da caixa de corte escolhida — ou seja, o usuário vê
/// exatamente como o vídeo vai aparecer na matéria antes de confirmar.
///
/// Duas formas de enquadrar:
/// - Presets prontos (Original, 16:9, 1:1, 4:5, 9:16): a caixa muda de
///   proporção; dentro dela dá pra arrastar o vídeo para escolher que
///   parte fica visível (pan) e usar o slider de zoom.
/// - Personalizado: o usuário arrasta um controle para ajustar a
///   proporção da caixa livremente, além de também poder mover/ampliar
///   o vídeo dentro dela.
///
/// Retorna (via Navigator.pop) o [VideoFrameConfig] escolhido, ou null
/// se o usuário cancelar.
class VideoFrameEditor extends StatefulWidget {
  const VideoFrameEditor({
    Key? key,
    required this.videoFile,
    this.initialConfig,
  }) : super(key: key);

  final File videoFile;
  final VideoFrameConfig? initialConfig;

  @override
  State<VideoFrameEditor> createState() => _VideoFrameEditorState();
}

class _VideoFrameEditorState extends State<VideoFrameEditor> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  late VideoFramePreset _preset;
  late double _customAspectRatio;
  late double _zoom;
  late double _offsetX;
  late double _offsetY;

  // Faixa de proporção livre (largura/altura) para o modo personalizado.
  static const double _minCustomRatio = 9 / 16; // bem vertical
  static const double _maxCustomRatio = 16 / 9; // bem horizontal

  @override
  void initState() {
    super.initState();
    final initial = widget.initialConfig ?? VideoFrameConfig.original;
    _preset = initial.preset;
    _customAspectRatio = initial.customAspectRatio;
    _zoom = initial.zoom;
    _offsetX = initial.offsetX;
    _offsetY = initial.offsetY;

    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller
          ..setLooping(true)
          ..play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _videoAspectRatio =>
      _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio;

  /// Proporção (largura/altura) da caixa de exibição para o preset ou
  /// ajuste personalizado atualmente selecionado.
  double get _boxAspectRatio {
    switch (_preset) {
      case VideoFramePreset.original:
        return _videoAspectRatio;
      case VideoFramePreset.ratio16x9:
        return 16 / 9;
      case VideoFramePreset.ratio1x1:
        return 1.0;
      case VideoFramePreset.ratio4x5:
        return 4 / 5;
      case VideoFramePreset.ratio9x16:
        return 9 / 16;
      case VideoFramePreset.custom:
        return _customAspectRatio;
    }
  }

  bool get _isCropped => _preset != VideoFramePreset.original;

  void _selectPreset(VideoFramePreset preset) {
    setState(() {
      _preset = preset;
      // Volta o enquadramento ao centro ao trocar de preset, para não
      // herdar um deslocamento que não fazia sentido na proporção antiga.
      _offsetX = 0.0;
      _offsetY = 0.0;
      _zoom = 1.0;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size boxSize) {
    if (!_isCropped) return; // sem corte, não há o que arrastar
    setState(() {
      // Converte o arrasto em pixels para um deslocamento normalizado
      // (-1..1), relativo ao tamanho da caixa — arrastar a tela inteira
      // de largura move o offset em 1.0.
      _offsetX =
          (_offsetX + details.delta.dx / boxSize.width).clamp(-1.0, 1.0);
      _offsetY =
          (_offsetY + details.delta.dy / boxSize.height).clamp(-1.0, 1.0);
    });
  }

  VideoFrameConfig get _resultConfig => VideoFrameConfig(
        preset: _preset,
        customAspectRatio: _customAspectRatio,
        zoom: _zoom,
        offsetX: _offsetX,
        offsetY: _offsetY,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ajustar enquadramento',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: _initialized
                ? () => Navigator.of(context).pop(_resultConfig)
                : null,
            child: const Text('Concluir',
                style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            )
          : Column(
              children: [
                Expanded(child: Center(child: _buildPreview())),
                _buildControls(),
              ],
            ),
    );
  }

  Widget _buildPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 32;
        final maxH = constraints.maxHeight - 24;
        final ratio = _boxAspectRatio;

        double boxW = maxW;
        double boxH = boxW / ratio;
        if (boxH > maxH) {
          boxH = maxH;
          boxW = boxH * ratio;
        }
        final boxSize = Size(boxW, boxH);

        final videoInner = _isCropped
            ? Transform.scale(
                scale: _zoom,
                child: Align(
                  // Alinhamento entre -1..1 já é exatamente o formato que
                  // Align espera, então o offset serve como alignment.
                  alignment: Alignment(_offsetX, _offsetY),
                  child: AspectRatio(
                    aspectRatio: _videoAspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : VideoPlayer(_controller);

        return GestureDetector(
          onPanUpdate: (d) => _onPanUpdate(d, boxSize),
          child: Container(
            width: boxSize.width,
            height: boxSize.height,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryOrange, width: 1.5),
            ),
            child: ClipRect(
              child: _isCropped
                  ? OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoAspectRatio,
                          height: 1,
                          child: videoInner,
                        ),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: _videoAspectRatio,
                      child: VideoPlayer(_controller),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Formato',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 66,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _presetChip(VideoFramePreset.original, Icons.crop_free_rounded,
                    'Original'),
                _presetChip(
                    VideoFramePreset.ratio16x9, Icons.crop_16_9_rounded, '16:9'),
                _presetChip(
                    VideoFramePreset.ratio1x1, Icons.crop_square_rounded, '1:1'),
                _presetChip(
                    VideoFramePreset.ratio4x5, Icons.crop_portrait_rounded, '4:5'),
                _presetChip(VideoFramePreset.ratio9x16,
                    Icons.stay_current_portrait_rounded, '9:16'),
                _presetChip(
                    VideoFramePreset.custom, Icons.tune_rounded, 'Livre'),
              ],
            ),
          ),
          if (_preset == VideoFramePreset.custom) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.crop_portrait_rounded,
                    color: Colors.white38, size: 16),
                Expanded(
                  child: Slider(
                    value: _customAspectRatio.clamp(
                        _minCustomRatio, _maxCustomRatio),
                    min: _minCustomRatio,
                    max: _maxCustomRatio,
                    activeColor: AppColors.primaryOrange,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _customAspectRatio = v),
                  ),
                ),
                const Icon(Icons.crop_landscape_rounded,
                    color: Colors.white38, size: 16),
              ],
            ),
          ],
          if (_isCropped) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.zoom_out_rounded,
                    color: Colors.white38, size: 18),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1.0,
                    max: 2.5,
                    activeColor: AppColors.primaryOrange,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _zoom = v),
                  ),
                ),
                const Icon(Icons.zoom_in_rounded,
                    color: Colors.white38, size: 18),
              ],
            ),
            const Text(
              'Arraste o vídeo para escolher o que fica visível',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _presetChip(VideoFramePreset preset, IconData icon, String label) {
    final selected = _preset == preset;
    return GestureDetector(
      onTap: () => _selectPreset(preset),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOrange.withOpacity(0.12)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryOrange : const Color(0xFF262626),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.primaryOrange : Colors.white54),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.primaryOrange : Colors.white54,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}