import 'package:flutter/material.dart';
import '../services/xp_service.dart';
import 'badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// EMBLEMAS 3D — CONFIGURAÇÃO VISUAL
//
// Tudo aqui é APARÊNCIA. Nenhuma regra de desbloqueio, XP, nível,
// missão ou assinatura é lida ou alterada por este arquivo: os ids,
// títulos, descrições e ícones continuam vindo de XpService e
// BadgeConfig. A raridade abaixo é só metadado visual (não é gravada
// no Firebase).
// ═══════════════════════════════════════════════════════════════════

/// Raridade VISUAL da medalha: define intensidade de brilho, partículas
/// e pedrarias — não afeta nada fora da tela.
enum MedalRarity { comum, incomum, raro, epico, lendario, mitico }

extension MedalRarityVisual on MedalRarity {
  String get label {
    switch (this) {
      case MedalRarity.comum:
        return 'COMUM';
      case MedalRarity.incomum:
        return 'INCOMUM';
      case MedalRarity.raro:
        return 'RARO';
      case MedalRarity.epico:
        return 'ÉPICO';
      case MedalRarity.lendario:
        return 'LENDÁRIO';
      case MedalRarity.mitico:
        return 'MÍTICO';
    }
  }

  /// Cor de destaque da raridade (etiqueta, borda do cartão).
  Color get accent {
    switch (this) {
      case MedalRarity.comum:
        return const Color(0xFF42A5F5);
      case MedalRarity.incomum:
        return const Color(0xFF43B581);
      case MedalRarity.raro:
        return const Color(0xFFAB47BC);
      case MedalRarity.epico:
        return const Color(0xFFFF7A00);
      case MedalRarity.lendario:
        return const Color(0xFFFFC400);
      case MedalRarity.mitico:
        return const Color(0xFFB388FF);
    }
  }

  /// 0 (comum) … 5 (mítico): quanto mais alto, mais efeitos.
  int get tier => index;
}

/// Material e símbolo de uma medalha.
class MedalSpec {
  final String id;
  final IconData icon;
  final MedalRarity rarity;

  /// Metal da borda: sombra, tom médio e luz.
  final Color dark;
  final Color mid;
  final Color light;

  /// Cor da aura / brilhos.
  final Color glow;

  /// true = cristal (facetas translúcidas no fundo).
  final bool crystal;

  /// true = medalha suprema (anel e efeitos exclusivos).
  final bool supreme;

  const MedalSpec({
    required this.id,
    required this.icon,
    required this.rarity,
    required this.dark,
    required this.mid,
    required this.light,
    required this.glow,
    this.crystal = false,
    this.supreme = false,
  });

  // Fundo (campo) da medalha, derivado do metal.
  Color get fieldCenter => Color.lerp(mid, dark, 0.38)!;
  Color get fieldMid => Color.lerp(dark, mid, 0.30)!;
  Color get fieldEdge => Color.lerp(dark, Colors.black, 0.55)!;

  // Símbolo em relevo: face, laterais e sombra.
  Color get symbolTop => light;
  Color get symbolMid => Color.lerp(light, mid, 0.55)!;
  Color get symbolSide => Color.lerp(mid, dark, 0.72)!;

  /// Versão "bloqueada": metal escuro, sem cor. Continua 3D.
  MedalSpec get lockedVersion => MedalSpec(
        id: id,
        icon: icon,
        rarity: rarity,
        dark: const Color(0xFF151515),
        mid: const Color(0xFF3A3A3A),
        light: const Color(0xFF727272),
        glow: const Color(0xFF444444),
        crystal: false,
        supreme: false,
      );
}

class Badge3DConfig {
  Badge3DConfig._();

  static MedalSpec specFor(String id) => _specs[id] ?? _fallback(id);

