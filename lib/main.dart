import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'services/app_config_service.dart';
import 'services/deep_link_service.dart';
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
    // Aguarda o primeiro frame para garantir que o Navigator (via
    // navigatorKey) já está montado antes de tentar abrir uma
    // matéria vinda de deep link ou de install referrer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.init();
    });
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
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
    return StreamBuilder<AppGlobalConfig>(
      stream: AppConfigService().stream(),
      builder: (context, configSnapshot) {
        final config = configSnapshot.data;

        // Enquanto a config ainda não chegou, segue direto pro fluxo
        // normal de autenticação — não vale a pena travar a
        // splash inteira esperando essa checagem extra.
        if (config == null || !config.maintenanceMode) {
          return const _AuthenticatedGate();
        }

        // Modo manutenção ativo: verifica se o usuário logado é
        // admin (admins continuam acessando normalmente, pra poder
        // desativar a manutenção pelo próprio painel).
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashLoading();
            }
            final user = authSnapshot.data;
            if (user == null) {
              return _MaintenanceScreen(message: config.maintenanceMessage);
            }
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('admins')
                  .doc(user.uid)
                  .get(),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SplashLoading();
                }
                final isAdmin = adminSnapshot.data?.exists == true;
                if (isAdmin) {
                  return const _AuthenticatedGate();
                }
                return _MaintenanceScreen(message: config.maintenanceMessage);
              },
            );
          },
        );
      },
    );
  }
}

/// Tela de bloqueio mostrada a usuários comuns durante manutenção.
class _MaintenanceScreen extends StatelessWidget {
  final String message;
  const _MaintenanceScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle_rounded,
                  color: Color(0xFFEF5350), size: 64),
              const SizedBox(height: 20),
              const Text(
                'Em manutenção',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty
                    ? message
                    : 'Estamos fazendo uma atualização rápida. Volte '
                        'daqui a pouco!',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fluxo normal de autenticação (login/home), sem a checagem de
/// manutenção — extraído do antigo _AuthGate para ser reutilizado
/// tanto quando a manutenção está desligada quanto quando o usuário
/// logado é admin.
class _AuthenticatedGate extends StatelessWidget {
  const _AuthenticatedGate();

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