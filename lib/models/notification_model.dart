import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de notificação suportados pela central de notificações.
/// Mantido como String (não enum puro) na gravação para facilitar
/// consultas/filtragem no Firestore e permitir novos tipos no futuro
/// sem migração.
class NotificationType {
  static const String commentReply = 'comment_reply';
  static const String commentLike = 'comment_like';
}

/// Notificação in-app (coleção `notifications`), usada pela central
/// de notificações (sino + tela) e como origem de dados para o push
/// via OneSignal.
class AppNotificationModel {
  final String id;

  /// Usuário que deve RECEBER a notificação.
  final String recipientUserId;

  /// Tipo: NotificationType.commentReply | NotificationType.commentLike
  final String type;

  /// Usuário que realizou a ação (quem respondeu / quem curtiu).
  final String actorUserId;
  final String actorUserName;
  final String? actorPhotoUrl;

  final String postId;
  final String postTitle;

  /// ID do comentário raiz envolvido (o que foi respondido/curtido,
  /// ou o comentário-pai quando a ação foi numa resposta).
  final String commentId;

  /// Preenchido apenas quando a ação ocorreu numa resposta (reply)
  /// em vez de num comentário raiz.
  final String? replyId;

  /// Prévia curta do texto da resposta (comment_reply) — não usado
  /// em comment_like.
  final String? previewText;

  final DateTime createdAt;
  final bool read;

  const AppNotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.actorUserId,
    required this.actorUserName,
    this.actorPhotoUrl,
    required this.postId,
    required this.postTitle,
    required this.commentId,
    this.replyId,
    this.previewText,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotificationModel(
      id: doc.id,
      recipientUserId: data['recipientUserId'] ?? '',
      type: data['type'] ?? '',
      actorUserId: data['actorUserId'] ?? '',
      actorUserName: data['actorUserName'] ?? 'Alguém',
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      postId: data['postId'] ?? '',
      postTitle: data['postTitle'] ?? '',
      commentId: data['commentId'] ?? '',
      replyId: data['replyId'] as String?,
      previewText: data['previewText'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
    );
  }

  String get message {
    switch (type) {
      case NotificationType.commentReply:
        return '$actorUserName respondeu ao seu comentário';
      case NotificationType.commentLike:
        return '$actorUserName curtiu seu comentário';
      default:
        return '$actorUserName interagiu com seu comentário';
    }
  }
}