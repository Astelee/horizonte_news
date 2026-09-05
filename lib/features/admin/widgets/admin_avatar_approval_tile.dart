import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../services/admin_avatar_approval_service.dart';
import 'admin_shared_widgets.dart';

class AdminAvatarApprovalTile extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final AdminAvatarApprovalService approvalService;

  const AdminAvatarApprovalTile({
    required this.uid,
    required this.data,
    required this.approvalService,
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
    final userName = (data['userName'] as String?)?.trim().isNotEmpty == true
        ? data['userName'] as String
        : 'Usuário';
    final pendingPhotoUrl = data['pendingPhotoUrl'] as String?;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.35),
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
                _buildPreview(context, pendingPhotoUrl),
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
                      const SizedBox(height: 4),
                      if (submittedAt != null)
                        AdminBanInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Enviada',
                          value: _timeAgo(submittedAt),
                        ),
                    ],
                  ),
                ),
                const AdminBadge(
                  label: 'Pendente',
                  color: AppColors.primaryOrange,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdminActionButton(
                  icon: Icons.close_rounded,
                  label: 'Rejeitar',
                  color: const Color(0xFFEF5350),
                  onTap: () => _handleReject(context, userName),
                ),
                const SizedBox(width: 8),
                AdminActionButton(
                  icon: Icons.check_rounded,
                  label: 'Aprovar',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _handleApprove(context, userName,
                      pendingPhotoUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.person_off_rounded,
            color: AppColors.textMuted, size: 28),
      );
    }
    return GestureDetector(
      onTap: () => _showFullPreview(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 64,
              height: 64,
              color: const Color(0xFF1A1A1A),
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
          },
          errorBuilder: (context, error, stack) => Container(
            width: 64,
            height: 64,
            color: const Color(0xFF1A1A1A),
            child: const Icon(Icons.broken_image_rounded,
                color: AppColors.textMuted, size: 24),
          ),
        ),
      ),
    );
  }

  void _showFullPreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    String userName,
    String? pendingPhotoUrl,
  ) async {
    if (pendingPhotoUrl == null || pendingPhotoUrl.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Aprovar foto?',
        message: 'A foto de $userName vai aparecer no ranking e nos '
            'comentários do app.',
        confirmLabel: 'Aprovar',
        confirmColor: const Color(0xFF66BB6A),
      ),
    );
    if (confirm != true) return;

    await approvalService.approve(uid: uid, pendingPhotoUrl: pendingPhotoUrl);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto de $userName aprovada.'),
          backgroundColor: const Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _handleReject(BuildContext context, String userName) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rejeitar foto?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A foto de $userName não será usada. A foto anterior '
              '(se houver) é mantida.',
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
              'Rejeitar',
              style: TextStyle(
                  color: Color(0xFFEF5350), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await approvalService.reject(
      uid: uid,
      reason: reasonController.text,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto de $userName rejeitada.'),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
    }
  }
}