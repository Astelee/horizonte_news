import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Upload de fotos de perfil para o Cloudinary.
///
/// Usa o "unsigned upload preset" `horizonte_news_avatars`, exclusivo
/// para fotos de perfil (Settings → Upload → Upload presets no painel
/// do Cloudinary). O cloud name e o nome do preset NÃO são segredos —
/// só o API Secret é, e ele nunca aparece aqui nem em nenhum outro
/// lugar do app.
///
/// IMPORTANTE: uploads não assinados (unsigned) do Cloudinary não
/// permitem sobrescrever um asset existente (`overwrite: true` é
/// rejeitado nesse modo por segurança). Por isso, cada troca de foto
/// gera um novo arquivo no Cloudinary com um public_id único, em vez
/// de substituir o anterior — o app sempre exibe a foto mais recente
/// (a URL nova é salva no Firestore a cada troca), mas fotos antigas
/// continuam existindo no Cloudinary, consumindo um pouco de
/// armazenamento com o tempo. Para um app com poucas trocas de foto
/// por usuário, isso é aceitável dentro do plano gratuito do
/// Cloudinary. Caso vire um problema de cota no futuro, a solução é
/// migrar para upload assinado (signed), que exige gerar a assinatura
/// em um servidor/função separada — o API Secret nunca pode ir no app.
class AvatarUploadService {
  static const String cloudName = 'pcja5a5l';
  static const String uploadPreset = 'horizonte_news_avatars';

  static Uri get _endpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Envia a foto de perfil do usuário (uid) e retorna a secure_url.
  Future<String> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    final request = http.MultipartRequest('POST', _endpoint)
      ..fields['upload_preset'] = uploadPreset
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

    return secureUrl;
  }
}