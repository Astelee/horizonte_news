import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Upload de imagens/vídeos para o Cloudinary a partir do painel ADM.
///
/// Usa um "unsigned upload preset" configurado no painel do Cloudinary
/// (Settings → Upload → Upload presets → Add upload preset → Signing
/// Mode: Unsigned). O cloud name e o nome do preset NÃO são segredos —
/// só o API Secret é, e ele nunca aparece aqui nem em nenhum outro
/// lugar do app.
///
/// Restrinja o preset no painel do Cloudinary (pasta de destino,
/// formatos permitidos, tamanho máximo) já que qualquer requisição
/// autenticada como admin no app pode chamá-lo.
class CloudinaryUploadService {
  // TODO: substituir pelo cloud name real da conta Cloudinary.
  static const String cloudName = 'SEU_CLOUD_NAME';
  // TODO: criar este preset como "Unsigned" no painel do Cloudinary.
  static const String uploadPreset = 'horizonte_news_unsigned';

  static Uri _endpoint(String resourceType) => Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

  /// Envia uma imagem e retorna a secure_url do Cloudinary.
  Future<String> uploadImage(File file) => _upload(file, 'image');

  /// Envia um vídeo e retorna a secure_url do Cloudinary.
  Future<String> uploadVideo(File file) => _upload(file, 'video');

  Future<String> _upload(File file, String resourceType) async {
    final request = http.MultipartRequest('POST', _endpoint(resourceType))
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
          'Falha no upload para o Cloudinary (${response.statusCode}): '
          '${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null) {
      throw Exception('Cloudinary não retornou secure_url: ${response.body}');
    }
    return secureUrl;
  }
}