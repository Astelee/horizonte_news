import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'providers/posts_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favorites_provider.dart';

void main() {
  // Garante que as ligações dos widgets do Flutter estejam inicializadas antes de rodar os serviços
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PostsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(),
        ),
      ],
      child: const HorizonteNewsApp(),
    ),
  );
}

class HorizonteNewsApp extends StatelessWidget {
  const HorizonteNewsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Escuta as mudanças de tema controladas pelo usuário ou sistema
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Horizonte News',
      debugShowCheckedModeBanner: false,
      
      // Definição dos temas estruturados
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.currentTheme,
      
      // Mapeamento de rotas e ponto inicial
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
