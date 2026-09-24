import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/badge_config.dart';
import '../../../config/premium_config.dart';
import '../../../services/xp_service.dart';
import '../../../widgets/app_avatar.dart';
import '../services/admin_user_service.dart';
import 'admin_shared_widgets.dart';
import 'user_profile_sheet.dart';

/// Card de UM usuário na lista da aba Usuários.
///
/// Recebe os dados já lidos pelo stream da lista (UsersTab) — não abre
/// nenhum listener Firestore próprio. Antes, cada tile assinava de
/// novo o mesmo documento em users_xp (um listener por card, além do
/// stream que a lista inteira já mantinha); com muitos usuários isso
/// significava dezenas de listeners redundantes ao mesmo tempo.
/// Detalhes que exigem leitura à parte (histórico, suspensão) só são
/// buscados quando o perfil individual é aberto — ver
/// [UserProfileSheet].
class AdminUserTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final AdminUserService userService;
  final bool isSuspended;

  const AdminUserTile({
    required this.userId,
    required this.data,
    required this.userService,
    this.isSuspended = false,
    Key? key,
  }) : super(key: key);

  String _lastSeenLabel(DateTime? lastSeen) {
    if (lastSeen == null) return 'Nunca visto';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 60) return 'Online agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    if (diff.inDays < 30) return 'Há ${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays < 365) return 'Há ${(diff.inDays / 30).floor()} meses';
    return 'Há mais de 1 ano';
  }

  Color _lastSeenColor(DateTime? lastSeen) {
    if (lastSeen == null) return AppColors.textMuted;
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 5) return const Color(0xFF43B581);
    if (diff.inHours < 1) return const Color(0xFF66BB6A);
    if (diff.inHours < 24) return const Color(0xFFFFCA28);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final d = data;

    String name = 'Sem nome';
    for (final f in ['displayName', 'name', 'userName']) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) {
        name = v.trim();
        break;
      }
    }
    if (name == 'Sem nome') {
      final em = (d['email'] as String?) ?? '';
      if (em.isNotEmpty) name = em.split('@').first;
    }

    final photoUrl = d['photoUrl'] as String?;
    final email = d['email'] as String? ?? '';
    final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
    final level = XpService.levelFromXp(xp);
    final comments = (d['stats']?['commentsPosted'] as num?)?.toInt() ?? 0;
    final articles = (d['stats']?['articlesRead'] as num?)?.toInt() ?? 0;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final createdStr = createdAt != null
        ? 'Desde ${createdAt.day.toString().padLeft(2, '0')}/'
            '${createdAt.month.toString().padLeft(2, '0')}/'
            '${createdAt.year}'
        : '';
    final lvlTitle = BadgeConfig.levelTitle(level);
    final lvlIcon = BadgeConfig.levelIcon(level);

    final hasOverride = d['adminOverrideActive'] == true;
    final hasTitleOverride = d['adminOverrideTitleActive'] == true;
    final premiumTier = premiumTierFromData(d);

    final lastSeenAt = (d['lastSeenAt'] as Timestamp?)?.toDate();
    final lastSeenLabel = _lastSeenLabel(lastSeenAt);
    final lastSeenColor = _lastSeenColor(lastSeenAt);
    final isOnline = lastSeenAt != null &&
        DateTime.now().difference(lastSeenAt).inMinutes < 5;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showUserProfileSheet(
          context,
          userId: userId,
          userService: userService,
          initialData: d,
        ),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSuspended
                  ? const Color(0xFFEF5350).withOpacity(0.45)
                  : isOnline
                      ? const Color(0xFF43B581).withOpacity(0.4)
                      : AppColors.borderDark,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AppAvatar(
                    name: name,
                    seed: userId,
                    photoUrl: photoUrl,
                    size: 46,
                    showBorder: false,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF43B581),
                          border: Border.all(
                              color: const Color(0xFF0A0A0A), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline
                                  ? Icons.circle
                                  : Icons.access_time_rounded,
                              size: 9,
                              color: lastSeenColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              lastSeenLabel,
                              style: TextStyle(
                                color: lastSeenColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (createdStr.isNotEmpty)
                      Text(
                        createdStr,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AdminStatChip(
                          icon: lvlIcon,
                          label: 'Nv $level · $lvlTitle',
                          color: AppColors.primaryOrange,
                        ),
                        if (hasOverride || hasTitleOverride)
                          const AdminStatChip(
                            icon: Icons.auto_awesome_rounded,
                            label: 'CUSTOM',
                            color: Color(0xFFFFD700),
                          ),
                        if (premiumTier.isPremium)
                          AdminStatChip(
                            icon: premiumTier.icon,
                            label: premiumTier.label,
                            color: premiumTier.accentColor,
                          ),
                        if (isSuspended)
                          const AdminStatChip(
                            icon: Icons.block_rounded,
                            label: 'SUSPENSO',
                            color: Color(0xFFEF5350),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AdminStatChip(
                          icon: Icons.bolt_rounded,
                          label: '$xp XP',
                          color: const Color(0xFFFFD54F),
                        ),
                        const SizedBox(width: 6),
                        AdminStatChip(
                          icon: Icons.chat_bubble_rounded,
                          label: '$comments',
                          color: const Color(0xFF4FC3F7),
                        ),
                        const SizedBox(width: 6),
                        AdminStatChip(
                          icon: Icons.article_rounded,
                          label: '$articles',
                          color: const Color(0xFF66BB6A),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}