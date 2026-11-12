/// Domínio oficial do portal usado nos links compartilhados.
/// Precisa ser o mesmo host do AndroidManifest.xml e do assetlinks.json.
class AppLinksConfig {
  static const String host = 'horizontenews.app.br';

  static String noticiaUrl(String postId) => 'https://$host/noticia/$postId';
}