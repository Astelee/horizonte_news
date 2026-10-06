import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/support_models.dart';
import '../utils/search_normalizer.dart';
import 'app_notification_service.dart';

/// Atendimento privado entre o usuário e a equipe Horizonte News.
///
/// Uma conversa por usuário: `support_conversations/{uid}` (o ID é o
/// próprio UID, então nunca há duas conversas para a mesma pessoa e o
/// "Enviar mensagem" do painel ADM abre a mesma conversa). As mensagens
/// ficam em `.../messages/{messageId}`, com ID gerado no aparelho antes
/// do envio — por isso reenviar a mesma mensagem nunca a duplica.
///
/// Sem Cloud Functions (plano gratuito): cada envio grava, no MESMO
/// batch, a mensagem e o resumo da conversa (última mensagem, contador
/// de não lidas, status). As regras do Firestore (ver firestore.rules,
/// seção "Atendimento privado") só aceitam o par quando os dois chegam
/// juntos, com horário do servidor e o remetente correto.
class SupportChatService {
  SupportChatService._();
  static final SupportChatService instance = SupportChatService._();

  /// Mesmos limites validados em firestore.rules.
  static const int maxTextLength = 2000;
  static const int pageSize = 30;

  /// Intervalo mínimo entre dois envios do usuário (a regra do
  /// Firestore recusa envios em menos de 2 s; o app avisa antes).
  static const Duration minSendInterval = Duration(seconds: 2);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> conversationRef(String id) =>
      _db.collection('support_conversations').doc(id);

  CollectionReference<Map<String, dynamic>> _messagesRef(String convId) =>
      conversationRef(convId).collection('messages');

  /// ID da nova mensagem, gerado localmente (sem rede). Guarde-o para
  /// reenviar a MESMA mensagem em caso de falha.
  String newMessageId(String conversationId) =>
      _messagesRef(conversationId).doc().id;

  // ── Leitura ─────────────────────────────────────────────────────

  Stream<SupportConversation?> watchConversation(String conversationId) {
    return conversationRef(conversationId).snapshots().map(
          (doc) => doc.exists ? SupportConversation.fromDoc(doc) : null,
        );
  }

