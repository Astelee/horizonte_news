import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/premium_config.dart';
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
  ///
  /// Retorna true somente quando o OneSignal confirmou o envio (HTTP
  /// 200 com `id` preenchido). [idempotencyKey], quando informado,
  /// faz o OneSignal ignorar pedidos repetidos com a mesma chave (vale
  /// entre aparelhos do mesmo usuário; ver notifyPremiumExpiringSoon).
  static Future<bool> _sendPush({
    String? recipientUserId,
    Map<String, dynamic>? targeting,
    required String title,
    required String body,
    required Map<String, String> data,
    String? idempotencyKey,
    String? collapseId,
  }) async {
    assert(recipientUserId != null || targeting != null);
    if (_restApiKey.isEmpty) {
      debugPrint(
          'Push de notificação não enviado: ONESIGNAL_REST_API_KEY ausente.');
      return false;
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
          ...(targeting ??
              {
                'include_aliases': {
                  'external_id': [recipientUserId],
                },
                'target_channel': 'push',
              }),
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
          if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
          if (collapseId != null) 'collapse_id': collapseId,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint(
            'Falha ao enviar push de notificação (${response.statusCode}): ${response.body}');
        return false;
      }
      // O OneSignal responde 200 com `id` vazio quando ninguém pôde
      // receber (ex.: usuário sem assinatura de push ativa).
      try {
        final decoded = json.decode(response.body);
        final id = decoded is Map ? decoded['id'] : null;
        return id is String && id.isNotEmpty;
      } catch (_) {
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao enviar push de notificação: $e');
      return false;
    }
  }

  // ── Atendimento (chat privado usuário ↔ equipe) ────────────────

  /// Tag do OneSignal que marca os aparelhos dos atendentes que devem
  /// receber o push de "nova mensagem de usuário". É mantida por
  /// SupportProvider conforme support_config/agents (notifyUids).
  static const String supportAgentTagKey = 'support_agent';

  /// Push de uma mensagem do atendimento.
  ///
  /// [recipientUserId] != null → vai para ESSE usuário (External ID =
  /// UID do Firebase). null → vai para a equipe (aparelhos com a tag
  /// `support_agent = 1`), porque o app do usuário não pode ler a lista
  /// de atendentes.
  ///
  /// Dados do toque: kind, conversationId e messageId. A chave de
  /// idempotência é derivada do messageId: reenviar a mesma mensagem
  /// não gera um segundo push. O collapse_id substitui o aviso anterior
  /// da mesma conversa na bandeja em vez de empilhar vários.
  ///
  /// Melhor esforço: o Android pode atrasar ou descartar notificações
  /// (economia de bateria, permissão negada, app restrito), então a
  /// entrega não é garantida — o histórico e os contadores vêm do
  /// Firestore e funcionam mesmo sem push.
  static Future<bool> sendSupportPush({
    required String conversationId,
    required String messageId,
    required String title,
    required String body,
    String? recipientUserId,
  }) {
    final toTeam = recipientUserId == null;
    return _sendPush(
      recipientUserId: recipientUserId,
      targeting: toTeam
          ? {
              'filters': [
                {
                  'field': 'tag',
                  'key': supportAgentTagKey,
                  'relation': '=',
                  'value': '1',
                },
              ],
            }
          : null,
      title: title,
      body: body,
      data: {
        'kind': 'support',
        'conversationId': conversationId,
        'messageId': messageId,
      },
      idempotencyKey: _deterministicUuid(
          'support|$messageId|${toTeam ? 'team' : recipientUserId}'),
      collapseId: 'support_$conversationId',
    );
  }

  // ── Aviso de assinatura Premium perto de vencer ─────────────────

  /// Quantos dias antes do vencimento o aviso passa a valer.
  static const int _expiryWarningDays = 3;

  static const String _expiryStoragePrefix = 'premium_expiry_warned_';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Último "uid:vencimento" já avisado nesta sessão (evita ler o
  /// storage a cada snapshot do Firestore).
  static String? _lastExpiryWarnedKey;
  static bool _expiryCheckRunning = false;

  /// Avisa por push (uma única vez por vencimento) que a assinatura
  /// Premium ativa está a até 3 dias de vencer.
  ///
  /// [tier] deve ser o plano JÁ EFETIVO (premiumTierFromData) — quem
  /// não tem assinatura ativa é ignorado. Sem servidor agendado (plano
  /// gratuito do Firebase), a checagem acontece quando o app está
  /// aberto durante a janela de 3 dias; chamar aqui a cada atualização
  /// dos dados do usuário é seguro e barato.
  ///
  /// Anti-repetição: (1) marca local por uid + data de vencimento;
  /// (2) idempotency_key no OneSignal, que também evita duplicata
  /// quando o usuário abre o app em outro aparelho. Ao renovar, o
  /// vencimento muda e um novo aviso passa a valer para ele.
  static Future<void> notifyPremiumExpiringSoon({
    required String uid,
    required PremiumTier tier,
    required DateTime expiresAt,
  }) async {
    if (uid.isEmpty || !tier.isPremium) return;

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return; // já venceu
    if (remaining > const Duration(days: _expiryWarningDays)) return;

    final millis = expiresAt.millisecondsSinceEpoch;
    final key = '$uid:$millis';
    if (_lastExpiryWarnedKey == key || _expiryCheckRunning) return;
    _expiryCheckRunning = true;

    try {
      final storageKey = '$_expiryStoragePrefix$uid';
      final stored = await _secureStorage.read(key: storageKey);
      if (stored == '$millis') {
        _lastExpiryWarnedKey = key;
        return;
      }

      // Cortesia de teste dada pelo admin (premiumTrial): o usuário
      // acabou de ganhar o período e já recebeu o push de presente,
      // então não faz sentido avisar "vai vencer, renove" logo em
      // seguida. Assinaturas normais não têm essa marca.
      final userDoc = await _db.collection('users_xp').doc(uid).get();
      if (userDoc.data()?['premiumTrial'] == true) {
        _lastExpiryWarnedKey = key;
        await _secureStorage.write(key: storageKey, value: '$millis');
        return;
      }

      // Só tenta enviar se este aparelho já está apto a receber o
      // push do próprio usuário; senão o OneSignal responderia "não
      // enviado" e a chave de idempotência ficaria gasta à toa. Na
      // próxima atualização dos dados a checagem roda de novo.
      if (!(OneSignal.User.pushSubscription.optedIn ?? false)) return;
      final externalId = await OneSignal.User.getExternalId();
      if (externalId != uid) return;

      final local = expiresAt.toLocal();
      final dateLabel = '${local.day.toString().padLeft(2, '0')}/'
          '${local.month.toString().padLeft(2, '0')}';

      final sent = await _sendPush(
        recipientUserId: uid,
        title: 'Sua assinatura está perto de vencer',
        body: 'Sua assinatura ${tier.label} vence em $dateLabel. '
            'Renove para continuar aproveitando seus benefícios.',
        // 'premium_promo' já abre a tela Premium ao tocar (ver
        // NotificationService.init).
        data: {'kind': 'premium_promo'},
        idempotencyKey: _deterministicUuid('premium_expiry|$uid|$millis'),
      );

      if (sent) {
        _lastExpiryWarnedKey = key;
        await _secureStorage.write(key: storageKey, value: '$millis');
      }
    } catch (e) {
      debugPrint('Erro ao avisar sobre vencimento do Premium: $e');
    } finally {
      _expiryCheckRunning = false;
    }
  }

  /// Gera um identificador em formato UUID, sempre igual para a mesma
  /// entrada (FNV-1a de 64 bits, duas vezes com sementes diferentes).
  /// Serve de chave de idempotência igual em todos os aparelhos.
  static String _deterministicUuid(String input) {
    int fnv(String text, int seed) {
      var hash = seed;
      for (final unit in utf8.encode(text)) {
        hash ^= unit;
        hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
      }
      return hash;
    }

    final a = fnv(input, 0x2bf29ce484222325);
    final b = fnv('$input#', 0x1a2b3c4d5e6f7081);
    final hex = a.toRadixString(16).padLeft(16, '0') +
        b.toRadixString(16).padLeft(16, '0');
    // Versão 4 e variante RFC 4122 nos campos correspondentes.
    final variant = '89ab'[int.parse(hex[16], radix: 16) & 3];
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '4${hex.substring(13, 16)}-$variant${hex.substring(17, 20)}-'
        '${hex.substring(20, 32)}';
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