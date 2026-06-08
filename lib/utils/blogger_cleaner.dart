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

    // Múltiplos <br> → um só parágrafo
    html = html.replaceAll(
        RegExp(r'(<br\s*/?>(\s|&nbsp;)*){2,}', caseSensitive: false),
        '</p><p>');
    html = html.replaceAll(
        RegExp(r'<br\s*/?>', caseSensitive: false), ' ');

    // Remove parágrafos vazios
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