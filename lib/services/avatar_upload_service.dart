import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Upload de fotos de perfil para o Cloudinary.
///
/// As fotos são enviadas para o Cloudinary e depois registradas
/// como pendentes de aprovação no Firestore.
class AvatarUploadService {
  static const String cloudName = 'pcja5a5l';
  static const String uploadPreset = 'horizonte_news_avatars';

  static Uri get _endpoint =>
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

  /// Envia a foto de perfil e retorna a secure_url do Cloudinary.
  Future<String> uploadAvatar({
    required File file,
    required String uid,
  }) async {
    if (!await file.exists()) {
      throw Exception(
        'Arquivo temporário não encontrado: ${file.path}',
      );
    }

    final fileLength = await file.length();

    if (fileLength == 0) {
      throw Exception(
        'O arquivo da foto está vazio.',
      );
    }

    debugPrint(
      'AvatarUploadService: iniciando upload '
      '($fileLength bytes)',
    );

    final request = http.MultipartRequest(
      'POST',
      _endpoint,
    );

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
      ),
    );

    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await request.send();
    } catch (e) {
      throw Exception(
        'Não foi possível conectar ao Cloudinary: $e',
      );
    }

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    debugPrint(
      'Cloudinary status: ${response.statusCode}',
    );

    debugPrint(
      'Cloudinary response: ${response.body}',
    );

    if (response.statusCode != 200) {
      String message = response.body;

      try {
        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;

        final error = decoded['error'];

        if (error is Map<String, dynamic>) {
          message =
              error['message']?.toString() ?? response.body;
        }
      } catch (_) {
        // Mantém o corpo original caso não seja JSON.
      }

      throw Exception(
        'Cloudinary recusou o upload '
        '(${response.statusCode}): $message',
      );
    }

    Map<String, dynamic> data;

    try {
      data = jsonDecode(response.body)
          as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        'Resposta inválida do Cloudinary: $e',
      );
    }

    final secureUrl = data['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary não retornou secure_url. '
        'Resposta: ${response.body}',
      );
    }

    debugPrint(
      'Avatar enviado com sucesso: $secureUrl',
    );

    return secureUrl;
  }
}
