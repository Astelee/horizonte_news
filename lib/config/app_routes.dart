import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/category_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/videos_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/settings_screen.dart'; // Import da nova tela

class AppRoutes {
  static const String home = '/';
  static const String category = '/category';
  static const String postDetail = '/post-detail';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String videos = '/videos';
  static const String contact = '/contact';
  static const String settings = '/settings'; // Nova constante

  static Map<String, WidgetBuilder> get routes {
    return {
      home: (context) => const HomeScreen(),
      category: (context) => const CategoryScreen(),
      postDetail: (context) => const PostDetailScreen(),
      search: (context) => const SearchScreen(),
      favorites: (context) => const FavoritesScreen(),
      videos: (context) => const VideosScreen(),
      contact: (context) => const ContactScreen(),
      settings: (context) => const SettingsScreen(), // Registro da rota
    };
  }
}