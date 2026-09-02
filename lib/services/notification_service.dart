import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_navigator.dart';
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
      final postId = event.notification.additionalData?['postId'] as String?;
      if (postId != null && postId.isNotEmpty) {
        _openPost(postId);
      }
    });
  }

  /// Busca a notícia pelo id vindo do payload da notificação e
  /// navega até PostDetailScreen. Se a notícia não existir mais (ou
  /// tiver sido despublicada), não faz nada — não há como abrir uma
  /// tela sem o post.
  static Future<void> _openPost(String postId) async {
    if (navigatorKey.currentState == null) return;

    try {
      final post = await _newsService.fetchById(postId);
      if (post == null) return;

      navigatorKey.currentState?.pushNamed(
        '/post-detail', // mesmo valor de AppRoutes.postDetail
        arguments: post,
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