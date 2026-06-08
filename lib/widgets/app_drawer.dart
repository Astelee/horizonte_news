import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  static const List<_NavItem> _mainItems = [
    _NavItem(icon: Icons.home_rounded,         label: 'Início',               route: AppRoutes.home),
    _NavItem(icon: Icons.bookmark_rounded,     label: 'Notícias Salvas',      route: AppRoutes.favorites),
    _NavItem(icon: Icons.play_circle_rounded,  label: 'Vídeos / Reportagens', route: AppRoutes.videos),
    _NavItem(icon: Icons.search_rounded,       label: 'Pesquisar',            route: AppRoutes.search),
    _NavItem(icon: Icons.category_rounded,     label: 'Categorias',           route: AppRoutes.category),
  ];

  static const List<_NavItem> _secondaryItems = [
    _NavItem(icon: Icons.contact_mail_rounded, label: 'Fale Conosco / Denúncias', route: AppRoutes.contact),
    _NavItem(icon: Icons.settings_rounded,     label: 'Configurações',            route: AppRoutes.settings),
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, String route) {
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
      width: 295,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.drawerGradient),
        child: Stack(
          children: [
            // Glow decorativo superior
            Positioned(
              top: -80, left: -80,
              child: Container(
                width: 260, height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.glowOrange,
                ),
              ),
            ),
            // Linha brilhante direita
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: Container(
                width: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.borderGlow,
                      AppColors.borderGlow,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.25, 0.75, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Conteúdo
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
                          ..._mainItems.asMap().entries.map((e) =>
                              _DrawerTile(
                                item: e.value,
                                isActive: currentRoute == e.value.route,
                                delay: e.key * 55,
                                onTap: () =>
                                    _navigate(context, e.value.route),
                              )),
                          const SizedBox(height: 12),
                          _buildDivider(),
                          _buildSectionLabel('OUTROS'),
                          ..._secondaryItems.asMap().entries.map((e) =>
                              _DrawerTile(
                                item: e.value,
                                isActive: currentRoute == e.value.route,
                                delay: (_mainItems.length + e.key) * 55,
                                onTap: () =>
                                    _navigate(context, e.value.route),
                              )),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(context),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.55),
                          blurRadius: 22, spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryOrangeLight,
                          AppColors.primaryOrangeDark
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: AppColors.primaryOrange.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.newspaper_rounded,
                          color: Colors.white, size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.orangeGradient.createShader(b),
                    child: const Text(
                      'HORIZONTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  const Text(
                    'N E W S',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: AppColors.primaryOrange.withOpacity(0.10),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.30), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'AO VIVO  •  JORNALISMO INDEPENDENTE',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.transparent,
          AppColors.borderGlow,
          Colors.transparent,
        ]),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        children: [
          _buildDivider(),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _navigate(context, AppRoutes.login),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: AppColors.orangeGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'MINHA CONTA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Versão 1.0.0  ©  Horizonte News 2026',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Modelo ─────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon, required this.label, required this.route});
}

// ── Tile animado ───────────────────────────────────────────────────────────

class _DrawerTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final int delay;
  final VoidCallback onTap;

  const _DrawerTile({
    Key? key,
    required this.item,
    required this.isActive,
    required this.delay,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<_DrawerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _opacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide =
        Tween<Offset>(begin: const Offset(-0.12, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: widget.isActive
                  ? AppColors.primaryOrange.withOpacity(0.14)
                  : _pressed
                      ? AppColors.primaryOrange.withOpacity(0.07)
                      : Colors.transparent,
              border: Border.all(
                color: widget.isActive
                    ? AppColors.primaryOrange.withOpacity(0.35)
                    : Colors.transparent,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.10),
                        blurRadius: 10,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isActive)
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryOrange.withOpacity(0.18),
                        ),
                      ),
                    Icon(
                      widget.item.icon,
                      size: 20,
                      color: widget.isActive
                          ? AppColors.primaryOrange
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      color: widget.isActive
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: widget.isActive
                          ? FontWeight.w700
                          : FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (widget.isActive)
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryOrange,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
