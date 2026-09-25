import 'package:flutter/material.dart';

import 'premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO DE AVATARES ANIMADOS PREMIUM
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para os avatares animados exclusivos de
// assinantes. Cada entrada aqui vira automaticamente:
//   • um item na galeria (PremiumAvatarGalleryScreen)
//   • uma opção equipável no perfil
//   • um avatar renderizado dentro do AvatarFrame já existente
//
// Cada avatar tem um [minTier]: PRO libera os 6 avatares originais;
// ULTRA libera esses 6 + os 10 avatares exclusivos abaixo. A galeria
// já lê esse campo e bloqueia/mostra o selo certo automaticamente.
//
// Para adicionar o próximo avatar: crie o CustomPainter em
// lib/widgets/premium_avatars.dart, gere um novo PremiumAvatarId e
// registre a entrada na lista abaixo. Nada mais precisa mudar — a
// galeria, a persistência e a exibição já leem daqui.
// ═══════════════════════════════════════════════════════════════════

enum PremiumAvatarId {
  // ── Coleção PRO (original) ──
  novaAurora,
  fenixEletrica,
  loboEspectral,
  cristalQuantico,
  aguiaSolar,
  serpenteAurora,
  // ── Coleção ULTRA (exclusiva) ──
  fenixCelestial,
  dragaoOnix,
  coroaImperial,
  tigreNeon,
  rainhaGelo,
  panteraMistica,
  fenixOuroRosa,
  golemMagma,
  deusaEstelar,
  leaoDouradoReal,
  orquideaLunar,
  borboletaCristal,
  florCerejeira,
  coracaoAurora,
  penaCisne,
  jardimZafira,
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
      case PremiumAvatarId.fenixCelestial:
        return 'premium_fenix_celestial';
      case PremiumAvatarId.dragaoOnix:
        return 'premium_dragao_onix';
      case PremiumAvatarId.coroaImperial:
        return 'premium_coroa_imperial';
      case PremiumAvatarId.tigreNeon:
        return 'premium_tigre_neon';
      case PremiumAvatarId.rainhaGelo:
        return 'premium_rainha_gelo';
      case PremiumAvatarId.panteraMistica:
        return 'premium_pantera_mistica';
      case PremiumAvatarId.fenixOuroRosa:
        return 'premium_fenix_ouro_rosa';
      case PremiumAvatarId.golemMagma:
        return 'premium_golem_magma';
      case PremiumAvatarId.deusaEstelar:
        return 'premium_deusa_estelar';
      case PremiumAvatarId.leaoDouradoReal:
        return 'premium_leao_dourado_real';
      case PremiumAvatarId.orquideaLunar:
        return 'premium_orquidea_lunar';
      case PremiumAvatarId.borboletaCristal:
        return 'premium_borboleta_cristal';
      case PremiumAvatarId.florCerejeira:
        return 'premium_flor_cerejeira';
      case PremiumAvatarId.coracaoAurora:
        return 'premium_coracao_aurora';
      case PremiumAvatarId.penaCisne:
        return 'premium_pena_cisne';
      case PremiumAvatarId.jardimZafira:
        return 'premium_jardim_zafira';
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

  /// Tier mínimo necessário para EQUIPAR este avatar.
  /// PremiumTier.pro cobre a coleção original (PRO e ULTRA equipam).
  /// PremiumTier.ultra cobre a coleção exclusiva (só ULTRA equipa).
  final PremiumTier minTier;

  const PremiumAvatarDef({
    required this.id,
    required this.name,
    required this.description,
    required this.gradient,
    required this.accentColor,
    this.minTier = PremiumTier.pro,
  });

  bool get isUltraExclusive => minTier == PremiumTier.ultra;
}

class PremiumAvatarsConfig {
  PremiumAvatarsConfig._();

