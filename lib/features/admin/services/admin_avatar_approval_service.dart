import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Moderação manual de fotos de perfil.
///
/// Fluxo: ao trocar a foto, o usuário sobe a imagem para o Cloudinary
/// normalmente (ver AvatarUploadService), mas ela NÃO vira a foto
/// pública na hora. Em vez disso, fica registrada aqui como pendente,
/// em `avatarApprovals/{uid}`, e o campo `photoUrl` de `users_xp/{uid}`
/// (o que aparece no ranking, nos comentários etc.) só é atualizado
/// quando um admin aprova pelo painel.
class AdminAvatarApprovalService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _approvals => _db.collection('avatarApprovals');

  /// Fotos aguardando revisão, mais antigas primeiro (fila).
  Stream<QuerySnapshot> pendingStream() {
    return _approvals
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: false)
        .snapshots();
  }

  /// Aprova a foto pendente do usuário: ela vira a foto pública
  /// (`photoUrl` em users_xp) e o registro de aprovação é marcado
  /// como aprovado.
  Future<void> approve({
    required String uid,
    required String pendingPhotoUrl,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;

    await _db.collection('users_xp').doc(uid).set(
      {'photoUrl': pendingPhotoUrl},
      SetOptions(merge: true),
    );

    await _approvals.doc(uid).set({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.uid,
    }, SetOptions(merge: true));

    await _log('approve_avatar', uid);
  }

  /// Rejeita a foto pendente: a foto pública não muda (permanece a
  /// anterior, se houver), e o registro é marcado como rejeitado.
  Future<void> reject({
    required String uid,
    String? reason,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;

    await _approvals.doc(uid).set({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.uid,
      if (reason != null && reason.trim().isNotEmpty)
        'rejectionReason': reason.trim(),
    }, SetOptions(merge: true));

    await _log('reject_avatar', uid, extra: {'reason': reason ?? ''});
  }

  Future<void> _log(
    String action,
    String targetId, {
    Map<String, dynamic>? extra,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('admin_logs').add({
        'adminUid': user.uid,
        'adminName': user.displayName ?? user.email ?? 'Admin',
        'action': action,
        'targetId': targetId,
        'targetType': 'avatar',
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}