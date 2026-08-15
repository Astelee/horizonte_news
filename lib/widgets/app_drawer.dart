import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/user_xp_provider.dart';
import '../features/admin/providers/admin_provider.dart';
import '../services/sound_service.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _fireCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _headerFade;
  late Animation<double> _glowAnim;

  static const List<_NavItem> _mainItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Início', route: AppRoutes.home),
    _NavItem(icon: Icons.person_rounded, label: 'Meu Perfil', route: AppRoutes.profile),
    _NavItem(icon: Icons.emoji_events_rounded, label: 'Ranking', route: AppRoutes.ranking),
    _NavItem(icon: Icons.bookmark_rounded, label: 'Notícias Salvas', route: AppRoutes.favorites),
    _NavItem(icon: Icons.play_circle_rounded, label: 'Vídeos / Reportagens', route: AppRoutes.videos),
    _NavItem(icon: Icons.search_rounded, label: 'Pesquisar', route: AppRoutes.search),
    _NavItem(icon: Icons.local_fire_department_rounded, label: 'Mais Lidas', route: AppRoutes.mostRead),
  ];

  static const List<_NavItem> _supportItems = [
    _NavItem(icon: Icons.contact_mail_rounded, label: 'Fale Conosco / Denúncias', route: AppRoutes.contact),
    _NavItem(icon: Icons.settings_rounded, label: 'Configurações', route: AppRoutes.settings),
  ];

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fireCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _particleCtrl.dispose();
    _fireCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, String route) {
    HapticFeedback.lightImpact();
    SoundService.instance.playSystemClick();
    Navigator.pop(context);
    if (route == AppRoutes.home) {
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute =
        ModalRoute.of(context)?.settings.name ?? AppRoutes.home;

    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0200), Color(0xFF050505)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _DrawerParticlePainter(_particleCtrl.value),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Container(
                  width: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primaryOrange.withOpacity(0.3 * _glowAnim.value),
                        AppColors.primaryOrange.withOpacity(0.6 * _glowAnim.value),
                        AppColors.primaryOrange.withOpacity(0.3 * _glowAnim.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -60,
              left: -60,
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryOrange.withOpacity(0.18 * _glowAnim.value),
                        AppColors.primaryOrange.withOpacity(0.06 * _glowAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeTransition(
                    opacity: _headerFade,
                    child: _buildHeader(),
                  ),
                  _buildDivider(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('MENU PRINCIPAL'),
                          ..._mainItems.asMap().entries.map(
                            (e) => _DrawerTile(
                              item: e.value,
                              isActive: currentRoute == e.value.route,
                              delay: e.key * 60,
                              onTap: () => _navigate(context, e.value.route),
                              fireCtrl: _fireCtrl,
                              glowCtrl: _glowCtrl,
                              badge: e.value.route == AppRoutes.profile
                                  ? _XpBadge()
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDivider(),
                          _buildSectionLabel('SUPORTE'),
                          ..._supportItems.asMap().entries.map(
                            (e) => _DrawerTile(
                              item: e.value,
                              isActive: currentRoute == e.value.route,
                              delay: (_mainItems.length + e.key) * 60,
                              onTap: () => _navigate(context, e.value.route),
                              fireCtrl: _fireCtrl,
                              glowCtrl: _glowCtrl,
                            ),
                          ),
                          Consumer<AdminProvider>(
                            builder: (context, admin, _) {
                              if (!admin.isAdmin) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 10),
                                  _buildDivider(),
                                  _buildSectionLabel('ADMINISTRAÇÃO'),
                                  _DrawerTile(
                                    item: const _NavItem(
                                      icon: Icons.shield_rounded,
                                      label: 'Painel Administrativo',
                                      route: AppRoutes.adminPanel,
                                    ),
                                    isActive: currentRoute == AppRoutes.adminPanel,
                                    delay: 0,
                                    onTap: () => _navigate(context, AppRoutes.adminPanel),
                                    fireCtrl: _fireCtrl,
                                    glowCtrl: _glowCtrl,
                                    badge: _AdminBadge(),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_fireCtrl, _glowAnim]),
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange
                            .withOpacity(0.55 * _glowAnim.value),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF3300)
                            .withOpacity(0.25 * _fireCtrl.value),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primaryOrange.withOpacity(0.0),
                        AppColors.primaryOrange.withOpacity(0.9 * _glowAnim.value),
                        const Color(0xFFFF3300).withOpacity(0.7 * _fireCtrl.value),
                        AppColors.primaryOrange.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                      transform: GradientRotation(
                        _fireCtrl.value * 2 * math.pi,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6D00), Color(0xFFCC3300)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.primaryOrange.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.newspaper_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFFFB74D), Color(0xFFFF6D00)],
                ).createShader(b),
                child: const Text(
                  'HORIZONTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const Text(
                'N E W S',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3.5,
                ),
              ),
              const SizedBox(height: 7),
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.primaryOrange.withOpacity(0.12),
                    border: Border.all(
                      color: AppColors.primaryOrange
                          .withOpacity(0.25 + 0.25 * _glowAnim.value),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange
                            .withOpacity(0.1 * _glowAnim.value),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryOrange
                              .withOpacity(0.6 + 0.4 * _glowAnim.value),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryOrange
                                  .withOpacity(0.8 * _glowAnim.value),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'JORNALISMO INDEPENDENTE',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 1,
            color: AppColors.primaryOrange.withOpacity(0.4),
            margin: const EdgeInsets.only(right: 7),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.primaryOrange.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            AppColors.primaryOrange.withOpacity(0.15 + 0.15 * _glowAnim.value),
            AppColors.primaryOrange.withOpacity(0.3 + 0.2 * _glowAnim.value),
            AppColors.primaryOrange.withOpacity(0.15 + 0.15 * _glowAnim.value),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        children: [
          _buildDivider(),
          const SizedBox(height: 14),
          const Text(
            'Versão 1.0.0  ©  Horizonte News 2026',
            style: TextStyle(
              color: Color(0xFF333333),
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAINTER DE PARTÍCULAS DO DRAWER
// ═══════════════════════════════════════════════════════════════════
class _DrawerParticlePainter extends CustomPainter {
  final double t;
  _DrawerParticlePainter(this.t);

  static final _rng = math.Random(99);
  static final _particles = List.generate(
    30,
    (i) => _PData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 0.4 + _rng.nextDouble() * 1.4,
      speed: 0.015 + _rng.nextDouble() * 0.03,
      opacity: 0.05 + _rng.nextDouble() * 0.2,
      phase: _rng.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.025)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final p in _particles) {
      final dy = 1.0 - ((p.y + t * p.speed + p.phase) % 1.0);
      final dx = p.x + 0.02 * math.sin((t * 2 * math.pi * 0.5) + p.phase * 6.28);
      final opacity = p.opacity *
          (0.5 + 0.5 * math.sin(t * 2 * math.pi * p.speed * 12 + p.phase));

      final fireRatio = 1.0 - dy;
      final color = Color.lerp(
        const Color(0xFFFF6B00),
        const Color(0xFFFF2200),
        fireRatio,
      )!;

      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.size,
        Paint()..color = color.withOpacity(opacity.clamp(0.0, 0.3)),
      );
    }

    final linePaint = Paint()
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 2; i++) {
      final progress = (t * 0.4 + i * 0.5) % 1.0;
      final x = size.width * progress;
      linePaint.color =
          const Color(0xFFFF6B00).withOpacity(0.04 * (1 - progress));
      canvas.drawLine(
        Offset(x - 60, 0),
        Offset(x + 60, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DrawerParticlePainter old) => old.t != t;
}

class _PData {
  final double x, y, size, speed, opacity, phase;
  const _PData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

// ═══════════════════════════════════════════════════════════════════
// DRAWER TILE PREMIUM
// ═══════════════════════════════════════════════════════════════════
class _DrawerTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final int delay;
  final VoidCallback onTap;
  final AnimationController fireCtrl;
  final AnimationController glowCtrl;
  final Widget? badge;

  const _DrawerTile({
    Key? key,
    required this.item,
    required this.isActive,
    required this.delay,
    required this.onTap,
    required this.fireCtrl,
    required this.glowCtrl,
    this.badge,
  }) : super(key: key);

  @override
  State<_DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<_DrawerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-0.18, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedBuilder(
              animation: Listenable.merge([widget.fireCtrl, widget.glowCtrl]),
              builder: (_, __) {
                final isActive = widget.isActive;
                final glowVal = widget.glowCtrl.value;
                final fireVal = widget.fireCtrl.value;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isActive
                        ? AppColors.primaryOrange.withOpacity(0.10)
                        : _pressed
                            ? Colors.white.withOpacity(0.04)
                            : Colors.transparent,
                    border: isActive
                        ? Border.all(
                            color: AppColors.primaryOrange
                                .withOpacity(0.25 + 0.25 * glowVal),
                            width: 1,
                          )
                        : _pressed
                            ? Border.all(
                                color: AppColors.primaryOrange.withOpacity(0.15),
                                width: 1,
                              )
                            : null,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primaryOrange
                                  .withOpacity(0.12 * glowVal),
                              blurRadius: 16,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF3300)
                                  .withOpacity(0.06 * fireVal),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isActive)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryOrange.withOpacity(
                                        0.25 + 0.15 * glowVal),
                                    const Color(0xFFCC3300)
                                        .withOpacity(0.15 + 0.1 * fireVal),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryOrange
                                        .withOpacity(0.3 * glowVal),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            )
                          else
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: _pressed
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.white.withOpacity(0.04),
                              ),
                            ),
                          Icon(
                            widget.item.icon,
                            size: 19,
                            color: isActive
                                ? AppColors.primaryOrange
                                : Colors.white.withOpacity(0.5),
                          ),
                        ],
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (widget.badge != null) ...[
                        const SizedBox(width: 8),
                        widget.badge!,
                      ],
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        _FireDot(fireCtrl: widget.fireCtrl),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PONTO DE FOGO — INDICADOR DE ROTA ATIVA
// ═══════════════════════════════════════════════════════════════════
class _FireDot extends StatelessWidget {
  final AnimationController fireCtrl;
  const _FireDot({required this.fireCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fireCtrl,
      builder: (_, __) {
        final v = fireCtrl.value;
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.9),
                AppColors.primaryOrange,
                const Color(0xFFFF2200).withOpacity(0.5 + 0.5 * v),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.8 + 0.2 * v),
                blurRadius: 6 + 4 * v,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: const Color(0xFFFF2200).withOpacity(0.4 * v),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BADGE DE XP
// ═══════════════════════════════════════════════════════════════════
class _XpBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserXpProvider>(
      builder: (context, xpProvider, _) {
        final level = xpProvider.data.level;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppColors.primaryOrange.withOpacity(0.2),
                AppColors.primaryOrange.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            'Nv. $level',
            style: const TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BADGE ADM
// ═══════════════════════════════════════════════════════════════════
class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6D00), Color(0xFFCC2200)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Text(
        'ADM',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NAV ITEM MODEL
// ═══════════════════════════════════════════════════════════════════
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon, required this.label, required this.route});
}
