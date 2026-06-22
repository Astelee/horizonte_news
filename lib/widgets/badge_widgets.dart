import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// BADGE WIDGETS — PREMIUM COM GLOW E GRADIENTES
// ═══════════════════════════════════════════════════════════════════

// ── Tag de Nível inline (comentários, feed, ranking) ──────────────
class LevelBadgeInline extends StatelessWidget {
  final int level;
  final double iconSize;
  final double fontSize;

  const LevelBadgeInline({
    Key? key,
    required this.level,
    this.iconSize = 9,
    this.fontSize = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gradient = BadgeConfig.levelGradient(level);
    final color    = BadgeConfig.levelColor(level);
    final isEpic   = level >= 8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [gradient[0].withOpacity(0.85), gradient[1].withOpacity(0.85)],
        ),
        border: Border.all(
          color: color.withOpacity(isEpic ? 0.8 : 0.5),
          width: isEpic ? 1.2 : 0.8,
        ),
        boxShadow: isEpic
            ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 0)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(BadgeConfig.levelIcon(level), size: iconSize, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            BadgeConfig.levelTitle(level),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              shadows: isEpic
                  ? [Shadow(color: color.withOpacity(0.8), blurRadius: 6)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de conquista na grade do perfil ──────────────────────────
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
    final color    = unlocked ? BadgeConfig.achievementColor(achievementId) : const Color(0xFF333333);
    final gradient = unlocked ? BadgeConfig.achievementGradient(achievementId) : <Color>[const Color(0xFF111111), const Color(0xFF111111)];
    final isLeg    = unlocked && BadgeConfig.isLegendary(achievementId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: unlocked
            ? LinearGradient(
                colors: [gradient[0].withOpacity(0.2), gradient[1].withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: unlocked ? null : const Color(0xFF0D0D0D),
        border: Border.all(
          color: unlocked ? color.withOpacity(isLeg ? 0.7 : 0.4) : const Color(0xFF1E1E1E),
          width: isLeg ? 1.5 : 1,
        ),
        boxShadow: isLeg
            ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16)]
            : unlocked
                ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 10)]
                : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? LinearGradient(
                      colors: [gradient[0].withOpacity(0.3), gradient[1].withOpacity(0.1)],
                    )
                  : null,
              color: unlocked ? null : const Color(0xFF1A1A1A),
              border: Border.all(
                color: unlocked ? color.withOpacity(0.6) : const Color(0xFF2A2A2A),
                width: 1.5,
              ),
            ),
            child: Center(
              child: unlocked
                  ? ShaderMask(
                      shaderCallback: (b) => LinearGradient(colors: gradient).createShader(b),
                      child: FaIcon(BadgeConfig.achievementIcon(achievementId), size: 18, color: Colors.white),
                    )
                  : FaIcon(BadgeConfig.achievementIcon(achievementId), size: 18, color: const Color(0xFF3A3A3A)),
            ),
          ),
          const SizedBox(height: 8),
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
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? Colors.white.withOpacity(0.4) : const Color(0xFF2E2E2E),
              fontSize: 9,
              height: 1.3,
            ),
          ),
          if (!unlocked) ...[
            const SizedBox(height: 6),
            const FaIcon(FontAwesomeIcons.lock, size: 10, color: Color(0xFF333333)),
          ],
        ],
      ),
    );
  }
}

// ── Badge inline circular (ao lado do nome) ───────────────────────
class AchievementBadgeInline extends StatelessWidget {
  final String achievementId;
  final double size;

  const AchievementBadgeInline({
    Key? key,
    required this.achievementId,
    this.size = 11,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color  = BadgeConfig.achievementColor(achievementId);
    final isLeg  = BadgeConfig.isLegendary(achievementId);

    return Container(
      width: size + 12,
      height: size + 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(isLeg ? 0.8 : 0.4), width: isLeg ? 1.2 : 0.8),
        boxShadow: isLeg
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: FaIcon(BadgeConfig.achievementIcon(achievementId), size: size, color: color),
      ),
    );
  }
}

// ── Linha dos badges mais raros desbloqueados ─────────────────────
class UnlockedBadgesRow extends StatelessWidget {
  final List<String> unlockedAchievements;
  final int maxVisible;
  final double badgeSize;

  const UnlockedBadgesRow({
    Key? key,
    required this.unlockedAchievements,
    this.maxVisible = 3,
    this.badgeSize = 11,
  }) : super(key: key);

  static const _rarityOrder = [
    'first_login', 'articles_10', '1h_online', 'first_comment',
    'first_share', 'streak_7', 'articles_50', 'comments_10',
    'shares_10', '10h_online', 'streak_30', 'articles_100',
    'comments_50', '50h_online', 'level_5', 'streak_100',
    'articles_500', '100h_online', 'top_commenter',
    'influencer', 'level_10',
  ];

  List<String> get _topByRarity {
    final sorted = List<String>.from(unlockedAchievements);
    sorted.sort((a, b) {
      final ra = _rarityOrder.indexOf(a);
      final rb = _rarityOrder.indexOf(b);
      return (rb == -1 ? 0 : rb).compareTo(ra == -1 ? 0 : ra);
    });
    return sorted.take(maxVisible).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (unlockedAchievements.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _topByRarity.map((id) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: AchievementBadgeInline(achievementId: id, size: badgeSize),
      )).toList(),
    );
  }
}
