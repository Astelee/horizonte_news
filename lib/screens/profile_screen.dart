import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/badge_config.dart';
import '../providers/user_xp_provider.dart';
import '../services/xp_service.dart';
import '../widgets/badge_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late AnimationController _barCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barCtrl.forward();
    });

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(0.4);
    _audioPlayer.play(AssetSource('sounds/ambient.mp3'));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _barCtrl.dispose();
    _fadeCtrl.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _LogoutDialog(),
    );
    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Consumer<UserXpProvider>(
          builder: (context, xpProvider, _) {
            final data = xpProvider.data;
            final isLoading = xpProvider.isLoading;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(user, data),
                SliverToBoxAdapter(
                  child: isLoading
                      ? const _ProfileSkeleton()
                      : Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildXpCard(data),
                            const SizedBox(height: 16),
                            _buildStatsRow(data),
                            const SizedBox(height: 16),
                            _buildAchievementsSection(data),
                            const SizedBox(height: 16),
                            _buildAccountActions(),
                            const SizedBox(height: 40),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── SLIVER APP BAR ────────────────────────────────────────────────
  Widget _buildSliverAppBar(User? user, UserXpData data) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A0800), Color(0xFF000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryOrange
                            .withOpacity(0.15 * _glowAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, child) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryOrange
                                .withOpacity(0.5 * _glowAnim.value),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF1A0800),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFF6B00),
                              Color(0xFFCC4400),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(
                                user?.displayName ?? user?.email),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.displayName ??
                        user?.email?.split('@').first ??
                        'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: AppColors.orangeGradient,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          BadgeConfig.levelIcon(data.level),
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${BadgeConfig.levelTitle(data.level)}  •  Nível ${data.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CARD DE XP ────────────────────────────────────────────────────
  Widget _buildXpCard(UserXpData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.06),
              blurRadius: 30,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EXPERIÊNCIA',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${data.totalXp}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            'XP',
                            style: TextStyle(
                              color: AppColors.primaryOrange,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryOrange,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange
                              .withOpacity(0.4 * _glowAnim.value),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'LVL',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '${data.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${data.xpInCurrentLevel} / ${data.xpForNextLevel} XP',
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Nível ${data.level + 1} em ${data.xpForNextLevel - data.xpInCurrentLevel} XP',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildProgressBar(data.progressPercent),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primaryOrange.withOpacity(0.08),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Tempo online total:',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.formattedTimeOnline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '10 XP/min',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BARRA DE PROGRESSO ANIMADA ────────────────────────────────────
  Widget _buildProgressBar(double progress) {
    return AnimatedBuilder(
      animation: _barCtrl,
      builder: (_, __) {
        final animatedProgress =
            Curves.easeOutCubic.transform(_barCtrl.value) * progress;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: animatedProgress,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ESTATÍSTICAS ──────────────────────────────────────────────────
  Widget _buildStatsRow(UserXpData data) {
    final articles =
        (data.stats['articlesRead'] as num?)?.toInt() ?? 0;
    final shares =
        (data.stats['articlesShared'] as num?)?.toInt() ?? 0;
    final comments =
        (data.stats['commentsPosted'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.article_outlined,
            label: 'Artigos\nLidos',
            value: '$articles',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.share_outlined,
            label: 'Compar-\ntilhados',
            value: '$shares',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Comentá-\nrios',
            value: '$comments',
          ),
        ],
      ),
    );
  }

  // ── EMBLEMAS ──────────────────────────────────────────────────────
  Widget _buildAchievementsSection(UserXpData data) {
    final xpService = XpService();
    final achievements = xpService.getAllAchievements(data.achievements);
    final unlocked = achievements.where((a) => a.unlocked).toList();
    final locked = achievements.where((a) => !a.unlocked).toList();
    final unlockedCount = unlocked.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.medal,
                      color: AppColors.primaryOrange,
                      size: 13,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'EMBLEMAS',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.primaryOrange.withOpacity(0.12),
                    border: Border.all(
                      color: AppColors.primaryOrange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '$unlockedCount / ${achievements.length}',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            // ── Desbloqueados ──────────────────────────────────────
            if (unlocked.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF43B581),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'OBTIDOS',
                    style: TextStyle(
                      color: Color(0xFF43B581),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemCount: unlocked.length,
                itemBuilder: (context, i) => _EmblemCard(
                  achievement: unlocked[i],
                  unlocked: true,
                ),
              ),
            ],

            // ── Bloqueados ─────────────────────────────────────────
            if (locked.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'BLOQUEADOS',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemCount: locked.length,
                itemBuilder: (context, i) => _EmblemCard(
                  achievement: locked[i],
                  unlocked: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── AÇÕES DA CONTA ────────────────────────────────────────────────
  Widget _buildAccountActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.settings_outlined,
            label: 'Configurações',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.logout_rounded,
            label: 'Sair da conta',
            isDestructive: true,
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// ═══════════════════════════════════════════════════════════════════
// STAT CARD
// ═══════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryOrange, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═══════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.emergencyRed : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
            color: isDestructive
                ? AppColors.emergencyRed.withOpacity(0.3)
                : const Color(0xFF1A1A1A),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROFILE SKELETON
// ═══════════════════════════════════════════════════════════════════

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LOGOUT DIALOG
// ═══════════════════════════════════════════════════════════════════

class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.emergencyRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.emergencyRed.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.emergencyRed.withOpacity(0.3),
                ),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppColors.emergencyRed, size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sair da conta?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu progresso e XP estão salvos.\nVocê pode entrar novamente a qualquer momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Center(
                        child: Text(
                          'CANCELAR',
                          style: TextStyle(
                            color: Color(0xFF9E9E9E),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.emergencyRed.withOpacity(0.15),
                        border: Border.all(
                          color: AppColors.emergencyRed.withOpacity(0.4),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'SAIR',
                          style: TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EMBLEM CARD — versão premium com gradiente e animação
// ═══════════════════════════════════════════════════════════════════

class _EmblemCard extends StatefulWidget {
  final Achievement achievement;
  final bool unlocked;

  const _EmblemCard({
    required this.achievement,
    required this.unlocked,
  });

  @override
  State<_EmblemCard> createState() => _EmblemCardState();
}

class _EmblemCardState extends State<_EmblemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.unlocked) {
      _shimmerCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.unlocked
        ? BadgeConfig.achievementColor(widget.achievement.icon)
        : const Color(0xFF1E1E1E);

    final gradient = widget.unlocked
        ? BadgeConfig.achievementGradient(widget.achievement.icon)
        : [const Color(0xFF111111), const Color(0xFF111111)];

    return GestureDetector(
      onTap: () => _showDetail(context, color, gradient),
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (_, __) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: widget.unlocked
                  ? LinearGradient(
                      colors: [
                        gradient[0].withOpacity(0.18),
                        gradient[1].withOpacity(0.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: widget.unlocked ? null : const Color(0xFF0D0D0D),
              border: Border.all(
                color: widget.unlocked
                    ? color.withOpacity(
                        0.28 + 0.22 * _shimmerCtrl.value)
                    : const Color(0xFF1A1A1A),
                width: widget.unlocked ? 1.5 : 1,
              ),
              boxShadow: widget.unlocked
                  ? [
                      BoxShadow(
                        color: color.withOpacity(
                            0.10 + 0.10 * _shimmerCtrl.value),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Ícone com ShaderMask (gradiente real no ícone) ──
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.unlocked
                        ? LinearGradient(
                            colors: [
                              gradient[0].withOpacity(0.28),
                              gradient[1].withOpacity(0.12),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: widget.unlocked
                        ? null
                        : const Color(0xFF161616),
                    border: Border.all(
                      color: widget.unlocked
                          ? color.withOpacity(0.5)
                          : const Color(0xFF222222),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: widget.unlocked
                        ? ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: FaIcon(
                              BadgeConfig.achievementIcon(
                                  widget.achievement.icon),
                              size: 17,
                              color: Colors.white,
                            ),
                          )
                        : FaIcon(
                            BadgeConfig.achievementIcon(
                                widget.achievement.icon),
                            size: 17,
                            color: const Color(0xFF2A2A2A),
                          ),
                  ),
                ),
                const SizedBox(height: 7),
                // ── Nome ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.achievement.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.unlocked
                          ? Colors.white
                          : const Color(0xFF2E2E2E),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // ── Indicador desbloqueado / cadeado ───────────────
                if (widget.unlocked)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.9),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  )
                else
                  const FaIcon(
                    FontAwesomeIcons.lock,
                    size: 8,
                    color: Color(0xFF2A2A2A),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Dialog de detalhe do emblema ──────────────────────────────────
  void _showDetail(
      BuildContext context, Color color, List<Color> gradient) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF0C0C0C),
            border: Border.all(
              color: widget.unlocked
                  ? color.withOpacity(0.45)
                  : const Color(0xFF1A1A1A),
              width: 1.5,
            ),
            boxShadow: widget.unlocked
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.22),
                      blurRadius: 48,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Ícone grande ──────────────────────────────────────
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.unlocked
                      ? LinearGradient(
                          colors: [
                            gradient[0].withOpacity(0.3),
                            gradient[1].withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.unlocked
                      ? null
                      : const Color(0xFF161616),
                  border: Border.all(
                    color: widget.unlocked
                        ? color.withOpacity(0.6)
                        : const Color(0xFF222222),
                    width: 2,
                  ),
                  boxShadow: widget.unlocked
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.35),
                            blurRadius: 28,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: widget.unlocked
                      ? ShaderMask(
                          shaderCallback: (b) => LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(b),
                          child: FaIcon(
                            BadgeConfig.achievementIcon(
                                widget.achievement.icon),
                            size: 34,
                            color: Colors.white,
                          ),
                        )
                      : FaIcon(
                          BadgeConfig.achievementIcon(
                              widget.achievement.icon),
                          size: 34,
                          color: const Color(0xFF2A2A2A),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.unlocked
                      ? Colors.white
                      : const Color(0xFF3A3A3A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.achievement.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              // ── Badge de status ───────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: widget.unlocked
                      ? LinearGradient(colors: gradient)
                      : null,
                  color: widget.unlocked
                      ? null
                      : const Color(0xFF161616),
                  border: widget.unlocked
                      ? null
                      : Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.unlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_rounded,
                      color: widget.unlocked
                          ? Colors.white
                          : const Color(0xFF444444),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.unlocked ? 'OBTIDO' : 'BLOQUEADO',
                      style: TextStyle(
                        color: widget.unlocked
                            ? Colors.white
                            : const Color(0xFF444444),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
