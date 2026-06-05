import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posts_provider.dart';
import '../widgets/news_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({Key? key}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  bool _isInit = true;
  String _categoryName = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies() {
      if (_isInit) {
        // Captura o nome da categoria repassado por argumento de rota
        _categoryName = ModalRoute.of(context)!.settings.arguments as String;
        // Executa a requisição isolada baseada no marcador
        Provider.of<PostsProvider>(context, listen: false).loadPostsByCategory(_categoryName);
        _isInit = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_categoryName.toUpperCase()),
      ),
      body: Consumer<PostsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.categoryPosts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.feed, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma notícia encontrada em "$_categoryName" no momento.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.categoryPosts.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final post = provider.categoryPosts[index];
              return NewsCard(post: post);
            },
          );
        },
      ),
    );
  }
}
