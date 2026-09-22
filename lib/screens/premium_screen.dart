import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/premium_config.dart';
import '../services/purchase_service.dart';
import 'premium_avatar_gallery_screen.dart';

// ── URLs oficiais (mesmas usadas no cadastro) ────────────────────────
const String _kTermsUrl = 'https://astelee.github.io/horizonte_termos/';
const String _kPrivacyUrl = 'https://astelee.github.io/horizonte-news-privacy/';

// ═══════════════════════════════════════════════════════════════════
// TELA PREMIUM — planos PRO e ULTRA
// ═══════════════════════════════════════════════════════════════════
// A vitrine (preço) vem do que foi cadastrado no Google Play Console
// — PremiumProductIds.pro/ultra em purchase_service.dart — e não mais
// de texto fixo aqui. Ícones, cores e lista de benefícios continuam
// definidos no app, já que a Play Store não guarda esse tipo de
// informação visual.
//
// Enquanto os produtos não existirem no Play Console (ou o app não
// estiver rodando num dispositivo com Play Store), os cards mostram
// os preços de referência abaixo e o botão "Assinar" informa que o
// plano ainda não está disponível — sem travar a tela.
// ═══════════════════════════════════════════════════════════════════

class PremiumPlan {
  final String productId;
  final String name;
  final String subtitle;
  final String fallbackPrice;
  final String xpTag;
  final Color accentColor;
  final List<Color> gradient;
  final IconData icon;
  final List<PremiumFeature> features;

  const PremiumPlan({
    required this.productId,
    required this.name,
    required this.subtitle,
    required this.fallbackPrice,
    required this.xpTag,
    required this.accentColor,
    required this.gradient,
    required this.icon,
    required this.features,
  });
}

class PremiumFeature {
  final IconData icon;
  final String label;
  final String? tag;

