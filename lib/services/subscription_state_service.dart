import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/premium_config.dart';
import 'backend_client.dart';

// ═══════════════════════════════════════════════════════════════════
// ESTADO DA ASSINATURA (somente leitura) — usado pelo perfil, pela tela
// Premium e por "Minha assinatura".
// ═══════════════════════════════════════════════════════════════════
// • Plano/validade: users_xp/{uid} em tempo real (o app NUNCA grava ali).
//   Assim o banner do perfil muda sozinho quando a assinatura começa,
//   vence ou é revogada, e também no horário exato do vencimento.
// • Detalhes (início, renovação, cancelamento agendado, carência) e a
//   trava de compra vêm do BACKEND (/v1/billing/status), que é a fonte
//   da verdade. Sem BACKEND_URL no build, só o estado local existe.
// ═══════════════════════════════════════════════════════════════════

/// Formata dd/MM/aaaa sem depender de intl.
String formatDatePt(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/${l.year}';
}

DateTime? _parseDate(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

class SubscriptionSnapshot {
  final PremiumTier tier;
  final DateTime? expiresAt;

  /// Plano liberado pela Google Play (premiumSource == 'play').
  final bool fromPlay;

  /// Cortesia de teste do admin.
  final bool trial;
  final bool loaded;

  const SubscriptionSnapshot({
    required this.tier,
    required this.expiresAt,
    required this.fromPlay,
    required this.trial,
    required this.loaded,
  });

  const SubscriptionSnapshot.empty()
      : tier = PremiumTier.none,
        expiresAt = null,
        fromPlay = false,
        trial = false,
        loaded = false;

  bool get hasAccess => tier.isPremium;
}

class SubscriptionDetails {
  final PremiumTier tier;
  final String state;
  final bool benefitsActive;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final bool autoRenewing;
  final bool cancelScheduled;
  final bool inGracePeriod;
  final bool onHold;

  const SubscriptionDetails({
    required this.tier,
    required this.state,
    required this.benefitsActive,
    required this.startedAt,
    required this.expiresAt,
    required this.autoRenewing,
    required this.cancelScheduled,
    required this.inGracePeriod,
    required this.onHold,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> j) {
    return SubscriptionDetails(
      tier: PremiumTierX.fromId(j['tier'] as String?),
      state: (j['state'] as String?) ?? '',
      benefitsActive: j['benefitsActive'] == true,
      startedAt: _parseDate(j['startedAt']),
      expiresAt: _parseDate(j['expiresAt']),
      autoRenewing: j['autoRenewing'] == true,
      cancelScheduled: j['cancelScheduled'] == true,
      inGracePeriod: j['inGracePeriod'] == true,
      onHold: j['onHold'] == true,
    );
  }
}

class ManualGrant {
  final PremiumTier tier;
  final DateTime? expiresAt;
  final bool trial;
  const ManualGrant(this.tier, this.expiresAt, this.trial);
}

class BillingStatus {
  /// true = existe assinatura em vigor (inclui cancelada-mas-paga, carência
  /// e pagamento em espera): PRO e ULTRA ficam bloqueados para nova compra.
  final bool blocksPurchase;
  final SubscriptionDetails? subscription;
  final ManualGrant? manualGrant;

  const BillingStatus({
    required this.blocksPurchase,
    required this.subscription,
    required this.manualGrant,
  });

  factory BillingStatus.fromJson(Map<String, dynamic> j) {
    final sub = j['subscription'];
    final manual = j['manualGrant'];
    return BillingStatus(
      blocksPurchase: j['blocksPurchase'] == true,
      subscription: sub is Map<String, dynamic>
          ? SubscriptionDetails.fromJson(sub)
          : null,
      manualGrant: manual is Map<String, dynamic>
          ? ManualGrant(
              PremiumTierX.fromId(manual['tier'] as String?),
              _parseDate(manual['expiresAt']),
              manual['trial'] == true,
            )
          : null,
    );
  }
}

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String packageName = 'com.astelee.horizonte_news';

  /// Página oficial de assinaturas da Google Play.
  static Uri manageUri({String? productId}) => Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        {
          'package': packageName,
          if (productId != null) 'sku': productId,
        },
      );

  final ValueNotifier<SubscriptionSnapshot> snapshot =
      ValueNotifier(const SubscriptionSnapshot.empty());
  final ValueNotifier<BillingStatus?> status = ValueNotifier(null);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  Timer? _expiryTimer;
  Map<String, dynamic>? _lastData;
  bool _started = false;

  /// Idempotente. Acompanha login/logout sozinho.
  void ensureStarted() {
    if (_started) return;
    _started = true;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_attach);
    _attach(FirebaseAuth.instance.currentUser);
  }

  void _attach(User? user) {
    _docSub?.cancel();
    _docSub = null;
    _expiryTimer?.cancel();
    _lastData = null;
    status.value = null;
    if (user == null) {
      snapshot.value = const SubscriptionSnapshot.empty();
      return;
    }
    _docSub = FirebaseFirestore.instance
        .collection('users_xp')
        .doc(user.uid)
        .snapshots()
        .listen(
      (snap) {
        _lastData = snap.data();
        _apply();
      },
      onError: (Object e) {
        debugPrint('SubscriptionService: $e');
        snapshot.value = const SubscriptionSnapshot(
          tier: PremiumTier.none,
          expiresAt: null,
          fromPlay: false,
          trial: false,
          loaded: true,
        );
      },
    );
  }

  void _apply() {
    final data = _lastData ?? const <String, dynamic>{};
    final tier = premiumTierFromData(data);
    final exp = data['premiumExpiresAt'];
    final expiresAt = exp is Timestamp ? exp.toDate() : null;
    final prev = snapshot.value;
    final next = SubscriptionSnapshot(
      tier: tier,
      expiresAt: tier.isPremium ? expiresAt : null,
      fromPlay: tier.isPremium && data['premiumSource'] == 'play',
      trial: tier.isPremium && data['premiumTrial'] == true,
      loaded: true,
    );
    snapshot.value = next;

    // Na hora exata do vencimento, reavalia (o Firestore não emite evento).
    _expiryTimer?.cancel();
    if (tier.isPremium && expiresAt != null) {
      final wait = expiresAt.difference(DateTime.now());
      if (wait > Duration.zero && wait < const Duration(days: 30)) {
        _expiryTimer = Timer(wait + const Duration(seconds: 1), _apply);
      }
    }

    // Plano mudou (comprou, renovou, venceu, revogou): atualiza detalhes.
    if (prev.loaded &&
        (prev.tier != next.tier || prev.expiresAt != next.expiresAt)) {
      unawaited(refreshStatus());
    }
  }

  /// Consulta o backend. Devolve null se não houver backend/rede — quem
  /// chama então usa só o estado local.
  Future<BillingStatus?> refreshStatus() async {
    final res = await BackendClient.instance.post('/v1/billing/status', {});
    if (res == null || !res.ok) return null;
    final s = BillingStatus.fromJson(res.body);
    status.value = s;
    return s;
  }
}