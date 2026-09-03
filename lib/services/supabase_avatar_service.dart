import 'dart:io';
import 'package:http/http.dart' as http;

/// Upload de fotos de perfil para o Supabase Storage.
///
/// Usa o bucket público "avatars" com a anon/public key do projeto.
/// A anon key NÃO é segredo — é a mesma usada em qualquer client do
/// Supabase (web, mobile), protegida por regras de acesso no painel
/// (RLS/policies do bucket), nunca pela chave em si.
///
/// Cada usuário sobrescreve sempre o mesmo arquivo (nomeado pelo uid),
/// então não é necessário limpar uploads antigos.
class SupabaseAvatarService {
  static const String projectUrl =
      'https://icrklgnzhxmohhvhxafo.supabase.co';
  static const String bucket = 'avatars';
  static const String anonKey =
      'sb_publishable_hOeJY--pjTLsfZ-SX2y0hQ_RGUvDRo9';

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

    final uploadUri = Uri.parse(
      '$projectUrl/storage/v1/object/$bucket/$objectPath',
    );

    final bytes = await file.readAsBytes();

    final response = await http.post(
      uploadUri,
      headers: {
        // Chaves no novo formato (sb_publishable_..., sb_secret_...) NÃO
        // são JWTs e não devem ir no header Authorization: Bearer — isso
        // causa erro de autenticação. Vão só no header "apikey".
        'apikey': anonKey,
        'Content-Type': _contentTypeFor(ext),
        // Sobrescreve o arquivo existente em vez de dar erro de conflito.
        'x-upsert': 'true',
      },
      body: bytes,
    );

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