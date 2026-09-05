import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lado do usuário da moderação manual de fotos de perfil.
///
/// Registra a foto recém-enviada (já hospedada no Cloudinary, via
/// AvatarUploadService) como pendente de aprovação, sem tocar no
/// campo `photoUrl` público em `users_xp` — só um admin, pelo painel,
/// pode promovê-la a foto pública (ver AdminAvatarApprovalService).
class AvatarApprovalService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _approvals => _db.collection('avatarApprovals');

  /// Envia a nova foto para a fila de aprovação. Sobrescreve qualquer
  /// pendência anterior do mesmo usuário (só a mais recente importa).
  Future<void> submitForApproval({
    required String uid,
    required String userName,
    required String newPhotoUrl,
    String? previousPhotoUrl,
  }) async {
    await _approvals.doc(uid).set({
      'uid': uid,
      'userName': userName,
      'pendingPhotoUrl': newPhotoUrl,
      'previousPhotoUrl': previousPhotoUrl,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
    });
  }

  /// Status da última submissão do usuário atual (ou null se nunca
  /// enviou nenhuma, ou não está logado).
  Stream<DocumentSnapshot>? myApprovalStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _approvals.doc(uid).snapshots();
  }
}