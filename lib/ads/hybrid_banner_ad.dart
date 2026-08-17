import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

// ============================================================
// HybridBannerAd
// ============================================================
// Coloque-o em qualquer Scaffold como bottomNavigationBar.
// Decide automaticamente:
//   Parceiro ativo → imagem local (asset)
//   Sem parceiro   → BannerAd AdMob
//   AdMob falhou   → Container vazio (sem quebrar a tela)
// ============================================================

class HybridBannerAd extends StatefulWidget {
  const HybridBannerAd({super.key});

  @override
  State<HybridBannerAd> createState() => _HybridBannerAdState();
}

class _HybridBannerAdState extends State<HybridBannerAd> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  bool _adFailed = false;

  // Altura padrão do banner AdMob BANNER (320×50 → altura 50 dp)
  // Usamos 52 para dar uma margem confortável.
  static const double _bannerHeight = 52;

  @override
  void initState() {
    super.initState();
    // Só cria o AdMob se não houver parceiro ativo
    if (!AdConfig.hasActivePartner) {
      _loadAdMobBanner();
    }
  }

  void _loadAdMobBanner() {
    _bannerAd = BannerAd(
      adUnitId: AdConfig.admobBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _adFailed = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Parceiro local ativo ───────────────────────────────
    final partner = AdConfig.activePartner;
    if (partner != null) {
      return _PartnerBanner(assetPath: partner.assetPath);
    }

    // ── AdMob carregando ──────────────────────────────────
    if (!_adLoaded && !_adFailed) {
      return const _AdPlaceholder();
    }

    // ── AdMob falhou ──────────────────────────────────────
    if (_adFailed) {
      return const SizedBox.shrink(); // Sem espaço vazio visível
    }

    // ── AdMob pronto ──────────────────────────────────────
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _bannerHeight,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

// ── Banner do parceiro local ──────────────────────────────────
class _PartnerBanner extends StatelessWidget {
  final String assetPath;
  const _PartnerBanner({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          // Se a imagem não existir no asset, exibe fallback silencioso
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ── Placeholder enquanto AdMob carrega ───────────────────────
class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 52,
        width: double.infinity,
        color: const Color(0xFF0A0A0A),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFF333333)),
            ),
          ),
        ),
      ),
    );
  }
}
