import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// TELA PREMIUM — planos PRO e ULTRA
// ═══════════════════════════════════════════════════════════════════
// Por enquanto é só a interface (igual ao layout de referência do
// RaidCall): mostra os planos, preços e vantagens de cada um.
//
// O botão "Assinar" ainda não faz a compra de verdade — isso entra
// numa etapa seguinte, quando integrarmos o Google Play Billing
// (pacote in_app_purchase) e uma Cloud Function para validar o
// recibo da compra com segurança antes de liberar o Premium.
// ═══════════════════════════════════════════════════════════════════

class PremiumPlan {
  final String id;
  final String name;
  final String subtitle;
  final String price;
  final String period;
  final String xpTag;
  final Color accentColor;
  final List<Color> gradient;
  final IconData icon;
  final List<PremiumFeature> features;

  const PremiumPlan({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.price,
    required this.period,
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

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const List<PremiumPlan> _plans = [
    PremiumPlan(
      id: 'premium_pro_monthly',
      name: 'PRO',
      subtitle: 'Distintivo Pro',
      price: 'R\$ 14,99',
      period: '/ mês',
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
      ],
    ),
    PremiumPlan(
      id: 'premium_ultra_monthly',
      name: 'ULTRA',
      subtitle: 'Distintivo Ultra',
      price: 'R\$ 39,99',
      period: '/ mês',
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
          icon: FontAwesomeIcons.gem,
          label: 'Avatar animado',
          tag: 'GIF',
        ),
      ],
    ),
  ];

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PlanCard(plan: _plans[index]),
                ),
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

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const _InfoBar(),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _footerLink(context, 'Termos de Uso'),
            _footerLink(context, 'Política de Privacidade'),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Restaurar compras ainda não disponível.'),
              ),
            );
          },
          child: Text(
            'Restaurar compras',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footerLink(BuildContext context, String label) {
    return InkWell(
      onTap: () {},
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
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE PLANO
// ═══════════════════════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final PremiumPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
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
              Text(
                plan.price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                plan.period,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: plan.gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showComingSoon(context),
                  child: Center(
                    child: Text(
                      'Assinar',
                      style: TextStyle(
                        color: plan.id == 'premium_ultra_monthly'
                            ? Colors.black.withOpacity(0.85)
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assinaturas chegam em breve por aqui 🚧'),
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