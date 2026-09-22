import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/premium_config.dart';
import 'admin_user_service.dart';

/// Aprovação manual de assinaturas (PRO/ULTRA compradas via Google
/// Play Billing).
///
/// Fluxo: depois que o Google Play confirma a compra, o app grava a
/// solicitação em `subscriptionRequests/{autoId}` com status
/// "pendente" (ver SubscriptionRequestService) — o Premium NÃO é
/// liberado nesse momento. Só quando um admin aprova aqui pelo
/// painel é que o Premium é ativado, reaproveitando o MESMO
/// AdminUserService.grantPremium já usado na concessão manual (mesmos
/// campos premiumTier/premiumExpiresAt em users_xp/{uid}).
class AdminSubscriptionRequestService {
  final _db = FirebaseFirestore.instance;
  final _userService = AdminUserService();

  CollectionReference get _requests =>
      _db.collection('subscriptionRequests');

  /// Duração padrão de uma assinatura aprovada (planos são mensais).
  static const Duration _subscriptionDuration = Duration(days: 30);

  /// Solicitações aguardando revisão, mais antigas primeiro (fila).
  Stream<QuerySnapshot> pendingStream() {
    return _requests
        .where('status', isEqualTo: 'pendente')
        .orderBy('requestedAt', descending: false)
        .snapshots();
  }

  /// Aprova a solicitação: ativa o Premium correspondente para o UID
  /// (via AdminUserService.grantPremium — mesma trava de admin já
  /// usada na concessão manual), marca a solicitação como "aprovado",
  /// mantém a data da aprovação e registra qual admin aprovou.
  Future<void> approve({
    required String requestId,
    required String uid,
    required PremiumTier tier,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;

    await _userService.grantPremium(
      uid,
      tier,
      expiresAt: DateTime.now().add(_subscriptionDuration),
    );

    await _requests.doc(requestId).update({
      'status': 'aprovado',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.uid,
      'reviewedByName': admin?.displayName ?? admin?.email ?? 'Admin',
    });

    await _log('approve_subscription_request', uid, extra: {
      'requestId': requestId,
      'tier': tier.id,
    });
  }

  /// Recusa a solicitação: marca como "recusado" e NÃO libera Premium.
  Future<void> reject({
    required String requestId,
    required String uid,
    String? reason,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;

    await _requests.doc(requestId).update({
      'status': 'recusado',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.uid,
      'reviewedByName': admin?.displayName ?? admin?.email ?? 'Admin',
      if (reason != null && reason.trim().isNotEmpty)
        'rejectionReason': reason.trim(),
    });

    await _log('reject_subscription_request', uid, extra: {
      'requestId': requestId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
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
        'targetType': 'subscription_request',
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}