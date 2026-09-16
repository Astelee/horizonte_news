import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/premium_avatars_config.dart';
import '../providers/user_xp_provider.dart';
import '../widgets/premium_avatars.dart';
import '../widgets/subscriber_badge.dart';

// ═══════════════════════════════════════════════════════════════════
// GALERIA DE AVATARES ANIMADOS PREMIUM
// ═══════════════════════════════════════════════════════════════════
// Qualquer usuário pode ABRIR esta tela e visualizar os 6 avatares
// animados em movimento. Só assinantes (premiumTier != none, lido do
// UserXpProvider já existente) podem EQUIPAR um avatar — a gravação
// acontece via UserXpProvider.setEquippedPremiumAvatar, que persiste
// em users_xp/{uid}.equippedPremiumAvatarId (Firestore), então o
// avatar equipado continua salvo após fechar e abrir o app.
//
// A grade é gerada a partir de PremiumAvatarsConfig.all — adicionar
// um 7º avatar no config já faz ele aparecer aqui automaticamente,
// sem tocar nesta tela.
// ═══════════════════════════════════════════════════════════════════

class PremiumAvatarGalleryScreen extends StatelessWidget {
  const PremiumAvatarGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserXpProvider>(
      builder: (context, xpProvider, _) {
        final data = xpProvider.data;
        final isSubscriber = data.isPremium;
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
                child: _buildIntroBanner(context, isSubscriber),
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
                      return _AvatarCard(
                        def: def,
                        isSubscriber: isSubscriber,
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

  Widget _buildIntroBanner(BuildContext context, bool isSubscriber) {
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
                    isSubscriber
                        ? 'Você é assinante! ✨'
                        : 'Exclusivo para assinantes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSubscriber
                        ? 'Toque em um avatar para equipá-lo no seu perfil.'
                        : 'Visualize à vontade. Assine o Premium para equipar '
                            'qualquer um destes avatares animados.',
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
  final bool isSubscriber;
  final bool isEquipped;
  final VoidCallback onEquip;

  const _AvatarCard({
    required this.def,
    required this.isSubscriber,
    required this.isEquipped,
    required this.onEquip,
  });

  void _handleTap(BuildContext context) {
    if (isSubscriber) {
      onEquip();
      return;
    }
    // Não assinante: mostra aviso e oferece ir para a tela Premium,
    // sem nunca equipar o avatar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: const Text(
          'Assine o Premium para equipar este avatar.',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        action: SnackBarAction(
          label: 'ASSINAR',
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
                    opacity: isSubscriber ? 1.0 : 0.55,
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: PremiumAnimatedAvatar(
                        avatarId: def.id,
                        size: 78,
                      ),
                    ),
                  ),
                  if (!isSubscriber)
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
                      : (isSubscriber ? 'EQUIPAR' : 'PREMIUM'),
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