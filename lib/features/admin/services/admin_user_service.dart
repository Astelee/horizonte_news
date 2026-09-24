import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../config/premium_config.dart';
import '../../../services/xp_service.dart';

class AdminUserService {
  final _db = FirebaseFirestore.instance;

  // ── Usuários ────────────────────────────────────────────────────

  Stream<QuerySnapshot> usersStream() {
    // Ordena por última vez que o usuário abriu o app (lastSeenAt),
    // do mais recente pro mais antigo. Usamos lastSeenAt em vez de
    // createdAt (data de cadastro) porque createdAt é fixo — quem se
    // cadastrou há mais tempo nunca subiria na lista, mesmo estando
    // online agora. lastSeenAt é atualizado toda vez que o app é
    // aberto ou retomado (ver UserXpProvider._updateLastSeen), então
    // reflete quem usou o app mais recentemente.
    return _db
        .collection('users_xp')
        .orderBy('lastSeenAt', descending: true)
        .snapshots();
  }

  // ── Suspensões ──────────────────────────────────────────────────

  Stream<QuerySnapshot> suspensionsStream() {
    return _db.collection('suspensions').snapshots();
  }

  Future<void> suspendUser(
    String userId,
    int days,
    String reason,
  ) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'suspended': true,
      'reason': reason,
      'suspendedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'suspendedAt': FieldValue.serverTimestamp(),
    };
    if (days > 0) {
      data['until'] = Timestamp.fromDate(now.add(Duration(days: days)));
    }
    await _db.collection('suspensions').doc(userId).set(data);
    await _log('suspend_user', userId,
        extra: {'days': days, 'reason': reason});
  }

  Future<void> unsuspendUser(String userId) async {
    await _db.collection('suspensions').doc(userId).delete();
    await _log('unsuspend_user', userId);
  }

  Future<Map<String, dynamic>?> getBanData(String userId) async {
    final doc = await _db.collection('suspensions').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final until = (data['until'] as Timestamp?)?.toDate();
    if (until != null && DateTime.now().isAfter(until)) return null;
    return data;
  }

  Future<bool> isUserSuspended(String userId) async {
    return (await getBanData(userId)) != null;
  }

  // ── Dados brutos de um usuário (para carregar o painel Poderes) ──

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users_xp').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Stream ao vivo do documento de UM usuário — usado pelo perfil
  /// administrativo individual (aberto sob demanda, não pela lista).
  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) {
    return _db.collection('users_xp').doc(uid).snapshots();
  }

  /// Histórico de ações administrativas sobre UM usuário específico
  /// (admin_logs.targetId == uid), carregado só quando o perfil é
  /// aberto — evita puxar o log inteiro do sistema para a lista.
  Stream<List<Map<String, dynamic>>> userLogsStream(
    String uid, {
    int limit = 30,
  }) {
    return _db
        .collection('admin_logs')
        .where('targetId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Status de suspensão de UM usuário, em tempo real — usado pelo
  /// perfil individual para refletir instantaneamente uma ação de
  /// suspender/remover suspensão feita ali mesmo.
  Stream<DocumentSnapshot<Map<String, dynamic>>> suspensionDocStream(
      String uid) {
    return _db.collection('suspensions').doc(uid).snapshots();
  }

  // ── Override de NÍVEL (moldura, XP, cor) ─────────────────────────

  Future<void> applyLevelOverride(String uid, int level) async {
    // Trava no teto real do sistema de níveis (XpService.maxLevel) —
    // evita salvar um nível acima do que a UI atual permite, mesmo
    // se o valor vier de uma chamada antiga/externa.
    final clamped = level.clamp(1, XpService.maxLevel).toInt();
    await _db.collection('users_xp').doc(uid).update({
      'level': clamped,
      'adminOverrideLevel': clamped,
      'adminOverrideActive': true,
    });
    await _log('level_override', uid, extra: {'level': clamped});
  }

  Future<void> resetLevelOverride(String uid, int realLevel) async {
    await _db.collection('users_xp').doc(uid).update({
      'level': realLevel,
      'adminOverrideActive': false,
      'adminOverrideLevel': FieldValue.delete(),
    });
    await _log('level_reset', uid);
  }

  // ── Override de TAG/TÍTULO (independente do nível) ───────────────

  Future<void> applyTitleOverride(String uid, int titleLevel) async {
    // titleLevel é o nível "de referência" cujo título/ícone será copiado —
    // não altera o nível real do usuário, só o texto exibido.
    await _db.collection('users_xp').doc(uid).update({
      'adminOverrideTitleLevel': titleLevel,
      'adminOverrideTitleActive': true,
    });
    await _log('title_override', uid, extra: {'titleLevel': titleLevel});
  }

  Future<void> resetTitleOverride(String uid) async {
    await _db.collection('users_xp').doc(uid).update({
      'adminOverrideTitleActive': false,
      'adminOverrideTitleLevel': FieldValue.delete(),
    });
    await _log('title_reset', uid);
  }

  // ── Plano Premium (PRO/ULTRA) — concessão manual pelo admin ───────
  // Enquanto a compra real (Google Play Billing) não está integrada,
  // esta é a única forma de um usuário virar Premium: usada tanto
  // para testar o sistema quanto para suporte manual (cortesia,
  // reembolso, compra feita por outro canal, etc.).
  //
  // Sempre que a validação de compra automática existir, ela deve
  // escrever esses MESMOS campos (premiumTier/premiumExpiresAt) via
  // Cloud Function com Admin SDK — que passa pela mesma regra
  // isAdmin() do Firestore, sem precisar de tratamento especial.
  Future<void> grantPremium(
    String uid,
    PremiumTier tier, {
    required DateTime expiresAt,
  }) async {
    await _db.collection('users_xp').doc(uid).update({
      'premiumTier': tier.id,
      'premiumExpiresAt': Timestamp.fromDate(expiresAt),
    });
    await _log('premium_granted', uid, extra: {
      'tier': tier.id,
      'expiresAt': expiresAt.toIso8601String(),
    });
  }

  Future<void> revokePremium(String uid) async {
    await _db.collection('users_xp').doc(uid).update({
      'premiumTier': FieldValue.delete(),
      'premiumExpiresAt': FieldValue.delete(),
    });
    await _log('premium_revoked', uid);
  }

  Future<void> syncAllUserLevels() async {
    final snap = await _db.collection('users_xp').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final xp = (doc.data()['totalXp'] as num?)?.toInt() ?? 0;
      batch.update(doc.reference, {'level': XpService.levelFromXp(xp)});
    }
    await batch.commit();
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
        'targetType': 'user',
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}