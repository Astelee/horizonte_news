import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

/// Central de notificações in-app (coleção `notifications`) + disparo
/// de push individual via OneSignal usando External ID.
///
/// Reutiliza a MESMA REST API Key e o MESMO app_id já usados por
/// PushNotificationService (ver esse arquivo para o histórico de
/// como a chave chega ao binário via --dart-define). Aqui, em vez de
/// mandar para o segmento "All", miramos um usuário específico via
/// `include_aliases: {external_id: [...]}` — por isso é essencial
/// que o uid do Firebase tenha sido registrado como External ID no
/// SDK do OneSignal (ver NotificationService.loginExternalUser,
/// chamado a cada login/troca de sessão).
class AppNotificationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const String _appId = '999de6a2-1965-4cb0-9558-a0cc8ed39828';
  static const String _restApiKey =
      String.fromEnvironment('ONESIGNAL_REST_API_KEY');
  static const String _endpoint =
      'https://onesignal.com/api/v1/notifications';

  static CollectionReference get _notificationsRef =>
      _db.collection('notifications');

  /// Cria a notificação de "resposta ao comentário" e dispara o push
  /// correspondente. Não faz nada se:
  /// - o autor do comentário original é quem está respondendo (sem
  ///   auto-notificação);
  /// - já existe uma notificação idêntica para essa resposta
  ///   específica (evita duplicata em caso de reenvio/retry).
  static Future<void> notifyCommentReply({
    required String recipientUserId,
    required String actorUserId,
    required String actorUserName,
    String? actorPhotoUrl,
    required String postId,
    required String postTitle,
    required String commentId,
    String? replyId,
    required String previewText,
  }) async {
    if (recipientUserId == actorUserId) return; // não notifica a si mesmo
    if (recipientUserId.isEmpty) return;

    // A resposta em si (replyId, quando existe) é o identificador
    // mais específico do evento — usamos como docId determinístico
    // da notificação para tornar a criação idempotente: se o mesmo
    // evento tentar gravar de novo (ex.: um retry de rede depois de
    // já ter enviado a resposta), o Firestore simplesmente
    // sobrescreve o mesmo documento em vez de duplicar.
    final dedupeKey = replyId ?? commentId;
    final docId = 'reply_${postId}_$dedupeKey';

    final trimmedPreview = previewText.trim();
    final preview = trimmedPreview.length > 120
        ? '${trimmedPreview.substring(0, 120)}…'
        : trimmedPreview;

    try {
      await _notificationsRef.doc(docId).set({
        'recipientUserId': recipientUserId,
        'type': NotificationType.commentReply,
        'actorUserId': actorUserId,
        'actorUserName': actorUserName,
        'actorPhotoUrl': actorPhotoUrl,
        'postId': postId,
        'postTitle': postTitle,
        'commentId': commentId,
        'replyId': replyId,
        'previewText': preview,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Erro ao criar notificação de resposta: $e');
      return;
    }

    await _sendPush(
      recipientUserId: recipientUserId,
      title: actorUserName,
      body: 'respondeu ao seu comentário: $preview',
      data: {
        'kind': 'comment',
        'postId': postId,
        'commentId': commentId,
        if (replyId != null) 'replyId': replyId,
      },
    );
  }

  /// Cria a notificação de "curtida no comentário" e dispara o push.
  /// Mesma lógica de dedupe/auto-notificação do reply, mas a chave
  /// de idempotência aqui é (comentário curtido + quem curtiu), já
  /// que descurtir-e-curtir de novo pela mesma pessoa deve reabrir a
  /// MESMA notificação (marcando como não lida de novo) em vez de
  /// gerar uma nova a cada ciclo de curtir/descurtir.
  static Future<void> notifyCommentLike({
    required String recipientUserId,
    required String actorUserId,
    required String actorUserName,
    String? actorPhotoUrl,
    required String postId,
    required String postTitle,
    required String commentId,
    String? replyId,
  }) async {
    if (recipientUserId == actorUserId) return;
    if (recipientUserId.isEmpty) return;

    final dedupeKey = replyId ?? commentId;
    final docId = 'like_${postId}_${dedupeKey}_$actorUserId';
    final docRef = _notificationsRef.doc(docId);

    try {
      final existing = await docRef.get();
      if (existing.exists) {
        // Já existe notificação dessa curtida específica (a pessoa
        // curtiu, descurtiu e curtiu de novo) — só marca como não
        // lida de novo e atualiza o horário, sem enviar push
        // repetido nem criar um segundo documento.
        await docRef.update({
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      await docRef.set({
        'recipientUserId': recipientUserId,
        'type': NotificationType.commentLike,
        'actorUserId': actorUserId,
        'actorUserName': actorUserName,
        'actorPhotoUrl': actorPhotoUrl,
        'postId': postId,
        'postTitle': postTitle,
        'commentId': commentId,
        'replyId': replyId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Erro ao criar notificação de curtida: $e');
      return;
    }

    await _sendPush(
      recipientUserId: recipientUserId,
      title: actorUserName,
      body: 'curtiu seu comentário',
      data: {
        'kind': 'comment',
        'postId': postId,
        'commentId': commentId,
        if (replyId != null) 'replyId': replyId,
      },
    );
  }

  /// Envia o push individual via REST API do OneSignal, mirando pelo
  /// External ID (uid do Firebase). Silencioso em caso de falha — a
  /// notificação in-app (já gravada no Firestore antes desta chamada)
  /// é a fonte de verdade; o push é só o "empurrão" imediato.
  static Future<void> _sendPush({
    required String recipientUserId,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    if (_restApiKey.isEmpty) {
      debugPrint(
          'Push de notificação não enviado: ONESIGNAL_REST_API_KEY ausente.');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: json.encode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': [recipientUserId],
          },
          'target_channel': 'push',
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint(
            'Falha ao enviar push de notificação (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro ao enviar push de notificação: $e');
    }
  }

  // ── Central de notificações (leitura/estado) ────────────────────

  static String get _myUid => _auth.currentUser?.uid ?? '';

  /// Stream com as notificações do usuário logado, mais recentes
  /// primeiro.
  static Stream<List<AppNotificationModel>> watchMyNotifications() {
    if (_myUid.isEmpty) return const Stream.empty();
    return _notificationsRef
        .where('recipientUserId', isEqualTo: _myUid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppNotificationModel.fromDoc(d)).toList());
  }

  /// Stream só com a contagem de não lidas — usado pelo badge do
  /// sino em qualquer tela, sem precisar montar a lista inteira.
  static Stream<int> watchUnreadCount() {
    if (_myUid.isEmpty) return Stream.value(0);
    return _notificationsRef
        .where('recipientUserId', isEqualTo: _myUid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'read': true});
    } catch (e) {
      debugPrint('Erro ao marcar notificação como lida: $e');
    }
  }

  static Future<void> markAllAsRead() async {
    if (_myUid.isEmpty) return;
    try {
      final unread = await _notificationsRef
          .where('recipientUserId', isEqualTo: _myUid)
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Erro ao marcar todas as notificações como lidas: $e');
    }
  }
}