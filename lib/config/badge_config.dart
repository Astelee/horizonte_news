import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BadgeConfig {
  BadgeConfig._();

  // ── SISTEMA DE NÍVEIS — 30 NÍVEIS, UM TÍTULO POR NÍVEL ───────────
  // Sistema revisado: antes eram 100 níveis com faixas largas (algo
  // muito distante de se alcançar); agora são 30 níveis, cada um com
  // título, ícone, cor e gradiente próprios — uma progressão granular
  // do início ao fim, com identidade visual em cada degrau.
  static const List<String> _titles = [
    'Visitante',            // 1
    'Leitor Iniciante',     // 2
    'Leitor Curioso',       // 3
    'Acompanhante',         // 4
    'Seguidor Assíduo',     // 5
    'Entusiasta',           // 6
    'Explorador',           // 7
    'Investigador',         // 8
    'Super Leitor',         // 9
    'Fã da Informação',     // 10
    'Membro Destaque',      // 11
    'Analista Júnior',      // 12
    'Analista',             // 13
    'Correspondente',       // 14
    'Cronista',             // 15
    'Editor Amador',        // 16
    'Guardião das Notícias',// 17
    'Vanguarda',            // 18
    'Mestre da Informação', // 19
    'Sentinela',            // 20
    'Visionário',           // 21
    'Oráculo',              // 22
    'Fenômeno',             // 23
    'Lendário Absoluto',    // 24
    'Mítico',               // 25
    'Ícone do Horizonte',   // 26
    'Chama Suprema',        // 27
    'Elite Flamejante',     // 28
    'Elite Radiante',       // 29
    'Horizonte Supremo',    // 30
  ];

  static String levelTitle(int level) {
    final idx = level.clamp(1, _titles.length) - 1;
    return _titles[idx];
  }

  // Apenas ícones já validados no projeto (existentes antes desta
  // revisão) são usados aqui — evita depender de nomes de ícone não
  // conferidos no pacote font_awesome_flutter instalado no projeto.
  static const List<IconData> _icons = [
    FontAwesomeIcons.eye,                  // 1
    FontAwesomeIcons.bookOpen,             // 2
    FontAwesomeIcons.magnifyingGlass,      // 3
    FontAwesomeIcons.bookmark,             // 4
    FontAwesomeIcons.compass,              // 5
    FontAwesomeIcons.fire,                 // 6
    FontAwesomeIcons.featherPointed,       // 7
    FontAwesomeIcons.brain,                // 8
    FontAwesomeIcons.solidStar,            // 9
    FontAwesomeIcons.trophy,               // 10
    FontAwesomeIcons.medal,                // 11
    FontAwesomeIcons.chartLine,            // 12
    FontAwesomeIcons.graduationCap,        // 13
    FontAwesomeIcons.shareNodes,           // 14
    FontAwesomeIcons.solidComments,        // 15
    FontAwesomeIcons.bullhorn,             // 16
    FontAwesomeIcons.shieldHalved,         // 17
    FontAwesomeIcons.hourglass,            // 18
    FontAwesomeIcons.infinity,             // 19
    FontAwesomeIcons.eye,                  // 20 (Sentinela — vigilância)
    FontAwesomeIcons.wandMagicSparkles,    // 21
    FontAwesomeIcons.gem,                  // 22
    FontAwesomeIcons.meteor,               // 23
    FontAwesomeIcons.crown,                // 24
    FontAwesomeIcons.fireAlt,              // 25
    FontAwesomeIcons.solidNewspaper,       // 26
    FontAwesomeIcons.fireFlameCurved,      // 27
    FontAwesomeIcons.sun,                  // 28
    FontAwesomeIcons.bolt,                 // 29
    FontAwesomeIcons.crown,                // 30
  ];

  static IconData levelIcon(int level) {
    final idx = level.clamp(1, _icons.length) - 1;
    return _icons[idx];
  }

  // ── CORES POR NÍVEL — uma cor sólida por nível, sem repetição ────
  // Percorre o círculo cromático inteiro: azuis frios no início,
  // passando por verdes, dourados, róseos, roxos, até fogo e branco-
  // dourado incandescente no topo. Muito mais variedade que faixas
  // largas — cada nível já parece uma conquista visual distinta.
  static const List<Color> _colors = [
    Color(0xFF90A4AE), // 1  Visitante — cinza-azulado
    Color(0xFF64B5F6), // 2  azul claro
    Color(0xFF42A5F5), // 3  azul
    Color(0xFF29B6F6), // 4  azul-céu vívido
    Color(0xFF26C6DA), // 5  ciano
    Color(0xFF00BFA5), // 6  verde-água
    Color(0xFF66BB6A), // 7  verde
    Color(0xFF9CCC65), // 8  verde-lima
    Color(0xFFD4E157), // 9  lima-amarelado
    Color(0xFFFFD700), // 10 dourado — Fã da Informação
    Color(0xFFFFCA28), // 11 âmbar
    Color(0xFFFFA726), // 12 laranja claro
    Color(0xFFFF8A65), // 13 salmão
    Color(0xFFFF7043), // 14 laranja-fogo
    Color(0xFFEC407A), // 15 rosa vívido — Cronista
    Color(0xFFF06292), // 16 rosa claro
    Color(0xFFBA68C8), // 17 lilás
    Color(0xFF9575CD), // 18 roxo-azulado
    Color(0xFF7E57C2), // 19 roxo
    Color(0xFF5C6BC0), // 20 índigo
    Color(0xFF00E5FF), // 21 ciano elétrico
    Color(0xFFE040FB), // 22 magenta vívido
    Color(0xFFD500F9), // 23 magenta-roxo elétrico
    Color(0xFF7C4DFF), // 24 violeta cósmico
    Color(0xFFFF1744), // 25 vermelho intenso — Mítico
    Color(0xFFFF3D00), // 26 vermelho-fogo
    Color(0xFFFF6D00), // 27 laranja-fogo intenso
    Color(0xFFFFC400), // 28 dourado intenso
    Color(0xFFFFD54F), // 29 âmbar dourado
    Color(0xFFFFF176), // 30 dourado-branco — Horizonte Supremo
  ];

  static Color levelColor(int level) {
    final idx = level.clamp(1, _colors.length) - 1;
    return _colors[idx];
  }

  static const List<List<Color>> _gradients = [
    [Color(0xFF546E7A), Color(0xFF90A4AE)], // 1
    [Color(0xFF1976D2), Color(0xFF64B5F6)], // 2
    [Color(0xFF1565C0), Color(0xFF42A5F5)], // 3
    [Color(0xFF0277BD), Color(0xFF29B6F6)], // 4
    [Color(0xFF00838F), Color(0xFF26C6DA)], // 5
    [Color(0xFF00695C), Color(0xFF00BFA5)], // 6
    [Color(0xFF2E7D32), Color(0xFF66BB6A)], // 7
    [Color(0xFF558B2F), Color(0xFF9CCC65)], // 8
    [Color(0xFF9E9D24), Color(0xFFD4E157)], // 9
    [Color(0xFFB8860B), Color(0xFFFFD700)], // 10
    [Color(0xFFF57F17), Color(0xFFFFCA28)], // 11
    [Color(0xFFE65100), Color(0xFFFFA726)], // 12
    [Color(0xFFD84315), Color(0xFFFF8A65)], // 13
    [Color(0xFFBF360C), Color(0xFFFF7043)], // 14
    [Color(0xFF880E4F), Color(0xFFEC407A)], // 15
    [Color(0xFFAD1457), Color(0xFFF06292)], // 16
    [Color(0xFF6A1B9A), Color(0xFFBA68C8)], // 17
    [Color(0xFF512DA8), Color(0xFF9575CD)], // 18
    [Color(0xFF4527A0), Color(0xFF7E57C2)], // 19
    [Color(0xFF283593), Color(0xFF5C6BC0)], // 20
    [Color(0xFF006064), Color(0xFF00E5FF)], // 21
    [Color(0xFF6A1B9A), Color(0xFFE040FB)], // 22
    [Color(0xFF4A148C), Color(0xFFD500F9)], // 23
    [Color(0xFF311B92), Color(0xFF7C4DFF)], // 24
    [Color(0xFFB71C1C), Color(0xFFFF1744)], // 25
    [Color(0xFFBF360C), Color(0xFFFF3D00)], // 26
    [Color(0xFFE65100), Color(0xFFFF6D00)], // 27
    [Color(0xFFE65100), Color(0xFFFFC400)], // 28
    [Color(0xFFFF6D00), Color(0xFFFFD54F)], // 29
    [Color(0xFFFF3D00), Color(0xFFFFF176)], // 30
  ];

  static List<Color> levelGradient(int level) {
    final idx = level.clamp(1, _gradients.length) - 1;
    return _gradients[idx];
  }

  // ── RARIDADE — 10 faixas (o dobro de antes) para mais granularidade
  static String levelRarity(int level) {
    if (level <= 3)  return 'COMUM';
    if (level <= 6)  return 'INCOMUM';
    if (level <= 9)  return 'RARO';
    if (level <= 12) return 'ESPECIAL';
    if (level <= 15) return 'ÉPICO';
    if (level <= 18) return 'HEROICO';
    if (level <= 21) return 'LENDÁRIO';
    if (level <= 24) return 'MÍTICO';
    if (level <= 27) return 'SUPREMO';
    return 'HORIZONTE ELITE';
  }

  static String nextLevelUnlock(int currentLevel) {
    final next = currentLevel + 1;
    if (next <= 2)  return 'Cor de nível personalizada';
    if (next <= 3)  return 'Nova tag exclusiva';
    if (next <= 4)  return 'Primeiras partículas no avatar';
    if (next <= 6)  return 'Moldura animada + tag Incomum';
    if (next <= 7)  return 'Anel giratório na moldura';
    if (next <= 9)  return 'Mais partículas orbitais + tag Rara';
    if (next <= 10) return '🏆 Glow intenso + brilho dourado';
    if (next <= 12) return 'Tag ESPECIAL + espessura extra no anel';
    if (next <= 15) return 'Efeitos de partículas avançados + tag ÉPICA';
    if (next <= 18) return 'Pulso no avatar + tag HEROICA';
    if (next <= 21) return 'Halo cósmico + estrelas orbitais + tag LENDÁRIA';
    if (next <= 24) return 'Aura 360° dinâmica + tag MÍTICA';
    if (next <= 27) return '✨ Marca exclusiva SUPREMA + partículas máximas';
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
      case 'level_20':       return FontAwesomeIcons.gem;
      case 'level_30':       return FontAwesomeIcons.crown;
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
      case 'level_20':       return const Color(0xFF7C4DFF);
      case 'level_30':       return const Color(0xFFFFF176);
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
      case 'level_20':      return [const Color(0xFF311B92), const Color(0xFF7C4DFF)];
      case 'level_30':      return [const Color(0xFFFF3D00), const Color(0xFFFFF176)];
      default:
        return [Color.lerp(base, Colors.black, 0.4)!, base];
    }
  }

  static String achievementRarity(String id) {
    const legendary = {
      'articles_500', '100h_online', 'top_commenter',
      'streak_100', 'level_10', 'level_20', 'level_30', 'influencer',
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