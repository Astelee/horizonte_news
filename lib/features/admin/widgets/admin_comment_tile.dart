import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../services/admin_comment_service.dart';
import '../services/admin_user_service.dart';
import 'admin_shared_widgets.dart';
import 'ban_user_dialog.dart';

class AdminCommentTile extends StatelessWidget {
  final String commentId;
  final String postId;
  final Map<String, dynamic> data;
  final AdminCommentService commentService;
  final AdminUserService userService;

  const AdminCommentTile({
    required this.commentId,
    required this.postId,
    required this.data,
    required this.commentService,
    required this.userService,
    Key? key,
  }) : super(key: key);

  String _resolveName(Map<String, dynamic> d) {
    for (final f in [
      'authorName', 'userName', 'displayName', 'name', 'author'
    ]) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return 'Anônimo';
  }

  String? _resolvePhoto(Map<String, dynamic> d) {
    for (final f in [
      'authorPhotoUrl', 'photoUrl', 'avatarUrl', 'photoURL'
    ]) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  String? _resolveId(Map<String, dynamic> d) {
    for (final f in ['authorId', 'userId', 'uid', 'user_id']) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authorId = _resolveId(data);
    final name = _resolveName(data);

    if (name == 'Anônimo' && authorId != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: _fetchProfile(authorId),
        builder: (context, snap) {
          final enriched = Map<String, dynamic>.from(data);
          if (snap.hasData && snap.data!.exists) {
            final ud = snap.data!.data() as Map<String, dynamic>;
            enriched['authorName'] = ud['displayName'] ??
                ud['name'] ?? ud['userName'] ?? 'Anônimo';
            enriched['authorPhotoUrl'] =
                ud['photoUrl'] ?? ud['photoURL'] ?? ud['avatarUrl'];
          }
          return _buildTile(context, enriched);
        },
      );
    }
    return _buildTile(context, data);
  }

  Future<DocumentSnapshot> _fetchProfile(String uid) async {
    final xp = await FirebaseFirestore.instance
        .collection('users_xp')
        .doc(uid)
        .get();
    if (xp.exists) return xp;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
  }

  Widget _buildTile(BuildContext context, Map<String, dynamic> d) {
    final isHidden = d['hidden'] == true;
    final author = _resolveName(d);
    final photoUrl = _resolvePhoto(d);
    final authorId = _resolveId(d);
    final text =
        (d['text'] ?? d['content'] ?? d['body'] ?? '').toString();
    final ts = (d['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null
        ? '${ts.day.toString().padLeft(2, '0')}/'
            '${ts.month.toString().padLeft(2, '0')}/'
            '${ts.year}  '
            '${ts.hour.toString().padLeft(2, '0')}:'
            '${ts.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHidden
              ? AppColors.textSecondary.withOpacity(0.2)
              : AppColors.borderDark,
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
                  radius: 18,
                  backgroundColor:
                      AppColors.primaryOrange.withOpacity(0.15),
                  backgroundImage:
                      (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          author.isNotEmpty
                              ? author[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isHidden)
                  AdminBadge(
                    label: 'Oculto',
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isHidden)
                  AdminActionButton(
                    icon: Icons.visibility_rounded,
                    label: 'Restaurar',
                    color: const Color(0xFF4FC3F7),
                    onTap: () => commentService.restoreComment(
                        postId, commentId),
                  )
                else
                  AdminActionButton(
                    icon: Icons.visibility_off_rounded,
                    label: 'Ocultar',
                    color: AppColors.textSecondary,
                    onTap: () =>
                        commentService.hideComment(postId, commentId),
                  ),
                const SizedBox(width: 8),
                AdminActionButton(
                  icon: Icons.delete_rounded,
                  label: 'Excluir',
                  color: const Color(0xFFEF5350),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => const AdminConfirmDialog(
                        title: 'Excluir comentário?',
                        message: 'Esta ação não pode ser desfeita.',
                        confirmLabel: 'Excluir',
                        confirmColor: Color(0xFFEF5350),
                      ),
                    );
                    if (confirm == true) {
                      commentService.deleteComment(postId, commentId);
                    }
                  },
                ),
              ],
            ),
            if (authorId != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdminActionButton(
                    icon: Icons.person_off_rounded,
                    label: 'Banir usuário',
                    color: const Color(0xFFFF9800),
                    onTap: () async {
                      final result =
                          await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (_) =>
                            BanUserDialog(authorName: author),
                      );
                      if (result != null) {
                        await userService.suspendUser(
                          authorId,
                          result['days'] as int,
                          result['reason'] as String,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$author foi banido por ${result['days'] == 0 ? 'tempo indeterminado' : '${result['days']} dias'}.'),
                              backgroundColor:
                                  const Color(0xFFFF9800),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
