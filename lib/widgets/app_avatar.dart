import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/initials_helper.dart';

/// Avatar circular do app. Quando [photoUrl] é informado, exibe a foto
/// de perfil do usuário; caso contrário, gera as iniciais do nome em
/// tempo de execução — sem depender de imagens, emojis ou ícones de
/// pessoa. A cor de fundo das iniciais é determinística: o mesmo
/// [name] (ou [seed], quando informado) sempre resulta na mesma cor.
///
/// Único componente de avatar do app — reutilizado em perfil, ranking,
/// comentários e telas administrativas.
class AppAvatar extends StatelessWidget {
  /// Nome usado para gerar as iniciais exibidas no avatar.
  final String? name;

  /// Chave estável opcional para determinar a cor (ex.: UID do usuário).
  /// Quando ausente, a cor é determinada pelo próprio [name].
  final String? seed;

  /// URL da foto de perfil (Supabase Storage). Quando presente e
  /// carregada com sucesso, substitui as iniciais.
  final String? photoUrl;

  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    required this.name,
    this.seed,
    this.photoUrl,
    this.size = 44,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  // ── Paleta compatível com a identidade visual do Horizonte News:
  // tons escuros e variações de laranja, mantendo contraste suficiente
  // para o texto branco permanecer legível.
  static const List<Color> _palette = [
    Color(0xFFFF6B00), // laranja principal
    Color(0xFFCC4400), // laranja escuro
    Color(0xFFFF8C3A), // laranja claro
    Color(0xFF8A3B00), // marrom-laranja
    Color(0xFF2A2A2A), // grafite
    Color(0xFF3D3D3D), // cinza escuro
    Color(0xFF4A2A00), // âmbar escuro
    Color(0xFF662200), // ferrugem
  ];

  Color _colorFor(String key) {
    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    return _palette[hash % _palette.length];
  }

  Widget _initialsContent() {
    final key = (seed != null && seed!.trim().isNotEmpty)
        ? seed!.trim()
        : (name ?? '');
    final initials = InitialsHelper.getInitials(name);
    final bgColor = key.isEmpty ? const Color(0xFF2A2A2A) : _colorFor(key);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: showBorder
            ? Border.all(
                color: borderColor ?? const Color(0xFFFF6B00),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.2),
            blurRadius: size * 0.2,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    final content = hasPhoto
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: showBorder
                  ? Border.all(
                      color: borderColor ?? const Color(0xFFFF6B00),
                      width: 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.2),
                  blurRadius: size * 0.2,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              placeholder: (_, __) => _initialsContent(),
              errorWidget: (_, __, ___) => _initialsContent(),
            ),
          )
        : _initialsContent();

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}