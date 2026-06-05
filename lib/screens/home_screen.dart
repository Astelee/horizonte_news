import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posts_provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../widgets/category_bar.dart';
import '../widgets/featured_carousel.dart';
import '../widgets/breaking_news_banner.dart';
import '../widgets/news_card.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Dispara o carregamento assíncrono das postagens do Blogger na inicialização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
    });

    // Monitora a rolagem para ativar o scroll infinito ao se aproximar do final da página
    _scrollController.addListener(() {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        postsProvider.loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 40,
          // Caso a logo ainda não exista fisicamente na pasta assets, exibe texto como fallback de proteção
          errorBuilder: (context, error, stackTrace) => const Text(
            'HORIZONTE NEWS',
            style: TextStyle(fontWeight: FontWeight.black, letterSpacing: 1.5),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.search);
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => Provider.of<PostsProvider>(context, listen: false).loadInitialPosts(),
        child: Consumer<PostsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.posts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.errorMessage.isNotEmpty && provider.posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: AppColors.emergencyRed),
                      const SizedBox(height: 16),
                      Text(
                        'Não foi possível atualizar o feed.',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => provider.loadInitialPosts(),
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Descobre de forma dinâmica se há alguma postagem marcada como Urgente para o banner
            final urgentPost = provider.posts.any((p) => p.categories.any((c) => c.name.toLowerCase() == 'urgente' || c.name.toLowerCase() == 'plantão'))
                ? provider.posts.firstWhere((p) => p.categories.any((c) => c.name.toLowerCase() == 'urgente' || c.name.toLowerCase() == 'plantão'))
                : null;

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Barra de rolagem horizontal para categorias fixa no topo
                const SliverToBoxAdapter(child: CategoryBar()),

                // Banner Vermelho de Boletim Urgente / Plantão
                if (urgentPost != null)
                  SliverToBoxAdapter(child: BreakingNewsBanner(urgentPost: urgentPost)),

                // Seção 1: Carrossel de Destaques principais (Gera os 3 posts mais novos)
                SliverToBoxAdapter(
                  child: FeaturedCarousel(featuredPosts: provider.featuredPosts),
                ),

                // Divisor indicando a seção de últimas notícias
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                    child: Text(
                      'ÚLTIMAS NOTÍCIAS',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                ),

                // Seção 2: Feed Geral de Notícias Regulares (Ignora os posts fixados nos destaques do carrossel)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = provider.recentPosts[index];
                      return NewsCard(post: post);
                    },
                    childCount: provider.recentPosts.length,
                  ),
                ),

                // Indicador visual de carregamento de mais páginas no final do Scroll
                if (provider.hasMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
