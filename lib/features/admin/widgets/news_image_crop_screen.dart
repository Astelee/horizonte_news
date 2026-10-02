import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../widgets/app_messenger.dart';

/// Resultado do recorte: bytes já recortados (PNG) e a proporção
/// (largura/altura) real da imagem recortada.
class NewsCropResult {
  final Uint8List bytes;
  final double aspectRatio;
  const NewsCropResult(this.bytes, this.aspectRatio);
}

class _RatioOption {
  final String label;
  final double? ratio; // null = livre
  const _RatioOption(this.label, this.ratio);
}

const List<_RatioOption> _kRatios = [
  _RatioOption('Livre', null),
  _RatioOption('16:9', 16 / 9),
  _RatioOption('4:3', 4 / 3),
  _RatioOption('1:1', 1),
  _RatioOption('4:5', 4 / 5),
];

/// Tela de recorte de fotos do editor de notícias (capa e galeria).
/// Usa o mesmo pacote do recorte de avatar (crop_your_image).
/// Retorna [NewsCropResult] via Navigator.pop, ou null se cancelar.
class NewsImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const NewsImageCropScreen({Key? key, required this.imageBytes})
      : super(key: key);

  @override
  State<NewsImageCropScreen> createState() => _NewsImageCropScreenState();
}

class _NewsImageCropScreenState extends State<NewsImageCropScreen> {
  final _controller = CropController();
  bool _cropping = false;
  int _selected = 1; // começa em 16:9

  Future<void> _finish(Uint8List bytes) async {
    try {
      final image = await decodeImageFromList(bytes);
      final ratio = image.width / image.height;
      image.dispose();
      if (!mounted) return;
      Navigator.pop(context, NewsCropResult(bytes, ratio));
    } catch (_) {
      if (!mounted) return;
      setState(() => _cropping = false);
      AppMessenger.error('Não foi possível recortar a foto.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final option = _kRatios[_selected];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Recortar foto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cropping ? null : () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: _cropping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  )
                : const Text(
                    'Concluir',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              key: ValueKey(option.ratio),
              controller: _controller,
              image: widget.imageBytes,
              aspectRatio: option.ratio,
              interactive: true,
              baseColor: Colors.black,
              maskColor: Colors.black.withOpacity(0.6),
              progressIndicator: const CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
              onCropped: (result) {
                if (!mounted) return;
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    _finish(croppedImage);
                    break;
                  case CropFailure():
                    setState(() => _cropping = false);
                    AppMessenger.error('Não foi possível recortar a foto.');
                    break;
                }
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < _kRatios.length; i++)
                    ChoiceChip(
                      label: Text(_kRatios[i].label),
                      selected: _selected == i,
                      onSelected: _cropping
                          ? null
                          : (_) => setState(() => _selected = i),
                      selectedColor: AppColors.primaryOrange.withOpacity(0.25),
                      backgroundColor: const Color(0xFF0A0A0A),
                      labelStyle: TextStyle(
                        color: _selected == i
                            ? AppColors.primaryOrange
                            : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: _selected == i
                            ? AppColors.primaryOrange
                            : const Color(0xFF262626),
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