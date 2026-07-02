import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'models/post_model.dart';
import 'providers/posts_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/user_xp_provider.dart';
import 'features/admin/providers/admin_provider.dart';
import 'services/news_notification_service.dart';
import 'services/presence_service.dart';
import 'services/background_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Aviso: erro ao inicializar notificações: $e');
  }

  try {
    await BackgroundService.init();
    await BackgroundService.scheduleNewsCheck();
  } catch (e) {
    debugPrint('Aviso: erro ao inicializar WorkManager: $e');
  }

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

// ═══════════════════════════════════════════════════════════════════
// APP
// ═══════════════════════════════════════════════════════════════════
class HorizonteNewsApp extends StatefulWidget {
  const HorizonteNewsApp({Key? key}) : super(key: key);

  @override
  State<HorizonteNewsApp> createState() => _HorizonteNewsAppState();
}

class _HorizonteNewsAppState extends State<HorizonteNewsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingNotification();
    });
  }

  Future<void> _checkPendingNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('pending_news_url') ?? '';
    final title = prefs.getString('pending_news_title') ?? '';

    if (url.isEmpty) return;

    await prefs.remove('pending_news_url');
    await prefs.remove('pending_news_title');

    await Future.delayed(const Duration(milliseconds: 800));

    final post = PostModel(
      id: url.split('/').last.replaceAll('.html', ''),
      title: title,
      content: '',
      url: url,
      publishedAt: DateTime.now(),
      thumbnailUrl: '',
      categories: [],
    );

    navigatorKey.currentState?.pushNamed(
      AppRoutes.postDetail,
      arguments: post,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Horizonte News',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
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
// AUTH GATE — agora gerencia o dialog de notificação
// ═══════════════════════════════════════════════════════════════════
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _secureStorage = const FlutterSecureStorage();
  bool _notifChecked = false;

  // ── Verifica permissão real do sistema ───────────────────────────
  Future<bool> _systemNotifEnabled() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        final android = plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      } else if (Platform.isIOS) {
        final ios = plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final settings = await ios?.checkPermissions();
        return settings?.isEnabled ?? false;
      }
    } catch (_) {}
    return false;
  }

  // ── Dialog de permissão ──────────────────────────────────────────
  Future<void> _askNotificationPermission() async {
    if (_notifChecked) return;
    _notifChecked = true;

    final alreadyAsked =
        await _secureStorage.read(key: 'notif_permission_asked');
    if (alreadyAsked == 'true') return;

    final jaTemPermissao = await _systemNotifEnabled();

    // Marca como já perguntado antes de mostrar o dialog
    await _secureStorage.write(
        key: 'notif_permission_asked', value: 'true');

    if (jaTemPermissao) {
      await NotificationService.requestPermission();
      return;
    }

    if (!mounted) return;

    final userWantsNotif = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF6B00).withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.15),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFF8C3A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Fique por dentro!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ative as notificações para receber as últimas notícias do Horizonte News assim que forem publicadas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF8C3A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'ATIVAR NOTIFICAÇÕES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF2A2A2A)),
                    ),
                    child: const Center(
                      child: Text(
                        'Agora não',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (userWantsNotif == true) {
      await NotificationService.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoading();
        }

        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserXpProvider>(context, listen: false)
                .initialize();
            Provider.of<AdminProvider>(context, listen: false)
                .initialize();
            PresenceService.instance.start();

            // ── Pede notificação após login/sessão restaurada ──────
            _askNotificationPermission();
          });
          return AppRoutes.routes[AppRoutes.home]!(context);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          PresenceService.instance.stop();
          Provider.of<AdminProvider>(context, listen: false).reset();
        });

        return AppRoutes.routes[AppRoutes.login]!(context);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SPLASH
// ═══════════════════════════════════════════════════════════════════
class _SplashLoading extends StatefulWidget {
  const _SplashLoading();

  @override
  State<_SplashLoading> createState() => _SplashLoadingState();
}

class _SplashLoadingState extends State<_SplashLoading>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _textCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _progressAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _textFade;

  int _fraseIndex = 0;
  final List<String> _frases = [
    'Carregando últimas notícias...',
    'Buscando informações...',
    'Preparando sua experiência...',
    'Conectando ao Horizonte News...',
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return false;
      _textCtrl.reset();
      setState(() {
        _fraseIndex = (_fraseIndex + 1) % _frases.length;
      });
      _textCtrl.forward();
      return true;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _particleCtrl.dispose();
    _fadeCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _SplashParticlePainter(_particleCtrl.value),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) {
                        final glow = _pulseCtrl.value;
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFF6D00),
                                Color(0xFFE65100),
                                Color(0x00000000),
                              ],
                              stops: [0.0, 0.45, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00)
                                    .withOpacity(0.6 * glow),
                                blurRadius: 48,
                                spreadRadius: 12,
                              ),
                              BoxShadow(
                                color: const Color(0xFFE65100)
                                    .withOpacity(0.3 * glow),
                                blurRadius: 80,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.public,
                            size: 52,
                            color: Colors.white,
                          ),
                        );
                      },
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF6B00),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'AO VIVO',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFF6B00),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => Stack(
                        children: [
                          Container(
                            height: 2,
                            width: size.width - 96,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            height: 2,
                            width: (size.width - 96) * _progressAnim.value,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFBF360C),
                                  Color(0xFFFF6B00),
                                  Color(0xFFFFB74D),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B00)
                                      .withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      _frases[_fraseIndex],
                      style: const TextStyle(
                        color: Color(0xFF616161),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DO SPLASH
// ═══════════════════════════════════════════════════════════════════
class _SplashParticlePainter extends CustomPainter {
  final double t;
  _SplashParticlePainter(this.t);

  static final _rng = math.Random(42);
  static final _particles = List.generate(
    40,
    (i) => _ParticleData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 0.5 + _rng.nextDouble() * 1.5,
      speed: 0.04 + _rng.nextDouble() * 0.08,
      opacity: 0.1 + _rng.nextDouble() * 0.4,
      phase: _rng.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.03)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B00).withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.4),
        radius: size.width * 0.7,
      ));
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.4),
      size.width * 0.7,
      orbPaint,
    );

    for (final p in _particles) {
      final dy = (p.y + t * p.speed + p.phase) % 1.0;
      final dx =
          p.x + 0.03 * math.sin((t * 2 * math.pi) + p.phase * 6.28);
      final opacity = p.opacity *
          (0.5 +
              0.5 *
                  math.sin(
                      t * 2 * math.pi * p.speed * 10 + p.phase));
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.size,
        Paint()
          ..color = const Color(0xFFFF6B00)
              .withOpacity(opacity.clamp(0.0, 1.0)),
      );
    }

    final linePaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      final progress = (t + i * 0.33) % 1.0;
      final x = size.width * progress;
      linePaint.color =
          const Color(0xFFFF6B00).withOpacity(0.06 * (1 - progress));
      canvas.drawLine(
        Offset(x - 80, 0),
        Offset(x + 80, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SplashParticlePainter old) => old.t != t;
}

class _ParticleData {
  final double x, y, size, speed, opacity, phase;
  const _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}
