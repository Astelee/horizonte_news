import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../features/admin/services/admin_support_service.dart';
import '../models/support_models.dart';
import '../services/notification_service.dart';
import '../services/support_chat_service.dart';

/// Estado leve do atendimento, global:
///  • usuário comum → quantas mensagens da equipe ele ainda não leu
///    (um único documento, `support_conversations/{uid}`);
///  • atendente (admin autorizado) → quantas conversas têm mensagens
///    não lidas (consulta limitada, sem carregar mensagens);
///  • mantém no OneSignal a tag que define quais aparelhos de admin
///    recebem push de novas mensagens.
///
/// Tudo é cancelado e zerado ao trocar de conta ou sair.
class SupportProvider with ChangeNotifier {
  SupportProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  final AdminSupportService _adminService = AdminSupportService();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<SupportAgentsConfig>? _agentsSub;
  StreamSubscription<int>? _unreadSub;

  String? _uid;
  bool _isAdmin = false;
  int _unreadCount = 0;
  SupportAgentsConfig _agents = SupportAgentsConfig.empty;

  /// Usuário: mensagens não lidas. Atendente: conversas não lidas.
  int get unreadCount => _unreadCount;

  /// Admin autorizado a atender (ver support_config/agents).
  bool get isAgent => _isAdmin && _uid != null && _agents.canAttend(_uid!);

  /// Chamado pelo ProxyProvider quando o AdminProvider muda.
  void updateAdmin(bool isAdmin) {
    if (_isAdmin == isAdmin) return;
    _isAdmin = isAdmin;
    _restart();
    // Chamado de dentro do build do ProxyProvider: adia a notificação
    // para não mexer em widgets durante a construção.
    scheduleMicrotask(_notifySafe);
  }

  bool _disposed = false;

  void _notifySafe() {
    if (!_disposed) notifyListeners();
  }

  void _onAuth(User? user) {
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _agents = SupportAgentsConfig.empty;
    _unreadCount = 0;
    _stop();
    if (_uid != null) _restart();
    notifyListeners();
  }

  void _stop() {
    _agentsSub?.cancel();
    _agentsSub = null;
    _unreadSub?.cancel();
    _unreadSub = null;
  }

  void _restart() {
    _stop();
    final uid = _uid;
    if (uid == null) return;

    if (!_isAdmin) {
      // Conta sem admin: garante que este aparelho não fique marcado
      // como destino de push da equipe.
      NotificationService.syncSupportAgentTag(enabled: false);
      _watchOwnUnread(uid);
      return;
    }

    _agentsSub = _adminService.watchAgentsConfig().listen(
      (cfg) {
        _agents = cfg;
        NotificationService.syncSupportAgentTag(
          enabled: _isAdmin && cfg.canAttend(uid) && cfg.receivesPush(uid),
        );
        _resubscribeUnread(uid);
        notifyListeners();
      },
      onError: (_) {
        // Sem permissão/rede: segue no modo usuário.
        _agents = SupportAgentsConfig.empty;
        _resubscribeUnread(uid);
        notifyListeners();
      },
    );
  }

  void _resubscribeUnread(String uid) {
    _unreadSub?.cancel();
    _unreadSub = null;
    if (isAgent) {
      _unreadSub = _adminService.watchUnreadConversationCount().listen(
        _setUnread,
        onError: (_) => _setUnread(0),
      );
    } else {
      _watchOwnUnread(uid);
    }
  }

  void _watchOwnUnread(String uid) {
    _unreadSub?.cancel();
    _unreadSub = SupportChatService.instance
        .watchConversation(uid)
        .map((c) => c?.unreadUser ?? 0)
        .listen(_setUnread, onError: (_) => _setUnread(0));
  }

  void _setUnread(int value) {
    if (_unreadCount == value) return;
    _unreadCount = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _stop();
    super.dispose();
  }
}