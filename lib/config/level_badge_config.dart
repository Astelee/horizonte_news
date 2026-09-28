import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO DOS 30 SELOS DE NÍVEL — 100% CustomPainter, sem imagens
// ═══════════════════════════════════════════════════════════════════
// Substitui o antigo AvatarFrame (moldura ao redor do avatar). Cada
// nível agora tem um selo pequeno, autocontido e independente — sem
// envolver o avatar em nenhuma borda — desenhado dentro de um círculo
// próprio e posicionado flutuando sobre o avatar (canto superior
// esquerdo), no mesmo espírito estrutural do CheckinRewardBadge
// (canto inferior direito).
//
// 10 faixas de raridade, 3 níveis cada, mesma segmentação que já
// existia em BadgeConfig.levelRarity()/FrameRarityExt — não muda a
// progressão nem os títulos, só a arte do selo.
//
// Para adicionar/ajustar um nível: edite a entrada correspondente em
// [LevelBadgeConfig.all] e o painter equivalente em
// lib/widgets/level_badge_painters.dart (case no switch de
// LevelBadgeArt). Nada mais muda.
// ═══════════════════════════════════════════════════════════════════

enum LevelBadgeRarity {
  common, // 1-3
  uncommon, // 4-6
  rare, // 7-9
  special, // 10-12
  epic, // 13-15
  heroic, // 16-18
  legendary, // 19-21
  mythic, // 22-24
  supreme, // 25-27
  elite, // 28-30
}

extension LevelBadgeRarityX on LevelBadgeRarity {
  static LevelBadgeRarity fromLevel(int level) {
    if (level >= 28) return LevelBadgeRarity.elite;
    if (level >= 25) return LevelBadgeRarity.supreme;
    if (level >= 22) return LevelBadgeRarity.mythic;
    if (level >= 19) return LevelBadgeRarity.legendary;
    if (level >= 16) return LevelBadgeRarity.heroic;
    if (level >= 13) return LevelBadgeRarity.epic;
    if (level >= 10) return LevelBadgeRarity.special;
    if (level >= 7) return LevelBadgeRarity.rare;
    if (level >= 4) return LevelBadgeRarity.uncommon;
    return LevelBadgeRarity.common;
  }

  String get label {
    switch (this) {
      case LevelBadgeRarity.common:
        return 'Comum';
      case LevelBadgeRarity.uncommon:
        return 'Incomum';
      case LevelBadgeRarity.rare:
        return 'Raro';
      case LevelBadgeRarity.special:
        return 'Especial';
      case LevelBadgeRarity.epic:
        return 'Épico';
      case LevelBadgeRarity.heroic:
        return 'Heroico';
      case LevelBadgeRarity.legendary:
        return 'Lendário';
      case LevelBadgeRarity.mythic:
        return 'Mítico';
      case LevelBadgeRarity.supreme:
        return 'Supremo';
      case LevelBadgeRarity.elite:
        return 'Horizonte Elite';
    }
  }

  /// Quantidade de partículas/detalhes orbitais do selo — cresce com
  /// a raridade, culminando num acabamento denso nas faixas mais
  /// altas (mesma curva de progressão do antigo AvatarFrame).
  int get particleCount {
    switch (this) {
      case LevelBadgeRarity.common:
        return 0;
      case LevelBadgeRarity.uncommon:
        return 3;
      case LevelBadgeRarity.rare:
        return 4;
      case LevelBadgeRarity.special:
        return 5;
      case LevelBadgeRarity.epic:
        return 6;
      case LevelBadgeRarity.heroic:
        return 7;
      case LevelBadgeRarity.legendary:
        return 8;
      case LevelBadgeRarity.mythic:
        return 9;
      case LevelBadgeRarity.supreme:
        return 10;
      case LevelBadgeRarity.elite:
        return 12;
    }
  }

  bool get hasRotatingRing => this != LevelBadgeRarity.common;

  bool get hasSecondRing =>
      this == LevelBadgeRarity.heroic ||
      this == LevelBadgeRarity.legendary ||
      this == LevelBadgeRarity.mythic ||
      this == LevelBadgeRarity.supreme ||
      this == LevelBadgeRarity.elite;

