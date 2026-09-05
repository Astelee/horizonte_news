import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Upload de fotos de perfil para o Supabase Storage.
///
/// O bucket "avatars" é público apenas para LEITURA — como em qualquer
/// projeto Supabase, a escrita (upload) sempre passa pelas Row Level
/// Security Policies da tabela storage.objects, que exigem uma sessão
/// autenticada (role "authenticated"), mesmo com o bucket marcado como
/// público.
///
/// Como o app usa Firebase Auth (não Supabase Auth) para login, não há
/// uma sessão de usuário "de verdade" no Supabase. Para satisfazer a
/// policy sem expor a Service Role key no app (que ignoraria TODA
/// regra de segurança do banco, não só do Storage — nunca deve ir no
/// cliente), este serviço usa o login anônimo do Supabase
/// (`POST /auth/v1/signup` com corpo vazio): cada instalação do app
/// ganha uma sessão anônima própria, com role "authenticated", válida
/// só para operações de Storage — sem precisar de senha nem de
/// vincular com a conta Firebase do usuário.
///
/// IMPORTANTE: para este fluxo funcionar, o projeto precisa ter
/// "Allow anonymous sign-ins" habilitado em
/// Authentication > Sign In / Providers no painel do Supabase.
class SupabaseAvatarService {
  static const String projectUrl =
      'https://icrklgnzhxmohhvhxafo.supabase.co';
  static const String bucket = 'avatars';
  static const String publishableKey =
      'sb_publishable_hOeJY--pjTLsfZ-SX2y0hQ_RGUvDRo9';

  static const String _prefsAccessTokenKey = 'supabase_anon_access_token';
  static const String _prefsRefreshTokenKey = 'supabase_anon_refresh_token';

  /// Retorna um access_token válido de uma sessão anônima do Supabase,
  /// reaproveitando uma sessão salva localmente quando possível, ou
  /// criando uma nova via login anônimo.
  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_prefsAccessTokenKey);

    if (savedToken != null) {
      return savedToken;
    }

    return _signInAnonymously(prefs);
  }

  Future<String> _signInAnonymously(SharedPreferences prefs) async {
    final response = await http.post(
      Uri.parse('$projectUrl/auth/v1/signup'),
      headers: {
        'apikey': publishableKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Falha ao autenticar no Supabase (${response.statusCode}): '
        '${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken == null) {
      throw Exception(
        'Resposta de login anônimo do Supabase sem access_token: '
        '${response.body}',
      );
    }

    await prefs.setString(_prefsAccessTokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_prefsRefreshTokenKey, refreshToken);
    }

    return accessToken;
  }

  /// Limpa a sessão anônima salva localmente, forçando um novo login
  /// anônimo na próxima chamada. Útil quando o access_token salvo
  /// expirou e o upload falha por autenticação.
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAccessTokenKey);
    await prefs.remove(_prefsRefreshTokenKey);
  }

  /// Envia a foto de perfil do usuário (uid) e retorna a URL pública.
  ///
  /// Adiciona um parâmetro de cache-busting (?t=timestamp) na URL
  /// final para que o app não continue mostrando a foto antiga a
  /// partir do cache do CachedNetworkImage.
  Future<String> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    final ext = _extensionFor(file.path);
    final objectPath = 'profile_$uid.$ext';
    final bytes = await file.readAsBytes();

    var accessToken = await _getAccessToken();
    var response = await _doUpload(
      objectPath: objectPath,
      contentType: _contentTypeFor(ext),
      bytes: bytes,
      accessToken: accessToken,
    );

    // Se o token salvo expirou (401), tenta uma única vez com uma
    // sessão anônima nova antes de desistir.
    if (response.statusCode == 401) {
      await _clearSession();
      accessToken = await _getAccessToken();
      response = await _doUpload(
        objectPath: objectPath,
        contentType: _contentTypeFor(ext),
        bytes: bytes,
        accessToken: accessToken,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Falha no upload para o Supabase (${response.statusCode}): '
        '${response.body}',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$projectUrl/storage/v1/object/public/$bucket/$objectPath'
        '?t=$timestamp';
  }

  Future<http.Response> _doUpload({
    required String objectPath,
    required String contentType,
    required List<int> bytes,
    required String accessToken,
  }) {
    final uploadUri = Uri.parse(
      '$projectUrl/storage/v1/object/$bucket/$objectPath',
    );

    return http.post(
      uploadUri,
      headers: {
        // apikey identifica o projeto; Authorization carrega o JWT da
        // sessão anônima, que é o que a policy de RLS avalia como
        // role "authenticated".
        'apikey': publishableKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': contentType,
        // Sobrescreve o arquivo existente em vez de dar erro de conflito.
        'x-upsert': 'true',
      },
      body: bytes,
    );
  }

  String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}