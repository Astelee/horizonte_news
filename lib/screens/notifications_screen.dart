import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/notification_model.dart';
import '../services/app_notification_service.dart';
import '../screens/post_detail_screen.dart';
import '../services/news_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_messenger.dart';

/// Central de notificações — lista as notificações de "respondeu ao
/// seu comentário" e "curtiu seu comentário" do usuário logado, mais
/// recentes primeiro. Reutiliza a mesma paleta laranja/preto/branco
/// do resto do app (ver GUIA_DA_IA / preservação de identidade
/// visual pedida na tarefa).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _newsService = NewsService();
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    // Ao abrir a central, tudo que já está visível é considerado
    // "visto" — comportamento padrão da maioria dos apps (o badge
    // zera ao abrir a tela, não exige tocar item por item).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNotificationService.markAllAsRead();
    });
  }

  Future<void> _openNotification(AppNotificationModel notification) async {
    if (!notification.read) {
      AppNotificationService.markAsRead(notification.id);
    }
    try {
      final post = await _newsService.fetchById(notification.postId);
      if (post == null || !mounted) return;
      Navigator.of(context).pushNamed(
        '/post-detail',
        arguments: PostDetailArgs(
          post: post,
          highlightCommentId: notification.commentId,
          highlightReplyId: notification.replyId,
        ),
      );
    } catch (_) {
      if (mounted) {
        AppMessenger.error('Não foi possível abrir a notícia.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text(
          'Notificações',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _markingAll
                ? null
                : () async {
                    setState(() => _markingAll = true);
                    await AppNotificationService.markAllAsRead();
                    if (mounted) setState(() => _markingAll = false);
                  },
            child: const Text(
              'Marcar tudo como lido',
              style: TextStyle(color: AppColors.primaryOrange, fontSize: 12),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: AppNotificationService.watchMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 56, color: AppColors.textMuted.withOpacity(0.6)),
                    const SizedBox(height: 14),
                    const Text(
                      'Nenhuma notificação ainda',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quando alguém responder ou curtir seus '
                      'comentários, você vê aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted.withOpacity(0.8),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.borderSubtle),
            itemBuilder: (context, index) {
              final n = items[index];
              return _NotificationTile(
                notification: n,
                onTap: () => _openNotification(n),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.commentLike:
        return Icons.favorite_rounded;
      case NotificationType.commentReply:
      default:
        return Icons.reply_rounded;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.read
            ? Colors.transparent
            : AppColors.primaryOrange.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppAvatar(
                  name: notification.actorUserName,
                  seed: notification.actorUserId,
                  photoUrl: notification.actorPhotoUrl,
                  size: 42,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: notification.type == NotificationType.commentLike
                          ? AppColors.emergencyRed
                          : AppColors.primaryOrange,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.backgroundDark, width: 2),
                    ),
                    child: Icon(_icon, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, height: 1.35),
                      children: [
                        TextSpan(
                          text: notification.actorUserName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: notification.type ==
                                  NotificationType.commentLike
                              ? ' curtiu seu comentário'
                              : ' respondeu ao seu comentário',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (notification.previewText != null &&
                      notification.previewText!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${notification.previewText}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted.withOpacity(0.9),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!notification.read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}