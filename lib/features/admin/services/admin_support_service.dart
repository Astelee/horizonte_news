import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/support_models.dart';
import '../../../utils/search_normalizer.dart';

enum SupportInboxFilter { all, unread, awaiting, resolved }

/// Admin cadastrado em `admins/{uid}` (nome vem de users_xp).
class SupportAdminAccount {
  final String uid;
  final String name;
  final String role;
  const SupportAdminAccount({
    required this.uid,
    required this.name,
    required this.role,
  });
}

/// Caixa de entrada, ações e configurações do atendimento no painel ADM.
/// Mensagens (envio/leitura) ficam em SupportChatService, compartilhado
/// com a tela do usuário.
class AdminSupportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conv =>
      _db.collection('support_conversations');

  // ── Caixa de entrada ────────────────────────────────────────────

  Query<Map<String, dynamic>> _inboxQuery(SupportInboxFilter f, int limit) {
    switch (f) {
      case SupportInboxFilter.all:
        return _conv.orderBy('lastActivityAt', descending: true).limit(limit);
      case SupportInboxFilter.unread:
        // Ordenado no app (pinned + atividade): a consulta com desigualdade
        // em unreadAgent não precisa de índice composto.
        return _conv.where('unreadAgent', isGreaterThan: 0).limit(limit);
      case SupportInboxFilter.awaiting:
        return _conv
            .where('awaitingReply', isEqualTo: true)
            .orderBy('lastActivityAt', descending: true)
            .limit(limit);
      case SupportInboxFilter.resolved:
        return _conv
            .where('status', isEqualTo: 'resolved')
            .orderBy('lastActivityAt', descending: true)
            .limit(limit);
    }
  }

  static int _byPinnedThenActivity(SupportConversation a, SupportConversation b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final da = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  }

  /// Conversas do filtro, em tempo real, limitadas a [limit].
  Stream<List<SupportConversation>> watchInbox(
    SupportInboxFilter filter, {
    int limit = 40,
  }) {
    return _inboxQuery(filter, limit).snapshots().map((snap) {
      // Arquivadas ("Excluir só para mim") saem da caixa de entrada.
      final list = snap.docs
          .map(SupportConversation.fromDoc)
          .where((c) => !c.isArchived)
          .toList()
        ..sort(_byPinnedThenActivity);
      return list;
    });
  }

  /// Conversas fixadas (sempre aparecem no topo, mesmo antigas).
  Stream<List<SupportConversation>> watchPinned() {
    return _conv.where('pinned', isEqualTo: true).limit(30).snapshots().map(
        (snap) => snap.docs
            .map(SupportConversation.fromDoc)
            .where((c) => !c.isArchived)
            .toList());
  }

  /// Quantas conversas têm mensagens não lidas (conta até 99; não
  /// carrega histórico de mensagens).
  Stream<int> watchUnreadConversationCount() {
    return _conv
        .where('unreadAgent', isGreaterThan: 0)
        .limit(99)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Quantas conversas aguardam resposta da equipe (até 99).
  Stream<int> watchAwaitingCount() {
    return _conv
        .where('awaitingReply', isEqualTo: true)
        .limit(99)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Busca em conversas JÁ EXISTENTES: início do nome, início do
  /// username (sem acento/maiúscula) ou UID completo. O Firestore não
  /// faz busca por "contém"; quem nunca falou com o atendimento não
  /// aparece aqui — use Usuários → perfil → Enviar mensagem.
  Future<List<SupportConversation>> search(String raw) async {
    final q = SearchNormalizer.normalize(raw);
    if (q.isEmpty) return const [];
    final found = <String, SupportConversation>{};

    Future<void> prefix(String field) async {
      final snap = await _conv
          .where(field, isGreaterThanOrEqualTo: q)
          .where(field, isLessThanOrEqualTo: '$q\uf8ff')
          .limit(20)
          .get();
      for (final d in snap.docs) {
        found[d.id] = SupportConversation.fromDoc(d);
      }
    }

    await Future.wait([prefix('searchName'), prefix('usernameLower')]);

    final uid = raw.trim();
    if (uid.length >= 20 && !uid.contains(' ') && !found.containsKey(uid)) {
      try {
        final doc = await _conv.doc(uid).get();
        if (doc.exists) found[doc.id] = SupportConversation.fromDoc(doc);
      } catch (_) {}
    }

    return found.values.toList()..sort(_byPinnedThenActivity);
  }

  // ── Escolher um usuário para iniciar conversa ───────────────────

  SupportProfile _profileFrom(String uid, Map<String, dynamic> d) {
    final username = ((d['username'] as String?) ?? '').trim();
    var name = ((d['displayName'] as String?) ?? '').trim();
    if (name.isEmpty) {
      final email = (d['email'] as String?) ?? '';
      name = username.isNotEmpty
          ? username
          : (email.isNotEmpty ? email.split('@').first : 'Usuário');
    }
    final photo = d['photoUrl'] as String?;
    return SupportProfile(
      userId: uid,
      userName: name,
      username: username,
      photoUrl: (photo != null && photo.isNotEmpty) ? photo : null,
    );
  }

  /// Usuários que abriram o app mais recentemente (limitado; sem
  /// carregar a base inteira).
  Future<List<SupportProfile>> recentUsers({int limit = 40}) async {
    final snap = await _db
        .collection('users_xp')
        .orderBy('lastSeenAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => _profileFrom(d.id, d.data())).toList();
  }

  /// Busca usuários pelo início do nome, início do username ou UID
  /// completo (o Firestore não faz busca por "contém").
  Future<List<SupportProfile>> searchUsers(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return const [];
    final found = <String, SupportProfile>{};

    Future<void> prefix(String field, String value) async {
      if (value.isEmpty) return;
      try {
        final snap = await _db
            .collection('users_xp')
            .where(field, isGreaterThanOrEqualTo: value)
            .where(field, isLessThanOrEqualTo: '$value\uf8ff')
            .limit(15)
            .get();
        for (final d in snap.docs) {
          found[d.id] = _profileFrom(d.id, d.data());
        }
      } catch (_) {}
    }

    final capitalized = q[0].toUpperCase() + q.substring(1);
    await Future.wait([
      prefix('username', q.toLowerCase()),
      prefix('displayName', q),
      prefix('displayName', capitalized),
    ]);

    if (q.length >= 20 && !q.contains(' ') && !found.containsKey(q)) {
      try {
        final doc = await _db.collection('users_xp').doc(q).get();
        if (doc.exists) found[doc.id] = _profileFrom(doc.id, doc.data()!);
      } catch (_) {}
    }
    return found.values.toList();
  }

  // ── Ações em uma conversa ───────────────────────────────────────

  /// Resolver ou reabrir. Ao reabrir, volta a "aguardando resposta"
  /// se a última mensagem foi do usuário.
  Future<void> setResolved(SupportConversation c, bool resolved) {
    return _conv.doc(c.id).update({
      'status': resolved ? 'resolved' : 'open',
      'awaitingReply': !resolved && c.lastMessageSenderRole == 'user',
    });
  }

  /// "Excluir só para mim": tira da caixa de entrada e esconde o
  /// histórico anterior para a equipe. O usuário continua vendo a
  /// conversa; se ele escrever de novo, ela volta como nova.
  Future<void> archiveConversation(String conversationId) {
    return _conv.doc(conversationId).update({
      'status': 'archived',
      'awaitingReply': false,
      'unreadAgent': 0,
      'pinned': false,
      'agentClearedAt': FieldValue.serverTimestamp(),
    });
  }

  /// "Excluir para os dois": apaga todas as mensagens e a conversa,
  /// definitivamente. As exclusões vão em grupos pequenos porque cada
  /// uma passa pelas regras do Firestore.
  Future<void> deleteConversationForAll(String conversationId) async {
    final msgs = _conv.doc(conversationId).collection('messages');
    while (true) {
      final snap = await msgs.limit(100).get();
      if (snap.docs.isEmpty) break;
      for (var i = 0; i < snap.docs.length; i += 20) {
        final chunk = snap.docs.skip(i).take(20);
        await Future.wait(chunk.map((d) => d.reference.delete()));
      }
    }
    await _conv.doc(conversationId).delete();
  }

  Future<void> setPinned(String conversationId, bool pinned) =>
      _conv.doc(conversationId).update({'pinned': pinned});

  /// Bloqueia/desbloqueia o envio no atendimento. É uma ação
  /// separada da suspensão/banimento geral do app.
  Future<void> setBlocked(String conversationId, bool blocked) =>
      _conv.doc(conversationId).update({'blocked': blocked});

  // ── Configurações ───────────────────────────────────────────────

  Stream<SupportAgentsConfig> watchAgentsConfig() {
    return _db
        .collection('support_config')
        .doc('agents')
        .snapshots()
        .map((doc) => SupportAgentsConfig.fromMap(doc.data()));
  }

  Future<void> saveAgentsConfig({
    required List<String> agentUids,
    required List<String> notifyUids,
  }) {
    return _db.collection('support_config').doc('agents').set({
      'agentUids': agentUids,
      'notifyUids': notifyUids,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> savePublicConfig(SupportPublicConfig config) {
    return _db.collection('support_config').doc('public').set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admins existentes (admins/{uid}) com o nome do perfil, para
  /// escolher quem atende e quem recebe notificações. Os UIDs vêm do
  /// próprio banco — nada é digitado à mão.
  Future<List<SupportAdminAccount>> listAdmins() async {
    final snap = await _db.collection('admins').get();
    final out = <SupportAdminAccount>[];
    for (final doc in snap.docs) {
      String name = '';
      try {
        final u = await _db.collection('users_xp').doc(doc.id).get();
        name = ((u.data()?['displayName'] as String?) ?? '').trim();
        if (name.isEmpty) {
          final email = (u.data()?['email'] as String?) ?? '';
          if (email.isNotEmpty) name = email.split('@').first;
        }
      } catch (_) {}
      out.add(SupportAdminAccount(
        uid: doc.id,
        name: name.isEmpty ? 'Admin sem nome' : name,
        role: (doc.data()['role'] as String?) ?? 'admin',
      ));
    }
    return out;
  }

  // ── Respostas rápidas ───────────────────────────────────────────

  Stream<List<SupportQuickReply>> watchQuickReplies() {
    return _db
        .collection('support_quick_replies')
        .orderBy('order')
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(SupportQuickReply.fromDoc).toList());
  }

  Future<void> saveQuickReply({
    String? id,
    required String title,
    required String text,
    required int order,
  }) {
    final ref = id == null
        ? _db.collection('support_quick_replies').doc()
        : _db.collection('support_quick_replies').doc(id);
    return ref.set({
      'title': title.trim(),
      'text': text.trim(),
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteQuickReply(String id) =>
      _db.collection('support_quick_replies').doc(id).delete();
}