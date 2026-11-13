import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/premium_config.dart';
import '../services/purchase_service.dart';
import '../services/subscription_state_service.dart';
import 'my_subscription_screen.dart';
import 'premium_avatar_gallery_screen.dart';
import '../widgets/app_messenger.dart';

// ── URLs oficiais (mesmas usadas no cadastro) ────────────────────────
const String _kTermsUrl = 'https://astelee.github.io/horizonte_termos/';
const String _kPrivacyUrl = 'https://astelee.github.io/horizonte-news-privacy/';

// ═══════════════════════════════════════════════════════════════════
// TELA PREMIUM — planos PRO e ULTRA
// ═══════════════════════════════════════════════════════════════════
// Preço: sempre o cadastrado no Google Play (ProductDetails.price). Os
// benefícios são os já existentes no app. PRO e ULTRA são EXCLUSIVOS:
// com uma assinatura em vigor (ativa, cancelada-mas-paga, carência ou
// pagamento em espera) os dois botões ficam bloqueados; o backend também
// recusa a segunda compra. "Restaurar compras" nunca some.
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
  // Ícone com brilho pulsante — reservado para destaques do ULTRA.
  final bool animated;

  const PremiumFeature({
    required this.icon,
    required this.label,
    this.tag,
    this.animated = false,
  });
}

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
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
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.palette,
          label: 'Nome personalizado: cor, efeitos e intensidade',
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
          label: '22 avatares animados (16 só do Ultra)',
          tag: 'Novo',
          animated: true,
        ),
        PremiumFeature(
          icon: FontAwesomeIcons.palette,
          label: 'Nome personalizado: cor, efeitos e intensidade',
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
  final _subs = SubscriptionService.instance;

  Map<String, ProductDetails> _productsById = {};
  bool _loadingProducts = true;
  // Só o card do plano em compra entra em loading.
  String? _purchaseInFlightProductId;
  bool _restoring = false;
  StreamSubscription<PurchaseResult>? _purchaseSub;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _subs.ensureStarted();
    _purchaseService.initialize();
    _loadProducts();
    _purchaseSub = _purchaseService.purchaseResults.listen(_onPurchaseResult);
    unawaited(_subs.refreshStatus());
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _pulse.dispose();
    super.dispose();
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
    if (!mounted || result.silent) return;
    setState(() => _purchaseInFlightProductId = null);

    switch (result.status) {
      case PurchaseResultStatus.activated:
        _showSnack(context, 'Premium ativado! Aproveite seus benefícios.');
        break;
      case PurchaseResultStatus.pendingApproval:
        _showPendingApprovalDialog(context);
        break;
      case PurchaseResultStatus.pending:
        _showSnack(context, 'Pagamento em processamento...');
        break;
      case PurchaseResultStatus.cancelled:
        break;
      case PurchaseResultStatus.alreadySubscribed:
      case PurchaseResultStatus.error:
        _showSnack(
          context,
          result.message ?? 'Não foi possível concluir a compra.',
          isError: true,
        );
        break;
    }
  }

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

  Future<void> _buyPlan(PremiumPlan plan, bool blocked) async {
    if (blocked) {
      _showSnack(
        context,
        'Você já tem uma assinatura em vigor. Só é possível contratar '
        'outro plano depois que ela terminar.',
      );
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

  Future<void> _manage(PremiumTier tier) async {
    final id = tier == PremiumTier.ultra
        ? PremiumProductIds.ultra
        : PremiumProductIds.pro;
    final ok = await _purchaseService.openManageSubscription(productId: id);
    if (!ok && mounted) {
      _showSnack(context, 'Não foi possível abrir a Google Play.',
          isError: true);
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final outcome = await _purchaseService.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    switch (outcome) {
      case RestoreOutcome.restored:
        _showSnack(context, 'Compras verificadas e sincronizadas.');
        break;
      case RestoreOutcome.nothingFound:
        _showSnack(
            context, 'Nenhuma assinatura encontrada nesta conta Google Play.');
        break;
      case RestoreOutcome.unavailable:
        _showSnack(context, 'A Google Play Store não está disponível agora.',
            isError: true);
        break;
      case RestoreOutcome.failed:
        _showSnack(context, 'Não foi possível restaurar as compras agora.',
            isError: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: ValueListenableBuilder<SubscriptionSnapshot>(
        valueListenable: _subs.snapshot,
        builder: (context, snap, _) => ValueListenableBuilder<BillingStatus?>(
          valueListenable: _subs.status,
          builder: (context, status, _) => _buildBody(context, snap, status),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, SubscriptionSnapshot snap, BillingStatus? status) {
    // Fonte da verdade = backend; sem ele, usa o estado do Firestore.
    var blocked = false;
    var holder = PremiumTier.none;
    if (status != null) {
      blocked = status.blocksPurchase;
      holder = status.subscription?.tier ?? PremiumTier.none;
    } else if (snap.fromPlay && snap.hasAccess) {
      blocked = true;
      holder = snap.tier;
    }
    final details = status?.subscription;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHeader(context),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: blocked
                ? _ActiveBanner(
                    tier: holder,
                    details: details,
                    onMy: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MySubscriptionScreen(),
                    )),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escolha seu plano',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Suba de nível mais rápido e navegue sem anúncios.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13.5,
                        ),
                      ),
                      if (snap.hasAccess && !snap.fromPlay) ...[
                        const SizedBox(height: 10),
                        _InfoChip(
                          'Seu ${snap.tier.label} atual é uma cortesia'
                          '${snap.expiresAt != null ? ' até ${formatDatePt(snap.expiresAt!)}' : ''}.',
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final plan = _plans[index];
                final tier = PremiumProductIds.tierFor(plan.productId);
                final isCurrent = blocked && holder == tier;
                final buying = _purchaseInFlightProductId == plan.productId;
                final anyBuying = _purchaseInFlightProductId != null;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 450 + index * 150),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PlanCard(
                      plan: plan,
                      product: _productsById[plan.productId],
                      loadingProduct: _loadingProducts,
                      isBuying: buying,
                      isCurrent: isCurrent,
                      isBlockedByOther: blocked && !isCurrent,
                      otherTierLabel: holder.label,
                      disabled: anyBuying && !buying,
                      pulse: _pulse,
                      onSubscribe: () => _buyPlan(plan, blocked),
                      onManage: () => _manage(tier),
                    ),
                  ),
                );
              },
              childCount: _plans.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(child: _ComparisonTable(plans: _plans)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(child: _buildAvatarsTeaser(context)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          sliver: SliverToBoxAdapter(child: _buildFooter(context, blocked, holder)),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: 130,
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
        background: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryOrangeDark
                      .withOpacity(0.28 + 0.12 * _pulse.value),
                  AppColors.backgroundDark,
                ],
              ),
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

  Widget _buildFooter(BuildContext context, bool hasSub, PremiumTier holder) {
    return Column(
      children: [
        const _InfoBar(),
        const SizedBox(height: 18),
        // Restaurar compras: SEMPRE visível, com ou sem assinatura.
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _restoring ? null : _restorePurchases,
            icon: _restoring
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(FontAwesomeIcons.rotate,
                    size: 14, color: Colors.white70),
            label: Text(
              _restoring ? 'Verificando...' : 'Restaurar compras',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (hasSub) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _manage(holder),
              icon: Icon(FontAwesomeIcons.googlePlay,
                  size: 14, color: holder.accentColor),
              label: Text(
                'Gerenciar assinatura',
                style: TextStyle(
                  color: holder.accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: holder.accentColor.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _footerLink(context, 'Termos de Uso', _kTermsUrl),
            _footerLink(context, 'Política de Privacidade', _kPrivacyUrl),
          ],
        ),
        const SizedBox(height: 14),
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    if (isError) {
      AppMessenger.error(msg);
    } else {
      AppMessenger.info(msg);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// BANNER "ASSINATURA EM VIGOR" (no lugar do convite)
// ═══════════════════════════════════════════════════════════════════
class _ActiveBanner extends StatelessWidget {
  final PremiumTier tier;
  final SubscriptionDetails? details;
  final VoidCallback onMy;
  const _ActiveBanner(
      {required this.tier, required this.details, required this.onMy});

  @override
  Widget build(BuildContext context) {
    final color = tier.accentColor;
    final d = details;
    String line;
    if (d == null) {
      line = 'Seu plano ${tier.label} está em vigor.';
    } else if (d.onHold) {
      line = 'Pagamento pendente. Regularize na Google Play.';
    } else if (d.cancelScheduled && d.expiresAt != null) {
      line = 'Cancelado: benefícios até ${formatDatePt(d.expiresAt!)}.';
    } else if (d.expiresAt != null) {
      line = 'Ativo — ${d.autoRenewing ? 'renova' : 'vence'} em '
          '${formatDatePt(d.expiresAt!)}.';
    } else {
      line = 'Seu plano ${tier.label} está em vigor.';
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onMy,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: color.withOpacity(0.10),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(tier.icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Você é assinante ${tier.label}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Text(line,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              Text('Minha assinatura',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12.5,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE PLANO
// ═══════════════════════════════════════════════════════════════════
class _PlanCard extends StatefulWidget {
  final PremiumPlan plan;
  final ProductDetails? product;
  final bool loadingProduct;
  final bool isBuying;
  final bool isCurrent;
  final bool isBlockedByOther;
  final String otherTierLabel;
  final bool disabled;
  final Animation<double> pulse;
  final VoidCallback onSubscribe;
  final VoidCallback onManage;

  const _PlanCard({
    required this.plan,
    required this.product,
    required this.loadingProduct,
    required this.isBuying,
    required this.isCurrent,
    required this.isBlockedByOther,
    required this.otherTierLabel,
    required this.disabled,
    required this.pulse,
    required this.onSubscribe,
    required this.onManage,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final isUltra = plan.productId == PremiumProductIds.ultra;
    final available = widget.product != null;
    final priceLabel = widget.product?.price ?? plan.fallbackPrice;
    final dim = widget.isBlockedByOther;
    final canTap = !widget.isCurrent &&
        !widget.isBlockedByOther &&
        !widget.isBuying &&
        !widget.disabled;

    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (context, child) {
        final glow = widget.isCurrent ? 0.18 + 0.14 * widget.pulse.value : 0.10;
        return Opacity(
          opacity: dim ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: plan.accentColor
                    .withOpacity(widget.isCurrent ? 0.9 : 0.45),
                width: widget.isCurrent ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: plan.accentColor.withOpacity(glow),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  plan.accentColor.withOpacity(0.12),
                  AppColors.backgroundCard,
                ],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: plan.gradient),
                  shape: BoxShape.circle,
                ),
                child: Icon(plan.icon,
                    color: isUltra ? Colors.black.withOpacity(0.85) : Colors.white,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
                    Text(plan.subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (widget.isCurrent)
                _Pill('PLANO ATUAL', plan.accentColor, filled: true)
              else
                _Pill(plan.xpTag, plan.accentColor),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.loadingProduct)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white54),
            )
          else
            Text(priceLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900)),
          if (!widget.loadingProduct && !available) ...[
            const SizedBox(height: 6),
            Text('Plano ainda não disponível para compra.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 10),
          ...plan.features.map(
              (f) => _FeatureRow(feature: f, accentColor: plan.accentColor)),
          const SizedBox(height: 8),
          if (widget.isBlockedByOther)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Indisponível: você já tem o ${widget.otherTierLabel} ativo. '
                'Poderá contratar este plano quando ele terminar.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12.5,
                    height: 1.35),
              ),
            ),
          AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 100),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onHighlightChanged: (v) => setState(() => _down = v),
                  onTap: widget.isCurrent
                      ? widget.onManage
                      : (canTap ? widget.onSubscribe : null),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: (canTap)
                          ? LinearGradient(colors: plan.gradient)
                          : null,
                      color: canTap ? null : Colors.white.withOpacity(0.06),
                      border: canTap
                          ? null
                          : Border.all(
                              color: plan.accentColor
                                  .withOpacity(widget.isCurrent ? 0.6 : 0.2)),
                    ),
                    child: Center(
                      child: widget.isBuying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.isCurrent) ...[
                                  Icon(FontAwesomeIcons.googlePlay,
                                      size: 14, color: plan.accentColor),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  widget.isCurrent
                                      ? 'Gerenciar assinatura'
                                      : widget.isBlockedByOther
                                          ? 'Indisponível'
                                          : 'Assinar ${plan.name}',
                                  style: TextStyle(
                                    color: canTap
                                        ? (isUltra
                                            ? Colors.black.withOpacity(0.85)
                                            : Colors.white)
                                        : (widget.isCurrent
                                            ? plan.accentColor
                                            : Colors.white38),
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

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;
  const _Pill(this.text, this.color, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(filled ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// COMPARAÇÃO PRO × ULTRA (só benefícios que já existem no app)
// ═══════════════════════════════════════════════════════════════════
class _ComparisonTable extends StatelessWidget {
  final List<PremiumPlan> plans;
  const _ComparisonTable({required this.plans});

  static const List<List<String>> _rows = [
    ['Check-in sem anúncio', '✓', '✓'],
    ['Sem banner de anúncios', '✓', '✓'],
    ['Ganho de XP', '2x', '8x'],
    ['Avatares animados', '6', '22'],
    ['Nome personalizado', '✓', '✓'],
    ['Distintivo de assinante', 'Pro', 'Ultra'],
  ];

  @override
  Widget build(BuildContext context) {
    final pro = plans.first.accentColor;
    final ultra = plans.last.accentColor;
    Widget cell(String t, Color c, {bool bold = false}) => Expanded(
          flex: 2,
          child: Center(
            child: Text(t,
                style: TextStyle(
                    color: t == '✓' ? c : Colors.white,
                    fontWeight: bold || t == '✓' ? FontWeight.w900 : FontWeight.w700,
                    fontSize: t == '✓' ? 17 : 14)),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text('Compare os planos',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
              cell('PRO', pro, bold: true),
              cell('ULTRA', ultra, bold: true),
            ],
          ),
          const SizedBox(height: 6),
          for (final r in _rows) ...[
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(r[0],
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.5)),
                  ),
                  cell(r[1], pro),
                  cell(r[2], ultra),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatefulWidget {
  final PremiumFeature feature;
  final Color accentColor;
  const _FeatureRow({required this.feature, required this.accentColor});

  @override
  State<_FeatureRow> createState() => _FeatureRowState();
}

class _FeatureRowState extends State<_FeatureRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _glowController;

  @override
  void initState() {
    super.initState();
    if (widget.feature.animated) {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feature = widget.feature;
    final accentColor = widget.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (_glowController != null)
            AnimatedBuilder(
              animation: _glowController!,
              builder: (context, child) {
                final t = _glowController!.value;
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withOpacity(0.35 + 0.25 * t),
                        accentColor.withOpacity(0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: accentColor.withOpacity(0.5 + 0.4 * t),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.35 * t),
                        blurRadius: 10 * t,
                        spreadRadius: 0.5 * t,
                      ),
                    ],
                  ),
                  child: Icon(feature.icon, color: accentColor, size: 14),
                );
              },
            )
          else
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
