import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ═══════════════════════════════════════════════════════════════════
// CONFIGURAÇÃO CENTRALIZADA DE BADGES
// ═══════════════════════════════════════════════════════════════════

class BadgeConfig {
  BadgeConfig._();

  // ── Ícones das Conquistas ────────────────────────────────────────
  static IconData achievementIcon(String achievementId) {
    switch (achievementId) {
      case 'first_login':
        return FontAwesomeIcons.rocket;
      case '1h_online':
        return FontAwesomeIcons.solidClock;
      case '10h_online':
        return FontAwesomeIcons.trophy;
      case '100_articles':
        return FontAwesomeIcons.solidNewspaper;
      case 'first_share':
        return FontAwesomeIcons.shareNodes;
      case 'first_comment':
        return FontAwesomeIcons.solidComments;
      case 'level_5':
        return FontAwesomeIcons.solidStar;
      case 'level_10':
        return FontAwesomeIcons.crown;
      default:
        return FontAwesomeIcons.medal;
    }
  }

  // ── Cor de cada conquista — paleta premium ───────────────────────
  static Color achievementColor(String achievementId) {
    switch (achievementId) {
      case 'first_login':
        // Azul elétrico — "decolagem"
        return const Color(0xFF29B6F6);
      case '1h_online':
        // Verde menta — conquista leve
        return const Color(0xFF66BB6A);
      case '10h_online':
        // Dourado — dedicação
        return const Color(0xFFFFCA28);
      case '100_articles':
        // Laranja quente — leitor voraz
        return const Color(0xFFFF7043);
      case 'first_share':
        // Turquesa — conexão social
        return const Color(0xFF26C6DA);
      case 'first_comment':
        // Lilás — voz ativa
        return const Color(0xFFBA68C8);
      case 'level_5':
        // Amarelo estrela
        return const Color(0xFFFFEE58);
      case 'level_10':
        // Dourado premium
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFFFF6B00);
    }
  }

  // ── Gradientes de cada conquista ─────────────────────────────────
  // Usado no card expandido / destaque
  static List<Color> achievementGradient(String achievementId) {
    switch (achievementId) {
      case 'first_login':
        return [const Color(0xFF0288D1), const Color(0xFF29B6F6)];
      case '1h_online':
        return [const Color(0xFF388E3C), const Color(0xFF66BB6A)];
      case '10h_online':
        return [const Color(0xFFF57F17), const Color(0xFFFFCA28)];
      case '100_articles':
        return [const Color(0xFFBF360C), const Color(0xFFFF7043)];
      case 'first_share':
        return [const Color(0xFF00838F), const Color(0xFF26C6DA)];
      case 'first_comment':
        return [const Color(0xFF7B1FA2), const Color(0xFFBA68C8)];
      case 'level_5':
        return [const Color(0xFFF9A825), const Color(0xFFFFEE58)];
      case 'level_10':
        return [const Color(0xFFE65100), const Color(0xFFFFD700)];
      default:
        return [const Color(0xFFCC4400), const Color(0xFFFF6B00)];
    }
  }

  // ── Rótulo legível de cada conquista ─────────────────────────────
  static String achievementLabel(String achievementId) {
    switch (achievementId) {
      case 'first_login':   return 'Primeiro Acesso';
      case '1h_online':     return '1 Hora Online';
      case '10h_online':    return '10 Horas Online';
      case '100_articles':  return '100 Artigos';
      case 'first_share':   return 'Compartilhador';
      case 'first_comment': return 'Comentarista';
      case 'level_5':       return 'Veterano';
      case 'level_10':      return 'Especialista';
      default:              return 'Conquista';
    }
  }

  // ── Ícones dos Níveis ────────────────────────────────────────────
  static IconData levelIcon(int level) {
    if (level < 3)  return FontAwesomeIcons.seedling;
    if (level < 5)  return FontAwesomeIcons.bookOpen;
    if (level < 8)  return FontAwesomeIcons.penNib;
    if (level < 12) return FontAwesomeIcons.microphone;
    if (level < 17) return FontAwesomeIcons.scroll;
    if (level < 23) return FontAwesomeIcons.solidStar;
    if (level < 30) return FontAwesomeIcons.medal;
    return FontAwesomeIcons.crown;
  }

  // ── Cor do nível ─────────────────────────────────────────────────
  static Color levelColor(int level) {
    if (level < 3)  return const Color(0xFF81C784); // verde iniciante
    if (level < 5)  return const Color(0xFF64B5F6); // azul leitor
    if (level < 8)  return const Color(0xFFFF8A65); // laranja redator
    if (level < 12) return const Color(0xFFBA68C8); // lilás repórter
    if (level < 17) return const Color(0xFF4DB6AC); // teal analista
    if (level < 23) return const Color(0xFFFFD54F); // amarelo expert
    if (level < 30) return const Color(0xFFFFB74D); // âmbar veterano
    return const Color(0xFFFFD700);                 // ouro lendário
  }

  // ── Título do nível ──────────────────────────────────────────────
  static String levelTitle(int level) {
    if (level < 3)  return 'Leitor';
    if (level < 5)  return 'Curioso';
    if (level < 8)  return 'Redator';
    if (level < 12) return 'Repórter';
    if (level < 17) return 'Analista';
    if (level < 23) return 'Jornalista';
    if (level < 30) return 'Veterano';
    return 'Lendário';
  }
}