  // Identidade de cada uma das 10 conquistas atuais. O ícone é o MESMO
  // de BadgeConfig.achievementIcon (foguete, relógio, ampulheta, chapéu
  // de formatura, compartilhar, balões, estrela, coroa, diamante, coroa).
  static final Map<String, MedalSpec> _specs = {
    // 1 — metal azul, foguete
    'first_login': MedalSpec(
      id: 'first_login',
      icon: BadgeConfig.achievementIcon('first_login'),
      rarity: MedalRarity.comum,
      dark: const Color(0xFF0A2552),
      mid: const Color(0xFF1E88E5),
      light: const Color(0xFFBBDEFB),
      glow: const Color(0xFF29B6F6),
    ),
    // 2 — esmeralda, relógio
    '1h_online': MedalSpec(
      id: '1h_online',
      icon: BadgeConfig.achievementIcon('1h_online'),
      rarity: MedalRarity.incomum,
      dark: const Color(0xFF04301E),
      mid: const Color(0xFF12A15F),
      light: const Color(0xFFA9F5D2),
      glow: const Color(0xFF2ECC71),
      crystal: true,
    ),
    // 3 — ouro, ampulheta
    '10h_online': MedalSpec(
      id: '10h_online',
      icon: BadgeConfig.achievementIcon('10h_online'),
      rarity: MedalRarity.raro,
      dark: const Color(0xFF5A3900),
      mid: const Color(0xFFD9A21B),
      light: const Color(0xFFFFF1A6),
      glow: const Color(0xFFFFCA28),
    ),
    // 4 — cobre avermelhado, chapéu de formatura
    'articles_100': MedalSpec(
      id: 'articles_100',
      icon: BadgeConfig.achievementIcon('articles_100'),
      rarity: MedalRarity.epico,
      dark: const Color(0xFF3B0F04),
      mid: const Color(0xFFC4501F),
      light: const Color(0xFFFFC4A3),
      glow: const Color(0xFFFF7043),
    ),
    // 5 — cristal ciano, compartilhar
    'first_share': MedalSpec(
      id: 'first_share',
      icon: BadgeConfig.achievementIcon('first_share'),
      rarity: MedalRarity.incomum,
      dark: const Color(0xFF033F4A),
      mid: const Color(0xFF19B9CC),
      light: const Color(0xFFE3FCFF),
      glow: const Color(0xFF26C6DA),
      crystal: true,
    ),
    // 6 — ametista, balões de conversa
    'first_comment': MedalSpec(
      id: 'first_comment',
      icon: BadgeConfig.achievementIcon('first_comment'),
      rarity: MedalRarity.raro,
      dark: const Color(0xFF2B0948),
      mid: const Color(0xFF8E44C9),
      light: const Color(0xFFE8CCFF),
      glow: const Color(0xFFBA68C8),
      crystal: true,
    ),
    // 7 — ouro, estrela
    'level_5': MedalSpec(
      id: 'level_5',
      icon: BadgeConfig.achievementIcon('level_5'),
      rarity: MedalRarity.epico,
      dark: const Color(0xFF674000),
      mid: const Color(0xFFE8B620),
      light: const Color(0xFFFFF7B0),
      glow: const Color(0xFFFFD54F),
    ),
    // 8 — ouro brilhante, coroa
    'level_10': MedalSpec(
      id: 'level_10',
      icon: BadgeConfig.achievementIcon('level_10'),
      rarity: MedalRarity.lendario,
      dark: const Color(0xFF7A4B00),
      mid: const Color(0xFFFFC107),
      light: const Color(0xFFFFFDE7),
      glow: const Color(0xFFFFD54F),
    ),
    // 9 — cristal violeta, diamante
    'level_20': MedalSpec(
      id: 'level_20',
      icon: BadgeConfig.achievementIcon('level_20'),
      rarity: MedalRarity.mitico,
      dark: const Color(0xFF190A52),
      mid: const Color(0xFF7C4DFF),
      light: const Color(0xFFE3D8FF),
      glow: const Color(0xFFB388FF),
      crystal: true,
    ),
    // 10 — suprema: ouro + laranja, coroa
    'level_30': MedalSpec(
      id: 'level_30',
      icon: BadgeConfig.achievementIcon('level_30'),
      rarity: MedalRarity.mitico,
      dark: const Color(0xFF8A2500),
      mid: const Color(0xFFFF7A00),
      light: const Color(0xFFFFF59D),
      glow: const Color(0xFFFF9100),
      supreme: true,
    ),
  };

