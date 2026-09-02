import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../models/post_model.dart';

/// Dispara notificações push via API REST do OneSignal, chamada
/// diretamente do app quando um ADM publica uma notícia.
///
/// A REST API Key fica embutida no binário via `--dart-define`
/// (nunca hardcoded aqui). Como o app é o único emissor — não há
/// backend —, essa chave viaja dentro do APK. Ver observação de
/// segurança no README/CI sobre restringir essa chave no painel do
/// OneSignal (permissão apenas de "criar notificação").
class PushNotificationService {
  static const String _appId = '999de6a2-1965-4cb0-9558-a0cc8ed39828';

  static const String _restApiKey =
      String.fromEnvironment('ONESIGNAL_REST_API_KEY');

  static const String _endpoint =
      'https://onesignal.com/api/v1/notifications';

  /// Envia um push para todos os inscritos avisando de uma notícia
  /// nova/recém-publicada. Nunca lança exceção — a publicação da
  /// notícia em si não deve ser impedida por falha no push. O
  /// resultado é retornado para que a tela decida se mostra um aviso
  /// (ex.: SnackBar) ao ADM.
  static Future<PushNotificationResult> notifyPostPublished(
      PostModel post) async {
    if (_restApiKey.isEmpty) {
      const msg =
          'Push não enviado: chave do OneSignal ausente neste build '
          '(app não foi buildado com --dart-define=ONESIGNAL_REST_API_KEY=...).';
      debugPrint(msg);
      return const PushNotificationResult(success: false, message: msg);
    }

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          // Chaves REST API v2 do OneSignal (prefixo "os_v2_app_")
          // usam o esquema "Key", não "Basic" (esse era o esquema da
          // chave Legacy, que é um formato diferente).
          'Authorization': 'Key $_restApiKey',
        },
        body: json.encode({
          'app_id': _appId,
          'included_segments': ['All'],
          'headings': {'en': post.categories.isNotEmpty
              ? post.categories.first.name.toUpperCase()
              : 'HORIZONTE NEWS'},
          'contents': {'en': post.title},
          'big_picture': post.thumbnailUrl.isNotEmpty ? post.thumbnailUrl : null,
          'data': {'postId': post.id},
        }),
      );

      if (response.statusCode != 200) {
        final msg =
            'Falha ao enviar push (${response.statusCode}): ${response.body}';
        debugPrint(msg);
        return PushNotificationResult(success: false, message: msg);
      }

      // O OneSignal às vezes retorna HTTP 200 mesmo quando não há
      // ninguém para receber a notificação (ex.: segmento vazio) ou
      // quando há um erro "suave" embutido no corpo. Nesses casos o
      // campo "id" vem vazio/ausente e/ou "recipients" vem 0 — então
      // checamos o corpo em vez de confiar só no status HTTP.
      Map<String, dynamic>? body;
      try {
        body = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = null;
      }

      final notificationId = body?['id'] as String?;
      final recipients = body?['recipients'];
      final errors = body?['errors'];

      if (errors != null) {
        final msg = 'Push aceito (200) mas com erro: $errors';
        debugPrint(msg);
        return PushNotificationResult(success: false, message: msg);
      }

      if (notificationId == null || notificationId.isEmpty) {
        final msg =
            'Push aceito (200) mas sem id de notificação — resposta: '
            '${response.body}';
        debugPrint(msg);
        return PushNotificationResult(success: false, message: msg);
      }

      if (recipients == 0) {
        const msg =
            'Push enviado, mas 0 destinatários — ninguém está inscrito/'
            'opt-in no app no momento.';
        debugPrint(msg);
        return const PushNotificationResult(success: false, message: msg);
      }

      return PushNotificationResult(
        success: true,
        message: 'Enviado (id: $notificationId, destinatários: $recipients)',
      );
    } catch (e) {
      final msg = 'Erro ao enviar push: $e';
      debugPrint(msg);
      return PushNotificationResult(success: false, message: msg);
    }
  }
}

/// Resultado do envio de push, usado pela UI para exibir um aviso ao
/// ADM quando o envio falha (ex.: chave ausente, erro da API).
class PushNotificationResult {
  final bool success;
  final String? message;

  const PushNotificationResult({required this.success, this.message});
}