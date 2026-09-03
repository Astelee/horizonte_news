/// Converte texto puro (sem tags) digitado/colado no editor de notícias
/// em HTML com parágrafos reais.
///
/// O campo "Conteúdo completo" do editor aceita tanto HTML colado (ex.:
/// de um site, que passa por [BloggerCleaner]) quanto texto puro digitado
/// à mão ou colado de um bloco de notas/WhatsApp. Quando o texto já é
/// puro, ele precisa ser envolvido em tags `<p>` — sem isso, o
/// `flutter_html` não tem onde aplicar o estilo definido no app
/// (tamanho, cor, espaçamento) e usa o padrão do motor de renderização,
/// que fica grande, em branco puro e sem espaçamento entre parágrafos.
class PlainTextHtmlConverter {
  PlainTextHtmlConverter._();

  /// Se [content] já parece conter HTML (tem alguma tag reconhecível),
  /// retorna como está. Caso contrário, trata como texto puro: separa
  /// por linhas em branco (um ou mais `\n` seguidos), escapa caracteres
  /// especiais de HTML e envolve cada bloco resultante em `<p>`.
  static String ensureHtml(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return trimmed;

    // Já tem alguma tag HTML? Deixa como está (vai para o BloggerCleaner).
    if (RegExp(r'<\s*[a-zA-Z][^>]*>').hasMatch(trimmed)) {
      return trimmed;
    }

    final paragraphs = trimmed
        .split(RegExp(r'\n\s*\n+')) // linhas em branco separam parágrafos
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .map(_escapeHtml)
        // Uma quebra de linha simples dentro do mesmo bloco vira <br>.
        .map((block) => block.replaceAll('\n', '<br>'))
        .map((block) => '<p>$block</p>')
        .join();

    return paragraphs;
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}