  /// Qualquer outra conquista (ex.: ids que existem em BadgeConfig mas
  /// não aparecem na lista atual) ganha uma medalha derivada das cores
  /// já definidas para ela — nada deixa de renderizar.
  static MedalSpec _fallback(String id) {
    final g = BadgeConfig.achievementGradient(id);
    final base = BadgeConfig.achievementColor(id);
    MedalRarity r;
    switch (BadgeConfig.achievementRarity(id)) {
      case 'LENDÁRIO':
        r = MedalRarity.lendario;
        break;
      case 'ÉPICO':
        r = MedalRarity.epico;
        break;
      case 'RARO':
        r = MedalRarity.raro;
        break;
      default:
        r = MedalRarity.comum;
    }
    return MedalSpec(
      id: id,
      icon: BadgeConfig.achievementIcon(id),
      rarity: r,
      dark: g[0],
      mid: g[1],
      light: Color.lerp(g[1], Colors.white, 0.6)!,
      glow: base,
    );
  }

  /// Texto do critério de desbloqueio (espelha as descrições atuais).
  static String criteriaFor(String id, String fallbackDescription) {
    switch (id) {
      case 'first_login':
        return 'Entrar no Horizonte News pela primeira vez.';
      case '1h_online':
        return 'Acumular 1 hora de uso ativo no aplicativo.';
      case '10h_online':
        return 'Acumular 10 horas de uso ativo no aplicativo.';
      case 'articles_100':
        return 'Ler 100 notícias no aplicativo.';
      case 'first_share':
        return 'Compartilhar uma notícia pela primeira vez.';
      case 'first_comment':
        return 'Publicar o seu primeiro comentário.';
      case 'level_5':
        return 'Alcançar o nível 5.';
      case 'level_10':
        return 'Alcançar o nível 10.';
      case 'level_20':
        return 'Alcançar o nível 20.';
      case 'level_30':
        return 'Alcançar o nível máximo: 30.';
      default:
        return fallbackDescription;
    }
  }

  /// Progresso exibido para medalhas bloqueadas. Só LÊ os mesmos dados
  /// que o desbloqueio já usa (tempo online, estatísticas, nível).
  static MedalProgress? progressFor(String id, UserXpData d) {
    int stat(String key) => (d.stats[key] as num?)?.toInt() ?? 0;
    switch (id) {
      case '1h_online':
        return MedalProgress(
          current: d.totalSecondsOnline / 60,
          target: 60,
          unit: 'min',
        );
      case '10h_online':
        return MedalProgress(
          current: d.totalSecondsOnline / 3600,
          target: 10,
          unit: 'h',
          decimals: 1,
        );
      case 'articles_100':
        return MedalProgress(
          current: stat('articlesRead').toDouble(),
          target: 100,
          unit: 'notícias',
        );
      case 'first_share':
        return MedalProgress(
          current: stat('articlesShared').toDouble(),
          target: 1,
          unit: 'compartilhamento',
        );
      case 'first_comment':
        return MedalProgress(
          current: stat('commentsPosted').toDouble(),
          target: 1,
          unit: 'comentário',
        );
      case 'level_5':
        return MedalProgress(
            current: d.level.toDouble(), target: 5, unit: 'nível');
      case 'level_10':
        return MedalProgress(
            current: d.level.toDouble(), target: 10, unit: 'nível');
      case 'level_20':
        return MedalProgress(
            current: d.level.toDouble(), target: 20, unit: 'nível');
      case 'level_30':
        return MedalProgress(
            current: d.level.toDouble(), target: 30, unit: 'nível');
      default:
        return null;
    }
  }
}

class MedalProgress {
  final double current;
  final double target;
  final String unit;
  final int decimals;

  const MedalProgress({
    required this.current,
    required this.target,
    required this.unit,
    this.decimals = 0,
  });

  double get fraction =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();

  String get label {
    final c = current > target ? target : current;
    String f(double v) =>
        decimals == 0 ? v.floor().toString() : v.toStringAsFixed(decimals);
    return '${f(c)} / ${f(target)} $unit';
  }
}