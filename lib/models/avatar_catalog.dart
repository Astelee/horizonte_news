import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO DE AVATAR — sem raridade, todos liberados desde o início
// ═══════════════════════════════════════════════════════════════════
class AvatarData {
  final String id;

  const AvatarData({required this.id});

  /// URL via DiceBear "personas" — ilustrações flat coloridas,
  /// estilo próximo ao Google Play Games.
  String get networkUrl =>
      'https://api.dicebear.com/9.x/personas/png?seed=$id&size=256';
}

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO — 32 avatares, todos liberados, sem raridade
// ═══════════════════════════════════════════════════════════════════
class AvatarCatalog {
  AvatarCatalog._();

  static const String defaultAvatarId = 'avatar_01';

  static final List<AvatarData> all = const [
    AvatarData(id: 'avatar_01'),
    AvatarData(id: 'avatar_02'),
    AvatarData(id: 'avatar_03'),
    AvatarData(id: 'avatar_04'),
    AvatarData(id: 'avatar_05'),
    AvatarData(id: 'avatar_06'),
    AvatarData(id: 'avatar_07'),
    AvatarData(id: 'avatar_08'),
    AvatarData(id: 'avatar_09'),
    AvatarData(id: 'avatar_10'),
    AvatarData(id: 'avatar_11'),
    AvatarData(id: 'avatar_12'),
    AvatarData(id: 'avatar_13'),
    AvatarData(id: 'avatar_14'),
    AvatarData(id: 'avatar_15'),
    AvatarData(id: 'avatar_16'),
    AvatarData(id: 'avatar_17'),
    AvatarData(id: 'avatar_18'),
    AvatarData(id: 'avatar_19'),
    AvatarData(id: 'avatar_20'),
    AvatarData(id: 'avatar_21'),
    AvatarData(id: 'avatar_22'),
    AvatarData(id: 'avatar_23'),
    AvatarData(id: 'avatar_24'),
    AvatarData(id: 'avatar_25'),
    AvatarData(id: 'avatar_26'),
    AvatarData(id: 'avatar_27'),
    AvatarData(id: 'avatar_28'),
    AvatarData(id: 'avatar_29'),
    AvatarData(id: 'avatar_30'),
    AvatarData(id: 'avatar_31'),
    AvatarData(id: 'avatar_32'),
  ];

  static AvatarData byId(String? id) {
    if (id == null) return all.first;
    return all.firstWhere(
      (a) => a.id == id,
      orElse: () => all.first,
    );
  }

  static bool exists(String id) => all.any((a) => a.id == id);
}
