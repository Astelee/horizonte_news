import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/premium_config.dart';
import 'subscription_request_service.dart';

// ═══════════════════════════════════════════════════════════════════
// PURCHASE SERVICE — assinaturas Premium via Google Play Billing
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para o fluxo de compra: consulta os produtos
// cadastrados no Play Console e dispara a compra.
//
// APROVAÇÃO MANUAL (sem liberação automática):
// Quando o Google Play confirma a compra (PurchaseStatus.purchased ou
// .restored), o app NÃO valida a compra contra nenhum servidor nem
// grava premiumTier/premiumExpiresAt diretamente. Em vez disso, cria
// uma solicitação de assinatura pendente em `subscriptionRequests`
// (ver SubscriptionRequestService) e avisa os administradores — o
// Premium só é ativado quando um admin aprova manualmente pelo
// painel (ver AdminSubscriptionRequestService.approve, que usa o
// MESMO AdminUserService.grantPremium da concessão manual).
//
// O antigo Cloudflare Worker de validação automática NÃO é mais
// chamado por este serviço: ele existia só para confirmar a compra
// na Play Developer API e liberar o Premium sozinho, o que o novo
// fluxo de aprovação manual substitui por completo. As regras do
// Firestore continuam bloqueando o app de escrever premiumTier/
// premiumExpiresAt diretamente (ver firestore.rules) — só admin (via
// aprovação) ou a própria concessão manual no painel podem gravar
// esses campos.
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

  /// Chamar uma vez no início do app (ex.: junto do UserXpProvider),
  /// para que compras feitas fora da tela Premium (ex.: retomadas
  /// pelo Google após reinício do app) também sejam processadas.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final available = await _iap.isAvailable();
    if (!available) return;

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
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

  /// Inicia a compra de uma assinatura. O resultado (solicitação
  /// registrada, erro, pendente) chega depois, de forma assíncrona,
  /// por [purchaseResults].
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
  /// purchaseStream tratado em [_handlePurchaseUpdates]. Uma compra
  /// restaurada também não libera Premium sozinha — se ainda não
  /// houver solicitação aprovada para ela, cai no mesmo fluxo de
  /// aprovação manual.
  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
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
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _resultController.add(
            const PurchaseResult(PurchaseResultStatus.cancelled),
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // IMPORTANTE: não liberar Premium automaticamente aqui.
          // A compra em si já foi concluída no Google Play — isso
          // não é burlado nem revertido —, mas o Premium só é
          // ativado depois que um admin aprovar a solicitação
          // correspondente pelo painel.
          final registered = await _registerPendingRequest(purchase);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (registered) {
            _resultController.add(
              const PurchaseResult(PurchaseResultStatus.pendingApproval),
            );
          } else {
            _resultController.add(
              const PurchaseResult(
                PurchaseResultStatus.error,
                message:
                    'A compra foi concluída, mas não foi possível '
                    'registrar sua solicitação agora. Toque em '
                    '"Restaurar compras" em alguns instantes ou fale '
                    'com o suporte.',
              ),
            );
          }
          break;
      }
    }
  }

  /// Registra a solicitação de assinatura pendente (ver
  /// SubscriptionRequestService) a partir de uma compra já confirmada
  /// pelo Google Play. Retorna true se a solicitação foi criada com
  /// sucesso.
  Future<bool> _registerPendingRequest(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final tier = PremiumProductIds.tierFor(purchase.productID);
    if (tier == PremiumTier.none) return false;

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