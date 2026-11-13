import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_routes.dart';
import '../config/premium_config.dart';
import '../screens/my_subscription_screen.dart';
import '../services/subscription_state_service.dart';

/// Espaço da oferta Premium no perfil.
///  • sem plano  → banner "Seja Premium" (abre a tela Premium);
///  • com plano  → cartão "Minha assinatura" (PRO azul / ULTRA dourado).
/// Reage em tempo real ao Firestore: ao assinar, vencer ou ser revogado,
/// troca sozinho, sem reabrir o app.
class PremiumProfileSection extends StatelessWidget {
  const PremiumProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionService.instance..ensureStarted();
    return ValueListenableBuilder<SubscriptionSnapshot>(
      valueListenable: service.snapshot,
      builder: (context, snap, _) {
        if (!snap.loaded) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: snap.hasAccess
                ? _SubscriberCard(key: ValueKey(snap.tier), snap: snap)
                : const _OfferBanner(key: ValueKey('offer')),
          ),
        );
      },
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.premium),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFF2B705), Color(0xFFE08E00)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Icon(FontAwesomeIcons.crown,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seja Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Suba de nível mais rápido e remova anúncios',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriberCard extends StatefulWidget {
  final SubscriptionSnapshot snap;
  const _SubscriberCard({super.key, required this.snap});

  @override
  State<_SubscriberCard> createState() => _SubscriberCardState();
}

class _SubscriberCardState extends State<_SubscriberCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;
    final tier = snap.tier;
    final color = tier.accentColor;
    final until = snap.expiresAt;
    final subtitle = snap.fromPlay
        ? (until != null ? 'Ativo até ${formatDatePt(until)}' : 'Ativo')
        : (until != null
            ? '${snap.trial ? 'Cortesia de teste' : 'Cortesia'} até ${formatDatePt(until)}'
            : 'Plano ativo');

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.45 + 0.2 * _glow.value),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.10 + 0.10 * _glow.value),
                blurRadius: 18,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.16), const Color(0xFF0A0A0A)],
            ),
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MySubscriptionScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: tier.gradient),
                  ),
                  child: Icon(
                    tier.icon,
                    size: 18,
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
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Minha assinatura',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.6)),
                            ),
                            child: Text(
                              tier.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.5), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}