import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/premium_config.dart';
import 'backend_client.dart';
import 'subscription_request_service.dart';

// ═══════════════════════════════════════════════════════════════════
// PURCHASE SERVICE — assinaturas Premium via Google Play Billing
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para o fluxo de compra: consulta os produtos
// cadastrados no Play Console e dispara a compra.
//
// DOIS MODOS (escolhidos pelo build, ver BackendClient.isConfigured):
//
// 1) BACKEND ATIVO (--dart-define=BACKEND_URL=...): depois que o Google
//    Play confirma a compra, o app entrega o `purchaseToken` ao backend
//    (/v1/billing/verify). O backend consulta a Google Play Developer API,
//    confere produto/conta, reconhece (acknowledge) a compra e libera o
//    Premium sozinho — renovação, cancelamento, reembolso e expiração
//    chegam depois por notificações do Google (RTDN). O app NUNCA grava
//    premiumTier/premiumExpiresAt e só conclui a compra no Google depois
//    que o backend confirmou.
//
// 2) SEM BACKEND (modo antigo, aprovação manual): cria uma solicitação
//    pendente em `subscriptionRequests` e um admin aprova pelo painel.
//    Continua valendo até o backend estar configurado e testado, para não
//    mudar nada em produção antes da hora.
//
// Em ambos os modos o serviço é iniciado junto com o login (main.dart),
// não só na tela Premium — assim compras interrompidas (app fechado,
// sem internet, pagamento que só compensou depois) são processadas no
// próximo início do app, e o Google entrega de novo tudo que ainda não
// foi concluído. Premium nunca é concedido sem validação.
// ═══════════════════════════════════════════════════════════════════

/// IDs de produto que devem ser cadastrados EXATAMENTE assim no
/// Google Play Console (Monetizar → Produtos → Assinaturas).
class PremiumProductIds {
  static const String pro = 'premium_pro_mensal';
  static const String ultra = 'premium_ultra_mensal';

  static const Set<String> all = {pro, ultra};

  static PremiumTier tierFor(String productId) {
    switch (productId) {
      case pro:
        return PremiumTier.pro;
      case ultra:
        return PremiumTier.ultra;
      default:
        return PremiumTier.none;
    }
  }
}

enum PurchaseResultStatus {
  /// O backend validou a compra no Google Play e o Premium já está ativo.
  activated,

  /// A compra foi confirmada pelo Google Play e a solicitação de
  /// assinatura foi registrada, aguardando aprovação do admin. Ainda
  /// NÃO significa que o Premium está ativo.
  pendingApproval,
  pending,
  error,
  cancelled,
}

class PurchaseResult {
  final PurchaseResultStatus status;
  final String? message;
  const PurchaseResult(this.status, {this.message});
}