  // ── Lista ordenada exibida na galeria (ordem = ordem de exibição) ──
  static const List<PremiumAvatarDef> all = [
    // ═══════════════ COLEÇÃO PRO ═══════════════
    PremiumAvatarDef(
      id: PremiumAvatarId.novaAurora,
      name: 'Nova Aurora',
      description: 'Núcleo pulsante envolto em anéis de plasma laranja.',
      gradient: [Color(0xFFFF6B00), Color(0xFFFFD54F)],
      accentColor: Color(0xFFFF8C3A),
      minTier: PremiumTier.pro,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.fenixEletrica,
      name: 'Fênix Elétrica',
      description: 'Asas de energia que se recompõem em looping contínuo.',
      gradient: [Color(0xFFFF3D00), Color(0xFFFFC400)],
      accentColor: Color(0xFFFF5722),
      minTier: PremiumTier.pro,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.loboEspectral,
      name: 'Lobo Espectral',
      description: 'Silhueta fantasmagórica com névoa fria em movimento.',
      gradient: [Color(0xFF37474F), Color(0xFF90A4AE)],
      accentColor: Color(0xFFB0BEC5),
      minTier: PremiumTier.pro,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.cristalQuantico,
      name: 'Cristal Quântico',
      description: 'Poliedro facetado girando com refrações de luz.',
      gradient: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
      accentColor: Color(0xFF40C4FF),
      minTier: PremiumTier.pro,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.aguiaSolar,
      name: 'Águia Solar',
      description: 'Silhueta em voo com um sol pulsante ao fundo.',
      gradient: [Color(0xFFFFC400), Color(0xFFFF6D00)],
      accentColor: Color(0xFFFFD740),
      minTier: PremiumTier.pro,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.serpenteAurora,
      name: 'Serpente Aurora',
      description: 'Fita luminosa serpenteante em espiral hipnótica.',
      gradient: [Color(0xFF00BFA5), Color(0xFF7C4DFF)],
      accentColor: Color(0xFF64FFDA),
      minTier: PremiumTier.pro,
    ),

    // ═══════════════ COLEÇÃO ULTRA (exclusiva) ═══════════════
    PremiumAvatarDef(
      id: PremiumAvatarId.fenixCelestial,
      name: 'Fênix Celestial',
      description: 'Penas de luz branca e dourada erguendo-se aos céus.',
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFD700)],
      accentColor: Color(0xFFFFE082),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.dragaoOnix,
      name: 'Dragão Ônix',
      description: 'Escamas negras entalhadas com fumaça violeta pulsante.',
      gradient: [Color(0xFF1A0033), Color(0xFF9C27B0)],
      accentColor: Color(0xFFD500F9),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.coroaImperial,
      name: 'Coroa Imperial',
      description: 'Joia real suspensa girando sobre um trono de luz.',
      gradient: [Color(0xFF4A148C), Color(0xFFFFD700)],
      accentColor: Color(0xFFFFC107),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.tigreNeon,
      name: 'Tigre Neon',
      description: 'Listras cibernéticas rosa e ciano em pulso urbano.',
      gradient: [Color(0xFFFF1744), Color(0xFF00E5FF)],
      accentColor: Color(0xFFFF4081),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.rainhaGelo,
      name: 'Rainha do Gelo',
      description: 'Cristais de gelo em rotação sobre uma coroa congelada.',
      gradient: [Color(0xFFE1F5FE), Color(0xFF01579B)],
      accentColor: Color(0xFF80DEEA),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.panteraMistica,
      name: 'Pantera Mística',
      description: 'Silhueta ágil com olhos violeta e névoa arcana.',
      gradient: [Color(0xFF120024), Color(0xFF7C4DFF)],
      accentColor: Color(0xFFB388FF),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.fenixOuroRosa,
      name: 'Fênix Ouro Rosa',
      description: 'Plumagem metálica rosé que brilha a cada batida de asa.',
      gradient: [Color(0xFFF8BBD0), Color(0xFFEEA6A0)],
      accentColor: Color(0xFFFFCDD2),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.golemMagma,
      name: 'Golem de Magma',
      description: 'Rocha vulcânica com rachaduras incandescentes pulsando.',
      gradient: [Color(0xFF1A0000), Color(0xFFFF3D00)],
      accentColor: Color(0xFFFF6E40),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.deusaEstelar,
      name: 'Deusa Estelar',
      description: 'Constelação viva girando em véu de poeira cósmica.',
      gradient: [Color(0xFF1A237E), Color(0xFFE0E0FF)],
      accentColor: Color(0xFF9FA8FF),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.leaoDouradoReal,
      name: 'Leão Dourado Real',
      description: 'Juba solar flamejante ao redor de um olhar imponente.',
      gradient: [Color(0xFFFFB300), Color(0xFF8D4E00)],
      accentColor: Color(0xFFFFD54F),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.orquideaLunar,
      name: 'Orquídea Lunar',
      description: 'Pétalas lilás desabrochando sob um brilho prateado.',
      gradient: [Color(0xFFCE93D8), Color(0xFF4A148C)],
      accentColor: Color(0xFFE1BEE7),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.borboletaCristal,
      name: 'Borboleta de Cristal',
      description: 'Asas translúcidas com veios de luz batendo suavemente.',
      gradient: [Color(0xFF80DEEA), Color(0xFFF48FB1)],
      accentColor: Color(0xFFB2EBF2),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.florCerejeira,
      name: 'Flor de Cerejeira',
      description: 'Pétalas rosadas flutuando em espiral ao vento.',
      gradient: [Color(0xFFFFCDD2), Color(0xFFF06292)],
      accentColor: Color(0xFFFFF0F3),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.coracaoAurora,
      name: 'Coração Aurora',
      description: 'Núcleo em forma de coração pulsando em tons pastel.',
      gradient: [Color(0xFFF8BBD0), Color(0xFFCE93D8)],
      accentColor: Color(0xFFFFCDE0),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.penaCisne,
      name: 'Pena de Cisne',
      description: 'Plumagem branca e leve flutuando sobre névoa suave.',
      gradient: [Color(0xFFFFFFFF), Color(0xFFB3E5FC)],
      accentColor: Color(0xFFE1F5FE),
      minTier: PremiumTier.ultra,
    ),
    PremiumAvatarDef(
      id: PremiumAvatarId.jardimZafira,
      name: 'Jardim Zafira',
      description: 'Flores azuis brilhantes desabrochando em ciclo contínuo.',
      gradient: [Color(0xFF64B5F6), Color(0xFF1A237E)],
      accentColor: Color(0xFF90CAF9),
      minTier: PremiumTier.ultra,
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