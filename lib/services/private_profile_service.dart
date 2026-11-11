import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Dados pessoais do usuário (e-mail e data de nascimento).
///
/// Ficam em `users_private/{uid}` — só o próprio dono e administradores
/// leem (ver firestore.rules). Antes ficavam em `users_xp/{uid}`, que é
/// legível por QUALQUER usuário logado (ranking, perfis e comentários
/// dependem dele), então todo mundo conseguia ler o e-mail e a data de
/// nascimento de todo mundo.
///
/// O que continua público é só o que o usuário escolhe mostrar: ao ativar
/// "Mostrar minha idade", o app grava `publicBirthDate` em users_xp
/// (consentimento explícito); desativando, o campo é apagado.
class PrivateProfileService {
  PrivateProfileService._();
  static final PrivateProfileService instance = PrivateProfileService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? _migratedUid;
  bool _migrating = false;

  /// Move e-mail/data de nascimento do perfil público para users_private.
  /// Idempotente e silencioso: roda uma vez por sessão e por usuário.
  ///
  /// Ordem segura: primeiro GRAVA a cópia privada; só depois APAGA os
  /// campos do perfil público. Se qualquer passo falhar, o dado original
  /// continua onde estava e a próxima sessão tenta de novo.
  Future<void> migrateLegacyFields() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    if (_migratedUid == uid || _migrating) return;
    _migrating = true;

    try {
      final xpRef = _db.collection('users_xp').doc(uid);
      final privRef = _db.collection('users_private').doc(uid);

      final xpSnap = await xpRef.get();
      final xpData = xpSnap.data();
      if (xpData == null) return; // documento ainda não existe: tenta depois

      final privData = (await privRef.get()).data() ?? <String, dynamic>{};

      final payload = <String, dynamic>{};
      final authEmail = user.email ?? '';
      if (privData['email'] == null && authEmail.isNotEmpty) {
        payload['email'] = authEmail;
      }
      final legacyBirth = xpData['birthDate'];
      if (privData['birthDate'] == null && legacyBirth is Timestamp) {
        payload['birthDate'] = legacyBirth;
      }
      if (payload.isNotEmpty) {
        payload['updatedAt'] = FieldValue.serverTimestamp();
        await privRef.set(payload, SetOptions(merge: true));
      }

      final hasLegacyEmail = xpData.containsKey('email');
      final hasLegacyBirth = xpData.containsKey('birthDate');
      if (hasLegacyEmail || hasLegacyBirth) {
        await xpRef.update({
          if (hasLegacyEmail) 'email': FieldValue.delete(),
          if (hasLegacyBirth) 'birthDate': FieldValue.delete(),
        });
      }
      _migratedUid = uid;
    } catch (e) {
      debugPrint('Migração de dados pessoais adiada: $e');
    } finally {
      _migrating = false;
    }
  }

  /// Grava os dados pessoais do cadastro (e-mail da conta + nascimento).
  Future<void> saveRegistrationData({
    required String email,
    required DateTime birthDate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users_private').doc(uid).set({
      'email': email,
      'birthDate': Timestamp.fromDate(birthDate),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Data de nascimento do PRÓPRIO usuário (users_private; aceita o
  /// formato antigo em users_xp enquanto a migração não rodou).
  Future<DateTime?> loadOwnBirthDate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final priv = await _db.collection('users_private').doc(uid).get();
      final privBirth = priv.data()?['birthDate'];
      if (privBirth is Timestamp) return privBirth.toDate();

      final legacy = await _db.collection('users_xp').doc(uid).get();
      final legacyBirth = legacy.data()?['birthDate'];
      if (legacyBirth is Timestamp) return legacyBirth.toDate();
    } catch (e) {
      debugPrint('Erro ao ler data de nascimento: $e');
    }
    return null;
  }

  /// Salva a data de nascimento no cofre privado e, se o usuário optou por
  /// mostrar a idade, atualiza também a cópia pública (`publicBirthDate`).
  Future<void> saveBirthDate(DateTime birthDate, {required bool showAge}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ts = Timestamp.fromDate(birthDate);
    await _db.collection('users_private').doc(uid).set({
      'birthDate': ts,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await setPublicAge(showAge: showAge, birthDate: birthDate);
  }

  /// Liga/desliga a exibição pública da idade. A cópia pública só existe
  /// enquanto "Mostrar minha idade" estiver ativo.
  Future<void> setPublicAge({
    required bool showAge,
    DateTime? birthDate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('users_xp').doc(uid);
    if (!showAge) {
      await ref.update({
        'showAge': false,
        'publicBirthDate': FieldValue.delete(),
      });
      return;
    }
    final date = birthDate ?? await loadOwnBirthDate();
    await ref.update({
      'showAge': true,
      if (date != null) 'publicBirthDate': Timestamp.fromDate(date),
    });
  }

  /// Apaga os dados pessoais (exclusão de conta).
  Future<void> deleteOwn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users_private').doc(uid).delete();
    } catch (_) {}
  }
}

/// E-mails dos usuários para o PAINEL ADMIN. Como o e-mail saiu do perfil
/// público, o painel lê `users_private` (só admin consegue listar).
class AdminEmailDirectory {
  AdminEmailDirectory._();
  static final AdminEmailDirectory instance = AdminEmailDirectory._();

  Map<String, String> _emails = const {};
  DateTime? _loadedAt;
  Future<void>? _loading;

  /// Carrega (no máximo a cada 10 min) todos os e-mails. Só funciona para
  /// administradores; para os demais devolve vazio sem lançar erro.
  Future<void> ensureLoaded({bool force = false}) {
    final loadedAt = _loadedAt;
    if (!force &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 10)) {
      return Future.value();
    }
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users_private')
          .limit(5000)
          .get();
      _emails = {
        for (final d in snap.docs)
          d.id: ((d.data()['email'] as String?) ?? '').trim(),
      };
      _loadedAt = DateTime.now();
    } catch (e) {
      debugPrint('Diretório de e-mails indisponível: $e');
    }
  }

  /// E-mail do usuário: o da área privada; se ainda não migrou, o valor
  /// legado que veio no próprio documento público ([legacy]).
  String emailFor(String uid, {String? legacy}) {
    final priv = _emails[uid];
    if (priv != null && priv.isNotEmpty) return priv;
    return (legacy ?? '').trim();
  }
}