class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final _requestService = SubscriptionRequestService.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final _resultController = StreamController<PurchaseResult>.broadcast();

  /// Emite o resultado de cada compra processada, para a UI (tela
  /// Premium) mostrar feedback sem precisar conhecer os detalhes do
  /// Google Play Billing.
  Stream<PurchaseResult> get purchaseResults => _resultController.stream;

  bool _initialized = false;

  // Tokens em processamento agora (o Google pode entregar a mesma compra
  // duas vezes seguidas: purchaseStream + restore).
  final Set<String> _inFlight = <String>{};

  // Quantas novas tentativas já foram agendadas por compra (backend fora
  // do ar / sem internet). Limitado — depois disso o Google entrega de
  // novo no próximo início do app.
  final Map<String, int> _retries = <String, int>{};
  static const List<Duration> _retryDelays = [
    Duration(seconds: 20),
    Duration(seconds: 90),
    Duration(minutes: 5),
  ];

  /// Iniciar logo após o login (main.dart). Idempotente. Se o Google Play
  /// Billing ainda não estiver disponível, uma chamada futura tenta de novo.
  Future<void> initialize() async {
    if (_initialized) return;

    bool available;
    try {
      available = await _iap.isAvailable();
    } catch (e) {
      debugPrint('Google Play Billing indisponível: $e');
      return;
    }
    if (!available || _initialized) return;
    _initialized = true;

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _subscription?.cancel();
        _subscription = null;
        _initialized = false;
      },
      onError: (Object e) => debugPrint('Erro no purchaseStream: $e'),
    );
  }

  Future<bool> get isAvailable => _iap.isAvailable();

  /// Busca os planos cadastrados no Play Console. Retorna lista vazia
  /// se ainda não houver nenhum produto ativo — a tela Premium deve
  /// tratar isso mostrando os cards como "indisponível" em vez de
  /// travar a compra.
  Future<List<ProductDetails>> loadProducts() async {
    final response = await _iap.queryProductDetails(PremiumProductIds.all);
    if (response.error != null) {
      debugPrint('Erro ao carregar produtos Premium: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'Product IDs não encontrados no Play Console: ${response.notFoundIDs}',
      );
    }
    return response.productDetails;
  }

  /// Inicia a compra de uma assinatura. O resultado (Premium ativado,
  /// solicitação registrada, erro, pendente) chega depois, de forma
  /// assíncrona, por [purchaseResults].
  ///
  /// `applicationUserName` = uid do Firebase: o Google devolve esse valor
  /// na validação (obfuscatedExternalAccountId) e o backend só libera a
  /// compra para a MESMA conta que pagou.
  Future<void> buy(ProductDetails product) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _resultController.add(
        const PurchaseResult(
          PurchaseResultStatus.error,
          message: 'Faça login para assinar o Premium.',
        ),
      );
      return;
    }

    await initialize();

    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: uid,
    );

    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _resultController.add(
        PurchaseResult(
          PurchaseResultStatus.error,
          message: 'Não foi possível iniciar a compra: $e',
        ),
      );
    }
  }

  /// Dispara o fluxo de restauração de compras do Google Play. O
  /// resultado (se havia algo para restaurar) chega pelo mesmo
  /// purchaseStream tratado em [_handlePurchaseUpdates] e passa pela
  /// MESMA validação de uma compra nova.
  Future<void> restore() async {
    await initialize();
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      try {
        await _handleOne(purchase);
      } catch (e) {
        // Uma compra com problema não pode travar as seguintes.
        debugPrint('Erro ao processar compra ${purchase.productID}: $e');
        _resultController.add(
          const PurchaseResult(
            PurchaseResultStatus.error,
            message: 'Não foi possível processar a compra agora. '
                'Toque em "Restaurar compras" em alguns instantes.',
          ),
        );
      }
    }
  }

  Future<void> _handleOne(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _resultController.add(
          const PurchaseResult(PurchaseResultStatus.pending),
        );
        break;

      case PurchaseStatus.error:
        _resultController.add(
          PurchaseResult(
            PurchaseResultStatus.error,
            message: purchase.error?.message ??
                'Ocorreu um erro ao processar a compra.',
          ),
        );
        await _complete(purchase);
        break;

      case PurchaseStatus.canceled:
        _resultController.add(
          const PurchaseResult(PurchaseResultStatus.cancelled),
        );
        await _complete(purchase);
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _processConfirmedPurchase(purchase);
        break;
    }
  }

  /// Conclui a compra no Google Play (acknowledge). Nunca lança exceção.
  Future<void> _complete(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('Erro ao concluir compra ${purchase.productID}: $e');
    }
  }

  Future<void> _processConfirmedPurchase(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    // Sem login não dá para validar nem vincular a compra a uma conta.
    // NÃO concluímos: o Google entrega de novo no próximo início.
    if (user == null) return;

    final tier = PremiumProductIds.tierFor(purchase.productID);
    if (tier == PremiumTier.none) {
      // Produto que não é do Premium: não é assunto deste serviço.
      await _complete(purchase);
      return;
    }

    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      _resultController.add(
        const PurchaseResult(
          PurchaseResultStatus.error,
          message: 'Compra sem comprovante. Fale com o suporte.',
        ),
      );
      return;
    }
    if (!_inFlight.add(token)) return; // já em andamento

    try {
      if (BackendClient.isConfigured) {
        await _verifyWithBackend(purchase, token);
      } else {
        await _registerManualRequest(purchase);
      }
    } finally {
      _inFlight.remove(token);
    }
  }

  // ── Modo 1: validação no backend ────────────────────────────────────
  Future<void> _verifyWithBackend(
    PurchaseDetails purchase,
    String token,
  ) async {
    final res = await BackendClient.instance.post(
      '/v1/billing/verify',
      {'productId': purchase.productID, 'purchaseToken': token},
    );

    if (res != null && res.ok) {
      _retries.remove(token);
      final entitled = res.body['entitled'] == true;
      if (entitled) {
        await _complete(purchase);
        _resultController.add(
          const PurchaseResult(PurchaseResultStatus.activated),
        );
      } else {
        // Compra existe mas ainda não vale (pagamento em análise/em
        // espera). O Google avisa o backend quando mudar.
        _resultController.add(
          const PurchaseResult(PurchaseResultStatus.pending),
        );
      }
      return;
    }

    if (res == null || res.isTransient) {
      // Backend fora do ar / sem internet: NÃO conclui a compra (o Google
      // entrega de novo) e tenta novamente em instantes.
      _scheduleRetry(purchase, token);
      _resultController.add(
        const PurchaseResult(
          PurchaseResultStatus.error,
          message: 'Não foi possível validar sua compra agora. Vamos tentar '
              'de novo automaticamente — seu Premium será liberado assim '
              'que a validação concluir.',
        ),
      );
      return;
    }

    // Recusa definitiva (compra de outra conta, produto inválido,
    // comprovante inexistente...). Não libera nada.
    _resultController.add(
      PurchaseResult(
        PurchaseResultStatus.error,
        message: _friendlyBackendError(res),
      ),
    );
  }

  void _scheduleRetry(PurchaseDetails purchase, String token) {
    final attempt = _retries[token] ?? 0;
    if (attempt >= _retryDelays.length) return;
    _retries[token] = attempt + 1;
    Future.delayed(_retryDelays[attempt], () async {
      if (FirebaseAuth.instance.currentUser == null) return;
      if (!_inFlight.add(token)) return;
      try {
        await _verifyWithBackend(purchase, token);
      } catch (e) {
        debugPrint('Nova tentativa de validação falhou: $e');
      } finally {
        _inFlight.remove(token);
      }
    });
  }

  String _friendlyBackendError(BackendResponse res) {
    switch (res.error) {
      case 'purchase_belongs_to_other_account':
      case 'purchase_account_mismatch':
        return 'Esta assinatura pertence a outra conta do Horizonte News. '
            'Entre com a conta que fez a compra.';
      case 'purchase_not_found':
      case 'invalid_purchase_token':
        return 'O Google Play não reconheceu esta compra.';
      case 'unauthorized':
        return 'Sua sessão expirou. Entre novamente e toque em '
            '"Restaurar compras".';
      default:
        return 'Não foi possível validar a compra '
            '(${res.error ?? res.statusCode}). Fale com o suporte.';
    }
  }

  // ── Modo 2: aprovação manual (sem backend) ──────────────────────────
  Future<void> _registerManualRequest(PurchaseDetails purchase) async {
    final registered = await _registerPendingRequest(purchase);
    if (registered) {
      // Só conclui no Google depois de registrar a solicitação — se o
      // registro falhar (sem internet), o Google entrega de novo.
      await _complete(purchase);
      _resultController.add(
        const PurchaseResult(PurchaseResultStatus.pendingApproval),
      );
    } else {
      _resultController.add(
        const PurchaseResult(
          PurchaseResultStatus.error,
          message: 'A compra foi concluída, mas não foi possível '
              'registrar sua solicitação agora. Toque em '
              '"Restaurar compras" em alguns instantes ou fale '
              'com o suporte.',
        ),
      );
    }
  }

  /// Registra a solicitação de assinatura pendente (ver
  /// SubscriptionRequestService) a partir de uma compra já confirmada
  /// pelo Google Play. Retorna true se a solicitação existe (criada agora
  /// ou já registrada antes) ou se o plano já está ativo.
  Future<bool> _registerPendingRequest(PurchaseDetails purchase) async {
    try {
      await _requestService.createPendingRequest(
        productId: purchase.productID,
      );
      return true;
    } catch (e) {
      debugPrint('Erro ao registrar solicitação de assinatura: $e');
      return false;
    }
  }

  /// No Android, trocar de plano (ex.: Pro → Ultra) usa
  /// GooglePlayPurchaseParam + ChangeSubscriptionParam em vez de
  /// buyNonConsumable simples — não implementado aqui de propósito:
  /// a maioria dos apps trata upgrade/downgrade como "cancelar o
  /// atual na Play Store e assinar o outro", que já funciona com o
  /// fluxo padrão de buy() acima. Se quiser oferecer troca direta no
  /// futuro, use ReplacementMode do pacote in_app_purchase_android.

  void dispose() {
    _subscription?.cancel();
    _resultController.close();
  }
}