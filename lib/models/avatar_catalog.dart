// lib/models/avatar_catalog.dart
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// CATEGORIAS
// ═══════════════════════════════════════════════════════════════════
enum AvatarCategory {
  animais,
  robos,
  personagens,
  esportes,
  tecnologia,
  natureza,
  espaco,
  fantasia,
}

extension AvatarCategoryExt on AvatarCategory {
  String get label {
    switch (this) {
      case AvatarCategory.animais:     return 'Animais';
      case AvatarCategory.robos:       return 'Robôs';
      case AvatarCategory.personagens: return 'Personagens';
      case AvatarCategory.esportes:    return 'Esportes';
      case AvatarCategory.tecnologia:  return 'Tecnologia';
      case AvatarCategory.natureza:    return 'Natureza';
      case AvatarCategory.espaco:      return 'Espaço';
      case AvatarCategory.fantasia:    return 'Fantasia';
    }
  }

  IconData get tabIcon {
    switch (this) {
      case AvatarCategory.animais:     return Icons.pets_rounded;
      case AvatarCategory.robos:       return Icons.smart_toy_rounded;
      case AvatarCategory.personagens: return Icons.theater_comedy_rounded;
      case AvatarCategory.esportes:    return Icons.sports_basketball_rounded;
      case AvatarCategory.tecnologia:  return Icons.memory_rounded;
      case AvatarCategory.natureza:    return Icons.eco_rounded;
      case AvatarCategory.espaco:      return Icons.rocket_launch_rounded;
      case AvatarCategory.fantasia:    return Icons.auto_awesome_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// RARIDADE — já estruturado para desbloqueios futuros
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
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE UM AVATAR
// ═══════════════════════════════════════════════════════════════════
class AvatarData {
  final String id;
  final String emoji;
  final AvatarCategory category;
  final AvatarRarity rarity;
  final int requiredLevel; // nível mínimo para desbloquear (0 = liberado)

  const AvatarData({
    required this.id,
    required this.emoji,
    required this.category,
    required this.rarity,
    this.requiredLevel = 0,
  });

  bool isUnlockedFor(int userLevel) => userLevel >= requiredLevel;
}

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO — 104 avatares, 13 por categoria
// Fácil de estender: só adicionar itens em _raw, sem tocar no resto do app
// ═══════════════════════════════════════════════════════════════════
class AvatarCatalog {
  AvatarCatalog._();

  static const String defaultAvatarId = 'animais_01';

  // emoji, raridade, nível mínimo — nessa ordem, por categoria
  static const Map<AvatarCategory, List<List<Object>>> _raw = {
    AvatarCategory.animais: [
      ['🦁', AvatarRarity.comum, 0],
      ['🐯', AvatarRarity.comum, 0],
      ['🐺', AvatarRarity.comum, 0],
      ['🦊', AvatarRarity.comum, 0],
      ['🐻', AvatarRarity.comum, 0],
      ['🐼', AvatarRarity.comum, 0],
      ['🐨', AvatarRarity.comum, 0],
      ['🐸', AvatarRarity.comum, 0],
      ['🐵', AvatarRarity.raro, 5],
      ['🐶', AvatarRarity.raro, 5],
      ['🐱', AvatarRarity.raro, 5],
      ['🦉', AvatarRarity.epico, 10],
      ['🦄', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.robos: [
      ['🤖', AvatarRarity.comum, 0],
      ['⚙️', AvatarRarity.comum, 0],
      ['🔧', AvatarRarity.comum, 0],
      ['💾', AvatarRarity.comum, 0],
      ['🖥️', AvatarRarity.comum, 0],
      ['🔋', AvatarRarity.comum, 0],
      ['📡', AvatarRarity.comum, 0],
      ['🧲', AvatarRarity.comum, 0],
      ['👾', AvatarRarity.raro, 5],
      ['🛰️', AvatarRarity.raro, 5],
      ['🦾', AvatarRarity.epico, 10],
      ['🦿', AvatarRarity.epico, 10],
      ['🧠', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.personagens: [
      ['🤠', AvatarRarity.comum, 0],
      ['🕵️', AvatarRarity.comum, 0],
      ['👻', AvatarRarity.comum, 0],
      ['🎭', AvatarRarity.comum, 0],
      ['🧑‍🚀', AvatarRarity.comum, 0],
      ['🥷', AvatarRarity.comum, 0],
      ['🧛', AvatarRarity.comum, 0],
      ['🧟', AvatarRarity.comum, 0],
      ['🧝', AvatarRarity.raro, 5],
      ['🧞', AvatarRarity.raro, 5],
      ['🦸', AvatarRarity.epico, 10],
      ['🦹', AvatarRarity.epico, 10],
      ['🧙', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.esportes: [
      ['⚽', AvatarRarity.comum, 0],
      ['🏀', AvatarRarity.comum, 0],
      ['🏈', AvatarRarity.comum, 0],
      ['⚾', AvatarRarity.comum, 0],
      ['🎾', AvatarRarity.comum, 0],
      ['🏐', AvatarRarity.comum, 0],
      ['🥋', AvatarRarity.comum, 0],
      ['⛹️', AvatarRarity.comum, 0],
      ['🚴', AvatarRarity.raro, 5],
      ['🏄', AvatarRarity.raro, 5],
      ['🏂', AvatarRarity.epico, 10],
      ['🥊', AvatarRarity.epico, 10],
      ['🏆', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.tecnologia: [
      ['💻', AvatarRarity.comum, 0],
      ['📱', AvatarRarity.comum, 0],
      ['⌨️', AvatarRarity.comum, 0],
      ['🖱️', AvatarRarity.comum, 0],
      ['🖨️', AvatarRarity.comum, 0],
      ['🔌', AvatarRarity.comum, 0],
      ['📊', AvatarRarity.comum, 0],
      ['🎮', AvatarRarity.comum, 0],
      ['🕹️', AvatarRarity.raro, 5],
      ['🔬', AvatarRarity.raro, 5],
      ['🧬', AvatarRarity.epico, 10],
      ['📡', AvatarRarity.epico, 10],
      ['💡', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.natureza: [
      ['🌵', AvatarRarity.comum, 0],
      ['🌲', AvatarRarity.comum, 0],
      ['🍁', AvatarRarity.comum, 0],
      ['🌸', AvatarRarity.comum, 0],
      ['🍄', AvatarRarity.comum, 0],
      ['☀️', AvatarRarity.comum, 0],
      ['🌙', AvatarRarity.comum, 0],
      ['❄️', AvatarRarity.comum, 0],
      ['🌊', AvatarRarity.raro, 5],
      ['🌈', AvatarRarity.raro, 5],
      ['⚡', AvatarRarity.epico, 10],
      ['🌋', AvatarRarity.epico, 10],
      ['🔥', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.espaco: [
      ['⭐', AvatarRarity.comum, 0],
      ['🌍', AvatarRarity.comum, 0],
      ['🌑', AvatarRarity.comum, 0],
      ['☄️', AvatarRarity.comum, 0],
      ['🌠', AvatarRarity.comum, 0],
      ['🔭', AvatarRarity.comum, 0],
      ['🛰️', AvatarRarity.comum, 0],
      ['🌟', AvatarRarity.comum, 0],
      ['🪐', AvatarRarity.raro, 5],
      ['🚀', AvatarRarity.raro, 5],
      ['🌌', AvatarRarity.epico, 10],
      ['🛸', AvatarRarity.epico, 10],
      ['👽', AvatarRarity.lendario, 20],
    ],
    AvatarCategory.fantasia: [
      ['⚔️', AvatarRarity.comum, 0],
      ['🛡️', AvatarRarity.comum, 0],
      ['🗡️', AvatarRarity.comum, 0],
      ['🏰', AvatarRarity.comum, 0],
      ['🧿', AvatarRarity.comum, 0],
      ['🦂', AvatarRarity.comum, 0],
      ['💎', AvatarRarity.comum, 0],
      ['🪄', AvatarRarity.comum, 0],
      ['🔮', AvatarRarity.raro, 5],
      ['🧚', AvatarRarity.raro, 5],
      ['👑', AvatarRarity.epico, 10],
      ['🐲', AvatarRarity.epico, 10],
      ['🐉', AvatarRarity.lendario, 20],
    ],
  };

  static final List<AvatarData> all = _build();

  static List<AvatarData> _build() {
    final list = <AvatarData>[];
    _raw.forEach((category, items) {
      for (int i = 0; i < items.length; i++) {
        final emoji = items[i][0] as String;
        final rarity = items[i][1] as AvatarRarity;
        final level = items[i][2] as int;
        list.add(AvatarData(
          id: '${category.name}_${(i + 1).toString().padLeft(2, '0')}',
          emoji: emoji,
          category: category,
          rarity: rarity,
          requiredLevel: level,
        ));
      }
    });
    return list;
  }

  static List<AvatarData> byCategory(AvatarCategory category) =>
      all.where((a) => a.category == category).toList();

  static AvatarData byId(String? id) {
    if (id == null) return all.first;
    return all.firstWhere(
      (a) => a.id == id,
      orElse: () => all.first,
    );
  }

  static bool exists(String id) => all.any((a) => a.id == id);
}
