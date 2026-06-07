import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import necessário
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

  // Função de Logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    // Como o AuthGate no main.dart escuta as mudanças, 
    // ele enviará o usuário para a tela de login automaticamente.
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
    });

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
      // Fundo escuro igual ao seu Login
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'HORIZONTE NEWS',
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            letterSpacing: 2, 
            color: Colors.white
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.primaryOrange),
            onPressed: _logout, // Chama a função de sair
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primaryOrange,
        backgroundColor: Colors.black,
        onRefresh: () async {
          await Provider.of<PostsProvider>(context, listen: false).loadInitialPosts();
        },
        child: Consumer<PostsProvider>(
          builder: (context, provider, child) {
            // ... (manter sua lógica de erro e loading igual)
            
            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: CategoryBar()),
                
                // Adicionei uma leve transparência para combinar com o estilo "Glow"
                if (provider.posts.isNotEmpty) 
                  SliverToBoxAdapter(child: FeaturedCarousel(featuredPosts: provider.featuredPosts)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Text(
                      'ÚLTIMAS NOTÍCIAS',
                      style: TextStyle(
                        color: AppColors.primaryOrange, // Cor laranja para combinar
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => NewsCard(post: provider.recentPosts[index]),
                    childCount: provider.recentPosts.length,
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