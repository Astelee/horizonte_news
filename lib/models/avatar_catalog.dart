// lib/models/avatar_catalog.dart
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// CATEGORIAS
// ═══════════════════════════════════════════════════════════════════
enum AvatarCategory {
  homem,
  mulher,
}

extension AvatarCategoryExt on AvatarCategory {
  String get label {
    switch (this) {
      case AvatarCategory.homem:  return 'Homem';
      case AvatarCategory.mulher: return 'Mulher';
    }
  }

  IconData get tabIcon {
    switch (this) {
      case AvatarCategory.homem:  return Icons.man_rounded;
      case AvatarCategory.mulher: return Icons.woman_rounded;
    }
  }
}

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
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE UM AVATAR
// ═══════════════════════════════════════════════════════════════════
class AvatarData {
  final String id;
  final AvatarCategory category;
  final AvatarRarity rarity;
  final int requiredLevel; // nível mínimo para desbloquear (0 = liberado)

  const AvatarData({
    required this.id,
    required this.category,
    required this.rarity,
    this.requiredLevel = 0,
  });

  bool isUnlockedFor(int userLevel) => userLevel >= requiredLevel;

  /// URL da ilustração gerada dinamicamente via DiceBear.
  /// Cada avatarId funciona como "seed": sempre gera a mesma ilustração
  /// para o mesmo id, sem precisar de nenhum arquivo local.
  /// Estilo "personas" = pessoa ilustrada estilo flat/mascote,
  /// nunca emoji, ícone ou caractere unicode.
  String get networkUrl =>
      'https://api.dicebear.com/9.x/personas/png?seed=$id&backgroundColor=transparent&size=256';
}

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO — 2 categorias (Homem/Mulher), 8 avatares cada = 16 no total
// Fácil de estender: só adicionar itens em _raw, sem tocar no resto do app
// ═══════════════════════════════════════════════════════════════════
class AvatarCatalog {
  AvatarCatalog._();

  static const String defaultAvatarId = 'homem_01';

  // raridade, nível mínimo — nessa ordem, por categoria (8 itens cada)
  // Distribuição: 4 Comum, 2 Raro, 1 Épico, 1 Lendário
  static const Map<AvatarCategory, List<List<Object>>> _raw = {
    AvatarCategory.homem: [
      [AvatarRarity.comum, 0],
      [AvatarRarity.comum, 0],
      [AvatarRarity.comum, 0],
      [AvatarRarity.comum, 0],
      [AvatarRarity.raro, 5],
      [AvatarRarity.raro, 5],
      [AvatarRarity.epico, 10],
      [AvatarRarity.lendario, 20],
    ],
    AvatarCategory.mulher: [
      [AvatarRarity.comum, 0],
      [AvatarRarity.comum, 0],
      [AvatarRarity.comum, 0],
      [AvatarRarity.comum, 0],
      [AvatarRarity.raro, 5],
      [AvatarRarity.raro, 5],
      [AvatarRarity.epico, 10],
      [AvatarRarity.lendario, 20],
    ],
  };

  static final List<AvatarData> all = _build();

  static List<AvatarData> _build() {
    final list = <AvatarData>[];
    _raw.forEach((category, items) {
      for (int i = 0; i < items.length; i++) {
        final rarity = items[i][0] as AvatarRarity;
        final level = items[i][1] as int;
        list.add(AvatarData(
          id: '${category.name}_${(i + 1).toString().padLeft(2, '0')}',
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
