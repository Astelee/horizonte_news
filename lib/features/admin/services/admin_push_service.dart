import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'push_notification_service.dart' show PushNotificationResult;

/// Envio de push feito pelo ADM a partir do painel:
///  • [sendToUser]  → só para UM usuário (External ID = uid do Firebase).
///  • [sendToAll]   → para todos os inscritos (segmento "All").
///
/// Usa a MESMA chave/app_id do OneSignal já usados no app. Nada de
/// Cloud Functions: a chamada sai direto do app do admin.
class AdminPushService {
  static const String _appId = '999de6a2-1965-4cb0-9558-a0cc8ed39828';
  static const String _restApiKey =
      String.fromEnvironment('ONESIGNAL_REST_API_KEY');
  static const String _endpoint =
      'https://onesignal.com/api/v1/notifications';

  /// Push individual. O usuário só recebe se já abriu o app numa
  /// versão com NotificationService.loginExternalUser e permitiu
  /// notificações.
  static Future<PushNotificationResult> sendToUser({
    required String uid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) {
    return _send(
      target: {
        'include_aliases': {
          'external_id': [uid],
        },
        'target_channel': 'push',
      },
      title: title,
      body: body,
      data: data,
    );
  }

  /// Push para todos os inscritos.
  static Future<PushNotificationResult> sendToAll({
    required String title,
    required String body,
    Map<String, String>? data,
  }) {
    return _send(
      target: {
        'included_segments': ['All'],
      },
      title: title,
      body: body,
      data: data,
    );
  }

  static Future<PushNotificationResult> _send({
    required Map<String, dynamic> target,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (_restApiKey.isEmpty) {
      return const PushNotificationResult(
        success: false,
        message: 'Chave do OneSignal ausente neste build '
            '(faltou --dart-define=ONESIGNAL_REST_API_KEY=...).',
      );
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
          ...target,
          'headings': {'en': title},
          'contents': {'en': body},
          if (data != null && data.isNotEmpty) 'data': data,
        }),
      );

      if (response.statusCode != 200) {
        return PushNotificationResult(
          success: false,
          message: 'Falha (${response.statusCode}): ${response.body}',
        );
      }

      Map<String, dynamic>? res;
      try {
        res = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        res = null;
      }

      final id = res?['id'] as String?;
      final recipients = res?['recipients'];
      final errors = res?['errors'];

      // Usuário sem aparelho registrado (nunca logou numa versão nova
      // do app, negou permissão ou está deslogado).
      if (errors != null && (id == null || id.isEmpty)) {
        return const PushNotificationResult(
          success: false,
          message: 'Nenhum aparelho encontrado: o usuário ainda não '
              'abriu a versão nova do app, está deslogado ou desativou '
              'as notificações.',
        );
      }
      if (id == null || id.isEmpty || recipients == 0) {
        return const PushNotificationResult(
          success: false,
          message: '0 destinatários — ninguém disponível para receber.',
        );
      }

      return PushNotificationResult(
        success: true,
        message: 'Enviado para $recipients aparelho(s).',
      );
    } catch (e) {
      debugPrint('Erro no AdminPushService: $e');
      return PushNotificationResult(
        success: false,
        message: 'Erro ao enviar: $e',
      );
    }
  }
}