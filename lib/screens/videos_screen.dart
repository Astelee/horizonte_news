import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

class VideosScreen extends StatelessWidget {
  const VideosScreen({Key? key}) : super(key: key);

  // Lista estática simulando o feed de reportagens em vídeo do Horizonte News
  // Pode ser integrada futuramente com a API do YouTube
  static const List<Map<String, String>> _videoMock = [
    {
      'title': 'Cobertura Especial: Eventos e Ações no Município',
      'duration': '05:42',
      'url': 'https://www.youtube.com',
      'thumb': 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?q=80&w=600'
    },
    {
      'title': 'Entrevista Exclusiva com Lideranças Comunitárias',
      'duration': '12:15',
      'url': 'https://www.youtube.com',
      'thumb': 'https://images.unsplash.com/photo-1526470608268-f674ce90ebd4?q=80&w=600'
    }
  ];

  Future<void> _openVideo(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o reprodutor de vídeo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VÍDEOS E REPORTAGENS'),
      ),
      body: ListView.builder(
        itemCount: _videoMock.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final video = _videoMock[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => _openVideo(context, video['url']!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        video['thumb']!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.emergencyRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, py: 2),
                          color: Colors.black87,
                          child: Text(
                            video['duration']!,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      )
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      video['title']!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
