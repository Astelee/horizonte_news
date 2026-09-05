import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Upload de fotos de perfil para o Cloudinary.
///
/// Usa o mesmo "unsigned upload preset" já configurado no painel do
/// Cloudinary para as imagens de notícias (Settings → Upload → Upload
/// presets). O cloud name e o nome do preset NÃO são segredos — só o
/// API Secret é, e ele nunca aparece aqui nem em nenhum outro lugar
/// do app.
///
/// Cada usuário sobrescreve sempre o mesmo public_id (baseado no uid),
/// então o Cloudinary substitui a foto anterior automaticamente
/// (`overwrite: true`) em vez de acumular uma foto nova a cada troca.
class AvatarUploadService {
  static const String cloudName = 'pcja5a5l';
  static const String uploadPreset = 'horizonte_news_unsigned';

  static Uri get _endpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Envia a foto de perfil do usuário (uid) e retorna a secure_url.
  ///
  /// Usa public_id fixo por usuário (profile_<uid>) para que trocar a
  /// foto substitua a anterior no Cloudinary, e adiciona um parâmetro
  /// de cache-busting (?v=timestamp) na URL para que o app não continue
  /// mostrando a foto antiga a partir do cache do CachedNetworkImage.
  Future<String> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    final request = http.MultipartRequest('POST', _endpoint)
      ..fields['upload_preset'] = uploadPreset
      ..fields['public_id'] = 'avatars/profile_$uid'
      ..fields['overwrite'] = 'true'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'Falha no upload para o Cloudinary (${response.statusCode}): '
        '${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;

    if (secureUrl == null) {
      throw Exception(
        'Cloudinary não retornou secure_url: ${response.body}',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final separator = secureUrl.contains('?') ? '&' : '?';
    return '$secureUrl${separator}v=$timestamp';
  }
}