import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lado do usuário da moderação manual de fotos de perfil.
class AvatarApprovalService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _approvals =>
      _db.collection('avatarApprovals');

  Future<void> submitForApproval({
    required String uid,
    required String userName,
    required String newPhotoUrl,
    String? previousPhotoUrl,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    debugPrint('========== AVATAR APPROVAL ==========');
    debugPrint('UID recebido: $uid');
    debugPrint('UID autenticado: ${currentUser?.uid}');
    debugPrint('Usuário autenticado: ${currentUser != null}');
    debugPrint('Nome: $userName');
    debugPrint('URL nova: $newPhotoUrl');
    debugPrint('URL anterior: $previousPhotoUrl');

    if (currentUser == null) {
      throw Exception(
        'Usuário não está autenticado no Firebase Auth.',
      );
    }

    if (currentUser.uid != uid) {
      throw Exception(
        'UID divergente. '
        'Autenticado: ${currentUser.uid} | '
        'Recebido: $uid',
      );
    }

    if (newPhotoUrl.trim().isEmpty) {
      throw Exception(
        'A URL da nova foto está vazia.',
      );
    }

    final data = {
      'uid': uid,
      'userName': userName,
      'pendingPhotoUrl': newPhotoUrl,
      'previousPhotoUrl': previousPhotoUrl,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
    };

    debugPrint('Gravando em: avatarApprovals/$uid');
    debugPrint('Dados: $data');

    try {
      await _approvals.doc(uid).set(data);

      debugPrint(
        'AVATAR APPROVAL: gravação concluída com sucesso.',
      );
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'AVATAR APPROVAL FIREBASE ERROR',
      );
      debugPrint('Código: ${e.code}');
      debugPrint('Mensagem: ${e.message}');
      debugPrint('$stackTrace');

      throw Exception(
        'Firestore ${e.code}: ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AVATAR APPROVAL ERROR: $e',
      );
      debugPrint('$stackTrace');

      rethrow;
    }
  }

  Stream<DocumentSnapshot>? myApprovalStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return null;
    }

    return _approvals.doc(uid).snapshots();
  }
}
