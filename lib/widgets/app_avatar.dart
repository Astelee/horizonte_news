// lib/widgets/app_avatar.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/avatar_catalog.dart';

/// Widget reutilizável que renderiza um avatar ilustrado a partir do avatarId.
/// A ilustração é gerada dinamicamente via URL (DiceBear) e cacheada
/// localmente pelo CachedNetworkImage — não depende de nenhum arquivo
/// em assets/, então qualquer um dos 16 avatarIds já funciona sem upload.
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
      child: CachedNetworkImage(
        imageUrl: avatar.networkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1A1A),
          child: Center(
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: avatar.rarity.accentColor.withOpacity(0.6),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}
