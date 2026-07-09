import 'package:flutter/material.dart';
import '../models/avatar_catalog.dart';

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
        color: const Color(0xFF1A1A1A),
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
      child: Image.asset(
        avatar.assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Fallback caso a imagem não exista ainda
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1A1A),
          child: Icon(
            Icons.person_rounded,
            color: const Color(0xFFFF6B00).withOpacity(0.5),
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
