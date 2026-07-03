// lib/widgets/app_avatar.dart
import 'package:flutter/material.dart';
import '../models/avatar_catalog.dart';

/// Widget reutilizável que renderiza um avatar ilustrado a partir do avatarId.
/// Usa uma cascata de fallback de 3 níveis para nunca quebrar mesmo que
/// nem todas as 104 ilustrações existam ainda em assets/avatars/:
///
///   1º) tenta a ilustração específica do avatar   (ex: animais_07.png)
///   2º) se não existir, tenta a padrão da categoria (ex: animais_01.png)
///   3º) se não existir, usa o placeholder global    (placeholder.png)
///
/// Use em qualquer lugar que hoje mostra a "foto" do usuário: perfil,
/// comentários, aba amigos, card de conversas, menus de contexto, etc.
class AppAvatar extends StatelessWidget {
  final String? avatarId;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppAvatar({
    Key? key,
    required this.avatarId,
    this.size = 44,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarCatalog.byId(avatarId);

    final content = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: avatar.rarity.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: showBorder
            ? Border.all(
                color: borderColor ?? const Color(0xFFFF6B00),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: avatar.rarity.accentColor.withOpacity(0.25),
            blurRadius: size * 0.25,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: _AvatarIllustration(avatar: avatar, size: size),
    );

    if (onTap == null) return content;

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

/// Faz a cascata de fallback entre 3 imagens usando errorBuilder,
/// sem nunca exibir emoji, ícone ou caractere unicode como avatar.
class _AvatarIllustration extends StatelessWidget {
  final AvatarData avatar;
  final double size;

  const _AvatarIllustration({required this.avatar, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      avatar.assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // 2º nível: ilustração padrão da categoria
        return Image.asset(
          avatar.categoryFallbackAssetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 3º nível: placeholder global — sempre deve existir
            return Image.asset(
              AvatarData.globalPlaceholderAssetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Último recurso, caso nem o placeholder exista ainda:
                // fundo sólido sem emoji/ícone/unicode.
                return Container(
                  width: size,
                  height: size,
                  color: const Color(0xFF1A1A1A),
                );
              },
            );
          },
        );
      },
    );
  }
}
