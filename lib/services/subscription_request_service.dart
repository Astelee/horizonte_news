import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// SUBSCRIPTION REQUEST SERVICE — aprovação manual de assinaturas
// ═══════════════════════════════════════════════════════════════════
// Depois que o Google Play Billing confirma a compra (PurchaseStatus.
// purchased/restored), o app NÃO libera mais o Premium sozinho nem
// chama um Worker externo para validar automaticamente. Em vez disso,
// grava um documento em `subscriptionRequests/{autoId}` com
// status "pendente" e dispara um push para os administradores. O
// Premium só é ativado quando um admin aprova pelo painel (ver
// AdminSubscriptionRequestService), reaproveitando o MESMO
// AdminUserService.grantPremium já usado para concessão manual.
//
// O documento da compra NUNCA é escrito pelo app com status diferente
// de "pendente" — as regras do Firestore (subscriptionRequests) só
// permitem ao dono criar com status: 'pendente' e nunca mais alterar
// depois; só admin pode mudar o status.
// ═══════════════════════════════════════════════════════════════════

class SubscriptionRequestService {
  SubscriptionRequestService._internal();
  static final SubscriptionRequestService instance =
      SubscriptionRequestService._internal();

  final _db = FirebaseFirestore.instance;
  final _http = http.Client();

  static const String _appId = '999de6a2-1965-4cb0-9558-a0cc8ed39828';
  static const String _restApiKey =
      String.fromEnvironment('ONESIGNAL_REST_API_KEY');
  static const String _oneSignalEndpoint =
      'https://onesignal.com/api/v1/notifications';

  CollectionReference get _requests =>
      _db.collection('subscriptionRequests');

  /// Cria a solicitação de assinatura pendente para o usuário logado
  /// e avisa os administradores por push. Não libera Premium — isso
  /// só acontece quando um admin aprova pelo painel.
  ///
  /// [productId] é o ID exato do produto comprado no Google Play
  /// (ver PremiumProductIds), usado tanto para exibição no painel
  /// quanto para saber qual tier conceder na aprovação.
  Future<void> createPendingRequest({
    required String productId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tier = PremiumProductIds.tierFor(productId);
    if (tier == PremiumTier.none) return;

    // Nome de exibição: displayName do Firebase Auth, com fallback
    // para o e-mail — o app sempre tem pelo menos um dos dois após
    // o cadastro (ver register_screen.dart).
    final userName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email ?? 'Usuário');

    final docRef = await _requests.add({
      'uid': user.uid,
      'userName': userName,
      'userEmail': user.email ?? '',
      'plan': tier.id, // 'pro' ou 'ultra'
      'productId': productId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pendente',
    });

    await _notifyAdmins(
      requestId: docRef.id,
      userName: userName,
      planLabel: tier.label,
    );
  }

  /// Envia um push individual (via External ID do OneSignal) para
  /// cada administrador cadastrado em `admins/`. Reaproveita a MESMA
  /// REST API Key e app_id já usados por PushNotificationService e
  /// AppNotificationService — e o mesmo mecanismo de External ID
  /// (uid do Firebase, associado no login por
  /// NotificationService.loginExternalUser) para mirar só neles, sem
  /// avisar os demais usuários.
  ///
  /// Silencioso em caso de falha: a solicitação já foi gravada no
  /// Firestore (fonte de verdade) e vai aparecer no painel do admin
  /// mesmo que o push não chegue.
  Future<void> _notifyAdmins({
    required String requestId,
    required String userName,
    required String planLabel,
  }) async {
    if (_restApiKey.isEmpty) {
      debugPrint(
        'Push de nova assinatura não enviado: ONESIGNAL_REST_API_KEY '
        'ausente neste build.',
      );
      return;
    }

    try {
      final adminsSnap = await _db.collection('admins').get();
      final adminUids = adminsSnap.docs.map((d) => d.id).toList();
      if (adminUids.isEmpty) return;

      final response = await _http.post(
        Uri.parse(_oneSignalEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': adminUids,
          },
          'target_channel': 'push',
          'headings': {'en': 'Nova solicitação de assinatura'},
          'contents': {
            'en': '$userName solicitou o plano $planLabel.',
          },
          'data': {
            'kind': 'subscription_request',
            'requestId': requestId,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Falha ao notificar admins sobre nova assinatura '
          '(${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Erro ao notificar admins sobre nova assinatura: $e');
    }
  }
}