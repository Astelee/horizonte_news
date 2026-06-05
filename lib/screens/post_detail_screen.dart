import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../providers/favorites_provider.dart';
import '../config/app_colors.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Recupera o objeto de notícia enviado via argumentos de navegação
    final PostModel post = ModalRoute.of(context)!.settings.arguments as PostModel;
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final bool isFav = favoritesProvider.isFavorite(post.id);
    final String formattedDate = DateFormat('dd/MM/yyyy • HH:mm').format(post.publishedAt);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Barra superior flexível com a imagem de capa da notícia
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            actions: [
              // Botão Reativo de Favoritar dentro do artigo
              IconButton(
                icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => favoritesProvider.toggleFavorite(post),
              ),
              // Botão de Compartilhar Link nativo
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  Share.share('${post.title}\n\nLeia a matéria completa em: ${post.url}');
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: post.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
                  ),
                  // Gradiente sutil para não sumir os botões brancos superiores
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Corpo do Artigo jornalístico
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título Principal
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Metadados (Data e Identificadores)
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  // Interpretador de conteúdo HTML do Blogger
                  Html(
                    data: post.content,
                    style: {
                      "p": Style(
                        fontSize: FontSize(16.5),
                        lineHeight: LineHeight.em(1.5),
                        margin: Margins.only(bottom: 16),
                      ),
                      "a": Style(
                        color: AppColors.primaryBlue,
                        textDecoration: TextDecoration.underline,
                      ),
                      "img": Style(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
