import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/premium_config.dart';
import '../services/purchase_service.dart';
import '../services/subscription_state_service.dart';
import '../widgets/app_messenger.dart';

// ═══════════════════════════════════════════════════════════════════
// MINHA ASSINATURA
// ═══════════════════════════════════════════════════════════════════
// Só mostra dados reais: plano e validade vêm do Firestore (liberados pelo
// backend); início, renovação, cancelamento e carência vêm do backend
// (/v1/billing/status), que confere o Google Play. Cancelar acontece na
// própria Google Play — aqui só abrimos a página oficial.
// ═══════════════════════════════════════════════════════════════════
class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen>
    with WidgetsBindingObserver {
  final _service = SubscriptionService.instance;
  final _purchases = PurchaseService.instance;

  bool _loading = true;
  bool _restoring = false;
  bool _wentToPlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.ensureStarted();
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ao voltar da Google Play (cancelou, trocou o cartão...), pede ao Google
  // o estado atual e o backend confere — o cancelamento aparece na hora.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToPlay) {
      _wentToPlay = false;
      unawaited(_syncAfterPlay());
    }
  }

  Future<void> _syncAfterPlay() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _purchases.restore(silent: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    await _service.refreshStatus();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _manage(PremiumTier tier) async {
    final id = tier == PremiumTier.ultra
        ? PremiumProductIds.ultra
        : tier == PremiumTier.pro
            ? PremiumProductIds.pro
            : null;
    final ok = await _purchases.openManageSubscription(productId: id);
    if (!mounted) return;
    if (ok) {
      _wentToPlay = true;
    } else {
      AppMessenger.error('Não foi possível abrir a Google Play.');
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    final outcome = await _purchases.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    switch (outcome) {
      case RestoreOutcome.restored:
        AppMessenger.info('Compras verificadas e sincronizadas.');
        break;
      case RestoreOutcome.nothingFound:
        AppMessenger.info(
            'Nenhuma assinatura encontrada nesta conta Google Play.');
        break;
      case RestoreOutcome.unavailable:
        AppMessenger.error('A Google Play não está disponível agora.');
        break;
      case RestoreOutcome.failed:
        AppMessenger.error('Não foi possível restaurar agora.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text('Minha assinatura',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: ValueListenableBuilder<SubscriptionSnapshot>(
        valueListenable: _service.snapshot,
        builder: (context, snap, _) => ValueListenableBuilder<BillingStatus?>(
          valueListenable: _service.status,
          builder: (context, status, _) => RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.primaryOrange,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ..._content(snap, status),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: FontAwesomeIcons.rotate,
                  label: _restoring ? 'Verificando...' : 'Restaurar compras',
                  onTap: _restoring ? null : _restore,
                ),
                const SizedBox(height: 10),
                Text(
                  'Reinstalou o app, trocou de celular ou o Premium não '
                  'apareceu? Restaurar compras confere sua conta Google Play.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(SubscriptionSnapshot snap, BillingStatus? status) {
    final sub = status?.subscription;
    // Assinatura do Google Play (mesmo cancelada ou em espera).
    if (sub != null) {
      final tier = sub.tier;
      final notice = _notice(sub);
      return [
        _PlanCard(
          tier: tier,
          status: _statusLabel(sub),
          rows: [
            if (sub.startedAt != null)
              _Row('Início', formatDatePt(sub.startedAt!)),
            if (sub.expiresAt != null)
              _Row(_dateLabel(sub), formatDatePt(sub.expiresAt!)),
            _Row('Renovação automática',
                sub.benefitsActive && sub.autoRenewing ? 'Ativada' : 'Desativada'),
          ],
        ),
        if (notice != null) ...[const SizedBox(height: 12), _Notice(notice)],
        const SizedBox(height: 16),
        _ActionButton(
          icon: FontAwesomeIcons.googlePlay,
          label: 'Gerenciar assinatura',
          highlight: tier.accentColor,
          onTap: () => _manage(tier),
        ),
      ];
    }

    // Plano liberado, mas ainda sem detalhes do Google (cortesia do admin
    // ou backend ainda confirmando).
    if (snap.hasAccess) {
      final exp = snap.expiresAt;
      return [
        _PlanCard(
          tier: snap.tier,
          status: snap.fromPlay
              ? 'Ativa'
              : (snap.trial ? 'Cortesia de teste' : 'Cortesia'),
          rows: [
            if (exp != null) _Row('Válido até', formatDatePt(exp)),
          ],
        ),
        if (!snap.fromPlay) ...[
          const SizedBox(height: 12),
          const _Notice(
              'Este plano foi concedido pela equipe do Horizonte News, não '
              'por uma assinatura da Google Play. Você pode assinar um plano '
              'normalmente quando quiser.'),
          const SizedBox(height: 16),
          _ActionButton(
            icon: FontAwesomeIcons.crown,
            label: 'Ver planos',
            highlight: AppColors.primaryOrange,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.premium),
          ),
        ] else ...[
          const SizedBox(height: 16),
          _ActionButton(
            icon: FontAwesomeIcons.googlePlay,
            label: 'Gerenciar assinatura',
            highlight: snap.tier.accentColor,
            onTap: () => _manage(snap.tier),
          ),
        ],
      ];
    }

    // Sem assinatura.
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Icon(FontAwesomeIcons.crown,
                color: Colors.white.withOpacity(0.4), size: 26),
            const SizedBox(height: 12),
            const Text('Você não tem uma assinatura ativa',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _ActionButton(
        icon: FontAwesomeIcons.crown,
        label: 'Ver planos',
        highlight: AppColors.primaryOrange,
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.premium),
      ),
    ];
  }

  String _statusLabel(SubscriptionDetails s) {
    if (s.onHold) return 'Pagamento pendente — acesso suspenso';
    if (s.inGracePeriod) return 'Pagamento em atraso — período de carência';
    if (s.cancelScheduled) return 'Cancelada — benefícios até o fim do período';
    if (s.benefitsActive) return 'Ativa';
    return 'Encerrada';
  }

  String _dateLabel(SubscriptionDetails s) {
    if (s.onHold) return 'Venceu em';
    if (s.inGracePeriod) return 'Regularizar até';
    if (s.cancelScheduled) return 'Benefícios até';
    if (!s.benefitsActive) return 'Encerrou em';
    return s.autoRenewing ? 'Próxima renovação' : 'Vence em';
  }

  String? _notice(SubscriptionDetails s) {
    if (s.onHold) {
      return 'Não conseguimos cobrar sua assinatura. Atualize a forma de '
          'pagamento na Google Play para recuperar o acesso. Enquanto ela '
          'existir, não é possível contratar outro plano.';
    }
    if (s.inGracePeriod) {
      return 'A cobrança falhou, mas você continua com os benefícios durante '
          'o período de carência. Regularize o pagamento na Google Play.';
    }
    if (s.cancelScheduled && s.expiresAt != null) {
      return 'Você cancelou a renovação. Seus benefícios continuam até '
          '${formatDatePt(s.expiresAt!)}. Depois dessa data, PRO e ULTRA '
          'ficam liberados para uma nova contratação.';
    }
    return null;
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _PlanCard extends StatelessWidget {
  final PremiumTier tier;
  final String status;
  final List<_Row> rows;
  const _PlanCard(
      {required this.tier, required this.status, required this.rows});

  @override
  Widget build(BuildContext context) {
    final color = tier.accentColor;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.55), width: 1.3),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 22)],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.18), const Color(0xFF0A0A0A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: tier.gradient),
                ),
                child: Icon(
                  tier.icon,
                  size: 20,
                  color: tier == PremiumTier.ultra
                      ? Colors.black.withOpacity(0.85)
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plano ${tier.label}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('Assinante Horizonte News',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.label,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13.5)),
                    Text(r.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FontAwesomeIcons.circleInfo,
              size: 14, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? highlight;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.highlight});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.highlight ?? Colors.white70;
    final enabled = widget.onTap != null;
    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 100),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Ink(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: widget.highlight != null
                    ? color.withOpacity(0.12)
                    : Colors.white.withOpacity(0.05),
                border: Border.all(
                    color: widget.highlight != null
                        ? color.withOpacity(0.5)
                        : Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 15, color: color),
                  const SizedBox(width: 10),
                  Text(widget.label,
                      style: TextStyle(
                          color: widget.highlight != null
                              ? color
                              : Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}