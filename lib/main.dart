import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'providers/posts_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/user_xp_provider.dart';

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => UserXpProvider()),
      ],
      child: const HorizonteNewsApp(),
    ),
  );
}

class HorizonteNewsApp extends StatelessWidget {
  const HorizonteNewsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
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
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      home: const _AuthGate(),
      onGenerateRoute: (settings) {
        final builder = AppRoutes.routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(
            builder: builder,
            settings: settings,
          );
        }
        return MaterialPageRoute(builder: (_) => const _AuthGate());
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AUTH GATE — inicializa XP quando usuário está logado
// ═══════════════════════════════════════════════════════════════════
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoading();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Inicializa o sistema de XP quando o usuário está logado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final xpProvider =
                Provider.of<UserXpProvider>(context, listen: false);
            xpProvider.initialize();
          });
          return AppRoutes.routes[AppRoutes.home]!(context);
        }

        return AppRoutes.routes[AppRoutes.login]!(context);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SPLASH LOADING
// ═══════════════════════════════════════════════════════════════════
class _SplashLoading extends StatefulWidget {
  const _SplashLoading();

  @override
  State<_SplashLoading> createState() => _SplashLoadingState();
}

class _SplashLoadingState extends State<_SplashLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE65100)
                          .withOpacity(0.6 * _pulse.value),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: child,
              ),
              child: const Icon(
                Icons.public,
                size: 56,
                color: Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 28),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFF6D00),
                  Color(0xFFFFB74D),
                  Color(0xFFE65100),
                ],
              ).createShader(bounds),
              child: const Text(
                'HORIZONTE NEWS',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFE65100).withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
