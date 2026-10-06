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
      final list = snap.docs.map(SupportConversation.fromDoc).toList()
        ..sort(_byPinnedThenActivity);
      return list;
    });
  }

  /// Conversas fixadas (sempre aparecem no topo, mesmo antigas).
  Stream<List<SupportConversation>> watchPinned() {
    return _conv
        .where('pinned', isEqualTo: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(SupportConversation.fromDoc).toList());
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

  // ── Ações em uma conversa ───────────────────────────────────────

  /// Resolver ou reabrir. Ao reabrir, volta a "aguardando resposta"
  /// se a última mensagem foi do usuário.
  Future<void> setResolved(SupportConversation c, bool resolved) {
    return _conv.doc(c.id).update({
      'status': resolved ? 'resolved' : 'open',
      'awaitingReply': !resolved && c.lastMessageSenderRole == 'user',
    });
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