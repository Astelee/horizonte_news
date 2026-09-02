import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ✅ AdMob adicionado
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'providers/posts_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/user_xp_provider.dart';
import 'features/admin/providers/admin_provider.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'config/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyAAzDgrlLGUTsu3helestO6USQ5UMC8N3A',
      appId: '1:435843055834:android:0567d65464ec25dd9765e3',
      messagingSenderId: '435843055834',
      projectId: 'horizontenews-6b48f',
      storageBucket: 'horizontenews-6b48f.firebasestorage.app',
    ),
  );

  // ✅ AdMob inicializado após Firebase
  await MobileAds.instance.initialize();

  // ✅ Verifica a preferência de "Lembrar login" ANTES de exibir
  // qualquer tela, evitando piscar a Home antes de deslogar.
  await AuthService.instance.enforceRememberPreference();

  await NotificationService.init();
  await SoundService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => UserXpProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const HorizonteNewsApp(),
    ),
  );
}

// Transformado em StatefulWidget para suportar o initState()
class HorizonteNewsApp extends StatefulWidget {
  const HorizonteNewsApp({Key? key}) : super(key: key);

  @override
  State<HorizonteNewsApp> createState() => _HorizonteNewsAppState();
}

class _HorizonteNewsAppState extends State<HorizonteNewsApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Horizonte News',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.currentTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: const _AuthGate(),
      onGenerateRoute: (settings) {
        final builder = AppRoutes.routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder, settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const _AuthGate());
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoading();
        }

        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserXpProvider>(context, listen: false).initialize();
            Provider.of<AdminProvider>(context, listen: false).initialize();
          });
          return AppRoutes.routes[AppRoutes.home]!(context);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<AdminProvider>(context, listen: false).reset();
        });

        return AppRoutes.routes[AppRoutes.login]!(context);
      },
    );
  }
}