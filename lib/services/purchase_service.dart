import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// PURCHASE SERVICE — assinaturas Premium via Google Play Billing
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para o fluxo de compra: consulta os produtos
// cadastrados no Play Console, dispara a compra, escuta o resultado
// (compra nova, restaurada ou pendente) e envia o purchaseToken para
// o Worker de validação (Cloudflare) — é ELE quem valida a compra na
// Play Developer API e grava o tier Premium em users_xp/{uid}, não
// mais o app diretamente.
//
// VALIDAÇÃO DE SERVIDOR:
// O app não grava mais premiumTier/premiumExpiresAt diretamente no
// Firestore (as regras do Firestore inclusive bloqueiam isso, só
// admin pode escrever nesses campos). Em vez disso, chamamos o
// endpoint _validatorEndpoint abaixo, que confirma a compra contra a
// Play Developer API do Google antes de liberar o Premium — fechando
// o buraco de segurança de confiar só na resposta local do Google
// Play Billing.
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

/// URL do Cloudflare Worker que valida a compra na Play Developer API
/// e grava o Premium no Firestore (com privilégio de admin — o app
/// não tem mais permissão de gravar esses campos diretamente).
const String _validatorEndpoint =
    'https://horizonte-premium-validator.diego-magno321.workers.dev';

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
  final http.Client _http = http.Client();

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
          final validated = await _validateAndGrantPremium(purchase);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (validated) {
            _resultController.add(
              const PurchaseResult(PurchaseResultStatus.success),
            );
          } else {
            _resultController.add(
              const PurchaseResult(
                PurchaseResultStatus.error,
                message:
                    'Não foi possível confirmar sua compra. Se o valor foi '
                    'cobrado, tente "Restaurar compras" em alguns instantes '
                    'ou fale com o suporte.',
              ),
            );
          }
          break;
      }
    }
  }

  /// Envia a compra para o Worker de validação, que confirma o
  /// purchaseToken na Play Developer API do Google e só então grava
  /// premiumTier/premiumExpiresAt em users_xp/{uid} — com privilégio
  /// de admin, já que o app não tem mais permissão de gravar esses
  /// campos diretamente (ver firestore.rules).
  ///
  /// Retorna true se o Premium foi liberado com sucesso, false caso
  /// contrário (rede indisponível, compra inválida, uid não bate etc).
  Future<bool> _validateAndGrantPremium(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final tier = PremiumProductIds.tierFor(purchase.productID);
    if (tier == PremiumTier.none) return false;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null) return false;

      final response = await _http.post(
        Uri.parse(_validatorEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'productId': purchase.productID,
          'userId': user.uid,
          'idToken': idToken,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Validação de compra falhou (${response.statusCode}): '
          '${response.body}',
        );
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['ok'] == true;
    } catch (e) {
      debugPrint('Erro ao validar compra com o Worker: $e');
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
    _http.close();
  }
}