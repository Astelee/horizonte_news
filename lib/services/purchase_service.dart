import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// PURCHASE SERVICE — assinaturas Premium via Google Play Billing
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para o fluxo de compra: consulta os produtos
// cadastrados no Play Console, dispara a compra, escuta o resultado
// (compra nova, restaurada ou pendente) e grava o tier Premium em
// users_xp/{uid} — o mesmo campo que o admin usa em grantPremium.
//
// IMPORTANTE — validação de servidor:
// Este serviço libera o Premium confiando na resposta local do
// Google Play Billing (purchase.status == purchased/restored), sem
// validar o token de compra contra a Play Developer API num backend.
// Isso é suficiente para uso normal, mas não protege contra recibos
// forjados por um dispositivo modificado. Quando o projeto sair do
// plano Spark do Firebase (ou ganhar um Cloudflare Worker próprio
// para isso), o ideal é mover a chamada a completePurchase() e a
// gravação em users_xp para depois dessa validação server-side.
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

/// Resultado de diagnóstico de [PurchaseService.loadProductsDebug] —
/// mesmos dados que já eram logados via debugPrint, só que
/// estruturados para a UI poder exibi-los diretamente na tela.
class ProductQueryDebug {
  final List<ProductDetails> products;
  final List<String> notFoundIDs;
  final String? error;

  const ProductQueryDebug({
    required this.products,
    required this.notFoundIDs,
    required this.error,
  });
}

enum PurchaseResultStatus { success, pending, error, cancelled }

class PurchaseResult {
  final PurchaseResultStatus status;
  final String? message;
  const PurchaseResult(this.status, {this.message});
}

class PurchaseService {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    final result = await loadProductsDebug();
    return result.products;
  }

  /// Igual a [loadProducts], mas devolve também o motivo de qualquer
  /// produto não encontrado/erro — usado apenas para diagnóstico
  /// visível na tela (ver ProductQueryDebug), sem precisar de adb.
  Future<ProductQueryDebug> loadProductsDebug() async {
    final billingAvailable = await _iap.isAvailable();
    if (!billingAvailable) {
      return const ProductQueryDebug(
        products: [],
        notFoundIDs: [],
        error: 'Google Play Billing indisponível neste dispositivo/conta.',
      );
    }

    final response = await _iap.queryProductDetails(PremiumProductIds.all);
    if (response.error != null) {
      debugPrint('Erro ao carregar produtos Premium: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'Product IDs não encontrados no Play Console: ${response.notFoundIDs}',
      );
    }
    return ProductQueryDebug(
      products: response.productDetails,
      notFoundIDs: response.notFoundIDs,
      error: response.error?.message,
    );
  }

  /// Inicia a compra de uma assinatura. O resultado (sucesso, erro,
  /// pendente) chega depois, de forma assíncrona, por [purchaseResults].
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
  /// purchaseStream tratado em [_handlePurchaseUpdates].
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
          await _grantPremiumFor(purchase);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _resultController.add(
            const PurchaseResult(PurchaseResultStatus.success),
          );
          break;
      }
    }
  }

  /// Grava o tier Premium em users_xp/{uid}, no mesmo formato que o
  /// admin usa em AdminUserService.grantPremium — a diferença é que
  /// aqui a expiração é sempre "daqui a 1 mês", já que é uma
  /// assinatura mensal recorrente (o Google renova automaticamente
  /// enquanto ativa; se cancelada, simplesmente para de renovar e o
  /// campo expira sozinho na data prevista).
  Future<void> _grantPremiumFor(PurchaseDetails purchase) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tier = PremiumProductIds.tierFor(purchase.productID);
    if (tier == PremiumTier.none) return;

    final expiresAt = DateTime.now().add(const Duration(days: 32));

    await _db.collection('users_xp').doc(uid).update({
      'premiumTier': tier.id,
      'premiumExpiresAt': Timestamp.fromDate(expiresAt),
      'premiumPurchaseToken': purchase.verificationData.serverVerificationData,
      'premiumProductId': purchase.productID,
      'premiumUpdatedAt': FieldValue.serverTimestamp(),
    });
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