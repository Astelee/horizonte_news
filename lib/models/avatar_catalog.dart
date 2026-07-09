import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// RARIDADE
// ═══════════════════════════════════════════════════════════════════
enum AvatarRarity { comum, raro, epico, lendario }

extension AvatarRarityExt on AvatarRarity {
  String get label {
    switch (this) {
      case AvatarRarity.comum:    return 'Comum';
      case AvatarRarity.raro:     return 'Raro';
      case AvatarRarity.epico:    return 'Épico';
      case AvatarRarity.lendario: return 'Lendário';
    }
  }

  List<Color> get gradient {
    switch (this) {
      case AvatarRarity.comum:
        return const [Color(0xFF3A3A3A), Color(0xFF1E1E1E)];
      case AvatarRarity.raro:
        return const [Color(0xFF29B6F6), Color(0xFF0277BD)];
      case AvatarRarity.epico:
        return const [Color(0xFFAB47BC), Color(0xFF6A1B9A)];
      case AvatarRarity.lendario:
        return const [Color(0xFFFFD700), Color(0xFFFF6B00)];
    }
  }

  Color get accentColor {
    switch (this) {
      case AvatarRarity.comum:    return const Color(0xFF9E9E9E);
      case AvatarRarity.raro:     return const Color(0xFF29B6F6);
      case AvatarRarity.epico:    return const Color(0xFFAB47BC);
      case AvatarRarity.lendario: return const Color(0xFFFFD700);
    }
  }

  Color get badgeBg {
    switch (this) {
      case AvatarRarity.comum:    return const Color(0xFF2A2A2A);
      case AvatarRarity.raro:     return const Color(0xFF0D2A3A);
      case AvatarRarity.epico:    return const Color(0xFF2A0D3A);
      case AvatarRarity.lendario: return const Color(0xFF3A2800);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE AVATAR
// ═══════════════════════════════════════════════════════════════════
class AvatarData {
  final String id;
  final AvatarRarity rarity;
  final int requiredLevel;

  const AvatarData({
    required this.id,
    required this.rarity,
    this.requiredLevel = 0,
  });

  bool isUnlockedFor(int userLevel) => userLevel >= requiredLevel;

  /// URL ilustrada via DiceBear "adventurer" — personagens estilo
  /// mascote/fantasia (animais, criaturas, heróis), nunca foto ou emoji.
  /// Cada seed gera sempre o mesmo personagem.
  String get networkUrl =>
      'https://api.dicebear.com/9.x/adventurer/png?seed=$id&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf&size=256';
}

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO — 32 avatares, sem categoria de sexo
// Distribuição por raridade:
//   Comum    (nv 0):  16 avatares — liberados desde o início
//   Raro     (nv 5):   8 avatares — desbloqueiam no nível 5
//   Épico    (nv 10):  6 avatares — desbloqueiam no nível 10
//   Lendário (nv 20):  2 avatares — desbloqueiam no nível 20
// ═══════════════════════════════════════════════════════════════════
class AvatarCatalog {
  AvatarCatalog._();

  static const String defaultAvatarId = 'horizonte_fox';

  static final List<AvatarData> all = const [

    // ── COMUM (nível 0) ─────────────────────────────────────────
    AvatarData(id: 'horizonte_fox',      rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_bear',     rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_wolf',     rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_cat',      rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_rabbit',   rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_owl',      rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_panda',    rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_penguin',  rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_lion',     rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_deer',     rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_koala',    rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_frog',     rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_duck',     rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_hamster',  rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_sloth',    rarity: AvatarRarity.comum, requiredLevel: 0),
    AvatarData(id: 'horizonte_hedgehog', rarity: AvatarRarity.comum, requiredLevel: 0),

    // ── RARO (nível 5) ──────────────────────────────────────────
    AvatarData(id: 'horizonte_pirate',   rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_ninja',    rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_wizard',   rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_viking',   rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_robot',    rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_ghost',    rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_skull',    rarity: AvatarRarity.raro, requiredLevel: 5),
    AvatarData(id: 'horizonte_alien',    rarity: AvatarRarity.raro, requiredLevel: 5),

    // ── ÉPICO (nível 10) ────────────────────────────────────────
    AvatarData(id: 'horizonte_dragon',   rarity: AvatarRarity.epico, requiredLevel: 10),
    AvatarData(id: 'horizonte_unicorn',  rarity: AvatarRarity.epico, requiredLevel: 10),
    AvatarData(id: 'horizonte_phoenix',  rarity: AvatarRarity.epico, requiredLevel: 10),
    AvatarData(id: 'horizonte_werewolf', rarity: AvatarRarity.epico, requiredLevel: 10),
    AvatarData(id: 'horizonte_mermaid',  rarity: AvatarRarity.epico, requiredLevel: 10),
    AvatarData(id: 'horizonte_samurai',  rarity: AvatarRarity.epico, requiredLevel: 10),

    // ── LENDÁRIO (nível 20) ─────────────────────────────────────
    AvatarData(id: 'horizonte_titan',    rarity: AvatarRarity.lendario, requiredLevel: 20),
    AvatarData(id: 'horizonte_god',      rarity: AvatarRarity.lendario, requiredLevel: 20),
  ];

  // Filtra por raridade (usado na tela do picker por seção)
  static List<AvatarData> byRarity(AvatarRarity rarity) =>
      all.where((a) => a.rarity == rarity).toList();

  static AvatarData byId(String? id) {
    if (id == null) return all.first;
    return all.firstWhere(
      (a) => a.id == id,
      orElse: () => all.first,
    );
  }

  static bool exists(String id) => all.any((a) => a.id == id);
}