  const PremiumFeature({required this.icon, required this.label, this.tag});
}

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const List<PremiumPlan> _plans = [
    PremiumPlan(
      productId: PremiumProductIds.pro,
      name: 'PRO',
      subtitle: 'Distintivo Pro',
      fallbackPrice: 'R\$ 14,99 / mês',
      xpTag: '2x XP',
      accentColor: Color(0xFF4C8DFF),
      gradient: [Color(0xFF4C8DFF), Color(0xFF2E5FE8)],
      icon: FontAwesomeIcons.bolt,
      features: [
        PremiumFeature(
          icon: FontAwesomeIcons.circleCheck,
          label: 'Check-in sem anúncio',
          tag: 'Recupera na hora',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.eye,
          label: 'Sem banner de anúncios',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.bolt,
          label: 'Distintivo Pro',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.chartLine,
          label: 'Ganho de 2x XP',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.wandMagicSparkles,
          label: '6 avatares animados exclusivos',
          tag: 'Novo',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.gem,
          label: 'Distintivo exclusivo de assinante',
        ),
      ],
    ),
    PremiumPlan(
      productId: PremiumProductIds.ultra,
      name: 'ULTRA',
      subtitle: 'Distintivo Ultra',
      fallbackPrice: 'R\$ 39,99 / mês',
      xpTag: '8x XP',
      accentColor: Color(0xFFF2B705),
      gradient: [Color(0xFFF2B705), Color(0xFFE08E00)],
      icon: FontAwesomeIcons.crown,
      features: [
        PremiumFeature(
          icon: FontAwesomeIcons.circleCheck,
          label: 'Check-in sem anúncio',
          tag: 'Recupera na hora',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.eye,
          label: 'Sem banner de anúncios',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.crown,
          label: 'Distintivo Ultra',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.chartLine,
          label: 'Ganho de 8x XP',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.wandMagicSparkles,
          label: '6 avatares animados exclusivos',
          tag: 'Novo',
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.gem,
          label: 'Distintivo exclusivo de assinante',
        ),
      ],
    ),
  ];

  final _purchaseService = PurchaseService.instance;

  Map<String, ProductDetails> _productsById = {};
  bool _loadingProducts = true;
  // Guarda o productId em compra no momento (não um bool genérico),
  // para que só o card daquele plano específico entre em loading —
  // clicar em ULTRA não pode travar o botão do PRO junto.
  String? _purchaseInFlightProductId;
  StreamSubscription<PurchaseResult>? _purchaseSub;

  // Tier Premium que o usuário JÁ possui (lido de users_xp/{uid}).
  // Usado para desabilitar/renomear o botão "Assinar" do plano que
  // ele já tem — evita reenviar a compra pro Google Play e receber
  // o erro itemAlreadyOwned.
  PremiumTier _currentTier = PremiumTier.none;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tierSub;

  @override
  void initState() {
    super.initState();
    _purchaseService.initialize();
    _loadProducts();
    _purchaseSub = _purchaseService.purchaseResults.listen(_onPurchaseResult);
    _listenCurrentTier();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _tierSub?.cancel();
    super.dispose();
  }

  void _listenCurrentTier() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _tierSub = FirebaseFirestore.instance
        .collection('users_xp')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      setState(() {
        _currentTier =
            data != null ? premiumTierFromData(data) : PremiumTier.none;
      });
    });
  }

  Future<void> _loadProducts() async {
    final products = await _purchaseService.loadProducts();
    if (!mounted) return;
    setState(() {
      _productsById = {for (final p in products) p.id: p};
      _loadingProducts = false;
    });
  }

  void _onPurchaseResult(PurchaseResult result) {
    if (!mounted) return;
    setState(() => _purchaseInFlightProductId = null);

    switch (result.status) {
      case PurchaseResultStatus.pendingApproval:
        _showPendingApprovalDialog(context);
        break;
      case PurchaseResultStatus.pending:
        _showSnack(context, 'Pagamento em processamento...');
        break;
      case PurchaseResultStatus.cancelled:
        // Usuário cancelou o fluxo de pagamento — não precisa de aviso.
        break;
      case PurchaseResultStatus.error:
        _showSnack(
          context,
          result.message ?? 'Não foi possível concluir a compra.',
          isError: true,
        );
        break;
    }
  }

  // ── Compra confirmada pelo Google Play, aguardando aprovação ────
  // A compra em si já foi concluída — isso NÃO é revertido nem
  // burlado —, mas o Premium só é ativado depois que um admin aprovar
  // a solicitação pelo painel. Mostramos isso claramente aqui, com um
  // atalho para o canal de contato já existente no app, caso o
  // usuário queira acelerar ou tirar dúvidas.
  void _showPendingApprovalDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(FontAwesomeIcons.circleCheck,
                color: AppColors.primaryOrange, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Compra registrada',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'A compra foi registrada e está aguardando a validação '
          'do administrador.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openContactChannel(context);
            },
            child: Text(
              'Entrar em contato',
              style: TextStyle(
                color: AppColors.primaryOrangeLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Entendi',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ── Abre o canal de contato que já existe no app (tela ContactScreen,
  // rota AppRoutes.contact) — mesmo canal usado no resto do app, sem
  // criar um novo.
  void _openContactChannel(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.contact);
  }

  Future<void> _buyPlan(PremiumPlan plan) async {
    // Já é assinante deste exato plano — não reenvia pro Google Play
    // (evita o erro itemAlreadyOwned). O botão já deveria estar
    // desabilitado neste caso, isso aqui é uma segunda trava.
    if (PremiumProductIds.tierFor(plan.productId) == _currentTier) {
      return;
    }

    final product = _productsById[plan.productId];
    if (product == null) {
      _showSnack(
        context,
        'Esse plano ainda não está disponível para compra.',
        isError: true,
      );
      return;
    }
    setState(() => _purchaseInFlightProductId = plan.productId);
    await _purchaseService.buy(product);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Escolha um plano e suba de nível mais rápido.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _buildAvatarsTeaser(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final plan = _plans[index];
                  final isThisPlanBuying =
                      _purchaseInFlightProductId == plan.productId;
                  final anyPurchaseInFlight =
                      _purchaseInFlightProductId != null;
                  final isOwned =
                      PremiumProductIds.tierFor(plan.productId) ==
                          _currentTier;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PlanCard(
                      plan: plan,
                      product: _productsById[plan.productId],
                      loadingProduct: _loadingProducts,
                      isBuying: isThisPlanBuying,
                      isOwned: isOwned,
                      disabled:
                          (anyPurchaseInFlight && !isThisPlanBuying) ||
                              isOwned,
                      onSubscribe: () => _buyPlan(plan),
                    ),
                  );
                },
                childCount: _plans.length,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverToBoxAdapter(
              child: _buildFooter(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      expandedHeight: 120,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          'Premium',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryOrangeDark.withOpacity(0.35),
                AppColors.backgroundDark,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarsTeaser(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PremiumAvatarGalleryScreen(),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0A0A0A),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  FontAwesomeIcons.wandMagicSparkles,
                  color: AppColors.primaryOrange,
                  size: 15,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '6 avatares animados exclusivos',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toque para ver todos em movimento',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const _InfoBar(),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _footerLink(context, 'Termos de Uso', _kTermsUrl),
            _footerLink(context, 'Política de Privacidade', _kPrivacyUrl),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => _restorePurchases(context),
          child: Text(
            'Restaurar compras',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Toda compra fica pendente de aprovação manual do admin — este
        // botão dá acesso direto ao canal de contato já existente no
        // app (mesma ContactScreen usada no resto do app) para quem
        // quiser tirar dúvidas ou acelerar a validação.
        OutlinedButton.icon(
          onPressed: () => _openContactChannel(context),
          icon: Icon(FontAwesomeIcons.headset,
              size: 14, color: AppColors.primaryOrangeLight),
          label: Text(
            'Entrar em contato',
            style: TextStyle(
              color: AppColors.primaryOrangeLight,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppColors.primaryOrangeLight.withOpacity(0.4),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _footerLink(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => _openUrl(context, url),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryOrangeLight,
          fontSize: 13,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // ── Abre Termos / Privacidade no navegador ───────────────────────
  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _showSnack(context, 'Não foi possível abrir o link.');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Não foi possível abrir o link.');
      }
    }
  }

  // ── Restaura compras já feitas na conta Google Play do usuário ───
  // O resultado chega de forma assíncrona em _onPurchaseResult, pelo
  // mesmo purchaseStream usado para compras novas.
  Future<void> _restorePurchases(BuildContext context) async {
    final available = await _purchaseService.isAvailable;
    if (!context.mounted) return;

    if (!available) {
      _showSnack(
        context,
        'A Google Play Store não está disponível no momento.',
        isError: true,
      );
      return;
    }

    try {
      await _purchaseService.restore();
      if (!context.mounted) return;
      _showSnack(context, 'Verificando suas compras anteriores...');
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(
        context,
        'Não foi possível restaurar as compras agora.',
        isError: true,
      );
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE PLANO
// ═══════════════════════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final ProductDetails? product;
  final bool loadingProduct;
  final bool isBuying;
  final bool isOwned;
  final bool disabled;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.product,
    required this.loadingProduct,
    required this.isBuying,
    required this.isOwned,
    required this.disabled,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final priceLabel = product?.price ?? plan.fallbackPrice;
    final available = product != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.accentColor.withOpacity(0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: plan.accentColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: plan.gradient),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(plan.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      plan.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: plan.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: plan.accentColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  plan.xpTag,
                  style: TextStyle(
                    color: plan.accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (loadingProduct)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              else
                Text(
                  priceLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (!loadingProduct && !available) ...[
            const SizedBox(height: 6),
            Text(
              'Plano ainda não disponível para compra.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 14),
          ...plan.features.map((f) => _FeatureRow(
                feature: f,
                accentColor: plan.accentColor,
              )),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Opacity(
              opacity: isOwned
                  ? 1
                  : (disabled ? 0.5 : 1),
              child: DecoratedBox(
                decoration: isOwned
                    ? BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: plan.accentColor.withOpacity(0.5),
                        ),
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(colors: plan.gradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    // Plano já é do usuário → botão nunca é clicável,
                    // nem mostra loading (não há compra a iniciar).
                    onTap: (isOwned || isBuying || disabled)
                        ? null
                        : onSubscribe,
                    child: Center(
                      child: isBuying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isOwned) ...[
                                  Icon(
                                    FontAwesomeIcons.circleCheck,
                                    size: 15,
                                    color: plan.accentColor,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  isOwned ? 'Plano atual' : 'Assinar',
                                  style: TextStyle(
                                    color: isOwned
                                        ? plan.accentColor
                                        : (plan.productId ==
                                                PremiumProductIds.ultra
                                            ? Colors.black.withOpacity(0.85)
                                            : Colors.white),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final PremiumFeature feature;
  final Color accentColor;
  const _FeatureRow({required this.feature, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Icon(feature.icon, color: accentColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (feature.tag != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                feature.tag!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 10,
      children: const [
        _InfoItem(
          icon: FontAwesomeIcons.lock,
          label: 'Pagamento seguro pela Play Store',
        ),
        _InfoItem(
          icon: FontAwesomeIcons.circleCheck,
          label: 'Cancele a qualquer momento',
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}