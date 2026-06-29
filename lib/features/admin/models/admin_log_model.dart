import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLogModel {
  final String id;
  final String adminUid;
  final String adminName;
  final String action;
  final String targetId;
  final String targetType;
  final String? postId;
  final DateTime timestamp;
  final Map<String, dynamic> extra;

  const AdminLogModel({
    required this.id,
    required this.adminUid,
    required this.adminName,
    required this.action,
    required this.targetId,
    required this.targetType,
    this.postId,
    required this.timestamp,
    this.extra = const {},
  });

  factory AdminLogModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdminLogModel(
      id: doc.id,
      adminUid: d['adminUid'] as String? ?? '',
      adminName: d['adminName'] as String? ?? 'Admin',
      action: d['action'] as String? ?? '',
      targetId: d['targetId'] as String? ?? '',
      targetType: d['targetType'] as String? ?? 'unknown',
      postId: d['postId'] as String?,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      extra: Map<String, dynamic>.from(
        d..remove('adminUid')
          ..remove('adminName')
          ..remove('action')
          ..remove('targetId')
          ..remove('targetType')
          ..remove('postId')
          ..remove('timestamp'),
      ),
    );
  }

  String get actionLabel {
    switch (action) {
      case 'hide_comment':    return 'Ocultou comentário';
      case 'restore_comment': return 'Restaurou comentário';
      case 'delete_comment':  return 'Excluiu comentário';
      case 'suspend_user':    return 'Baniu usuário';
      case 'unsuspend_user':  return 'Removeu banimento';
      case 'create_post':     return 'Publicou notícia';
      default:                return action;
    }
  }
}
