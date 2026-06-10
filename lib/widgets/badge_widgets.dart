import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/badge_config.dart';
import '../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// WIDGETS REUTILIZÁVEIS DE BADGE
// ═══════════════════════════════════════════════════════════════════

// ── Badge de Nível inline (ao lado do nome) ──────────────────────
// Usado em: CommentsSection, perfil compacto, qualquer listagem
class LevelBadgeInline extends StatelessWidget {
  final int level;
  final double iconSize;
  final double fontSize;
  final bool showLabel;

  const LevelBadgeInline({
    Key? key,
    required this.level,
    this.iconSize = 10,
    this.fontSize = 11,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = BadgeConfig.levelColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            BadgeConfig.levelIcon(level),
            size: iconSize,
            color: color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'Nv.$level',
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Badge de Conquista individual (card de conquistas) ───────────
// Usado em: ProfileScreen → seção de conquistas
class AchievementBadgeCard extends StatelessWidget {
  final String achievementId;
  final String title;
  final String description;
  final bool unlocked;

  const AchievementBadgeCard({
    Key? key,
    required this.achievementId,
    required this.title,
    required this.description,
    required this.unlocked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? BadgeConfig.achievementColor(achievementId)
        : const Color(0xFF333333);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: unlocked
            ? color.withOpacity(0.08)
            : const Color(0xFF0D0D0D),
        border: Border.all(
          color: unlocked
              ? color.withOpacity(0.35)
              : const Color(0xFF1E1E1E),
          width: 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone com fundo circular
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? color.withOpacity(0.15)
                  : const Color(0xFF1A1A1A),
              border: Border.all(
                color: unlocked
                    ? color.withOpacity(0.4)
                    : const Color(0xFF2A2A2A),
                width: 1.5,
              ),
            ),
            child: Center(
              child: FaIcon(
                BadgeConfig.achievementIcon(achievementId),
                size: 18,
                color: unlocked ? color : const Color(0xFF3A3A3A),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Título
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? Colors.white : const Color(0xFF444444),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 3),

          // Descrição
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked
                  ? Colors.white.withOpacity(0.45)
                  : const Color(0xFF2E2E2E),
              fontSize: 9,
              height: 1.3,
            ),
          ),

          // Indicador de bloqueado
          if (!unlocked) ...[
            const SizedBox(height: 6),
            FaIcon(
              FontAwesomeIcons.lock,
              size: 10,
              color: const Color(0xFF333333),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Badge de conquista em linha (para usar ao lado do nome) ──────
// Usado em: comentários, para mostrar o badge mais raro desbloqueado
class AchievementBadgeInline extends StatelessWidget {
  final String achievementId;
  final double size;

  const AchievementBadgeInline({
    Key? key,
    required this.achievementId,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = BadgeConfig.achievementColor(achievementId);

    return Container(
      width: size + 10,
      height: size + 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Center(
        child: FaIcon(
          BadgeConfig.achievementIcon(achievementId),
          size: size,
          color: color,
        ),
      ),
    );
  }
}

// ── Linha de badges desbloqueados (até N badges em row) ──────────
// Exibe os badges mais recentes/raros ao lado do nome
class UnlockedBadgesRow extends StatelessWidget {
  final List<String> unlockedAchievements;
  final int maxVisible;
  final double badgeSize;

  const UnlockedBadgesRow({
    Key? key,
    required this.unlockedAchievements,
    this.maxVisible = 3,
    this.badgeSize = 12,
  }) : super(key: key);

  // Prioridade de raridade (índice mais alto = mais raro)
  static const _rarityOrder = [
    'first_login',
    '1h_online',
    'first_comment',
    'first_share',
    '100_articles',
    '10h_online',
    'level_5',
    'level_10',
  ];

  List<String> get _sortedByRarity {
    final sorted = List<String>.from(unlockedAchievements);
    sorted.sort((a, b) {
      final ia = _rarityOrder.indexOf(a);
      final ib = _rarityOrder.indexOf(b);
      // Desconhecidos vão para o fim
      final ra = ia == -1 ? 0 : ia;
      final rb = ib == -1 ? 0 : ib;
      return rb.compareTo(ra); // mais raro primeiro
    });
    return sorted.take(maxVisible).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (unlockedAchievements.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _sortedByRarity
          .map(
            (id) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: AchievementBadgeInline(
                achievementId: id,
                size: badgeSize,
              ),
            ),
          )
          .toList(),
    );
  }
}
