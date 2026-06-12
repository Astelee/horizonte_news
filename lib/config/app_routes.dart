import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/category_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/videos_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/most_read_screen.dart';
import '../screens/horizon_now_screen.dart';
import '../screens/events_screen.dart';

class AppRoutes {
  static const String home           = '/';
  static const String category       = '/category';
  static const String postDetail     = '/post-detail';
  static const String search         = '/search';
  static const String favorites      = '/favorites';
  static const String videos         = '/videos';
  static const String contact        = '/contact';
  static const String settings       = '/settings';
  static const String login          = '/login';
  static const String register       = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String profile        = '/profile';
  static const String adminPanel     = '/admin-panel';
  static const String mostRead       = '/most-read';
  static const String horizonNow     = '/horizon-now';
  static const String events         = '/events';

  static Map<String, WidgetBuilder> get routes => {
    home:           (context) => const HomeScreen(),
    category:       (context) => const CategoryScreen(),
    postDetail:     (context) => const PostDetailScreen(),
    search:         (context) => const SearchScreen(),
    favorites:      (context) => const FavoritesScreen(),
    videos:         (context) => const VideosScreen(),
    contact:        (context) => const ContactScreen(),
    settings:       (context) => const SettingsScreen(),
    login:          (context) => const LoginScreen(),
    register:       (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    profile:        (context) => const ProfileScreen(),
    adminPanel:     (context) => const AdminPanelScreen(),
    mostRead:       (context) => const MostReadScreen(),
    horizonNow:     (context) => const HorizonNowScreen(),
    events:         (context) => const EventsScreen(),
  };
}
