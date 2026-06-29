import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/xp_service.dart';

class AdminUserService {
  final _db = FirebaseFirestore.instance;

  // ── Usuários ────────────────────────────────────────────────────

  Stream<QuerySnapshot> usersStream() {
    return _db
        .collection('users_xp')
        .orderBy('totalXp', descending: true)
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

  // ── Override de nível (aba Poderes) ────────────────────────────

  Future<void> applyLevelOverride(String uid, int level) async {
    await _db.collection('users_xp').doc(uid).update({
      'level': level,
      'adminOverrideLevel': level,
      'adminOverrideActive': true,
    });
    await _log('level_override', uid, extra: {'level': level});
  }

  Future<void> resetLevelOverride(String uid, int realLevel) async {
    await _db.collection('users_xp').doc(uid).update({
      'level': realLevel,
      'adminOverrideActive': false,
      'adminOverrideLevel': FieldValue.delete(),
    });
    await _log('level_reset', uid);
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
