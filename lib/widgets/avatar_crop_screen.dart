import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Tela de recorte da foto de perfil, usada antes do upload.
///
/// Usa [Crop] (pacote crop_your_image), um widget 100% Flutter — sem
/// abrir nenhuma Activity nativa do Android por baixo dos panos. Isso
/// evita o crash "Reply already submitted" que ocorria com o
/// image_cropper, causado por conflito entre duas Activities nativas
/// (image_picker + uCrop) disputando o mesmo callback de resultado.
///
/// Retorna os bytes já recortados (PNG) via Navigator.pop, ou null se
/// o usuário cancelar.
class AvatarCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const AvatarCropScreen({
    Key? key,
    required this.imageBytes,
  }) : super(key: key);

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Ajustar foto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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
      body: Crop(
        controller: _controller,
        image: widget.imageBytes,
        aspectRatio: 1,
        interactive: true,
        withCircleUi: true,
        baseColor: Colors.black,
        maskColor: Colors.black.withOpacity(0.6),
        progressIndicator: const CircularProgressIndicator(
          color: AppColors.primaryOrange,
        ),
        onCropped: (result) {
          if (!mounted) return;

          switch (result) {
            case CropSuccess(:final croppedImage):
              Navigator.pop(context, croppedImage);
              break;

            case CropFailure():
              setState(() => _cropping = false);

              debugPrint(
                'Erro ao recortar imagem: CropFailure',
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Não foi possível recortar a foto.',
                  ),
                ),
              );
              break;
          }
        },
      ),
    );
  }
}
