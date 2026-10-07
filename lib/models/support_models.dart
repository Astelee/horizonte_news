import 'package:cloud_firestore/cloud_firestore.dart';

/// Categorias opcionais do atendimento (campo `category` da conversa).
class SupportCategory {
  SupportCategory._();

  static const String app = 'app';
  static const String technical = 'tecnico';
  static const String subscription = 'assinatura';
  static const String information = 'informacao';
  static const String advertise = 'anunciar';

  static const Map<String, String> labels = {
    app: 'Dúvida sobre o app',
    technical: 'Problema técnico',
    subscription: 'Assinatura',
    information: 'Enviar informação',
    advertise: 'Anunciar',
  };

  static String labelOf(String? key) => labels[key] ?? '';
}

/// Resposta citada dentro de uma mensagem (campo `replyTo`).
class SupportReplyRef {
  final String id;
  final String text;
  final String senderRole; // 'user' | 'agent'

  const SupportReplyRef({
    required this.id,
    required this.text,
    required this.senderRole,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text.length > 200 ? text.substring(0, 200) : text,
        'senderRole': senderRole,
      };

  static SupportReplyRef? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final text = raw['text'];
    final role = raw['senderRole'];
    if (id is! String || text is! String || role is! String) return null;
    return SupportReplyRef(id: id, text: text, senderRole: role);
  }
}

/// Dados do usuário copiados para a conversa (nome, username, foto),
/// usados pela caixa de entrada do ADM sem precisar ler users_xp de
/// cada conversa.
class SupportProfile {
  final String userId;
  final String userName;
  final String username;
  final String? photoUrl;

  const SupportProfile({
    required this.userId,
    required this.userName,
    this.username = '',
    this.photoUrl,
  });
}

class SupportMessage {
  final String id;
  final String senderId;
  final String senderRole; // 'user' | 'agent'
  final String text;

  /// Horário do servidor. Enquanto a gravação está pendente o Firestore
  /// devolve uma estimativa local (ver [pending]).
  final DateTime? createdAt;
  final Timestamp? createdTs;
  final SupportReplyRef? replyTo;

  /// true = ainda não confirmada pelo servidor (sem rede ou em envio).
  final bool pending;

  /// true = envio falhou e está só no aparelho (ver SupportChatScreen).
  final bool failed;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.createdAt,
    this.createdTs,
    this.replyTo,
    this.pending = false,
    this.failed = false,
  });

  bool get fromAgent => senderRole == 'agent';

  SupportMessage copyWith({bool? pending, bool? failed}) => SupportMessage(
        id: id,
        senderId: senderId,
        senderRole: senderRole,
        text: text,
        createdAt: createdAt,
        createdTs: createdTs,
        replyTo: replyTo,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );

  factory SupportMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    // Mensagem recém-enviada: enquanto o servidor não confirma, o
    // `createdAt` ainda não existe (vem null). `pending` indica isso e
    // a tela mostra "Enviando" em vez de horário.
    final ts = data['createdAt'];
    return SupportMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderRole: (data['senderRole'] as String?) ?? 'user',
      text: (data['text'] as String?) ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
      createdTs: ts is Timestamp ? ts : null,
      replyTo: SupportReplyRef.fromMap(data['replyTo']),
      pending: doc.metadata.hasPendingWrites,
    );
  }
}

class SupportConversation {
  final String id; // = UID do usuário
  final String userId;
  final String userName;
  final String username;
  final String? photoUrl;
  final String? category;
  final String status; // 'open' | 'resolved'
  final bool pinned;
  final bool blocked;
  final bool awaitingReply;
  final int unreadUser;
  final int unreadAgent;
  final String lastMessageText;
  final String lastMessageSenderRole;
  final DateTime? lastMessageAt;
  final DateTime? lastActivityAt;
  final DateTime? userReadAt;
  final DateTime? agentReadAt;

  /// "Limpar conversa" do usuário / "Excluir só para mim" do atendente:
  /// cada lado só enxerga mensagens posteriores a este horário.
  final DateTime? userClearedAt;
  final DateTime? agentClearedAt;
  final bool hidePreview;

  const SupportConversation({
    required this.id,
    required this.userId,
    required this.userName,
    this.username = '',
    this.photoUrl,
    this.category,
    this.status = 'open',
    this.pinned = false,
    this.blocked = false,
    this.awaitingReply = false,
    this.unreadUser = 0,
    this.unreadAgent = 0,
    this.lastMessageText = '',
    this.lastMessageSenderRole = '',
    this.lastMessageAt,
    this.lastActivityAt,
    this.userReadAt,
    this.agentReadAt,
    this.userClearedAt,
    this.agentClearedAt,
    this.hidePreview = true,
  });

  bool get isResolved => status == 'resolved';

