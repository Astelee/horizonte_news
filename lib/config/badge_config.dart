import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ═══════════════════════════════════════════════════════════════════
// CONFIGURAÇÃO CENTRALIZADA DE BADGES
// Toda mudança visual de ícone/cor acontece aqui.
// ═══════════════════════════════════════════════════════════════════

class BadgeConfig {
  BadgeConfig._();

  // ── Ícones das Conquistas (por ID) ───────────────────────────────
  static IconData achievementIcon(String achievementId) {
    switch (achievementId) {
      case 'first_login':
        return FontAwesomeIcons.rocket;
      case '1h_online':
        return FontAwesomeIcons.clock;
      case '10h_online':
        return FontAwesomeIcons.trophy;
      case '100_articles':
        return FontAwesomeIcons.newspaper;
      case 'first_share':
        return FontAwesomeIcons.shareFromSquare;
      case 'first_comment':
        return FontAwesomeIcons.comments;
      case 'level_5':
        return FontAwesomeIcons.star;
      case 'level_10':
        return FontAwesomeIcons.crown;
      default:
        return FontAwesomeIcons.medal;
    }
  }

  // ── Cor de cada conquista ────────────────────────────────────────
  static Color achievementColor(String achievementId) {
    switch (achievementId) {
      case 'first_login':
        return const Color(0xFF4FC3F7); // azul claro
      case '1h_online':
        return const Color(0xFFAED581); // verde claro
      case '10h_online':
        return const Color(0xFFFFD54F); // dourado
      case '100_articles':
        return const Color(0xFFFF8A65); // laranja suave
      case 'first_share':
        return const Color(0xFF80CBC4); // teal
      case 'first_comment':
        return const Color(0xFFCE93D8); // roxo claro
      case 'level_5':
        return const Color(0xFFFFEB3B); // amarelo
      case 'level_10':
        return const Color(0xFFFFD700); // ouro
      default:
        return const Color(0xFFFF6B00); // laranja padrão
    }
  }

  // ── Ícones dos Níveis (por faixa) ────────────────────────────────
  static IconData levelIcon(int level) {
    if (level < 3) return FontAwesomeIcons.seedling;
    if (level < 5) return FontAwesomeIcons.bookOpen;
    if (level < 8) return FontAwesomeIcons.penNib;
    if (level < 12) return FontAwesomeIcons.microphone;
    if (level < 17) return FontAwesomeIcons.scroll;
    if (level < 23) return FontAwesomeIcons.star;
    if (level < 30) return FontAwesomeIcons.medal;
    return FontAwesomeIcons.crown;
  }

  // ── Cor do nível ─────────────────────────────────────────────────
  static Color levelColor(int level) {
    if (level < 3) return const Color(0xFF81C784);  // verde
    if (level < 5) return const Color(0xFF64B5F6);  // azul
    if (level < 8) return const Color(0xFFFF8A65);  // laranja
    if (level < 12) return const Color(0xFFBA68C8); // roxo
    if (level < 17) return const Color(0xFF4DB6AC); // teal
    if (level < 23) return const Color(0xFFFFD54F); // dourado
    if (level < 30) return const Color(0xFFFFB74D); // ouro
    return const Color(0xFFFFD700);                 // ouro real
  }
}