  bool get hasSparkles =>
      this == LevelBadgeRarity.mythic ||
      this == LevelBadgeRarity.supreme ||
      this == LevelBadgeRarity.elite;

  /// Brilho crescente gradualmente desde o nível 1.
  double get glowIntensity {
    switch (this) {
      case LevelBadgeRarity.common:
        return 0.28;
      case LevelBadgeRarity.uncommon:
        return 0.38;
      case LevelBadgeRarity.rare:
        return 0.48;
      case LevelBadgeRarity.special:
        return 0.58;
      case LevelBadgeRarity.epic:
        return 0.68;
      case LevelBadgeRarity.heroic:
        return 0.77;
      case LevelBadgeRarity.legendary:
        return 0.85;
      case LevelBadgeRarity.mythic:
        return 0.92;
      case LevelBadgeRarity.supreme:
        return 0.97;
      case LevelBadgeRarity.elite:
        return 1.0;
    }
  }
}

/// Arquétipo visual do selo — cada nível tem um desenho com
/// identidade própria; o arquétipo só orienta a "família" de forma
/// (o painter de cada nível ainda é único, não uma reskin de cor).
enum LevelBadgeArchetype {
  eye,
  openBook,
  compassStar,
  bookmarkShield,
  windRose,
  emberSpark,
  feather,
  brainFacets,
  starBurst,
  trophyCrest,
  laurelMedal,
  ascendArrow,
  scrollSeal,
  signalWaves,
  quillInk,
  megaphoneRing,
  shieldEmblem,
  hourglassOrbit,
  infinityLoop,
  sentinelEye,
  wandSparkle,
  gemCut,
  meteorTrail,
  royalCrownSmall,
  crackedCore,
  phoenixFlame,
  flameCrown,
  radiantSun,
  boltCore,
  supremeCrown,
}

class LevelBadgeDef {
  final int level;
  final String name;
  final LevelBadgeRarity rarity;
  final LevelBadgeArchetype archetype;
  final List<Color> gradient;
  final Color accentColor;

  const LevelBadgeDef({
    required this.level,
    required this.name,
    required this.rarity,
    required this.archetype,
    required this.gradient,
    required this.accentColor,
  });
}

class LevelBadgeConfig {
  LevelBadgeConfig._();