  /// Tirada da caixa de entrada pela equipe ("Excluir só para mim").
  /// Volta sozinha quando o usuário escrever de novo.
  bool get isArchived => status == 'archived';

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory SupportConversation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const <String, dynamic>{};
    return SupportConversation(
      id: doc.id,
      userId: (d['userId'] as String?) ?? doc.id,
      userName: (d['userName'] as String?) ?? '',
      username: (d['username'] as String?) ?? '',
      photoUrl: d['photoUrl'] as String?,
      category: d['category'] as String?,
      status: (d['status'] as String?) ?? 'open',
      pinned: d['pinned'] == true,
      blocked: d['blocked'] == true,
      awaitingReply: d['awaitingReply'] == true,
      unreadUser: (d['unreadUser'] as num?)?.toInt() ?? 0,
      unreadAgent: (d['unreadAgent'] as num?)?.toInt() ?? 0,
      lastMessageText: (d['lastMessageText'] as String?) ?? '',
      lastMessageSenderRole: (d['lastMessageSenderRole'] as String?) ?? '',
      lastMessageAt: _date(d['lastMessageAt']),
      lastActivityAt: _date(d['lastActivityAt']),
      userReadAt: _date(d['userReadAt']),
      agentReadAt: _date(d['agentReadAt']),
      userClearedAt: _date(d['userClearedAt']),
      agentClearedAt: _date(d['agentClearedAt']),
      // Sem o campo (conversa criada pelo ADM) vale o padrão: ocultar.
      hidePreview: d['hidePreview'] != false,
    );
  }
}

/// Textos públicos do atendimento (support_config/public).
class SupportPublicConfig {
  final bool enabled;
  final String welcomeMessage;
  final String offHoursMessage;
  final bool hoursEnabled;

  /// Minutos desde 00:00 (horário local do aparelho). Ex.: 9h = 540.
  final int startMinutes;
  final int endMinutes;

  /// Dias da semana com atendimento, 1 = segunda ... 7 = domingo.
  final List<int> days;
  final bool hidePreviewAgent;

  const SupportPublicConfig({
    this.enabled = true,
    this.welcomeMessage = '',
    this.offHoursMessage = '',
    this.hoursEnabled = false,
    this.startMinutes = 9 * 60,
    this.endMinutes = 18 * 60,
    this.days = const [1, 2, 3, 4, 5],
    this.hidePreviewAgent = true,
  });

  static const SupportPublicConfig empty = SupportPublicConfig();

  factory SupportPublicConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null) return empty;
    final hours = d['hours'];
    final h = hours is Map ? hours : const {};
    final rawDays = h['days'];
    return SupportPublicConfig(
      enabled: d['enabled'] != false,
      welcomeMessage: (d['welcomeMessage'] as String?) ?? '',
      offHoursMessage: (d['offHoursMessage'] as String?) ?? '',
      hoursEnabled: h['enabled'] == true,
      startMinutes: (h['startMinutes'] as num?)?.toInt() ?? 9 * 60,
      endMinutes: (h['endMinutes'] as num?)?.toInt() ?? 18 * 60,
      days: rawDays is List
          ? rawDays.whereType<num>().map((e) => e.toInt()).toList()
          : const [1, 2, 3, 4, 5],
      hidePreviewAgent: d['hidePreviewAgent'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'welcomeMessage': welcomeMessage,
        'offHoursMessage': offHoursMessage,
        'hidePreviewAgent': hidePreviewAgent,
        'hours': {
          'enabled': hoursEnabled,
          'startMinutes': startMinutes,
          'endMinutes': endMinutes,
          'days': days,
        },
      };

  /// true quando [now] está FORA do horário configurado. Sem horário
  /// configurado nunca considera "fora do horário".
  bool isOutsideHours(DateTime now) {
    if (!hoursEnabled) return false;
    if (!days.contains(now.weekday)) return true;
    final minutes = now.hour * 60 + now.minute;
    return minutes < startMinutes || minutes >= endMinutes;
  }
}

/// Quem atende e quem recebe push (support_config/agents).
class SupportAgentsConfig {
  final List<String> agentUids;
  final List<String> notifyUids;

  /// false = o documento ainda não existe (modo inicial: todo admin
  /// atende e recebe push).
  final bool configured;

  const SupportAgentsConfig({
    this.agentUids = const [],
    this.notifyUids = const [],
    this.configured = false,
  });

  static const SupportAgentsConfig empty = SupportAgentsConfig();

  factory SupportAgentsConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null) return empty;
    List<String> list(dynamic v) =>
        v is List ? v.whereType<String>().toList() : <String>[];
    return SupportAgentsConfig(
      agentUids: list(d['agentUids']),
      notifyUids: list(d['notifyUids']),
      configured: true,
    );
  }

  bool canAttend(String uid) => !configured || agentUids.contains(uid);
  bool receivesPush(String uid) => !configured || notifyUids.contains(uid);
}

class SupportQuickReply {
  final String id;
  final String title;
  final String text;
  final int order;

  const SupportQuickReply({
    required this.id,
    required this.title,
    required this.text,
    this.order = 0,
  });

  factory SupportQuickReply.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return SupportQuickReply(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      text: (d['text'] as String?) ?? '',
      order: (d['order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Argumentos da rota do chat (AppRoutes.support). Sem argumentos, a
/// tela abre a conversa do próprio usuário logado. Com [conversationId]
/// de outra pessoa, só abre para atendentes (as regras do Firestore
/// recusam a leitura para qualquer outro).
class SupportChatArgs {
  final String conversationId;

  /// Dados do usuário para o ADM iniciar uma conversa que ainda não
  /// existe (nenhum documento criado até a primeira mensagem).
  final SupportProfile? seedProfile;

  const SupportChatArgs({required this.conversationId, this.seedProfile});
}