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
  // ⚠️ Substitua pela URL do seu blog
  // Exemplo: 'https://seublog.blogspot.com/feeds/posts/default?alt=rss&max-results=5'
  static const String _rssUrl =
      'https://horizontenews.com.br/feeds/posts/default?alt=rss&max-results=5';

  /// Busca os posts mais recentes pelo feed RSS.
  /// Retorna null em caso de erro para não travar o background.
  static Future<List<BloggerRssPost>?> fetchLatestPosts() async {
    try {
      final response = await http
          .get(Uri.parse(_rssUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');

      final posts = items.map((item) {
        final title = item.findElements('title').firstOrNull?.innerText ?? '';
        final link = item.findElements('link').firstOrNull?.innerText ?? '';
        final pubDate =
            item.findElements('pubDate').firstOrNull?.innerText ?? '';
        final description =
            item.findElements('description').firstOrNull?.innerText ?? '';

        // Remove tags HTML do resumo
        final cleanSummary = description
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .trim();

        final shortSummary = cleanSummary.length > 120
            ? '${cleanSummary.substring(0, 120)}...'
            : cleanSummary;

        // ID único baseado na URL
        final id = link.isNotEmpty
            ? link.split('/').last.replaceAll('.html', '')
            : title.hashCode.toString();

        DateTime parsed;
        try {
          parsed = DateTime.parse(pubDate);
        } catch (_) {
          parsed = DateTime.now();
        }

        return BloggerRssPost(
          id: id,
          title: title,
          summary: shortSummary,
          url: link,
          publishedAt: parsed,
        );
      }).toList();

      return posts;
    } catch (e) {
      return null;
    }
  }
}
