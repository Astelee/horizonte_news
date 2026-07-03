// lib/widgets/app_avatar.dart
import 'package:flutter/material.dart';
import '../models/avatar_catalog.dart';

/// Widget reutilizável que renderiza um avatar ilustrado a partir do avatarId.
/// Use em qualquer lugar que hoje mostra iniciais ou foto: perfil, comentários,
/// aba amigos, seguidores, notificações etc.
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
      child: Center(
        child: Text(
          avatar.emoji,
          style: TextStyle(fontSize: size * 0.5),
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
