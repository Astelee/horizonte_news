import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO DE AVATAR
// ═══════════════════════════════════════════════════════════════════
class AvatarData {
  final String id;
  final String seed; // nome usado na URL do Multiavatar

  const AvatarData({required this.id, required this.seed});

  /// URL via Multiavatar — SVG ilustrado colorido único por seed
String get networkUrl => 'https://api.multiavatar.com/$seed.svg';
}

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO — 32 avatares, todos liberados, sem raridade
// Cada seed diferente gera um personagem completamente diferente.
// ═══════════════════════════════════════════════════════════════════
class AvatarCatalog {
  AvatarCatalog._();

  static const String defaultAvatarId = 'avatar_01';

  static final List<AvatarData> all = const [
    AvatarData(id: 'avatar_01', seed: 'Felix'),
    AvatarData(id: 'avatar_02', seed: 'Luna'),
    AvatarData(id: 'avatar_03', seed: 'Zara'),
    AvatarData(id: 'avatar_04', seed: 'Orion'),
    AvatarData(id: 'avatar_05', seed: 'Nova'),
    AvatarData(id: 'avatar_06', seed: 'Blaze'),
    AvatarData(id: 'avatar_07', seed: 'Cleo'),
    AvatarData(id: 'avatar_08', seed: 'Titan'),
    AvatarData(id: 'avatar_09', seed: 'Mila'),
    AvatarData(id: 'avatar_10', seed: 'Dex'),
    AvatarData(id: 'avatar_11', seed: 'Aria'),
    AvatarData(id: 'avatar_12', seed: 'Rex'),
    AvatarData(id: 'avatar_13', seed: 'Ivy'),
    AvatarData(id: 'avatar_14', seed: 'Thor'),
    AvatarData(id: 'avatar_15', seed: 'Sage'),
    AvatarData(id: 'avatar_16', seed: 'Kira'),
    AvatarData(id: 'avatar_17', seed: 'Axel'),
    AvatarData(id: 'avatar_18', seed: 'Neon'),
    AvatarData(id: 'avatar_19', seed: 'Pixel'),
    AvatarData(id: 'avatar_20', seed: 'Storm'),
    AvatarData(id: 'avatar_21', seed: 'Ember'),
    AvatarData(id: 'avatar_22', seed: 'Cruz'),
    AvatarData(id: 'avatar_23', seed: 'Vega'),
    AvatarData(id: 'avatar_24', seed: 'Lyra'),
    AvatarData(id: 'avatar_25', seed: 'Onyx'),
    AvatarData(id: 'avatar_26', seed: 'Echo'),
    AvatarData(id: 'avatar_27', seed: 'Bolt'),
    AvatarData(id: 'avatar_28', seed: 'Jade'),
    AvatarData(id: 'avatar_29', seed: 'Ryuu'),
    AvatarData(id: 'avatar_30', seed: 'Koda'),
    AvatarData(id: 'avatar_31', seed: 'Zion'),
    AvatarData(id: 'avatar_32', seed: 'Mako'),
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