  /// Mensagens mais recentes (tempo real). As mais antigas vêm sob
  /// demanda por [loadOlder]. O listener é limitado a [limit] mensagens.
  Stream<List<SupportMessage>> watchLatestMessages(
    String conversationId, {
    int limit = pageSize,
  }) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map(SupportMessage.fromDoc).toList());
  }

  Future<List<SupportMessage>> loadOlder(
    String conversationId, {
    required Timestamp before,
    int limit = pageSize,
  }) async {
    final snap = await _messagesRef(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfter([before])
        .limit(limit)
        .get();
    return snap.docs.map(SupportMessage.fromDoc).toList();
  }

  Stream<SupportPublicConfig> watchPublicConfig() {
    return _db
        .collection('support_config')
        .doc('public')
        .snapshots()
        .map((doc) => SupportPublicConfig.fromMap(doc.data()));
  }

  /// Dados do usuário usados para criar a conversa (ADM iniciando uma
  /// conversa com alguém que nunca escreveu).
  Future<SupportProfile> loadUserProfile(String uid) async {
    final doc = await _db.collection('users_xp').doc(uid).get();
    final d = doc.data() ?? const <String, dynamic>{};
    String name = (d['displayName'] as String?)?.trim() ?? '';
    final username = (d['username'] as String?)?.trim() ?? '';
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

  // ── Envio ───────────────────────────────────────────────────────

  Map<String, dynamic> _profileFields(SupportProfile p) {
    final name = p.userName.length > 80 ? p.userName.substring(0, 80) : p.userName;
    final username =
        p.username.length > 40 ? p.username.substring(0, 40) : p.username;
    return {
      'userName': name,
      'username': username,
      'usernameLower': SearchNormalizer.normalize(username),
      'searchName': SearchNormalizer.normalize(name),
      'photoUrl': (p.photoUrl != null && p.photoUrl!.length <= 600)
          ? p.photoUrl
          : null,
    };
  }

  /// Envia (ou reenvia) uma mensagem.
  ///
  /// O Future só completa depois que o SERVIDOR confirma a gravação.
  /// Sem rede, o Firestore mantém a escrita na fila e o Future fica
  /// pendente até a conexão voltar — a tela mostra "Enviando" (via
  /// metadados do snapshot), nunca "Enviada" antes da confirmação.
  /// Se as regras recusarem, o Future lança e a tela marca "Falha ao
  /// enviar".
  ///
  /// [isRetry]: confere no servidor se a mensagem já tinha chegado
  /// antes de gravar de novo (evita erro/duplicata quando o primeiro
  /// envio funcionou mas a confirmação se perdeu).
  ///
  /// [conversationExists]: se a conversa já existe (a tela sabe pelo
  /// listener). Define se o batch cria ou atualiza o documento.
  Future<void> sendMessage({
    required String conversationId,
    required String messageId,
    required String text,
    required bool asAgent,
    required bool conversationExists,
    required SupportProfile profile,
    SupportReplyRef? replyTo,
    String? category,
    bool hidePreview = true,
    bool hidePreviewForAgents = true,
    bool isRetry = false,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError('Faça login para enviar mensagens.');
    }
    final clean = text.trim();
    if (clean.isEmpty) throw ArgumentError('Mensagem vazia.');
    if (clean.length > maxTextLength) {
      throw ArgumentError('Mensagem acima de $maxTextLength caracteres.');
    }

    final convRef = conversationRef(conversationId);
    final msgRef = _messagesRef(conversationId).doc(messageId);

    if (isRetry) {
      try {
        final existing =
            await msgRef.get(const GetOptions(source: Source.server));
        if (existing.exists) return; // já chegou: nada a regravar
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable') rethrow;
      }
    }

    final preview = clean.length > 200 ? clean.substring(0, 200) : clean;
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId': authUser.uid,
      'senderRole': asAgent ? 'agent' : 'user',
      'text': clean,
      'createdAt': now,
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });

    if (asAgent) {
      if (!conversationExists) {
        batch.set(convRef, {
          'userId': conversationId,
          ..._profileFields(profile),
          'status': 'open',
          'pinned': false,
          'blocked': false,
          'awaitingReply': false,
          'unreadUser': 1,
          'unreadAgent': 0,
          'lastMessageText': preview,
          'lastMessageSenderRole': 'agent',
          'lastMessageAt': now,
          'lastMessageId': messageId,
          'lastActivityAt': now,
          'lastAgentId': authUser.uid,
          'createdAt': now,
        });
      } else {
        batch.update(convRef, {
          'lastMessageText': preview,
          'lastMessageSenderRole': 'agent',
          'lastMessageAt': now,
          'lastMessageId': messageId,
          'lastActivityAt': now,
          'lastAgentId': authUser.uid,
          'unreadUser': FieldValue.increment(1),
          'awaitingReply': false,
          'status': 'open',
        });
      }
    } else {
      if (conversationId != authUser.uid) {
        throw StateError('Conversa inválida para este usuário.');
      }
      if (!conversationExists) {
        batch.set(convRef, {
          'userId': conversationId,
          ..._profileFields(profile),
          if (category != null) 'category': category,
          'hidePreview': hidePreview,
          'status': 'open',
          'pinned': false,
          'blocked': false,
          'awaitingReply': true,
          'unreadUser': 0,
          'unreadAgent': 1,
          'lastMessageText': preview,
          'lastMessageSenderRole': 'user',
          'lastMessageAt': now,
          'lastMessageId': messageId,
          'lastActivityAt': now,
          'lastUserSendAt': now,
          'createdAt': now,
        });
      } else {
        batch.update(convRef, {
          ..._profileFields(profile),
          if (category != null) 'category': category,
          'hidePreview': hidePreview,
          'status': 'open',
          'awaitingReply': true,
          'unreadAgent': FieldValue.increment(1),
          'lastMessageText': preview,
          'lastMessageSenderRole': 'user',
          'lastMessageAt': now,
          'lastMessageId': messageId,
          'lastActivityAt': now,
          'lastUserSendAt': now,
        });
      }
    }

    await batch.commit();

    // Push só depois da confirmação do servidor. Melhor esforço: a
    // mensagem e os contadores já estão salvos, então o histórico e as
    // não lidas funcionam mesmo se o push falhar ou estiver desativado.
    unawaited(_pushAfterSend(
      conversationId: conversationId,
      messageId: messageId,
      asAgent: asAgent,
      preview: preview,
      senderName: profile.userName,
      hideContent: asAgent ? hidePreview : hidePreviewForAgents,
    ));
  }

  Future<void> _pushAfterSend({
    required String conversationId,
    required String messageId,
    required bool asAgent,
    required String preview,
    required String senderName,
    required bool hideContent,
  }) async {
    try {
      if (asAgent) {
        await AppNotificationService.sendSupportPush(
          conversationId: conversationId,
          messageId: messageId,
          recipientUserId: conversationId,
          title: 'Atendimento Horizonte News',
          body: hideContent
              ? 'Você recebeu uma resposta do atendimento'
              : (preview.length > 100
                  ? '${preview.substring(0, 100)}…'
                  : preview),
        );
      } else {
        final who = senderName.trim().isEmpty ? 'Usuário' : senderName.trim();
        await AppNotificationService.sendSupportPush(
          conversationId: conversationId,
          messageId: messageId,
          recipientUserId: null, // equipe: aparelhos com a tag support_agent
          title: hideContent ? 'Atendimento Horizonte News' : '$who · Atendimento',
          body: hideContent
              ? 'Você tem uma nova mensagem no atendimento'
              : (preview.length > 100
                  ? '${preview.substring(0, 100)}…'
                  : preview),
        );
      }
    } catch (e) {
      debugPrint('Push do atendimento não enviado: $e');
    }
  }

  // ── Leitura / preferências ──────────────────────────────────────

  /// Marca como lidas as mensagens do outro lado. Só deve ser chamada
  /// quando a conversa está em primeiro plano e as mensagens
  /// realmente foram exibidas.
  Future<void> markRead(String conversationId, {required bool asAgent}) async {
    try {
      await conversationRef(conversationId).update(
        asAgent
            ? {
                'unreadAgent': 0,
                'agentReadAt': FieldValue.serverTimestamp(),
              }
            : {
                'unreadUser': 0,
                'userReadAt': FieldValue.serverTimestamp(),
              },
      );
    } catch (e) {
      debugPrint('Erro ao marcar conversa como lida: $e');
    }
  }

  /// Usuário: ocultar o conteúdo da mensagem na prévia do push que
  /// ele recebe. Só funciona com a conversa já criada; antes disso a
  /// preferência viaja junto com a primeira mensagem.
  Future<void> setHidePreview(String conversationId, bool value) async {
    try {
      await conversationRef(conversationId).update({'hidePreview': value});
    } catch (e) {
      debugPrint('Erro ao salvar preferência de prévia: $e');
    }
  }
}