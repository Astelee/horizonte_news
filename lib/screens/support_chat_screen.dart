import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../features/admin/providers/admin_provider.dart';
import '../features/admin/services/admin_support_service.dart';
import '../features/admin/services/admin_user_service.dart';
import '../features/admin/widgets/user_profile_sheet.dart';
import '../models/support_models.dart';
import '../providers/user_xp_provider.dart';
import '../services/support_chat_service.dart';
import '../services/support_launcher.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_messenger.dart';
import '../widgets/support_fab.dart';
import '../features/admin/widgets/support_delete_dialogs.dart';

/// Conversa de atendimento. A MESMA tela serve o usuário (sua própria
/// conversa) e o atendente (conversa de qualquer usuário, aberta pela
/// caixa de entrada, pelo perfil ADM ou pelo push).
///
/// Argumento opcional: [SupportChatArgs]. Sem argumento = conversa do
/// próprio usuário logado.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({Key? key}) : super(key: key);

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with WidgetsBindingObserver {
  final _service = SupportChatService.instance;
  final _adminService = AdminSupportService();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  late final String _myUid;
  late String _convId;
  late bool _asAgent;
  SupportProfile? _seedProfile;
  bool _argsRead = false;

  StreamSubscription<SupportConversation?>? _convSub;
  StreamSubscription<List<SupportMessage>>? _msgSub;
  StreamSubscription<SupportPublicConfig>? _cfgSub;
  StreamSubscription<User?>? _authSub;

  SupportConversation? _conv;
  bool _convLoaded = false;
  bool _noAccess = false;
  List<SupportMessage> _latest = const [];
  bool _messagesLoaded = false;
  final List<SupportMessage> _older = [];
  final List<SupportMessage> _failed = [];
  bool _loadingOlder = false;
  bool _hasMore = true;
  SupportPublicConfig _config = SupportPublicConfig.empty;

  SupportReplyRef? _replyTo;
  String? _category;
  bool _hidePreview = true;
  bool _resumed = true;
  bool _atBottom = true;
  bool _showJump = false;
  int _newWhileAway = 0;
  Set<String> _knownIds = {};
  bool _markingRead = false;

  // Histórico escondido por "Limpar conversa" (usuário) ou "Excluir só
  // para mim" (atendente): só mensagens depois deste horário.
  DateTime? _localCleared; // vale até o horário do servidor chegar
  DateTime? _subscribedBoundary;
  bool _msgsStarted = false;

  DateTime? get _boundary {
    final server = _asAgent ? _conv?.agentClearedAt : _conv?.userClearedAt;
    return server ?? _localCleared;
  }
  DateTime? _lastSendAt;
  bool _showOffHoursNote = false;
  bool _pendingSlow = false;
  Timer? _pendingTimer;
  Timer? _draftTimer;

  String get _draftKey => 'support_draft_${_myUid}_$_convId';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _convId = _myUid;
    _asAgent = false;
    _scroll.addListener(_onScroll);
    _controller.addListener(_onTextChanged);

    // Trocar de conta com o chat aberto: fecha a tela (os listeners
    // são cancelados em dispose).
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u?.uid != _myUid && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is SupportChatArgs) {
      _convId = args.conversationId;
      _seedProfile = args.seedProfile;
    }
    _asAgent = _convId != _myUid;

    _start();
  }

  Future<void> _start() async {
    if (_myUid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    _hidePreview = prefs.getBool('support_hide_preview_$_myUid') ?? true;
    final draft = prefs.getString(_draftKey);
    if (draft != null && draft.isNotEmpty && mounted) {
      _controller.text = draft;
    }

    _convSub = _service.watchConversation(_convId).listen(
      (c) {
        if (!mounted) return;
        setState(() {
          _conv = c;
          _convLoaded = true;
          _noAccess = false;
        });
        _syncMessageSubscription();
        _maybeMarkRead();
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _convLoaded = true;
            _noAccess = true;
          });
        }
      },
    );

    _cfgSub = _service.watchPublicConfig().listen((c) {
      if (mounted) setState(() => _config = c);
    }, onError: (_) {});

    if (_asAgent && _seedProfile == null) {
      try {
        final p = await _service.loadUserProfile(_convId);
        if (mounted) _seedProfile = p;
      } catch (_) {}
    }
    _updateViewing();
  }

  /// (Re)assina as mensagens quando muda o horário de "limpeza". Só
  /// começa depois de conhecer a conversa, para já usar o limite certo.
  void _syncMessageSubscription() {
    final b = _boundary;
    if (_msgsStarted && b == _subscribedBoundary) return;
    _msgsStarted = true;
    _subscribedBoundary = b;
    _msgSub?.cancel();
    _older.clear();
    _failed.clear();
    _latest = const [];
    _hasMore = true;
    _knownIds = {};
    _msgSub = _service
        .watchLatestMessages(_convId, after: b)
        .listen(
      _onMessages,
      onError: (_) {
        if (mounted) setState(() => _messagesLoaded = true);
      },
    );
  }

  // ── Ciclo de vida / presença ────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _updateViewing();
    if (_resumed) _maybeMarkRead();
  }

  void _updateViewing() {
    SupportLauncher.viewingConversationId = _resumed ? _convId : null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (SupportLauncher.viewingConversationId == _convId) {
      SupportLauncher.viewingConversationId = null;
    }
    _saveDraftNow();
    _convSub?.cancel();
    _msgSub?.cancel();
    _cfgSub?.cancel();
    _authSub?.cancel();
    _pendingTimer?.cancel();
    _draftTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Rascunho ────────────────────────────────────────────────────

  void _onTextChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraftNow);
    if (mounted) setState(() {});
  }

  Future<void> _saveDraftNow() async {
    if (_myUid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = _controller.text;
      if (text.trim().isEmpty) {
        await prefs.remove(_draftKey);
      } else {
        await prefs.setString(_draftKey, text);
      }
    } catch (_) {}
  }

  // ── Mensagens ───────────────────────────────────────────────────

  void _onMessages(List<SupportMessage> list) {
    if (!mounted) return;

    // Mensagens novas do outro lado enquanto a pessoa lê o histórico.
    final ids = list.map((m) => m.id).toSet();
    if (_messagesLoaded && !_atBottom) {
      final fresh = list
          .where((m) => !_knownIds.contains(m.id) && _isFromOtherSide(m));
      _newWhileAway += fresh.length;
    }
    _knownIds = ids;

    final anyPending = list.any((m) => m.pending);
    if (anyPending) {
      _pendingTimer ??= Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _pendingSlow = true);
      });
    } else {
      _pendingTimer?.cancel();
      _pendingTimer = null;
      _pendingSlow = false;
    }

    setState(() {
      _latest = list;
      _messagesLoaded = true;
      if (list.length < SupportChatService.pageSize && _older.isEmpty) {
        _hasMore = false;
      }
    });
    _maybeMarkRead();
  }

  bool _isFromOtherSide(SupportMessage m) =>
      _asAgent ? !m.fromAgent : m.fromAgent;

  List<SupportMessage> get _messages {
    final ids = _latest.map((m) => m.id).toSet();
    final all = [
      ..._latest,
      ..._older.where((m) => !ids.contains(m.id)),
    ]..sort((a, b) {
        final ta = a.createdAt, tb = b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return -1; // pendente = mais recente
        if (tb == null) return 1;
        return tb.compareTo(ta);
      });
    return [..._failed, ...all];
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore) return;
    final confirmed = _messages.where((m) => m.createdTs != null).toList();
    if (confirmed.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _service.loadOlder(
        _convId,
        before: confirmed.last.createdTs!,
        after: _subscribedBoundary,
      );
      if (!mounted) return;
      setState(() {
        _older.addAll(page);
        if (page.length < SupportChatService.pageSize) _hasMore = false;
      });
    } catch (_) {
      if (mounted) AppMessenger.error('Não foi possível carregar mensagens antigas.');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  // ── Scroll ──────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final off = _scroll.offset;
    final atBottom = off < 60;
    final showJump = off > 300;
    if (atBottom != _atBottom || showJump != _showJump) {
      setState(() {
        _atBottom = atBottom;
        _showJump = showJump;
        if (atBottom) _newWhileAway = 0;
      });
      if (atBottom) _maybeMarkRead();
    }
    if (_scroll.position.maxScrollExtent - off < 240) _loadOlder();
  }

  void _jumpToRecent() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Leitura ─────────────────────────────────────────────────────

  /// Marca como lidas só quando as mensagens do outro lado estão de
  /// fato na tela: app em primeiro plano, esta conversa na frente e a
  /// lista no fim (mensagens recentes visíveis).
  void _maybeMarkRead() {
    final conv = _conv;
    if (conv == null || _markingRead || !_resumed || !_atBottom) return;
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final unread = _asAgent ? conv.unreadAgent : conv.unreadUser;
    if (unread <= 0) return;
    // Só depois de a lista ter carregado e exibido a mensagem mais recente.
    if (!_messagesLoaded || !_latest.any(_isFromOtherSide)) return;

    _markingRead = true;
    _service.markRead(_convId, asAgent: _asAgent).whenComplete(() {
      _markingRead = false;
    });
  }

  // ── Envio ───────────────────────────────────────────────────────

  SupportProfile _senderProfile() {
    if (_asAgent) {
      return _seedProfile ??
          SupportProfile(
            userId: _convId,
            userName: _conv?.userName ?? 'Usuário',
            username: _conv?.username ?? '',
            photoUrl: _conv?.photoUrl,
          );
    }
    final user = FirebaseAuth.instance.currentUser;
    final xp = context.read<UserXpProvider>().data;
    final username = (xp.username ?? '').trim();
    String name = (user?.displayName ?? '').trim();
    if (name.isEmpty) {
      name = username.isNotEmpty
          ? username
          : ((user?.email ?? '').split('@').first);
    }
    if (name.isEmpty) name = 'Usuário';
    final photo = xp.photoUrl;
    return SupportProfile(
      userId: _myUid,
      userName: name,
      username: username,
      photoUrl: (photo != null && photo.isNotEmpty) ? photo : null,
    );
  }

  Future<void> _send({SupportMessage? retry}) async {
    final text = (retry?.text ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (text.length > SupportChatService.maxTextLength) {
      AppMessenger.error(
          'Mensagem muito longa (máximo ${SupportChatService.maxTextLength} caracteres).');
      return;
    }
    if (!_convLoaded) return;
    if (!_asAgent && (_conv?.blocked ?? false)) return;

    final last = _lastSendAt;
    if (!_asAgent &&
        last != null &&
        DateTime.now().difference(last) < SupportChatService.minSendInterval) {
      AppMessenger.warning('Aguarde um instante para enviar outra mensagem.');
      return;
    }
    _lastSendAt = DateTime.now();

    final messageId = retry?.id ?? _service.newMessageId(_convId);
    final reply = retry?.replyTo ?? _replyTo;
    final category = _asAgent ? null : (_conv?.category == null ? _category : null);
    final exists = _conv != null;

    setState(() {
      if (retry == null) {
        _controller.clear();
        _replyTo = null;
      } else {
        _failed.removeWhere((m) => m.id == messageId);
      }
    });
    if (retry == null) _saveDraftNow();
    _jumpToRecent();

    try {
      await _service.sendMessage(
        conversationId: _convId,
        messageId: messageId,
        text: text,
        asAgent: _asAgent,
        conversationExists: exists,
        profile: _senderProfile(),
        replyTo: reply,
        category: category,
        hidePreview: _asAgent ? (_conv?.hidePreview ?? true) : _hidePreview,
        hidePreviewForAgents: _config.hidePreviewAgent,
        isRetry: retry != null,
      );
      if (!_asAgent) await _maybeShowOffHoursNote();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed.insert(
          0,
          SupportMessage(
            id: messageId,
            senderId: _myUid,
            senderRole: _asAgent ? 'agent' : 'user',
            text: text,
            replyTo: reply,
            failed: true,
          ),
        );
      });
      AppMessenger.error('Falha ao enviar a mensagem. Toque nela para tentar de novo.');
    }
  }

  /// Aviso de fora do horário: mostrado uma vez a cada 6 horas, só
  /// depois de uma mensagem enviada (não a cada abertura do chat).
  Future<void> _maybeShowOffHoursNote() async {
    if (_config.offHoursMessage.trim().isEmpty ||
        !_config.isOutsideHours(DateTime.now())) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'support_offhours_notice_$_myUid';
    final lastMs = prefs.getInt(key) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastMs < const Duration(hours: 6).inMilliseconds) return;
    await prefs.setInt(key, now);
    if (mounted) setState(() => _showOffHoursNote = true);
  }

  // ── Ações ───────────────────────────────────────────────────────

  void _openMessageActions(SupportMessage m) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.failed) ...[
              ListTile(
                leading: const Icon(Icons.refresh_rounded,
                    color: AppColors.primaryOrange),
                title: const Text('Tentar enviar de novo',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _send(retry: m);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.emergencyRed),
                title: const Text('Descartar',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _failed.removeWhere((x) => x.id == m.id));
                },
              ),
            ] else if (!m.pending) ...[
              ListTile(
                leading: const Icon(Icons.reply_rounded,
                    color: AppColors.primaryOrange),
                title: const Text('Responder',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyTo = SupportReplyRef(
                      id: m.id,
                      text: m.text.length > 200
                          ? m.text.substring(0, 200)
                          : m.text,
                      senderRole: m.senderRole,
                    );
                  });
                  _focus.requestFocus();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white70),
              title: const Text('Copiar mensagem',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: m.text));
                AppMessenger.success('Mensagem copiada');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuickReplies() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: StreamBuilder<List<SupportQuickReply>>(
            stream: _adminService.watchQuickReplies(),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange),
                  ),
                );
              }
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma resposta rápida. Crie na aba Atendimento do painel (ícone de raio).',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.borderSubtle),
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i].title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(items[i].text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  onTap: () => Navigator.pop(ctx, items[i].text),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      _controller.text = picked;
      _controller.selection =
          TextSelection.collapsed(offset: picked.length);
      _focus.requestFocus();
    }
  }

  Future<void> _toggleResolved() async {
    final c = _conv;
    if (c == null) return;
    try {
      await _adminService.setResolved(c, !c.isResolved);
      if (mounted) {
        AppMessenger.success(
            c.isResolved ? 'Conversa reaberta' : 'Conversa resolvida');
      }
    } catch (_) {
      if (mounted) AppMessenger.error('Não foi possível atualizar a conversa.');
    }
  }

  Future<void> _togglePinned() async {
    final c = _conv;
    if (c == null) return;
    try {
      await _adminService.setPinned(c.id, !c.pinned);
    } catch (_) {
      if (mounted) AppMessenger.error('Não foi possível fixar a conversa.');
    }
  }

  Future<void> _toggleBlocked() async {
    final c = _conv;
    if (c == null) return;
    final blocking = !c.blocked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text(
          blocking ? 'Bloquear atendimento?' : 'Desbloquear atendimento?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          blocking
              ? 'Esta pessoa não poderá mais enviar mensagens ao atendimento. '
                  'Isso NÃO suspende nem bane a conta no app.'
              : 'Esta pessoa poderá voltar a enviar mensagens ao atendimento.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(blocking ? 'Bloquear' : 'Desbloquear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _adminService.setBlocked(c.id, blocking);
      if (!mounted) return;
      context.read<AdminProvider>().logAction(
            action: blocking ? 'support_block' : 'support_unblock',
            targetId: c.userId,
            targetType: 'user',
          );
      AppMessenger.success(
          blocking ? 'Envio bloqueado' : 'Envio liberado');
    } catch (_) {
      if (mounted) AppMessenger.error('Não foi possível alterar o bloqueio.');
    }
  }

  /// Usuário: esconde o histórico só para si. A equipe mantém tudo e
  /// uma nova mensagem reabre o atendimento.
  Future<void> _clearForMe({bool focusComposer = false}) async {
    if (_conv == null) return;
    final ok = focusComposer ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.backgroundElevated,
                title: const Text('Limpar conversa?',
                    style: TextStyle(color: Colors.white)),
                content: const Text(
                  'As mensagens anteriores somem só para você. A equipe '
                  'Horizonte News continua com o histórico. Se você escrever '
                  'de novo, o atendimento é reaberto.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Limpar')),
                ],
              ),
            ) ==
            true;
    if (!ok || !mounted) return;
    setState(() => _localCleared = DateTime.now());
    _syncMessageSubscription();
    try {
      await _service.clearForUser(_convId);
      if (!mounted) return;
      if (focusComposer) {
        _focus.requestFocus();
      } else {
        AppMessenger.success('Conversa limpa');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _localCleared = null);
      _syncMessageSubscription();
      AppMessenger.error('Não foi possível limpar a conversa.');
    }
  }

  /// Atendente: "Excluir só para mim" ou "Excluir para os dois".
  Future<void> _deleteConversation() async {
    final c = _conv;
    if (c == null) return;
    final done = await askAndDeleteSupportConversation(
      context,
      service: _adminService,
      conversation: c,
    );
    if (done && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _toggleHidePreview() async {
    final next = !_hidePreview;
    setState(() => _hidePreview = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('support_hide_preview_$_myUid', next);
    } catch (_) {}
    if (_conv != null) await _service.setHidePreview(_convId, next);
    if (mounted) {
      AppMessenger.info(next
          ? 'O conteúdo não aparece mais nas notificações'
          : 'O conteúdo aparece nas notificações');
    }
  }

  void _openProfile() {
    showUserProfileSheet(
      context,
      userId: _convId,
      userService: AdminUserService(),
    );
  }

  // ── Formatação ──────────────────────────────────────────────────

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _statusFor(SupportMessage m) {
    if (m.failed) return 'Falha ao enviar';
    if (m.pending) return 'Enviando';
    final readAt = _asAgent ? _conv?.userReadAt : _conv?.agentReadAt;
    if (readAt != null &&
        m.createdAt != null &&
        !m.createdAt!.isAfter(readAt)) {
      return 'Lida';
    }
    return 'Enviada';
  }

  // ── Construção da lista ─────────────────────────────────────────

  List<Widget> _buildItems(List<SupportMessage> msgs) {
    final items = <Widget>[];
    if (_showOffHoursNote && _config.offHoursMessage.trim().isNotEmpty) {
      items.add(_systemNote(_config.offHoursMessage.trim(),
          icon: Icons.schedule_rounded));
    }
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      // Mostra quem enviou quando muda o remetente (lista é do mais
      // novo para o mais antigo, então o "anterior" é o índice i + 1).
      final older = i + 1 < msgs.length ? msgs[i + 1] : null;
      final showLabel = older == null ||
          older.senderRole != m.senderRole ||
          older.senderId != m.senderId;
      items.add(_bubble(m, showLabel: showLabel));
      final d = m.createdAt;
      if (d != null) {
        final older = i + 1 < msgs.length ? msgs[i + 1].createdAt : null;
        if (older == null || !_sameDay(d, older)) {
          items.add(_daySeparator(_dayLabel(d)));
        }
      }
    }
    if (_hasMore && msgs.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _loadingOlder
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryOrange))
              : TextButton(
                  onPressed: _loadOlder,
                  child: const Text('Carregar mensagens anteriores',
                      style: TextStyle(color: AppColors.primaryOrange)),
                ),
        ),
      ));
    }
    return items;
  }

  Widget _daySeparator(String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _systemNote(String text, {IconData icon = Icons.info_outline_rounded}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderOrange),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.primaryOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.35)),
              ),
            ],
          ),
        ),
      );

  /// Identifica quem enviou. Para o usuário, toda mensagem da equipe
  /// vem com a etiqueta EQUIPE e o nome do atendimento. Para o
  /// atendente, mostra o nome do usuário e diferencia "você" de outro
  /// atendente.
  Widget _senderLabel(SupportMessage m) {
    final team = m.fromAgent;
    String text;
    if (!_asAgent) {
      if (!team) return const SizedBox.shrink(); // mensagem do próprio usuário
      text = 'Atendimento Horizonte News';
    } else if (team) {
      text = m.senderId == _myUid ? 'Você' : 'Outro atendente';
    } else {
      final name = _conv?.userName ?? _seedProfile?.userName ?? '';
      text = name.isEmpty ? 'Usuário' : name;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (team) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'EQUIPE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: team ? AppColors.primaryOrange : AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(SupportMessage m, {bool showLabel = false}) {
    final mine = _asAgent ? m.fromAgent : !m.fromAgent;
    final failed = m.failed;
    final bg = mine
        ? (failed
            ? AppColors.emergencyRed.withOpacity(0.25)
            : AppColors.primaryOrange)
        : AppColors.backgroundElevated;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final status = mine ? _statusFor(m) : null;
    final time = m.createdAt != null ? _hm(m.createdAt!) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (showLabel) _senderLabel(m),
          GestureDetector(
            onLongPress: () => _openMessageActions(m),
            onTap: failed ? () => _openMessageActions(m) : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                  border: failed
                      ? Border.all(color: AppColors.emergencyRed)
                      : (m.fromAgent && !_asAgent
                          ? Border.all(color: AppColors.borderOrange)
                          : null),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.replyTo != null) _quote(m.replyTo!, mine),
                    Text(
                      m.text,
                      style: TextStyle(
                        color: mine && !failed ? Colors.black : Colors.white,
                        fontSize: 14.5,
                        height: 1.3,
                        fontWeight:
                            mine && !failed ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              [if (time != null) time, if (status != null) status].join(' · '),
              style: TextStyle(
                color: failed ? AppColors.emergencyRed : AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: failed ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quote(SupportReplyRef r, bool mine) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(mine ? 0.15 : 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: mine ? Colors.black54 : AppColors.primaryOrange,
              width: 3,
            ),
          ),
        ),
        child: Text(
          r.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: mine ? Colors.black87 : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );

  // ── Interface ───────────────────────────────────────────────────

  PreferredSizeWidget _appBar() {
    if (_asAgent) {
      final name = (_conv?.userName.isNotEmpty ?? false)
          ? _conv!.userName
          : (_seedProfile?.userName ?? 'Usuário');
      final username = _conv?.username ?? _seedProfile?.username ?? '';
      final c = _conv;
      return AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(
              name: name,
              seed: _convId,
              photoUrl: _conv?.photoUrl ?? _seedProfile?.photoUrl,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  if (username.isNotEmpty)
                    Text('@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Perfil do usuário',
            icon: const Icon(Icons.person_search_rounded),
            onPressed: _openProfile,
          ),
          PopupMenuButton<String>(
            color: AppColors.backgroundElevated,
            iconColor: Colors.white,
            onSelected: (v) {
              switch (v) {
                case 'resolve':
                  _toggleResolved();
                  break;
                case 'pin':
                  _togglePinned();
                  break;
                case 'block':
                  _toggleBlocked();
                  break;
                case 'delete':
                  _deleteConversation();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (c != null) ...[
                PopupMenuItem(
                  value: 'resolve',
                  child: Text(c.isResolved ? 'Reabrir conversa' : 'Marcar como resolvida',
                      style: const TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Text(c.pinned ? 'Desafixar' : 'Fixar no topo',
                      style: const TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                      c.blocked
                          ? 'Desbloquear envio'
                          : 'Bloquear envio no atendimento',
                      style: const TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Excluir conversa…',
                      style: TextStyle(color: AppColors.emergencyRed)),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Atendimento Horizonte News',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          Text('Conversa privada com a equipe',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          color: AppColors.backgroundElevated,
          iconColor: Colors.white,
          onSelected: (v) {
            if (v == 'fab') {
              SupportFabVisibility.setHidden(false);
              AppMessenger.success('Botão "Fale conosco" reexibido');
            } else if (v == 'clear') {
              _clearForMe();
            } else {
              _toggleHidePreview();
            }
          },
          itemBuilder: (_) => [
            if (_conv != null)
              const PopupMenuItem(
                value: 'clear',
                child: Text('Limpar conversa (só para mim)',
                    style: TextStyle(color: Colors.white)),
              ),
            if (SupportFabVisibility.hidden.value)
              const PopupMenuItem(
                value: 'fab',
                child: Text('Mostrar botão "Fale conosco" nas telas',
                    style: TextStyle(color: Colors.white)),
              ),
            PopupMenuItem(
              value: 'preview',
              child: Text(
                _hidePreview
                    ? 'Mostrar conteúdo nas notificações'
                    : 'Ocultar conteúdo nas notificações',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _replyBar() {
    final r = _replyTo;
    if (r == null) return const SizedBox.shrink();
    return Container(
      color: AppColors.backgroundElevated,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: AppColors.primaryOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(r.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textSecondary),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  /// Atendimento finalizado pela equipe: o usuário pode seguir
  /// escrevendo (reabre) ou começar um novo atendimento limpo.
  Widget _resolvedBar() {
    final c = _conv;
    if (_asAgent || c == null || !c.isResolved) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.backgroundElevated,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primaryOrange, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Atendimento finalizado. Se escrever, ele é reaberto.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => _clearForMe(focusComposer: true),
            child: const Text('Novo atendimento',
                style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    if (_asAgent || _messages.isNotEmpty || _conv?.category != null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          for (final e in SupportCategory.labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: _category == e.key,
                selectedColor: AppColors.primaryOrange,
                backgroundColor: AppColors.backgroundElevated,
                labelStyle: TextStyle(
                  color: _category == e.key ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (sel) =>
                    setState(() => _category = sel ? e.key : null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    final conv = _conv;
    if (!_asAgent && (conv?.blocked ?? false)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.backgroundElevated,
        child: const SafeArea(
          top: false,
          child: Text(
            'O envio de mensagens ao atendimento está indisponível para esta conta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }
    if (!_asAgent && !_config.enabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.backgroundElevated,
        child: const SafeArea(
          top: false,
          child: Text(
            'O atendimento está temporariamente indisponível.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    final len = _controller.text.length;
    final canSend = _controller.text.trim().isNotEmpty && _convLoaded;
    return Container(
      color: AppColors.backgroundDark,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_asAgent)
                IconButton(
                  tooltip: 'Respostas rápidas',
                  icon: const Icon(Icons.bolt_rounded,
                      color: AppColors.primaryOrange),
                  onPressed: _openQuickReplies,
                ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                        SupportChatService.maxTextLength),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Escreva sua mensagem',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    counterText: '',
                    suffixText: len > 1800
                        ? '$len/${SupportChatService.maxTextLength}'
                        : null,
                    suffixStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: canSend
                    ? AppColors.primaryOrange
                    : AppColors.backgroundElevated,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canSend ? () => _send() : null,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(Icons.send_rounded,
                        size: 20,
                        color: canSend ? Colors.black : AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_myUid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(backgroundColor: AppColors.backgroundDark),
        body: const Center(
          child: Text('Faça login para falar com o atendimento.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_asAgent && context.watch<AdminProvider>().isAdmin == false) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(backgroundColor: AppColors.backgroundDark),
        body: const Center(
          child: Text('Você não tem acesso a esta conversa.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_noAccess) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Não foi possível abrir esta conversa. Verifique sua conexão ou seu acesso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final msgs = _messages;
    final loading = !_convLoaded || !_messagesLoaded;
    final showWelcome = !_asAgent &&
        !loading &&
        msgs.isEmpty &&
        _config.welcomeMessage.trim().isNotEmpty;

    final conv = _conv;
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _appBar(),
      body: Column(
        children: [
          if (_pendingSlow)
            Container(
              width: double.infinity,
              color: AppColors.primaryOrange.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Text(
                'Aguardando conexão para confirmar o envio. As mensagens '
                'só contam como enviadas quando o servidor confirmar.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          if (_asAgent && conv != null && (conv.isResolved || conv.blocked))
            Container(
              width: double.infinity,
              color: AppColors.backgroundElevated,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                [
                  if (conv.isResolved) 'Conversa resolvida',
                  if (conv.blocked) 'Envio do usuário bloqueado',
                ].join(' · '),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          if (conv?.category != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Categoria: ${SupportCategory.labelOf(conv!.category)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                if (loading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange),
                  )
                else if (showWelcome)
                  ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _systemNote(_config.welcomeMessage.trim(),
                          icon: Icons.waving_hand_rounded),
                    ],
                  )
                else if (msgs.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _asAgent
                            ? 'Nenhuma mensagem ainda. Escreva abaixo para iniciar a conversa.'
                            : 'Escreva sua mensagem para a equipe Horizonte News.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    children: _buildItems(msgs),
                  ),
                if (_showJump)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: _jumpToRecent,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundElevated,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderOrange),
                            ),
                            child: const Icon(
                                Icons.keyboard_double_arrow_down_rounded,
                                color: AppColors.primaryOrange),
                          ),
                          if (_newWhileAway > 0)
                            Positioned(
                              top: -6,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$_newWhileAway',
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _resolvedBar(),
          _replyBar(),
          _categoryBar(),
          _composer(),
        ],
      ),
    );
  }
}