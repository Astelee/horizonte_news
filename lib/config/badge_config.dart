import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BadgeConfig {
  BadgeConfig._();

  // ── SISTEMA DE NÍVEIS ────────────────────────────────────────────
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
    if (level <= 30) return 'Fenômeno';
    if (level <= 40) return 'Mítico Absoluto';
    if (level <= 50) return 'Chama Suprema';
    if (level <= 70) return 'Elite Flamejante';
    if (level <= 90) return 'Elite Radiante';
    return 'Horizonte Elite';
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
    if (level <= 30) return FontAwesomeIcons.gem;
    if (level <= 40) return FontAwesomeIcons.meteor;
    if (level <= 50) return FontAwesomeIcons.fireFlameCurved;
    if (level <= 70) return FontAwesomeIcons.sun;
    if (level <= 90) return FontAwesomeIcons.bolt;
    return FontAwesomeIcons.crown;
  }

  // ── CORES POR NÍVEL — progressão vívida do 1 ao 99+ ──────────────
  // Cada faixa tem uma identidade cromática própria, sem repetir tons
  // "seguros"/apagados nos níveis baixos.
  static Color levelColor(int level) {
    if (level <= 1)  return const Color(0xFF90A4AE); // Visitante — cinza-azulado claro
    if (level <= 2)  return const Color(0xFF4FC3F7); // Leitor — azul-céu
    if (level <= 3)  return const Color(0xFF29B6F6); // Acompanhante — azul vívido
    if (level <= 4)  return const Color(0xFF26C6DA); // Seguidor — ciano
    if (level <= 5)  return const Color(0xFF66BB6A); // Entusiasta — verde vivo
    if (level <= 6)  return const Color(0xFF9CCC65); // Explorador — verde-lima
    if (level <= 7)  return const Color(0xFFFFCA28); // Super Leitor — âmbar
    if (level <= 8)  return const Color(0xFFFFA726); // Fã da Informação — laranja
    if (level <= 9)  return const Color(0xFFFF7043); // Membro Destaque — laranja-fogo
    if (level <= 10) return const Color(0xFFFFD700); // Lenda das Notícias — dourado
    if (level <= 12) return const Color(0xFF26A69A); // Analista — verde-azulado
    if (level <= 15) return const Color(0xFFEC407A); // Cronista — rosa vívido
    if (level <= 18) return const Color(0xFF7E57C2); // Guardião — roxo
    if (level <= 22) return const Color(0xFFFF5722); // Mestre da Informação — vermelho-laranja
    if (level <= 27) return const Color(0xFF00E5FF); // Oráculo — ciano elétrico
    if (level <= 30) return const Color(0xFFE040FB); // Fenômeno — magenta vívido
    if (level <= 40) return const Color(0xFF7C4DFF); // Mítico Absoluto — violeta cósmico
    if (level <= 50) return const Color(0xFFFF3D00); // Chama Suprema — vermelho-fogo
    if (level <= 70) return const Color(0xFFFFC400); // Elite Flamejante — dourado intenso
    if (level <= 90) return const Color(0xFFFFD54F); // Elite Radiante — âmbar dourado
    return const Color(0xFFFFEA00); // Horizonte Elite — dourado-branco brilhante
  }

  static List<Color> levelGradient(int level) {
    if (level <= 1)  return [const Color(0xFF546E7A), const Color(0xFF90A4AE)];
    if (level <= 2)  return [const Color(0xFF0288D1), const Color(0xFF4FC3F7)];
    if (level <= 3)  return [const Color(0xFF0277BD), const Color(0xFF29B6F6)];
    if (level <= 4)  return [const Color(0xFF00838F), const Color(0xFF26C6DA)];
    if (level <= 5)  return [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
    if (level <= 6)  return [const Color(0xFF558B2F), const Color(0xFF9CCC65)];
    if (level <= 7)  return [const Color(0xFFF57F17), const Color(0xFFFFCA28)];
    if (level <= 8)  return [const Color(0xFFE65100), const Color(0xFFFFA726)];
    if (level <= 9)  return [const Color(0xFFBF360C), const Color(0xFFFF7043)];
    if (level <= 10) return [const Color(0xFFB8860B), const Color(0xFFFFD700)];
    if (level <= 12) return [const Color(0xFF00695C), const Color(0xFF26A69A)];
    if (level <= 15) return [const Color(0xFF880E4F), const Color(0xFFEC407A)];
    if (level <= 18) return [const Color(0xFF4527A0), const Color(0xFF7E57C2)];
    if (level <= 22) return [const Color(0xFFBF360C), const Color(0xFFFF5722)];
    if (level <= 27) return [const Color(0xFF006064), const Color(0xFF00E5FF)];
    // ── Sequência de fogo crescente — cada tier mais quente que o anterior ──
    if (level <= 30) return [const Color(0xFF6A1B9A), const Color(0xFFE040FB)];
    if (level <= 40) return [const Color(0xFF311B92), const Color(0xFF7C4DFF)];
    if (level <= 50) return [const Color(0xFFBF360C), const Color(0xFFFF3D00)];
    if (level <= 70) return [const Color(0xFFE65100), const Color(0xFFFFC400)];
    if (level <= 90) return [const Color(0xFFFF6D00), const Color(0xFFFFD54F)];
    return [const Color(0xFFFF3D00), const Color(0xFFFFEA00)];
  }

  // ── RARIDADE — faixas reorganizadas, mais granulares no início ───
  static String levelRarity(int level) {
    if (level <= 3)  return 'COMUM';
    if (level <= 6)  return 'INCOMUM';
    if (level <= 10) return 'RARO';
    if (level <= 15) return 'ÉPICO';
    if (level <= 22) return 'LENDÁRIO';
    if (level <= 30) return 'MÍTICO';
    if (level <= 50) return 'SUPREMO';
    return 'HORIZONTE ELITE';
  }

  static String nextLevelUnlock(int currentLevel) {
    final next = currentLevel + 1;
    if (next <= 2)  return 'Cor de nível personalizada';
    if (next <= 3)  return 'Nova tag exclusiva';
    if (next <= 5)  return 'Primeiras partículas no avatar';
    if (next <= 7)  return 'Moldura animada + tag Rara';
    if (next <= 10) return 'Anel giratório + glow especial';
    if (next <= 12) return '🏆 Tag ÉPICA + brilho intenso';
    if (next <= 15) return 'Efeitos de partículas avançados';
    if (next <= 18) return 'Tag LENDÁRIA + pulso no avatar';
    if (next <= 22) return 'Aura expandida ao redor do avatar';
    if (next <= 27) return 'Halo cósmico + estrelas orbitais';
    if (next <= 30) return '✨ Tag MÍTICA + efeitos únicos';
    if (next <= 40) return 'Aura 360° dinâmica';
    if (next <= 50) return 'Marca exclusiva de Elite';
    return 'Título máximo de Horizonte Elite';
  }

  // ── CONQUISTAS ───────────────────────────────────────────────────

  static IconData achievementIcon(String id) {
    switch (id) {
      case 'first_login':    return FontAwesomeIcons.rocket;
      case 'articles_10':    return FontAwesomeIcons.bookOpen;
      case 'articles_50':    return FontAwesomeIcons.solidNewspaper;
      case 'articles_100':   return FontAwesomeIcons.graduationCap;
      case 'articles_500':   return FontAwesomeIcons.brain;
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
      case 'streak_30':      return FontAwesomeIcons.fireFlameCurved;
      case 'streak_100':     return FontAwesomeIcons.fireAlt;
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
      'streak_100', 'level_10', 'influencer',
    };
    const epic = {
      'articles_100', '10h_online', 'comments_50',
      'streak_30', 'level_5', 'shares_10',
    };
    const rare = {
      'articles_50', '1h_online', 'comments_10',
      'streak_7', 'first_share',
    };
    if (legendary.contains(id)) return 'LENDÁRIO';
    if (epic.contains(id))      return 'ÉPICO';
    if (rare.contains(id))      return 'RARO';
    return 'COMUM';
  }

  static bool isLegendary(String id) => achievementRarity(id) == 'LENDÁRIO';
  static bool isEpic(String id)      => achievementRarity(id) == 'ÉPICO';
}
