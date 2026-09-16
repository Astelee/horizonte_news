import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO DE AVATARES ANIMADOS PREMIUM
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para os avatares animados exclusivos de
// assinantes. Cada entrada aqui vira automaticamente:
//   • um item na galeria (PremiumAvatarGalleryScreen)
//   • uma opção equipável no perfil
//   • um avatar renderizado dentro do AvatarFrame já existente
//
// Para adicionar o 7º, 8º avatar etc.: crie o CustomPainter em
// lib/widgets/premium_avatars.dart, gere um novo PremiumAvatarId e
// registre a entrada na lista abaixo. Nada mais precisa mudar — a
// galeria, a persistência e a exibição já leem daqui.
// ═══════════════════════════════════════════════════════════════════

enum PremiumAvatarId {
  novaAurora,
  fenixEletrica,
  loboEspectral,
  cristalQuantico,
  aguiaSolar,
  serpenteAurora,
}

extension PremiumAvatarIdX on PremiumAvatarId {
  String get storageKey {
    switch (this) {
      case PremiumAvatarId.novaAurora:
        return 'premium_nova_aurora';
      case PremiumAvatarId.fenixEletrica:
        return 'premium_fenix_eletrica';
      case PremiumAvatarId.loboEspectral:
        return 'premium_lobo_espectral';
      case PremiumAvatarId.cristalQuantico:
        return 'premium_cristal_quantico';
      case PremiumAvatarId.aguiaSolar:
        return 'premium_aguia_solar';
      case PremiumAvatarId.serpenteAurora:
        return 'premium_serpente_aurora';
    }
  }

  static PremiumAvatarId? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final id in PremiumAvatarId.values) {
      if (id.storageKey == key) return id;
    }
    return null;
  }
}

/// Descreve visualmente um avatar animado premium — usado tanto pela
/// galeria quanto pela lógica de exibição no AvatarFrame.
class PremiumAvatarDef {
  final PremiumAvatarId id;
  final String name;
  final String description;
  final List<Color> gradient;
  final Color accentColor;

  const PremiumAvatarDef({
    required this.id,
    required this.name,
    required this.description,
    required this.gradient,
    required this.accentColor,
  });
}

class PremiumAvatarsConfig {
  PremiumAvatarsConfig._();

  // ── Lista ordenada exibida na galeria (ordem = ordem de exibição) ──
  static const List<PremiumAvatarDef> all = [
    PremiumAvatarDef(
      id: PremiumAvatarId.novaAurora,
      name: 'Nova Aurora',
      description: 'Núcleo pulsante envolto em anéis de plasma laranja.',
      gradient: [Color(0xFFFF6B00), Color(0xFFFFD54F)],
      accentColor: Color(0xFFFF8C3A),
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.fenixEletrica,
      name: 'Fênix Elétrica',
      description: 'Asas de energia que se recompõem em looping contínuo.',
      gradient: [Color(0xFFFF3D00), Color(0xFFFFC400)],
      accentColor: Color(0xFFFF5722),
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.loboEspectral,
      name: 'Lobo Espectral',
      description: 'Silhueta fantasmagórica com névoa fria em movimento.',
      gradient: [Color(0xFF37474F), Color(0xFF90A4AE)],
      accentColor: Color(0xFFB0BEC5),
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.cristalQuantico,
      name: 'Cristal Quântico',
      description: 'Poliedro facetado girando com refrações de luz.',
      gradient: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
      accentColor: Color(0xFF40C4FF),
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.aguiaSolar,
      name: 'Águia Solar',
      description: 'Silhueta em voo com um sol pulsante ao fundo.',
      gradient: [Color(0xFFFFC400), Color(0xFFFF6D00)],
      accentColor: Color(0xFFFFD740),
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.serpenteAurora,
      name: 'Serpente Aurora',
      description: 'Fita luminosa serpenteante em espiral hipnótica.',
      gradient: [Color(0xFF00BFA5), Color(0xFF7C4DFF)],
      accentColor: Color(0xFF64FFDA),
    ),
  ];

  static PremiumAvatarDef defFor(PremiumAvatarId id) =>
      all.firstWhere((e) => e.id == id, orElse: () => all.first);

  static PremiumAvatarDef? defForStorageKey(String? key) {
    final id = PremiumAvatarIdX.fromStorageKey(key);
    if (id == null) return null;
    return defFor(id);
  }
}