/// Converte texto puro (sem tags) digitado/colado no editor de notícias
/// em HTML com parágrafos reais.
///
/// O campo "Conteúdo completo" do editor aceita três tipos de entrada:
/// 1. Texto puro digitado à mão ou colado de bloco de notas/WhatsApp.
/// 2. O mesmo texto puro, mas com marcações inseridas pela toolbar do
///    editor (negrito/destaque), que insere apenas `<b>`, `</b>`,
///    `<mark>` e `</mark>` diretamente no texto — o resto continua sendo
///    texto puro, não HTML pronto.
/// 3. HTML completo colado de um site (ex.: Blogger), que já vem com
///    `<p>`, `<div>`, `<h2>` etc. e deve passar pelo BloggerCleaner.
///
/// Sem sabermos diferenciar (2) de (3), qualquer tag no meio do texto
/// fazia o conversor tratar tudo como "HTML pronto" e pular a separação
/// em `<p>` — resultado: parágrafos colados sem espaçamento. E, se o
/// texto puro por acaso continha um `<` sem ser das tags da toolbar,
/// ele aparecia escapado e visível na tela (ex.: "&lt;mark&gt;").
///
/// Por isso, tratamos como (3) — HTML pronto de fora, sem mexer — apenas
/// quando aparece uma tag estrutural típica de página (p, div, h1-h6,
/// ul, ol, blockquote, img, a). Se as únicas tags presentes forem as da
/// toolbar (b, strong, mark, br), o texto ainda é tratado como puro:
/// separamos em parágrafos e escapamos tudo, exceto essas tags.
class PlainTextHtmlConverter {
  PlainTextHtmlConverter._();

  static final RegExp _structuralTag = RegExp(
    r'<\s*(p|div|h[1-6]|ul|ol|li|blockquote|img|a|table|section|article)\b',
    caseSensitive: false,
  );

  static final RegExp _toolbarTag = RegExp(
    r'<(/?)(b|strong|mark|br)\s*/?>',
    caseSensitive: false,
  );

  static String ensureHtml(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return trimmed;

    // Só confia que o conteúdo já é HTML pronto (vindo de outro site,
    // ex. Blogger) se houver alguma tag estrutural de página.
    if (_structuralTag.hasMatch(trimmed)) {
      return trimmed;
    }

    final paragraphs = trimmed
        .split(RegExp(r'\n\s*\n+')) // linhas em branco separam parágrafos
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .map(_escapePreservingToolbarTags)
        // Uma quebra de linha simples dentro do mesmo bloco vira <br>.
        .map((block) => block.replaceAll('\n', '<br>'))
        .map((block) => '<p>$block</p>')
        .join();

    return paragraphs;
  }

  /// Escapa `&`, `<` e `>` como HTML, exceto quando fazem parte de uma
  /// das tags inseridas pela toolbar do editor (`<b>`, `</b>`, `<mark>`,
  /// `</mark>`, `<br>`), que devem continuar funcionando como tags reais.
  static String _escapePreservingToolbarTags(String text) {
    final buffer = StringBuffer();
    int last = 0;
    for (final match in _toolbarTag.allMatches(text)) {
      buffer.write(_escapeHtml(text.substring(last, match.start)));
      buffer.write(match.group(0)); // tag da toolbar, sem escapar
      last = match.end;
    }
    buffer.write(_escapeHtml(text.substring(last)));
    return buffer.toString();
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}