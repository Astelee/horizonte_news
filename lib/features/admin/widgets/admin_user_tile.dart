import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../services/xp_service.dart';
import 'admin_shared_widgets.dart';

class AdminUserTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;

  const AdminUserTile({
    required this.userId,
    required this.data,
    Key? key,
  }) : super(key: key);

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
        final createdAt =
            (d['createdAt'] as Timestamp?)?.toDate();
        final createdStr = createdAt != null
            ? 'Desde ${createdAt.day.toString().padLeft(2, '0')}/'
                '${createdAt.month.toString().padLeft(2, '0')}/'
                '${createdAt.year}'
            : '';
        final lvlTitle = XpService.levelTitle(level);
        final lvlIcon = XpService.levelIcon(level);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      AppColors.primaryOrange.withOpacity(0.15),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          )),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            )),
                      if (createdStr.isNotEmpty)
                        Text(createdStr,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            )),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          AdminStatChip(
                            icon: Icons.star_rounded,
                            label: '$lvlIcon Nv $level · $lvlTitle',
                            color: AppColors.primaryOrange,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
