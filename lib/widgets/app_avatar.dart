import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      // ✅ SvgPicture.network renderiza SVG do Multiavatar corretamente
      child: SvgPicture.network(
        avatar.networkUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1A1A),
          child: Center(
            child: SizedBox(
              width: size * 0.35,
              height: size * 0.35,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFFFF6B00).withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
