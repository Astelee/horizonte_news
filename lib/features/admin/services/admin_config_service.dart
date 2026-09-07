import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lado admin das configurações globais do app: liga/desliga modo
/// manutenção e comentários, e gerencia quem tem acesso ao painel
/// admin (coleção `admins`).
class AdminConfigService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      _db.collection('app_config').doc('global');

  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection('admins').withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) => snap.data() ?? {},
            toFirestore: (data, _) => data,
          );

  Stream<DocumentSnapshot<Map<String, dynamic>>> configStream() {
    return _configDoc.snapshots();
  }

  Future<void> setMaintenanceMode({
    required bool enabled,
    String message = '',
  }) async {
    await _configDoc.set({
      'maintenanceMode': enabled,
      'maintenanceMessage': message,
    }, SetOptions(merge: true));

    await _log(enabled ? 'maintenance_on' : 'maintenance_off', 'global',
        extra: {'message': message});
  }

  Future<void> setCommentsEnabled(bool enabled) async {
    await _configDoc.set(
      {'commentsEnabled': enabled},
      SetOptions(merge: true),
    );
    await _log(enabled ? 'comments_enabled' : 'comments_disabled', 'global');
  }

  // ── Gerenciamento de admins ─────────────────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> adminsStream() {
    return _admins.snapshots();
  }

  /// Adiciona um admin pelo UID do Firebase Auth dele (o app não tem
  /// busca de usuário por e-mail no client, então o admin precisa
  /// pegar o UID da pessoa — ex.: na aba Usuários do painel).
  Future<void> addAdmin({
    required String uid,
    required String addedByName,
    String role = 'admin',
    String? label,
  }) async {
    await _admins.doc(uid).set({
      'role': role,
      'label': label ?? '',
      'addedAt': FieldValue.serverTimestamp(),
      'addedByName': addedByName,
    });
    await _log('admin_added', uid, extra: {'role': role});
  }

  Future<void> removeAdmin(String uid) async {
    await _admins.doc(uid).delete();
    await _log('admin_removed', uid);
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
        'targetType': 'config',
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}