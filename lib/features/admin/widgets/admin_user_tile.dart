import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../services/xp_service.dart';
import '../../../widgets/app_avatar.dart';
import '../services/admin_user_service.dart';
import 'admin_shared_widgets.dart';
import 'poderes_panel.dart';

class AdminUserTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final AdminUserService userService;

  const AdminUserTile({
    required this.userId,
    required this.data,
    required this.userService,
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

  void _abrirPoderes(BuildContext context, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF080808),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: PoderesPanel(
                    key: ValueKey(userId),
                    uid: userId,
                    userService: userService,
                    displayName: name,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users_xp')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        final d = (snap.hasData && snap.data!.exists)
            ? snap.data!.data() as Map<String, dynamic>
            : data;

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

        final email = d['email'] as String? ?? '';
        final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
        final level = XpService.levelFromXp(xp);
        final comments =
            (d['stats']?['commentsPosted'] as num?)?.toInt() ??
                (d['commentsPosted'] as num?)?.toInt() ??
                0;
        final articles =
            (d['stats']?['articlesRead'] as num?)?.toInt() ??
                (d['articlesRead'] as num?)?.toInt() ??
                0;
        final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
        final createdStr = createdAt != null
            ? 'Desde ${createdAt.day.toString().padLeft(2, '0')}/'
                '${createdAt.month.toString().padLeft(2, '0')}/'
                '${createdAt.year}'
            : '';
        final lvlTitle = XpService.levelTitle(level);
        final lvlIcon = XpService.levelIcon(level);

        final hasOverride = d['adminOverrideActive'] == true;
        final hasTitleOverride = d['adminOverrideTitleActive'] == true;

        // ── Último visto ────────────────────────────────────────
        final lastSeenAt = (d['lastSeenAt'] as Timestamp?)?.toDate();
        final lastSeenLabel = _lastSeenLabel(lastSeenAt);
        final lastSeenColor = _lastSeenColor(lastSeenAt);
        final isOnline = lastSeenAt != null &&
            DateTime.now().difference(lastSeenAt).inMinutes < 5;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOnline
                  ? const Color(0xFF43B581).withOpacity(0.4)
                  : AppColors.borderDark,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar com indicador online
                    Stack(
                      children: [
                        AppAvatar(
                          name: name,
                          seed: userId,
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
                                    color: const Color(0xFF0A0A0A),
                                    width: 2),
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
                          // Nome + último visto
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
                          Row(
                            children: [
                              AdminStatChip(
                                icon: Icons.star_rounded,
                                label: '$lvlIcon Nv $level · $lvlTitle',
                                color: AppColors.primaryOrange,
                              ),
                              if (hasOverride || hasTitleOverride) ...[
                                const SizedBox(width: 6),
                                AdminStatChip(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'CUSTOM',
                                  color: const Color(0xFFFFD700),
                                ),
                              ],
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
                  ],
                ),
                const SizedBox(height: 10),
                // ── Botão Poderes ─────────────────────────────────
                GestureDetector(
                  onTap: () => _abrirPoderes(context, name),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.primaryOrange.withOpacity(0.08),
                      border: Border.all(
                          color: AppColors.primaryOrange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: AppColors.primaryOrange, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'PODERES',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
