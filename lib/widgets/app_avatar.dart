import 'package:flutter/material.dart';
import '../utils/initials_helper.dart';

/// Avatar circular gerado inteiramente em tempo de execuÃ§Ã£o a partir das
/// iniciais do nome do usuÃ¡rio â€” sem depender de imagens, emojis ou Ã­cones
/// de pessoa. A cor de fundo Ã© determinÃ­stica: o mesmo [name] (ou [seed],
/// quando informado) sempre resulta na mesma cor.
///
/// Ãšnico componente de avatar do app â€” reutilizado em perfil, ranking,
/// comentÃ¡rios e telas administrativas.
class AppAvatar extends StatelessWidget {
  /// Nome usado para gerar as iniciais exibidas no avatar.
  final String? name;

  /// Chave estÃ¡vel opcional para determinar a cor (ex.: UID do usuÃ¡rio).
  /// Quando ausente, a cor Ã© determinada pelo prÃ³prio [name].
  final String? seed;

  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    required this.name,
    this.seed,
    this.size = 44,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  // â”€â”€ Paleta compatÃ­vel com a identidade visual do Horizonte News:
  // tons escuros e variaÃ§Ãµes de laranja, mantendo contraste suficiente
  // para o texto branco permanecer legÃ­vel.
  static const List<Color> _palette = [
    Color(0xFFFF6B00), // laranja principal
    Color(0xFFCC4400), // laranja escuro
    Color(0xFFFF8C3A), // laranja claro
    Color(0xFF8A3B00), // marrom-laranja
    Color(0xFF2A2A2A), // grafite
    Color(0xFF3D3D3D), // cinza escuro
    Color(0xFF4A2A00), // Ã¢mbar escuro
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

  @override
  Widget build(BuildContext context) {
    final key = (seed != null && seed!.trim().isNotEmpty)
        ? seed!.trim()
        : (name ?? '');
    final initials = InitialsHelper.getInitials(name);
    final bgColor =
        key.isEmpty ? const Color(0xFF2A2A2A) : _colorFor(key);

    final content = Container(
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

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
