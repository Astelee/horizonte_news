import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/user_xp_provider.dart';
import '../providers/admin_provider.dart';
import '../services/xp_service.dart';

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
    _NavItem(icon: Icons.home_rounded, label: 'Início', route: AppRoutes.home),
    _NavItem(icon: Icons.person_rounded, label: 'Meu Perfil', route: AppRoutes.profile),
    _NavItem(icon: Icons.people_rounded, label: 'Amigos', route: AppRoutes.friends),
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
      duration: const Duration(milliseconds: 500),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
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
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.glowOrange,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
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
                              delay: e.key * 45,
                              onTap: () => _navigate(context, e.value.route),
                              badge: e.value.route == AppRoutes.profile
                                  ? _XpBadge()
                                  : e.value.route == AppRoutes.friends
                                      ? _FriendRequestBadge()
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
                              delay: (_mainItems.length + e.key) * 45,
                              onTap: () => _navigate(context, e.value.route),
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
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.55),
                      blurRadius: 22,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryOrangeLight, AppColors.primaryOrangeDark],
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
                      color: Colors.white,
                      size: 26,
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
                shaderCallback: (b) => AppColors.orangeGradient.createShader(b),
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
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.primaryOrange.withOpacity(0.12),
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.30),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'JORNALISMO INDEPENDENTE',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
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
            onTap: () => _navigate(context, AppRoutes.profile),
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
              child: Consumer<UserXpProvider>(
                builder: (context, xpProvider, _) {
                  final level = xpProvider.data.level;
                  final title = XpService.levelTitle(level);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'MEU PERFIL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: Text(
                          'Nv.$level • $title',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Versão 1.0.0  ©  Horizonte News 2026',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── BADGE DE PEDIDOS PENDENTES ────────────────────────────────────
class _FriendRequestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.emergencyRed,
            boxShadow: [
              BoxShadow(
                color: AppColors.emergencyRed.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}

// ── BADGE DE XP ───────────────────────────────────────────────────
class _XpBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserXpProvider>(
      builder: (context, xpProvider, _) {
        final level = xpProvider.data.level;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.primaryOrange.withOpacity(0.15),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Text(
            'Nv. $level',
            style: const TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

// ── BADGE ADM ─────────────────────────────────────────────────────
class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.orangeGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Text(
        'ADM',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}

class _DrawerTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final int delay;
  final VoidCallback onTap;
  final Widget? badge;

  const _DrawerTile({
    Key? key,
    required this.item,
    required this.isActive,
    required this.delay,
    required this.onTap,
    this.badge,
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
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-0.12, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.isActive;

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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: isActive
                  ? AppColors.primaryOrange.withOpacity(0.13)
                  : _pressed
                      ? Colors.white.withOpacity(0.05)
                      : Colors.transparent,
              border: isActive
                  ? Border.all(
                      color: AppColors.primaryOrange.withOpacity(0.35),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: isActive
                        ? AppColors.primaryOrange.withOpacity(0.18)
                        : Colors.white.withOpacity(0.05),
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 18,
                    color: isActive ? AppColors.primaryOrange : Colors.white60,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 8),
                  widget.badge!,
                ],
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(left: 6),
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
