import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/premium_avatars_config.dart';
import '../config/premium_config.dart';
import '../providers/user_xp_provider.dart';
import '../widgets/premium_avatars.dart';
import '../widgets/subscriber_badge.dart';

// ═══════════════════════════════════════════════════════════════════
// GALERIA DE AVATARES ANIMADOS PREMIUM
// ═══════════════════════════════════════════════════════════════════
// Qualquer usuário pode ABRIR esta tela e visualizar todos os avatares
// animados em movimento. Para EQUIPAR, cada avatar exige o tier mínimo
// definido em PremiumAvatarDef.minTier:
//   • Coleção PRO  (6 avatares originais) — PRO e ULTRA equipam.
//   • Coleção ULTRA (10 avatares exclusivos) — só ULTRA equipa.
// A gravação acontece via UserXpProvider.setEquippedPremiumAvatar, que
// persiste em users_xp/{uid}.equippedPremiumAvatarId (Firestore), então
// o avatar equipado continua salvo após fechar e abrir o app.
//
// A grade é gerada a partir de PremiumAvatarsConfig.all — adicionar um
// novo avatar no config já faz ele aparecer aqui automaticamente, sem
// tocar nesta tela.
// ═══════════════════════════════════════════════════════════════════

/// Compara se [userTier] atende ou supera o [required]. Ordem de
/// poder: none < pro < ultra. PremiumTier.none nunca equipa nada.
bool _tierMeets(PremiumTier userTier, PremiumTier required) {
  const order = {
    PremiumTier.none: 0,
    PremiumTier.pro: 1,
    PremiumTier.ultra: 2,
  };
  if (userTier == PremiumTier.none) return false;
  return order[userTier]! >= order[required]!;
}

class PremiumAvatarGalleryScreen extends StatelessWidget {
  const PremiumAvatarGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserXpProvider>(
      builder: (context, xpProvider, _) {
        final data = xpProvider.data;
        final isSubscriber = data.isPremium;
        final userTier = data.premiumTier;
        final equippedId =
            PremiumAvatarIdX.fromStorageKey(data.equippedPremiumAvatarId);

        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          appBar: AppBar(
            backgroundColor: AppColors.backgroundDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Avatares Premium',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildIntroBanner(context, userTier),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final def = PremiumAvatarsConfig.all[index];
                      final isEquipped = equippedId == def.id;
                      final canEquip = _tierMeets(userTier, def.minTier);
                      return _AvatarCard(
                        def: def,
                        canEquip: canEquip,
                        isEquipped: isEquipped,
                        onEquip: () async {
                          if (isEquipped) {
                            await xpProvider.setEquippedPremiumAvatar(null);
                          } else {
                            await xpProvider
                                .setEquippedPremiumAvatar(def.id.storageKey);
                          }
                        },
                      );
                    },
                    childCount: PremiumAvatarsConfig.all.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntroBanner(BuildContext context, PremiumTier userTier) {
    final isSubscriber = userTier.isPremium;
    final isUltra = userTier == PremiumTier.ultra;

    final String title;
    final String subtitle;
    if (isUltra) {
      title = 'Você é ULTRA! 👑';
      subtitle = 'Toque em um avatar para equipá-lo — inclusive os 10 '
          'exclusivos ULTRA.';
    } else if (isSubscriber) {
      title = 'Você é assinante! ✨';
      subtitle = 'Toque em um avatar para equipá-lo. Os avatares com selo '
          'ULTRA pedem upgrade para o plano ULTRA.';
    } else {
      title = 'Exclusivo para assinantes';
      subtitle = 'Visualize à vontade. Assine o Premium para equipar os '
          'avatares animados — e o ULTRA libera 10 avatares exclusivos.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isSubscriber
                ? const [Color(0xFFF2B705), Color(0xFFE08E00)]
                : [
                    AppColors.primaryOrange.withOpacity(0.16),
                    Colors.transparent,
                  ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: isSubscriber
              ? null
              : Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            if (isSubscriber)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SubscriberBadge(size: 26),
              )
            else
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Icon(FontAwesomeIcons.wandMagicSparkles,
                    color: AppColors.primaryOrange, size: 18),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final PremiumAvatarDef def;
  final bool canEquip;
  final bool isEquipped;
  final VoidCallback onEquip;

  const _AvatarCard({
    required this.def,
    required this.canEquip,
    required this.isEquipped,
    required this.onEquip,
  });

  void _handleTap(BuildContext context) {
    if (canEquip) {
      onEquip();
      return;
    }
    // Sem tier suficiente: mostra aviso e oferece ir para a tela
    // Premium, sem nunca equipar o avatar.
    final message = def.isUltraExclusive
        ? 'Este avatar é exclusivo de quem assina o ULTRA.'
        : 'Assine o Premium para equipar este avatar.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        action: SnackBarAction(
          label: def.isUltraExclusive ? 'VER ULTRA' : 'ASSINAR',
          textColor: AppColors.primaryOrange,
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.premium),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF0A0A0A),
            border: Border.all(
              color: isEquipped
                  ? def.accentColor.withOpacity(0.9)
                  : Colors.white.withOpacity(0.08),
              width: isEquipped ? 1.6 : 1,
            ),
            boxShadow: isEquipped
                ? [
                    BoxShadow(
                      color: def.accentColor.withOpacity(0.35),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Reaproveita o AvatarFrame com um nível "neutro"
                  // (só para mostrar o preview do avatar dentro do
                  // círculo, sem moldura de nível competindo
                  // visualmente com o próprio avatar premium).
                  Opacity(
                    opacity: canEquip ? 1.0 : 0.55,
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: PremiumAnimatedAvatar(
                        avatarId: def.id,
                        size: 78,
                      ),
                    ),
                  ),
                  if (def.isUltraExclusive)
                    const Positioned(
                      top: -4,
                      left: -4,
                      child: _UltraTag(),
                    ),
                  if (!canEquip)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          FontAwesomeIcons.lock,
                          size: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  if (isEquipped)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: def.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                def.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                def.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isEquipped
                      ? def.accentColor.withOpacity(0.18)
                      : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color: isEquipped
                        ? def.accentColor.withOpacity(0.6)
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Text(
                  isEquipped
                      ? 'EQUIPADO'
                      : (canEquip
                          ? 'EQUIPAR'
                          : (def.isUltraExclusive ? 'ULTRA' : 'PREMIUM')),
                  style: TextStyle(
                    color: isEquipped ? def.accentColor : Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Selo compacto "ULTRA" exibido no canto dos avatares exclusivos do
/// tier ULTRA, para diferenciá-los visualmente dos avatares PRO.
class _UltraTag extends StatelessWidget {
  const _UltraTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFF2B705), Color(0xFFE08E00)],
        ),
        border: Border.all(color: Colors.black, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF2B705).withOpacity(0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.crown, size: 8, color: Colors.black),
          SizedBox(width: 3),
          Text(
            'ULTRA',
            style: TextStyle(
              color: Colors.black,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}