import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../services/admin_user_service.dart';
import 'admin_shared_widgets.dart';

class AdminBannedTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final AdminUserService userService;

  const AdminBannedTile({
    required this.userId,
    required this.data,
    required this.userService,
    Key? key,
  }) : super(key: key);

  String _resolveName(Map<String, dynamic> ud) {
    for (final f in ['displayName', 'name', 'userName']) {
      final v = ud[f];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final email = (ud['email'] as String?) ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return userId.substring(0, userId.length.clamp(0, 16));
  }

  @override
  Widget build(BuildContext context) {
    final reason = (data['reason'] as String?)?.trim() ?? '';
    final bannedAt = (data['suspendedAt'] as Timestamp?)?.toDate();
    final expiresAt = (data['until'] as Timestamp?)?.toDate();
    final isPermanent = expiresAt == null;

    final bannedStr = bannedAt != null
        ? '${bannedAt.day.toString().padLeft(2, '0')}/'
            '${bannedAt.month.toString().padLeft(2, '0')}/'
            '${bannedAt.year}'
        : 'Data desconhecida';

    int daysLeft = 0;
    bool isExpired = false;
    if (!isPermanent && expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now());
      daysLeft = diff.inDays;
      if (diff.inSeconds <= 0) {
        isExpired = true;
        daysLeft = diff.inDays.abs();
      } else if (daysLeft == 0) {
        daysLeft = 1;
      }
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users_xp')
          .doc(userId)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          );
        }

        String name = 'Usuário desconhecido';
        String email = '';
        if (snap.hasData && snap.data!.exists) {
          final ud = snap.data!.data() as Map<String, dynamic>;
          name = _resolveName(ud);
          email = (ud['email'] as String?) ?? '';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPermanent
                  ? const Color(0xFFEF5350).withOpacity(0.4)
                  : const Color(0xFFFF9800).withOpacity(0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          const Color(0xFFEF5350).withOpacity(0.15),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                        ],
                      ),
                    ),
                    AdminBadge(
                      label: isPermanent
                          ? 'Permanente'
                          : isExpired
                              ? 'Expirado'
                              : 'Temporário',
                      color: isPermanent
                          ? const Color(0xFFEF5350)
                          : isExpired
                              ? AppColors.textSecondary
                              : const Color(0xFFFF9800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminBanInfoRow(
                  icon: Icons.event_rounded,
                  label: 'Banido em',
                  value: bannedStr,
                ),
                const SizedBox(height: 6),
                if (reason.isNotEmpty) ...[
                  AdminBanInfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Motivo',
                    value: reason,
                  ),
                  const SizedBox(height: 6),
                ],
                if (!isPermanent) ...[
                  AdminBanInfoRow(
                    icon: Icons.timer_rounded,
                    label: isExpired ? 'Expirado há' : 'Dias restantes',
                    value:
                        '$daysLeft dia${daysLeft != 1 ? 's' : ''}${isExpired ? ' (expirado)' : ''}',
                    valueColor: isExpired
                        ? AppColors.textSecondary
                        : daysLeft <= 3
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF66BB6A),
                  ),
                  const SizedBox(height: 6),
                ],
                AdminBanInfoRow(
                  icon: isPermanent
                      ? Icons.block_rounded
                      : Icons.access_time_rounded,
                  label: 'Status',
                  value: isPermanent
                      ? 'Banido permanentemente'
                      : isExpired
                          ? 'Banimento expirado'
                          : 'Banido temporariamente',
                  valueColor: isPermanent
                      ? const Color(0xFFEF5350)
                      : isExpired
                          ? AppColors.textSecondary
                          : const Color(0xFFFF9800),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: AdminActionButton(
                    icon: Icons.lock_open_rounded,
                    label: 'Remover banimento',
                    color: const Color(0xFF66BB6A),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AdminConfirmDialog(
                          title: 'Remover banimento?',
                          message: '$name poderá comentar novamente.',
                          confirmLabel: 'Remover',
                          confirmColor: const Color(0xFF66BB6A),
                        ),
                      );
                      if (confirm == true) {
                        await userService.unsuspendUser(userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Banimento de $name removido.'),
                              backgroundColor:
                                  const Color(0xFF66BB6A),
                            ),
                          );
                        }
                      }
                    },
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
