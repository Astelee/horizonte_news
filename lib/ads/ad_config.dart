class PartnerAd {
  final String name;
  final String assetPath;
  final bool isActive;

  const PartnerAd({
    required this.name,
    required this.assetPath,
    this.isActive = false,
  });
}

class AdConfig {
  // ── Parceiros ─────────────────────────────────────────────
  // Apenas o PRIMEIRO com isActive: true será exibido.
  // Se todos estiverem false, o AdMob é carregado.
  static const List<PartnerAd> partners = [
    PartnerAd(
      name: 'Parceiro A',
      assetPath: 'assets/ads/parceiros/parceiro_1.png',
      isActive: true,
    ),
    PartnerAd(
      name: 'Parceiro B',
      assetPath: 'assets/ads/parceiros/parceiro_2.png',
      isActive: false,
    ),
    PartnerAd(
      name: 'Parceiro C',
      assetPath: 'assets/ads/parceiros/parceiro_3.png',
      isActive: false,
    ),
  ];

  // ── AdMob IDs reais ───────────────────────────────────────
  static const String admobBannerId =
      'ca-app-pub-5015489666829491/6354307271';

  // ── Helpers ───────────────────────────────────────────────

  /// Retorna o primeiro parceiro com isActive == true, ou null.
  static PartnerAd? get activePartner {
    try {
      return partners.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  static bool get hasActivePartner => activePartner != null;
}
