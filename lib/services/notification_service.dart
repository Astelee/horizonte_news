import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static const String _permissionKey = 'notif_permission_asked';
  static const String _oneSignalAppId = 'SEU_APP_ID_AQUI'; // ← cole seu App ID do OneSignal

  static final _storage = const FlutterSecureStorage();

  // ── Inicializa o OneSignal — chamar no main() ─────────────────
  static Future<void> init() async {
    OneSignal.initialize(_oneSignalAppId);

    // Permite que o OneSignal exiba notificações em foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    // Log quando o usuário toca na notificação
    OneSignal.Notifications.addClickListener((event) {
      debugPrint(
          'OneSignal: notificação tocada — ${event.notification.title}');
    });
  }

  // ── Verifica se já pediu permissão antes (usa SecureStorage,
  //    não sofre com backup do Android) ──────────────────────────
  static Future<bool> jaFoiPedidoPermissao() async {
    final value = await _storage.read(key: _permissionKey);
    return value == 'true';
  }

  static Future<void> marcarPermissaoJaPedida() async {
    await _storage.write(key: _permissionKey, value: 'true');
  }

  // ── Pede permissão via OneSignal ──────────────────────────────
  static Future<void> pedirPermissao() async {
    await OneSignal.Notifications.requestPermission(true);
    await marcarPermissaoJaPedida();
  }

  // ── Ativa ou desativa notificações (usado nas configurações) ──
  static Future<void> setNotificacoesAtivas(bool ativo) async {
    await OneSignal.User.pushSubscription.optIn();
    if (!ativo) await OneSignal.User.pushSubscription.optOut();
  }

  static Future<bool> notificacoesAtivas() async {
    return OneSignal.User.pushSubscription.optedIn ?? false;
  }
}
