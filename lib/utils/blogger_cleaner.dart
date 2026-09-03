class BloggerCleaner {
  static String clean(String rawHtml) {
    if (rawHtml.isEmpty) return rawHtml;

    String html = rawHtml;

    // Remove a primeira imagem (já exibida como hero)
    html = html.replaceFirst(RegExp(r'<img[^>]*>'), '');

    // Remove style inline com margin/padding gigantes
    html = html.replaceAll(RegExp(r'margin[^:]*:\s*[^;]+;?'), '');
    html = html.replaceAll(RegExp(r'padding[^:]*:\s*[^;]+;?'), '');
    html = html.replaceAll(RegExp(r'line-height\s*:\s*[^;]+;?'), '');
    html = html.replaceAll(RegExp(r'font-size\s*:\s*[^;]+;?'), '');

    // Remove estilos inline de cor/transparência/peso de fonte vindos de
    // colagem externa (Google Docs, Word, Blogger) — eles sobrescrevem
    // as cores e pesos definidos no app, deixando o texto pequeno,
    // acinzentado/transparente ou com peso errado.
    html = html.replaceAll(
        RegExp(r'color\s*:\s*[^;]+;?', caseSensitive: false), '');
    html = html.replaceAll(
        RegExp(r'opacity\s*:\s*[^;]+;?', caseSensitive: false), '');
    html = html.replaceAll(
        RegExp(r'font-weight\s*:\s*[^;]+;?', caseSensitive: false), '');
    html = html.replaceAll(
        RegExp(r'font-family\s*:\s*[^;]+;?', caseSensitive: false), '');
    html = html.replaceAll(
        RegExp(r'background(-color)?\s*:\s*[^;]+;?', caseSensitive: false),
        '');

    // Remove atributos style="" que ficaram vazios após as remoções acima
    html = html.replaceAll(
        RegExp(r'''\s*style\s*=\s*["']\s*["']''', caseSensitive: false),
        '');

    // Remove atributos color/face de tags antigas (<font color="...">)
    html = html.replaceAll(
        RegExp(r'''\s*(color|face)\s*=\s*["'][^"']*["']''',
            caseSensitive: false),
        '');

    // Qualquer quantidade de <br> (1 ou mais) → fechamento de parágrafo
    // Isso garante que tanto 1 <br> quanto vários virem parágrafo separado
    html = html.replaceAll(
        RegExp(r'(<br\s*/?>(\s|&nbsp;)*)+', caseSensitive: false),
        '</p><p>');

    // Remove parágrafos vazios que sobraram
    html = html.replaceAll(
        RegExp(r'<p[^>]*>(\s|&nbsp;|&#160;)*</p>',
            caseSensitive: false),
        '');

    // Remove divs vazios
    html = html.replaceAll(
        RegExp(r'<div[^>]*>\s*</div>', caseSensitive: false), '');

    // Remove tags font
    html = html.replaceAll(
        RegExp(r'</?font[^>]*>', caseSensitive: false), '');

    // Remove scripts e iframes
    html = html.replaceAll(
        RegExp(r'<script[^>]*>.*?</script>',
            dotAll: true, caseSensitive: false),
        '');
    html = html.replaceAll(
        RegExp(r'<iframe[^>]*>.*?</iframe>',
            dotAll: true, caseSensitive: false),
        '');

    // Limpa &nbsp; solto
    html = html.replaceAll('&nbsp;', ' ');
    html = html.replaceAll('&#160;', ' ');

    // Múltiplos espaços
    html = html.replaceAll(RegExp(r' {2,}'), ' ');

    return html.trim();
  }
}