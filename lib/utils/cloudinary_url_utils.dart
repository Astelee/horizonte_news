/// Utilitários para URLs do Cloudinary.
///
/// O Cloudinary permite extrair um frame de um vídeo já hospedado e
/// devolvê-lo como imagem, sem precisar processar nada no app: basta
/// pedir a mesma URL do vídeo trocando a extensão para uma extensão
/// de imagem (jpg) e adicionando a transformação `so_<segundos>`
/// (start offset) antes do caminho do arquivo.
///
/// Ex.: um vídeo em
///   https://res.cloudinary.com/<cloud>/video/upload/v123/pasta/arq.mp4
/// vira, como imagem do frame em 1s:
///   https://res.cloudinary.com/<cloud>/video/upload/so_1/v123/pasta/arq.jpg
class CloudinaryUrlUtils {
  CloudinaryUrlUtils._();

  /// Retorna a URL de uma imagem (frame) extraída de [videoUrl], ou
  /// `null` se [videoUrl] for nulo/vazio ou não for reconhecido como
  /// uma URL de vídeo do Cloudinary.
  static String? videoThumbnail(String? videoUrl, {int atSecond = 1}) {
    if (videoUrl == null || videoUrl.trim().isEmpty) return null;

    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !uri.host.contains('res.cloudinary.com')) return null;

    final segments = List<String>.from(uri.pathSegments);
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex == segments.length - 1) return null;

    // Insere a transformação so_<segundo> logo após "upload".
    segments.insert(uploadIndex + 1, 'so_$atSecond');

    // Troca a extensão do último segmento (o arquivo) para .jpg.
    final lastIndex = segments.length - 1;
    final lastSegment = segments[lastIndex];
    final dotIndex = lastSegment.lastIndexOf('.');
    final withoutExt =
        dotIndex == -1 ? lastSegment : lastSegment.substring(0, dotIndex);
    segments[lastIndex] = '$withoutExt.jpg';

    return uri.replace(pathSegments: segments).toString();
  }
}