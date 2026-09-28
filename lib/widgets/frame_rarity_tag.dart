import 'package:flutter/material.dart';
import '../config/badge_config.dart';
import '../config/level_badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// TAG DE RARIDADE
// ═══════════════════════════════════════════════════════════════════
// Antes vivia em avatar_frame.dart, junto da moldura animada
// (AvatarFrame). A moldura foi removida por completo — o nível agora
// aparece como LevelBadge (lib/widgets/level_badge_painters.dart),
// flutuando no canto superior esquerdo do avatar — mas esta tag de
// texto (ex.: "LENDÁRIO", "SUPREMO") continua em uso em várias telas
// (ranking, comentários, perfil, configurações) para rotular a
// raridade do nível ao lado do nome, então foi preservada aqui,
// isolada do que era a moldura.
class FrameRarityTag extends StatelessWidget {
  final int level;
  final double fontSize;

  const FrameRarityTag({
    Key? key,
    required this.level,
    this.fontSize = 9,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rarity = LevelBadgeRarityX.fromLevel(level);
    final color = BadgeConfig.levelColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        rarity.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}