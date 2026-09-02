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
  /// nova/recém-publicada. Falhas são apenas logadas — nunca devem
  /// impedir a publicação da notícia em si.
  static Future<void> notifyPostPublished(PostModel post) async {
    if (_restApiKey.isEmpty) {
      debugPrint(
          'ONESIGNAL_REST_API_KEY vazia — build não foi feita com '
          '--dart-define=ONESIGNAL_REST_API_KEY=... Push não enviado.');
      return;
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
          'included_segments': ['Subscribed Users'],
          'headings': {'en': post.categories.isNotEmpty
              ? post.categories.first.name.toUpperCase()
              : 'HORIZONTE NEWS'},
          'contents': {'en': post.title},
          'big_picture': post.thumbnailUrl.isNotEmpty ? post.thumbnailUrl : null,
          'data': {'postId': post.id},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
            'Falha ao enviar push (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro ao enviar push: $e');
    }
  }
}