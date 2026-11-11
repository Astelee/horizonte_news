import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resposta do backend (Cloudflare Worker em `cloudflare/horizonte-worker`).
class BackendResponse {
  const BackendResponse({required this.statusCode, required this.body});

  /// 0 = sem rede / tempo esgotado.
  final int statusCode;
  final Map<String, dynamic> body;

  /// Sucesso de verdade: HTTP 2xx e `ok != false` no corpo.
  bool get ok => statusCode >= 200 && statusCode < 300 && body['ok'] != false;

  String? get error => body['error'] as String?;
  String? get message => body['message'] as String?;

  /// Falha que vale tentar de novo (rede, servidor, limite de taxa).
  bool get isTransient =>
      statusCode == 0 || statusCode >= 500 || statusCode == 429;
}

/// Cliente do backend seguro (push via OneSignal, validação de compras do
/// Google Play e XP de curtidas). Segredos NUNCA ficam no app: o app só
/// manda o ID token do Firebase e os IDs do que aconteceu.
///
/// Ligado por `--dart-define=BACKEND_URL=https://...workers.dev` no build
/// (ver .github/workflows/build_apk.yml). Sem essa URL [isConfigured] é
/// false e cada serviço usa o comportamento antigo — assim nada muda em
/// produção antes de o Worker estar configurado e testado.
class BackendClient {
  BackendClient._();
  static final BackendClient instance = BackendClient._();

  static const String _baseUrl = String.fromEnvironment('BACKEND_URL');

  static bool get isConfigured => _baseUrl.trim().isNotEmpty;

  final http.Client _http = http.Client();

  /// POST JSON autenticado. Devolve null só quando não há como tentar
  /// (backend desligado ou ninguém logado); falhas de rede viram uma
  /// resposta com `statusCode == 0`. Nunca lança exceção.
  Future<BackendResponse?> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!isConfigured) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return null;

      final base = _baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final response = await _http
          .post(
            Uri.parse('$base$path'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          )
          .timeout(timeout);

      Map<String, dynamic> decoded = const {};
      try {
        final raw = json.decode(utf8.decode(response.bodyBytes));
        if (raw is Map<String, dynamic>) decoded = raw;
      } catch (_) {
        // Corpo não-JSON: segue só com o status HTTP.
      }
      return BackendResponse(statusCode: response.statusCode, body: decoded);
    } on TimeoutException {
      return const BackendResponse(
        statusCode: 0,
        body: {'ok': false, 'error': 'timeout'},
      );
    } catch (e) {
      debugPrint('BackendClient $path: $e');
      return const BackendResponse(
        statusCode: 0,
        body: {'ok': false, 'error': 'network'},
      );
    }
  }
}