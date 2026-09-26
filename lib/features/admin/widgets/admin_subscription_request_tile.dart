import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/premium_config.dart';
import '../../../widgets/app_messenger.dart';
import '../services/admin_subscription_request_service.dart';
import 'admin_shared_widgets.dart';

class AdminSubscriptionRequestTile extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> data;
  final AdminSubscriptionRequestService requestService;

  const AdminSubscriptionRequestTile({
    required this.requestId,
    required this.data,
    required this.requestService,
    Key? key,
  }) : super(key: key);

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = data['uid'] as String? ?? '';
    final userName = (data['userName'] as String?)?.trim().isNotEmpty == true
        ? data['userName'] as String
        : 'Usuário';
    final userEmail = data['userEmail'] as String? ?? '';
    final planId = data['plan'] as String?;
    final tier = PremiumTierX.fromId(planId);
    final productId = data['productId'] as String? ?? '';
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();

    final tierColor =
        tier == PremiumTier.none ? AppColors.primaryOrange : tier.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tierColor.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tier == PremiumTier.ultra
                        ? Icons.workspace_premium_rounded
                        : Icons.bolt_rounded,
                    color: tierColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (userEmail.isNotEmpty)
                        Text(
                          userEmail,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      const SizedBox(height: 6),
                      AdminBanInfoRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Plano',
                        value: tier.label.isNotEmpty ? tier.label : (planId ?? '—'),
                      ),
                      if (productId.isNotEmpty)
                        AdminBanInfoRow(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Produto',
                          value: productId,
                        ),
                      if (requestedAt != null)
                        AdminBanInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Solicitado',
                          value: _timeAgo(requestedAt),
                        ),
                    ],
                  ),
                ),
                const AdminBadge(label: 'Pendente', color: Colors.amber),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdminActionButton(
                  icon: Icons.close_rounded,
                  label: 'Recusar',
                  color: const Color(0xFFEF5350),
                  onTap: () => _handleReject(context, userName, uid),
                ),
                const SizedBox(width: 8),
                AdminActionButton(
                  icon: Icons.check_rounded,
                  label: 'Aprovar',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _handleApprove(context, userName, uid, tier),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    String userName,
    String uid,
    PremiumTier tier,
  ) async {
    if (uid.isEmpty || tier == PremiumTier.none) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Aprovar assinatura?',
        message: 'O plano ${tier.label} será ativado imediatamente para '
            '$userName.',
        confirmLabel: 'Aprovar',
        confirmColor: const Color(0xFF66BB6A),
      ),
    );
    if (confirm != true) return;

    await requestService.approve(
      requestId: requestId,
      uid: uid,
      tier: tier,
    );

    if (context.mounted) {
      AppMessenger.success('Assinatura de $userName aprovada.');
    }
  }

  Future<void> _handleReject(
    BuildContext context,
    String userName,
    String uid,
  ) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.2)),
        ),
        title: const Text(
          'Recusar assinatura?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O Premium não será liberado para $userName.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Motivo (opcional)',
                hintStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Recusar',
              style: TextStyle(
                  color: Color(0xFFEF5350), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await requestService.reject(
      requestId: requestId,
      uid: uid,
      reason: reasonController.text,
    );

    if (context.mounted) {
      AppMessenger.warning('Assinatura de $userName recusada.');
    }
  }
}