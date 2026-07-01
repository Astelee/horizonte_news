import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class BloggerRssPost {
  final String id;
  final String title;
  final String summary;
  final String url;
  final DateTime publishedAt;

  const BloggerRssPost({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.publishedAt,
  });
}

class BloggerRssService {
  // Feed RSS do blog Horizonte News
  static const String _rssUrl =
      'https://horizontenews.com.br/feeds/posts/default?alt=rss&max-results=5';

  // URL alternativa caso a de cima não funcione (via ID do Blogger)
  static const String _rssUrlFallback =
      'https://www.blogger.com/feeds/2093381478467700202/posts/default?alt=rss&max-results=5';

  /// Busca os posts mais recentes pelo feed RSS.
  /// Tenta a URL principal primeiro, depois o fallback.
  /// Retorna null em caso de erro para não travar o background.
  static Future<List<BloggerRssPost>?> fetchLatestPosts() async {
    final posts = await _fetch(_rssUrl);
    if (posts != null) return posts;
    return _fetch(_rssUrlFallback);
  }

  static Future<List<BloggerRssPost>?> _fetch(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final document = XmlDocument.parse(response.body);

      // Feed RSS usa <item>, feed Atom do Blogger usa <entry>
      final isAtom = document.findAllElements('entry').isNotEmpty;
      
      if (isAtom) {
        return _parseAtom(document);
      } else {
        return _parseRss(document);
      }
    } catch (e) {
      return null;
    }
  }

  // ── PARSER RSS ───────────────────────────────────────────────
  static List<BloggerRssPost> _parseRss(XmlDocument document) {
    final items = document.findAllElements('item');

    return items.map((item) {
      final title =
          item.findElements('title').firstOrNull?.innerText ?? '';
      final link =
          item.findElements('link').firstOrNull?.innerText ?? '';
      final pubDate =
          item.findElements('pubDate').firstOrNull?.innerText ?? '';
      final description =
          item.findElements('description').firstOrNull?.innerText ?? '';

      final cleanSummary = _cleanHtml(description);
      final shortSummary = cleanSummary.length > 120
          ? '${cleanSummary.substring(0, 120)}...'
          : cleanSummary;

      final id = link.isNotEmpty
          ? link.split('/').last.replaceAll('.html', '')
          : title.hashCode.toString();

      return BloggerRssPost(
        id: id,
        title: _cleanHtml(title),
        summary: shortSummary,
        url: link,
        publishedAt: _parseDate(pubDate),
      );
    }).toList();
  }

  // ── PARSER ATOM (formato nativo do Blogger) ──────────────────
  static List<BloggerRssPost> _parseAtom(XmlDocument document) {
    final entries = document.findAllElements('entry');

    return entries.map((entry) {
      final title =
          entry.findElements('title').firstOrNull?.innerText ?? '';

      // No Atom, o link é um elemento com atributo rel="alternate"
      String link = '';
      for (final linkEl in entry.findElements('link')) {
        final rel = linkEl.getAttribute('rel');
        if (rel == 'alternate') {
          link = linkEl.getAttribute('href') ?? '';
          break;
        }
      }

      final published =
          entry.findElements('published').firstOrNull?.innerText ?? '';
      final content =
          entry.findElements('content').firstOrNull?.innerText ??
          entry.findElements('summary').firstOrNull?.innerText ?? '';

      final cleanSummary = _cleanHtml(content);
      final shortSummary = cleanSummary.length > 120
          ? '${cleanSummary.substring(0, 120)}...'
          : cleanSummary;

      final id = link.isNotEmpty
          ? link.split('/').last.replaceAll('.html', '')
          : title.hashCode.toString();

      return BloggerRssPost(
        id: id,
        title: _cleanHtml(title),
        summary: shortSummary,
        url: link,
        publishedAt: _parseDate(published),
      );
    }).toList();
  }

  // ── UTILITÁRIOS ──────────────────────────────────────────────
  static String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      // Tenta formato RFC 2822 do RSS: "Mon, 01 Jan 2024 12:00:00 +0000"
      try {
        final parts = raw.split(' ');
        if (parts.length >= 5) {
          final months = {
            'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
            'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
            'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
          };
          final day = parts[1].padLeft(2, '0');
          final month = months[parts[2]] ?? '01';
          final year = parts[3];
          final time = parts[4];
          return DateTime.parse('$year-$month-${day}T$time');
        }
      } catch (_) {}
      return DateTime.now();
    }
  }
}
