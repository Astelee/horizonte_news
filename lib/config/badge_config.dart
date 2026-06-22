import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ═══════════════════════════════════════════════════════════════════
// BADGE CONFIG — SISTEMA DE NÍVEIS PARA LEITORES
// ═══════════════════════════════════════════════════════════════════

class BadgeConfig {
  BadgeConfig._();

  // ── SISTEMA DE NÍVEIS (1–30) ─────────────────────────────────────
  static String levelTitle(int level) {
    if (level <= 1)  return 'Visitante';
    if (level <= 2)  return 'Leitor';
    if (level <= 3)  return 'Acompanhante';
    if (level <= 4)  return 'Seguidor';
    if (level <= 5)  return 'Entusiasta';
    if (level <= 6)  return 'Explorador';
    if (level <= 7)  return 'Super Leitor';
    if (level <= 8)  return 'Fã da Informação';
    if (level <= 9)  return 'Membro Destaque';
    if (level <= 10) return 'Lenda das Notícias';
    if (level <= 12) return 'Analista';
    if (level <= 15) return 'Cronista';
    if (level <= 18) return 'Guardião das Notícias';
    if (level <= 22) return 'Mestre da Informação';
    if (level <= 27) return 'Oráculo';
    return 'Lenda Suprema';
  }

  static IconData levelIcon(int level) {
    if (level <= 1)  return FontAwesomeIcons.eye;
    if (level <= 2)  return FontAwesomeIcons.bookOpen;
    if (level <= 3)  return FontAwesomeIcons.magnifyingGlass;
    if (level <= 4)  return FontAwesomeIcons.bookmark;
    if (level <= 5)  return FontAwesomeIcons.fire;
    if (level <= 6)  return FontAwesomeIcons.compass;
    if (level <= 7)  return FontAwesomeIcons.solidStar;
    if (level <= 8)  return FontAwesomeIcons.trophy;
    if (level <= 9)  return FontAwesomeIcons.medal;
    if (level <= 10) return FontAwesomeIcons.crown;
    if (level <= 12) return FontAwesomeIcons.chartLine;
    if (level <= 15) return FontAwesomeIcons.featherPointed;
    if (level <= 18) return FontAwesomeIcons.shieldHalved;
    if (level <= 22) return FontAwesomeIcons.infinity;
    if (level <= 27) return FontAwesomeIcons.wandMagicSparkles;
    return FontAwesomeIcons.meteor;
  }

  static Color levelColor(int level) {
    if (level <= 1)  return const Color(0xFF78909C);
    if (level <= 2)  return const Color(0xFF64B5F6);
    if (level <= 3)  return const Color(0xFF4FC3F7);
    if (level <= 4)  return const Color(0xFF4DB6AC);
    if (level <= 5)  return const Color(0xFF81C784);
    if (level <= 6)  return const Color(0xFFFF8A65);
    if (level <= 7)  return const Color(0xFFFF6B00);
    if (level <= 8)  return const Color(0xFFBA68C8);
    if (level <= 9)  return const Color(0xFFFFCA28);
    if (level <= 10) return const Color(0xFFFFD700);
    if (level <= 12) return const Color(0xFF26C6DA);
    if (level <= 15) return const Color(0xFFEC407A);
    if (level <= 18) return const Color(0xFF7E57C2);
    if (level <= 22) return const Color(0xFFFF5722);
    if (level <= 27) return const Color(0xFF00E5FF);
    return const Color(0xFFFFFFFF);
  }

  static List<Color> levelGradient(int level) {
    if (level <= 1)  return [const Color(0xFF455A64), const Color(0xFF78909C)];
    if (level <= 2)  return [const Color(0xFF1565C0), const Color(0xFF64B5F6)];
    if (level <= 3)  return [const Color(0xFF0277BD), const Color(0xFF4FC3F7)];
    if (level <= 4)  return [const Color(0xFF00695C), const Color(0xFF4DB6AC)];
    if (level <= 5)  return [const Color(0xFF2E7D32), const Color(0xFF81C784)];
    if (level <= 6)  return [const Color(0xFFBF360C), const Color(0xFFFF8A65)];
    if (level <= 7)  return [const Color(0xFFE65100), const Color(0xFFFF9800)];
    if (level <= 8)  return [const Color(0xFF6A1B9A), const Color(0xFFCE93D8)];
    if (level <= 9)  return [const Color(0xFFF57F17), const Color(0xFFFFEE58)];
    if (level <= 10) return [const Color(0xFFB8860B), const Color(0xFFFFD700)];
    if (level <= 12) return [const Color(0xFF006064), const Color(0xFF26C6DA)];
    if (level <= 15) return [const Color(0xFF880E4F), const Color(0xFFF48FB1)];
    if (level <= 18) return [const Color(0xFF311B92), const Color(0xFFB39DDB)];
    if (level <= 22) return [const Color(0xFFBF360C), const Color(0xFFFF7043)];
    if (level <= 27) return [const Color(0xFF006064), const Color(0xFF00E5FF)];
    return [const Color(0xFF424242), const Color(0xFFFFFFFF)];
  }

  static String levelRarity(int level) {
    if (level <= 2)  return 'COMUM';
    if (level <= 4)  return 'INCOMUM';
    if (level <= 7)  return 'RARO';
    if (level <= 10) return 'ÉPICO';
    if (level <= 18) return 'LENDÁRIO';
    return 'MÍTICO';
  }