  static const List<LevelBadgeDef> all = [
    LevelBadgeDef(
      level: 1,
      name: 'Visitante',
      rarity: LevelBadgeRarity.common,
      archetype: LevelBadgeArchetype.eye,
      gradient: [Color(0xFF546E7A), Color(0xFF90A4AE)],
      accentColor: Color(0xFF90A4AE),
    ),
    LevelBadgeDef(
      level: 2,
      name: 'Leitor Iniciante',
      rarity: LevelBadgeRarity.common,
      archetype: LevelBadgeArchetype.openBook,
      gradient: [Color(0xFF1976D2), Color(0xFF64B5F6)],
      accentColor: Color(0xFF64B5F6),
    ),
    LevelBadgeDef(
      level: 3,
      name: 'Leitor Curioso',
      rarity: LevelBadgeRarity.common,
      archetype: LevelBadgeArchetype.compassStar,
      gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
      accentColor: Color(0xFF42A5F5),
    ),
    LevelBadgeDef(
      level: 4,
      name: 'Acompanhante',
      rarity: LevelBadgeRarity.uncommon,
      archetype: LevelBadgeArchetype.bookmarkShield,
      gradient: [Color(0xFF0277BD), Color(0xFF29B6F6)],
      accentColor: Color(0xFF29B6F6),
    ),
    LevelBadgeDef(
      level: 5,
      name: 'Seguidor Assíduo',
      rarity: LevelBadgeRarity.uncommon,
      archetype: LevelBadgeArchetype.windRose,
      gradient: [Color(0xFF00838F), Color(0xFF26C6DA)],
      accentColor: Color(0xFF26C6DA),
    ),
    LevelBadgeDef(
      level: 6,
      name: 'Entusiasta',
      rarity: LevelBadgeRarity.uncommon,
      archetype: LevelBadgeArchetype.emberSpark,
      gradient: [Color(0xFF00695C), Color(0xFF00BFA5)],
      accentColor: Color(0xFF00BFA5),
    ),
    LevelBadgeDef(
      level: 7,
      name: 'Explorador',
      rarity: LevelBadgeRarity.rare,
      archetype: LevelBadgeArchetype.feather,
      gradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
      accentColor: Color(0xFF66BB6A),
    ),
    LevelBadgeDef(
      level: 8,
      name: 'Investigador',
      rarity: LevelBadgeRarity.rare,
      archetype: LevelBadgeArchetype.brainFacets,
      gradient: [Color(0xFF558B2F), Color(0xFF9CCC65)],
      accentColor: Color(0xFF9CCC65),
    ),
    LevelBadgeDef(
      level: 9,
      name: 'Super Leitor',
      rarity: LevelBadgeRarity.rare,
      archetype: LevelBadgeArchetype.starBurst,
      gradient: [Color(0xFF9E9D24), Color(0xFFD4E157)],
      accentColor: Color(0xFFD4E157),
    ),
    LevelBadgeDef(
      level: 10,
      name: 'Fã da Informação',
      rarity: LevelBadgeRarity.special,
      archetype: LevelBadgeArchetype.trophyCrest,
      gradient: [Color(0xFFB8860B), Color(0xFFFFD700)],
      accentColor: Color(0xFFFFD700),
    ),
    LevelBadgeDef(
      level: 11,
      name: 'Membro Destaque',
      rarity: LevelBadgeRarity.special,
      archetype: LevelBadgeArchetype.laurelMedal,
      gradient: [Color(0xFFF57F17), Color(0xFFFFCA28)],
      accentColor: Color(0xFFFFCA28),
    ),
    LevelBadgeDef(
      level: 12,
      name: 'Analista Júnior',
      rarity: LevelBadgeRarity.special,
      archetype: LevelBadgeArchetype.ascendArrow,
      gradient: [Color(0xFFE65100), Color(0xFFFFA726)],
      accentColor: Color(0xFFFFA726),
    ),
    LevelBadgeDef(
      level: 13,
      name: 'Analista',
      rarity: LevelBadgeRarity.epic,
      archetype: LevelBadgeArchetype.scrollSeal,
      gradient: [Color(0xFFD84315), Color(0xFFFF8A65)],
      accentColor: Color(0xFFFF8A65),
    ),
    LevelBadgeDef(
      level: 14,
      name: 'Correspondente',
      rarity: LevelBadgeRarity.epic,
      archetype: LevelBadgeArchetype.signalWaves,
      gradient: [Color(0xFFBF360C), Color(0xFFFF7043)],
      accentColor: Color(0xFFFF7043),
    ),
    LevelBadgeDef(
      level: 15,
      name: 'Cronista',
      rarity: LevelBadgeRarity.epic,
      archetype: LevelBadgeArchetype.quillInk,
      gradient: [Color(0xFF880E4F), Color(0xFFEC407A)],
      accentColor: Color(0xFFEC407A),
    ),
    LevelBadgeDef(
      level: 16,
      name: 'Editor Amador',
      rarity: LevelBadgeRarity.heroic,
      archetype: LevelBadgeArchetype.megaphoneRing,
      gradient: [Color(0xFFAD1457), Color(0xFFF06292)],
      accentColor: Color(0xFFF06292),
    ),
    LevelBadgeDef(
      level: 17,
      name: 'Guardião das Notícias',
      rarity: LevelBadgeRarity.heroic,
      archetype: LevelBadgeArchetype.shieldEmblem,
      gradient: [Color(0xFF6A1B9A), Color(0xFFBA68C8)],
      accentColor: Color(0xFFBA68C8),
    ),
    LevelBadgeDef(
      level: 18,
      name: 'Vanguarda',
      rarity: LevelBadgeRarity.heroic,
      archetype: LevelBadgeArchetype.hourglassOrbit,
      gradient: [Color(0xFF512DA8), Color(0xFF9575CD)],
      accentColor: Color(0xFF9575CD),
    ),
    LevelBadgeDef(
      level: 19,
      name: 'Mestre da Informação',
      rarity: LevelBadgeRarity.legendary,
      archetype: LevelBadgeArchetype.infinityLoop,
      gradient: [Color(0xFF4527A0), Color(0xFF7E57C2)],
      accentColor: Color(0xFF7E57C2),
    ),
    LevelBadgeDef(
      level: 20,
      name: 'Sentinela',
      rarity: LevelBadgeRarity.legendary,
      archetype: LevelBadgeArchetype.sentinelEye,
      gradient: [Color(0xFF283593), Color(0xFF5C6BC0)],
      accentColor: Color(0xFF5C6BC0),
    ),
    LevelBadgeDef(
      level: 21,
      name: 'Visionário',
      rarity: LevelBadgeRarity.legendary,
      archetype: LevelBadgeArchetype.wandSparkle,
      gradient: [Color(0xFF006064), Color(0xFF00E5FF)],
      accentColor: Color(0xFF00E5FF),
    ),
    LevelBadgeDef(
      level: 22,
      name: 'Oráculo',
      rarity: LevelBadgeRarity.mythic,
      archetype: LevelBadgeArchetype.gemCut,
      gradient: [Color(0xFF6A1B9A), Color(0xFFE040FB)],
      accentColor: Color(0xFFE040FB),
    ),
    LevelBadgeDef(
      level: 23,
      name: 'Fenômeno',
      rarity: LevelBadgeRarity.mythic,
      archetype: LevelBadgeArchetype.meteorTrail,
      gradient: [Color(0xFF4A148C), Color(0xFFD500F9)],
      accentColor: Color(0xFFD500F9),
    ),
    LevelBadgeDef(
      level: 24,
      name: 'Lendário Absoluto',
      rarity: LevelBadgeRarity.mythic,
      archetype: LevelBadgeArchetype.royalCrownSmall,
      gradient: [Color(0xFF311B92), Color(0xFF7C4DFF)],
      accentColor: Color(0xFF7C4DFF),
    ),
    LevelBadgeDef(
      level: 25,
      name: 'Mítico',
      rarity: LevelBadgeRarity.supreme,
      archetype: LevelBadgeArchetype.crackedCore,
      gradient: [Color(0xFFB71C1C), Color(0xFFFF1744)],
      accentColor: Color(0xFFFF1744),
    ),
    LevelBadgeDef(
      level: 26,
      name: 'Ícone do Horizonte',
      rarity: LevelBadgeRarity.supreme,
      archetype: LevelBadgeArchetype.phoenixFlame,
      gradient: [Color(0xFFBF360C), Color(0xFFFF3D00)],
      accentColor: Color(0xFFFF3D00),
    ),
    LevelBadgeDef(
      level: 27,
      name: 'Chama Suprema',
      rarity: LevelBadgeRarity.supreme,
      archetype: LevelBadgeArchetype.flameCrown,
      gradient: [Color(0xFFE65100), Color(0xFFFF6D00)],
      accentColor: Color(0xFFFF6D00),
    ),
    LevelBadgeDef(
      level: 28,
      name: 'Elite Flamejante',
      rarity: LevelBadgeRarity.elite,
      archetype: LevelBadgeArchetype.radiantSun,
      gradient: [Color(0xFFE65100), Color(0xFFFFC400)],
      accentColor: Color(0xFFFFC400),
    ),
    LevelBadgeDef(
      level: 29,
      name: 'Elite Radiante',
      rarity: LevelBadgeRarity.elite,
      archetype: LevelBadgeArchetype.boltCore,
      gradient: [Color(0xFFFF6D00), Color(0xFFFFD54F)],
      accentColor: Color(0xFFFFD54F),
    ),
    LevelBadgeDef(
      level: 30,
      name: 'Horizonte Supremo',
      rarity: LevelBadgeRarity.elite,
      archetype: LevelBadgeArchetype.supremeCrown,
      gradient: [Color(0xFFFF3D00), Color(0xFFFFF176)],
      accentColor: Color(0xFFFFF176),
    ),
  ];

  static LevelBadgeDef defFor(int level) {
    final idx = level.clamp(1, all.length) - 1;
    return all[idx];
  }
}