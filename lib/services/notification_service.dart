import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_navigator.dart';
import '../screens/post_detail_screen.dart';
import 'news_service.dart';

class NotificationService {
  static const String _permissionKey = 'notif_permission_asked';
  static const String _oneSignalAppId = '999de6a2-1965-4cb0-9558-a0cc8ed39828';

  static final _storage = const FlutterSecureStorage();
  static final _newsService = NewsService();

  static Future<void> init() async {
    OneSignal.initialize(_oneSignalAppId);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      final postId = data?['postId'] as String?;
      final commentId = data?['commentId'] as String?;
      final replyId = data?['replyId'] as String?;
      if (postId != null && postId.isNotEmpty) {
        _openPost(postId, commentId: commentId, replyId: replyId);
      }
    });
  }

  /// Associa o uid do Firebase ao usuário do OneSignal como External
  /// ID — é essa associação que permite mirar push para UM usuário
  /// específico (ver AppNotificationService), em vez de só o
  /// broadcast "All" usado para novas notícias. Deve ser chamado
  /// sempre que o login for concluído (ver AuthService.signIn e o
  /// listener de authStateChanges em main.dart, que também cobre
  /// "lembrar login").
  static Future<void> loginExternalUser(String uid) async {
    try {
      await OneSignal.login(uid);
    } catch (e) {
      debugPrint('Erro ao registrar external_id no OneSignal: $e');
    }
  }

  /// Desassocia o dispositivo do uid ao deslogar, para que pushes
  /// direcionados a esse uid parem de chegar neste aparelho.
  static Future<void> logoutExternalUser() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('Erro ao remover external_id do OneSignal: $e');
    }
  }

  /// Busca a notícia pelo id vindo do payload da notificação e
  /// navega até PostDetailScreen. Se a notícia não existir mais (ou
  /// tiver sido despublicada), não faz nada — não há como abrir uma
  /// tela sem o post. Quando o payload inclui commentId/replyId (caso
  /// de notificações de resposta/curtida em comentário), repassa como
  /// argumento para a tela abrir os comentários já expandidos e
  /// destacar o item correspondente.
  static Future<void> _openPost(
    String postId, {
    String? commentId,
    String? replyId,
  }) async {
    if (navigatorKey.currentState == null) return;

    try {
      final post = await _newsService.fetchById(postId);
      if (post == null) return;

      navigatorKey.currentState?.pushNamed(
        '/post-detail', // mesmo valor de AppRoutes.postDetail
        arguments: (commentId != null && commentId.isNotEmpty)
            ? PostDetailArgs(
                post: post,
                highlightCommentId: commentId,
                highlightReplyId: replyId,
              )
            : post,
      );
    } catch (e) {
      debugPrint('Erro ao abrir notícia a partir da notificação: $e');
    }
  }

  static Future<bool> jaFoiPedidoPermissao() async {
    final value = await _storage.read(key: _permissionKey);
    return value == 'true';
  }

  static Future<void> marcarPermissaoJaPedida() async {
    await _storage.write(key: _permissionKey, value: 'true');
  }

  static Future<void> pedirPermissao() async {
    await OneSignal.Notifications.requestPermission(true);
    await marcarPermissaoJaPedida();
  }

  static Future<void> setNotificacoesAtivas(bool ativo) async {
    await OneSignal.User.pushSubscription.optIn();
    if (!ativo) await OneSignal.User.pushSubscription.optOut();
  }

  static Future<bool> notificacoesAtivas() async {
    return OneSignal.User.pushSubscription.optedIn ?? false;
  }

  // ── Aliases usados por settings_screen.dart ────────────────────────

  /// Verifica se as notificações estão habilitadas (permissão do SO
  /// concedida e usuário opt-in no OneSignal).
  static Future<bool> areNotificationsEnabled() async {
    final permissionStatus = OneSignal.Notifications.permission;
    final optedIn = OneSignal.User.pushSubscription.optedIn ?? false;
    return permissionStatus && optedIn;
  }

  /// Solicita a permissão de notificação ao usuário e retorna se foi
  /// concedida.
  static Future<bool> requestPermission() async {
    final granted = await OneSignal.Notifications.requestPermission(true);
    await marcarPermissaoJaPedida();
    if (granted) {
      await OneSignal.User.pushSubscription.optIn();
    }
    return granted;
  }
}