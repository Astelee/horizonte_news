import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static const String _permissionKey = 'notif_permission_asked';
  static const String _oneSignalAppId = '999de6a2-1965-4cb0-9558-a0cc8ed39828';

  static final _storage = const FlutterSecureStorage();

  static Future<void> init() async {
    OneSignal.initialize(_oneSignalAppId);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    OneSignal.Notifications.addClickListener((event) {
      debugPrint(
          'OneSignal: notificação tocada — ${event.notification.title}');
    });
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
}
