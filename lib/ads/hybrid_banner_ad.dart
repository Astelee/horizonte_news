import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ad_config.dart';

// ============================================================
// HybridBannerAd
// ============================================================
// Coloque-o em qualquer Scaffold como bottomNavigationBar.
//
// O modo exibido é controlado pelo painel administrativo (aba
// "Barra de anúncios"), salvo em Firestore em
// app_config/global.adsBarMode: 'admob' | 'partner' | 'off'.
// A mudança se aplica em tempo real, sem precisar publicar uma
// nova versão do app.
//
//   'admob'   → BannerAd do AdMob
//   'partner' → imagem do parceiro configurada no painel
//               (adsPartnerName / adsPartnerImageUrl / adsPartnerLinkUrl)
//   'off'     → nada é exibido, espaço totalmente limpo
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
  bool _admobRequested = false;

  // Altura padrão do banner AdMob BANNER (320×50 → altura 50 dp)
  // Usamos 52 para dar uma margem confortável.
  static const double _bannerHeight = 52;

  final Stream<DocumentSnapshot<Map<String, dynamic>>> _configStream =
      FirebaseFirestore.instance
          .collection('app_config')
          .doc('global')
          .snapshots();

  void _ensureAdMobLoaded() {
    if (_admobRequested) return;
    _admobRequested = true;
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _configStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        // Enquanto a config ainda não carregou, não exibe nada — evita
        // "piscar" um AdMob que pode ter sido desativado pelo admin.
        if (!snapshot.hasData) return const SizedBox.shrink();

        final mode = (data?['adsBarMode'] as String?) ?? 'admob';

        if (mode == 'off') {
          return const SizedBox.shrink();
        }

        if (mode == 'partner') {
          final imageUrl = (data?['adsPartnerImageUrl'] as String?) ?? '';
          final linkUrl = (data?['adsPartnerLinkUrl'] as String?) ?? '';
          if (imageUrl.isEmpty) return const SizedBox.shrink();
          return _PartnerBanner(imageUrl: imageUrl, linkUrl: linkUrl);
        }

        // mode == 'admob' (padrão)
        _ensureAdMobLoaded();

        if (!_adLoaded && !_adFailed) {
          return const _AdPlaceholder();
        }
        if (_adFailed) {
          return const SizedBox.shrink(); // Sem espaço vazio visível
        }
        return SafeArea(
          top: false,
          child: SizedBox(
            height: _bannerHeight,
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }
}

// ── Banner do parceiro (imagem hospedada, definida no painel) ────
class _PartnerBanner extends StatelessWidget {
  final String imageUrl;
  final String linkUrl;
  const _PartnerBanner({required this.imageUrl, required this.linkUrl});

  Future<void> _handleTap() async {
    if (linkUrl.isEmpty) return;
    final uri = Uri.tryParse(linkUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: linkUrl.isEmpty ? null : _handleTap,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            // Se a imagem falhar ao carregar, exibe fallback silencioso
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
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