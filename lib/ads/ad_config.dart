// ============================================================
// AdConfig — Configuração centralizada de anúncios
// ============================================================
// Para ativar/desativar um parceiro: mude isActive
// Para trocar o banner:              mude assetPath
// Para adicionar parceiro:           adicione um PartnerAd
// ============================================================

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
      isActive: false, // ← mude para true para ativar
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

  // ── AdMob IDs ─────────────────────────────────────────────
  // IDs de TESTE — nunca geram tráfego inválido.
  // Substitua pelos reais antes de publicar na loja.
  static const String admobBannerId =
      'ca-app-pub-3940256099942544/6300978111'; // Android teste

  // IDs REAIS (descomente e preencha antes de publicar):
  // static const String admobBannerId = 'SEU_ADMOB_BANNER_ID';

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