  static String nextLevelUnlock(int currentLevel) {
    final next = currentLevel + 1;
    if (next <= 3)  return 'Nova tag exclusiva';
    if (next <= 5)  return 'Moldura animada + tag rara';
    if (next <= 7)  return 'Glow especial no avatar';
    if (next <= 8)  return 'Tag Épica com partículas';
    if (next <= 9)  return 'Perfil em destaque na comunidade';
    if (next <= 10) return '🏆 Tag LENDÁRIA + efeitos únicos';
    return 'Título exclusivo de elite';
  }

  // ── CONQUISTAS ───────────────────────────────────────────────────

  static IconData achievementIcon(String id) {
    switch (id) {
      case 'first_login':    return FontAwesomeIcons.rocket;
      case 'articles_10':    return FontAwesomeIcons.bookOpen;
      case 'articles_50':    return FontAwesomeIcons.solidNewspaper;
      case 'articles_100':   return FontAwesomeIcons.graduationCap;
      case 'articles_500':   return FontAwesomeIcons.brainCircuit;
      case '1h_online':      return FontAwesomeIcons.solidClock;
      case '10h_online':     return FontAwesomeIcons.hourglass;
      case '50h_online':     return FontAwesomeIcons.infinity;
      case '100h_online':    return FontAwesomeIcons.meteor;
      case 'first_comment':  return FontAwesomeIcons.solidComments;
      case 'comments_10':    return FontAwesomeIcons.solidComment;
      case 'comments_50':    return FontAwesomeIcons.users;
      case 'top_commenter':  return FontAwesomeIcons.trophy;
      case 'first_share':    return FontAwesomeIcons.shareNodes;
      case 'shares_10':      return FontAwesomeIcons.bullhorn;
      case 'influencer':     return FontAwesomeIcons.wandMagicSparkles;
      case 'streak_7':       return FontAwesomeIcons.fire;
      case 'streak_30':      return FontAwesomeIcons.solidFire;
      case 'streak_100':     return FontAwesomeIcons.fireFlameEnhanced;
      case 'level_5':        return FontAwesomeIcons.solidStar;
      case 'level_10':       return FontAwesomeIcons.crown;
      case 'popular_friend': return FontAwesomeIcons.handshake;
      case 'collaborator':   return FontAwesomeIcons.circleCheck;
      default:               return FontAwesomeIcons.medal;
    }
  }

  static Color achievementColor(String id) {
    switch (id) {
      case 'first_login':    return const Color(0xFF29B6F6);
      case 'articles_10':    return const Color(0xFF66BB6A);
      case 'articles_50':    return const Color(0xFF26C6DA);
      case 'articles_100':   return const Color(0xFFFF7043);
      case 'articles_500':   return const Color(0xFFFF5722);
      case '1h_online':      return const Color(0xFF66BB6A);
      case '10h_online':     return const Color(0xFFFFCA28);
      case '50h_online':     return const Color(0xFFFFB74D);
      case '100h_online':    return const Color(0xFFFFD700);
      case 'first_comment':  return const Color(0xFFBA68C8);
      case 'comments_10':    return const Color(0xFFCE93D8);
      case 'comments_50':    return const Color(0xFFAB47BC);
      case 'top_commenter':  return const Color(0xFFFFD700);
      case 'first_share':    return const Color(0xFF26C6DA);
      case 'shares_10':      return const Color(0xFF4FC3F7);
      case 'influencer':     return const Color(0xFFEC407A);
      case 'streak_7':       return const Color(0xFFFF7043);
      case 'streak_30':      return const Color(0xFFFF5722);
      case 'streak_100':     return const Color(0xFFFF1744);
      case 'level_5':        return const Color(0xFFFFEE58);
      case 'level_10':       return const Color(0xFFFFD700);
      case 'popular_friend': return const Color(0xFF4DB6AC);
      case 'collaborator':   return const Color(0xFF81C784);
      default:               return const Color(0xFFFF6B00);
    }
  }

  static List<Color> achievementGradient(String id) {
    final base = achievementColor(id);
    switch (id) {
      case 'first_login':   return [const Color(0xFF0277BD), const Color(0xFF29B6F6)];
      case 'articles_100':  return [const Color(0xFFBF360C), const Color(0xFFFF7043)];
      case 'articles_500':  return [const Color(0xFF880E4F), const Color(0xFFFF5722)];
      case '100h_online':   return [const Color(0xFFB8860B), const Color(0xFFFFD700)];
      case 'top_commenter': return [const Color(0xFFB8860B), const Color(0xFFFFD700)];
      case 'influencer':    return [const Color(0xFF880E4F), const Color(0xFFF48FB1)];
      case 'streak_100':    return [const Color(0xFFB71C1C), const Color(0xFFFF1744)];
      case 'level_10':      return [const Color(0xFFB8860B), const Color(0xFFFFD700)];
      default:
        return [Color.lerp(base, Colors.black, 0.4)!, base];
    }
  }

  static String achievementRarity(String id) {
    const legendary = {
      'articles_500', '100h_online', 'top_commenter',
      'streak_100', 'level_10', 'influencer'
    };
    const epic = {
      'articles_100', '10h_online', 'comments_50',
      'streak_30', 'level_5', 'shares_10'
    };
    const rare = {
      'articles_50', '1h_online', 'comments_10',
      'streak_7', 'first_share'
    };
    if (legendary.contains(id)) return 'LENDÁRIO';
    if (epic.contains(id))      return 'ÉPICO';
    if (rare.contains(id))      return 'RARO';
    return 'COMUM';
  }

  static bool isLegendary(String id) => achievementRarity(id) == 'LENDÁRIO';
  static bool isEpic(String id)      => achievementRarity(id) == 'ÉPICO';
}
