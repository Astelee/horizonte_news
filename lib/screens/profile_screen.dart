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
import '../widgets/avatar_frame.dart';
import '../widgets/level_up_overlay.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late AnimationController _glowCtrl;
  late AnimationController _barCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _counterCtrl;

  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _avatarScaleAnim;
  late Animation<double> _badgeSlideAnim;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioStarted = false;

  @override
  void initState() {
    super.initState();

    // Registra observer para ciclo de vida do app
    WidgetsBinding.instance.addObserver(this);

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _avatarScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _badgeSlideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    _counterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryCtrl.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _barCtrl.forward();
        _counterCtrl.forward();
      });

      final xpProvider =
          Provider.of<UserXpProvider>(context, listen: false);
      xpProvider.onLevelUp = (newLevel) {
        if (mounted) showLevelUpOverlay(context, newLevel);
      };

      // Inicia o áudio apenas depois do frame estar pronto
      _startAudio();
    });
  }

  Future<void> _startAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.4);
      await _audioPlayer.play(AssetSource('sounds/ambient.mp3'));
      _audioStarted = true;
    } catch (e) {
      debugPrint('Erro ao iniciar áudio: $e');
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.release();
    } catch (e) {
      debugPrint('Erro ao parar áudio: $e');
    }
  }

  // ── Para o áudio quando o app vai para background ─────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _audioPlayer.pause();
        break;
      case AppLifecycleState.resumed:
        // Só retoma se o áudio foi iniciado e a tela ainda está montada
        if (_audioStarted && mounted) {
          _audioPlayer.resume();
        }
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Remove callback de level up
    try {
      final xpProvider =
          Provider.of<UserXpProvider>(context, listen: false);
      xpProvider.onLevelUp = null;
    } catch (_) {}

    // Para e libera o áudio
    _stopAudio();
    _audioPlayer.dispose();

    _glowCtrl.dispose();
    _barCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _entryCtrl.dispose();
    _counterCtrl.dispose();

    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _LogoutDialog(),
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
                            const SizedBox(height: 12),
                            _buildNextLevelPreview(data),
                            const SizedBox(height: 16),
                            _buildStatsGrid(data),
                            const SizedBox(height: 16),
                            _buildDailyMissions(data),
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

  // ══════════════════════════════════════════════════════════════════
  // SLIVER APP BAR
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSliverAppBar(User? user, UserXpData data) {
    final levelColor = BadgeConfig.levelColor(data.level);

    return SliverAppBar(
      expandedHeight: 260,
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
              builder: (_, __) => Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        levelColor.withOpacity(0.12 * _glowAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  AvatarFrame(
                    level: data.level,
                    size: 84,
                    enableEntryAnimation: true,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1A0800),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(
                              user?.displayName ?? user?.email),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ??
                        user?.email?.split('@').first ??
                        'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _badgeSlideAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _badgeSlideAnim.value),
                      child: child,
                    ),
                    child: _buildLevelTag(data),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelTag(UserXpData data) {
    final gradient = BadgeConfig.levelGradient(data.level);
    final color = BadgeConfig.levelColor(data.level);
    final isEpic = data.level >= 8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(isEpic ? 0.3 : 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isEpic ? 0.6 : 0.35),
                blurRadius: isEpic ? 20 : 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(BadgeConfig.levelIcon(data.level),
                  size: 12, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                BadgeConfig.levelTitle(data.level),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FrameRarityTag(level: data.level),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CARD DE XP
  // ══════════════════════════════════════════════════════════════════
  Widget _buildXpCard(UserXpData data) {
    final levelColor = BadgeConfig.levelColor(data.level);
    final levelGradient = BadgeConfig.levelGradient(data.level);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.25),
              width: 1),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.06),
                blurRadius: 30),
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
                    AnimatedBuilder(
                      animation: _counterCtrl,
                      builder: (_, __) {
                        final val = (data.totalXp *
                                Curves.easeOut
                                    .transform(_counterCtrl.value))
                            .round();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$val',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            const Padding(
                              padding:
                                  EdgeInsets.only(bottom: 4, left: 4),
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
                        );
                      },
                    ),
                  ],
                ),
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: levelGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: levelColor
                              .withOpacity(0.5 * _glowAnim.value),
                          blurRadius: 20,
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
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '${data.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
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
                      color: Color(0xFF9E9E9E), fontSize: 12),
                ),
                Text(
                  'Faltam ${data.xpForNextLevel - data.xpInCurrentLevel} XP para Nível ${data.level + 1}',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPremiumProgressBar(
                data.progressPercent, levelGradient, levelColor),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primaryOrange.withOpacity(0.08),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Tempo online total:',
                    style: TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.formattedTimeOnline,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  const Text(
                    '10 XP/min',
                    style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumProgressBar(
      double progress, List<Color> gradient, Color glowColor) {
    return AnimatedBuilder(
      animation: Listenable.merge([_barCtrl, _shimmerAnim]),
      builder: (_, __) {
        final animatedProgress =
            Curves.easeOutCubic.transform(_barCtrl.value) * progress;

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: animatedProgress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: gradient),
                    boxShadow: [
                      BoxShadow(
                          color: glowColor.withOpacity(0.7),
                          blurRadius: 10),
                    ],
                  ),
                ),
              ),
              if (_barCtrl.value > 0.3)
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: animatedProgress,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          begin:
                              Alignment(_shimmerAnim.value - 1, 0),
                          end: Alignment(_shimmerAnim.value, 0),
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ).createShader(rect),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PREVIEW DO PRÓXIMO NÍVEL
  // ══════════════════════════════════════════════════════════════════
  Widget _buildNextLevelPreview(UserXpData data) {
    final nextGradient = BadgeConfig.levelGradient(data.level + 1);
    final nextColor = BadgeConfig.levelColor(data.level + 1);
    final unlock = BadgeConfig.nextLevelUnlock(data.level);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              nextColor.withOpacity(0.08),
              nextColor.withOpacity(0.03)
            ],
          ),
          border: Border.all(color: nextColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: nextGradient),
                boxShadow: [
                  BoxShadow(
                      color: nextColor.withOpacity(0.5), blurRadius: 10)
                ],
              ),
              child: Center(
                child: FaIcon(BadgeConfig.levelIcon(data.level + 1),
                    size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Próximo nível: ${BadgeConfig.levelTitle(data.level + 1)}',
                    style: TextStyle(
                      color: nextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🎁 Desbloqueia: $unlock',
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: nextGradient),
              ),
              child: Text(
                '${data.xpForNextLevel - data.xpInCurrentLevel} XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // GRADE DE ESTATÍSTICAS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildStatsGrid(UserXpData data) {
    final articles =
        (data.stats['articlesRead'] as num?)?.toInt() ?? 0;
    final shares =
        (data.stats['articlesShared'] as num?)?.toInt() ?? 0;
    final comments =
        (data.stats['commentsPosted'] as num?)?.toInt() ?? 0;
    final streak =
        (data.stats['consecutiveDays'] as num?)?.toInt() ?? 0;
    final timeH = data.totalSecondsOnline ~/ 3600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _AnimatedStatCard(
                controller: _counterCtrl,
                icon: Icons.article_outlined,
                label: 'Artigos\nLidos',
                value: articles,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 10),
              _AnimatedStatCard(
                controller: _counterCtrl,
                icon: Icons.share_outlined,
                label: 'Compar-\ntilhados',
                value: shares,
                color: const Color(0xFF26C6DA),
              ),
              const SizedBox(width: 10),
              _AnimatedStatCard(
                controller: _counterCtrl,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Comentá-\nrios',
                value: comments,
                color: const Color(0xFFBA68C8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _AnimatedStatCard(
                controller: _counterCtrl,
                icon: Icons.local_fire_department_rounded,
                label: 'Sequência\nAtual',
                value: streak,
                color: const Color(0xFFFF5722),
                suffix: 'd',
              ),
              const SizedBox(width: 10),
              _AnimatedStatCard(
                controller: _counterCtrl,
                icon: Icons.access_time_rounded,
                label: 'Horas\nOnline',
                value: timeH,
                color: const Color(0xFFFFCA28),
                suffix: 'h',
              ),
              const SizedBox(width: 10),
              _AnimatedStatCard(
                controller: _counterCtrl,
                icon: Icons.bolt_rounded,
                label: 'XP\nTotal',
                value: data.totalXp,
                color: const Color(0xFF81C784),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MISSÕES DIÁRIAS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDailyMissions(UserXpData data) {
    final articles = data.dailyArticles.clamp(0, 5);
    final comments = data.dailyComments.clamp(0, 2);
    final shares = data.dailyShares.clamp(0, 1);
    final minutes = data.dailyMinutes.clamp(0, 10);

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final hh = diff.inHours.toString().padLeft(2, '0');
    final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.listCheck,
                        color: AppColors.primaryOrange, size: 13),
                    SizedBox(width: 8),
                    Text(
                      'MISSÕES DIÁRIAS',
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
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF43B581).withOpacity(0.15),
                    border: Border.all(
                        color:
                            const Color(0xFF43B581).withOpacity(0.4)),
                  ),
                  child: Text(
                    'RESET: $hh:$mm',
                    style: const TextStyle(
                      color: Color(0xFF43B581),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MissionTile(
              icon: FontAwesomeIcons.newspaper,
              label: 'Ler 5 notícias',
              xp: 25,
              progress: articles,
              total: 5,
              color: AppColors.primaryOrange,
              completed: articles >= 5,
            ),
            const SizedBox(height: 10),
            _MissionTile(
              icon: FontAwesomeIcons.comment,
              label: 'Fazer 2 comentários',
              xp: 40,
              progress: comments,
              total: 2,
              color: const Color(0xFFBA68C8),
              completed: comments >= 2,
            ),
            const SizedBox(height: 10),
            _MissionTile(
              icon: FontAwesomeIcons.shareNodes,
              label: 'Compartilhar 1 notícia',
              xp: 15,
              progress: shares,
              total: 1,
              color: const Color(0xFF26C6DA),
              completed: shares >= 1,
            ),
            const SizedBox(height: 10),
            _MissionTile(
              icon: FontAwesomeIcons.solidClock,
              label: 'Ficar 10 min lendo',
              xp: 20,
              progress: minutes,
              total: 10,
              color: const Color(0xFF66BB6A),
              completed: minutes >= 10,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SEÇÃO DE EMBLEMAS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAchievementsSection(UserXpData data) {
    final xpService = XpService();
    final achievements = xpService.getAllAchievements(data.achievements);
    final unlocked = achievements.where((a) => a.unlocked).toList();
    final locked = achievements.where((a) => !a.unlocked).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.2),
              width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.medal,
                        color: AppColors.primaryOrange, size: 13),
                    SizedBox(width: 8),
                    Text(
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
                    color:
                        AppColors.primaryOrange.withOpacity(0.12),
                    border: Border.all(
                        color:
                            AppColors.primaryOrange.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${unlocked.length} / ${achievements.length}',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (unlocked.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionLabel('OBTIDOS', const Color(0xFF43B581)),
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
                itemBuilder: (_, i) => _EmblemCard(
                    achievement: unlocked[i], unlocked: true),
              ),
            ],
            if (locked.isNotEmpty) ...[
              const SizedBox(height: 22),
              _sectionLabel('BLOQUEADOS', const Color(0xFF333333)),
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
                itemBuilder: (_, i) => _EmblemCard(
                    achievement: locked[i], unlocked: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // AÇÕES DA CONTA
  // ══════════════════════════════════════════════════════════════════
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
    if (parts.length >= 2)
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

// ═══════════════════════════════════════════════════════════════════
// STAT CARD COM CONTADOR ANIMADO
// ═══════════════════════════════════════════════════════════════════
class _AnimatedStatCard extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String suffix;

  const _AnimatedStatCard({
    required this.controller,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0A0A0A),
          border:
              Border.all(color: color.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.05), blurRadius: 12)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: controller,
              builder: (_, __) {
                final val = (value *
                        Curves.easeOut.transform(controller.value))
                    .round();
                return Text(
                  '$val$suffix',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 10,
                  height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MISSION TILE
// ═══════════════════════════════════════════════════════════════════
class _MissionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int xp;
  final int progress;
  final int total;
  final Color color;
  final bool completed;

  const _MissionTile({
    required this.icon,
    required this.label,
    required this.xp,
    required this.progress,
    required this.total,
    required this.color,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: completed
            ? color.withOpacity(0.08)
            : const Color(0xFF111111),
        border: Border.all(
          color: completed
              ? color.withOpacity(0.5)
              : const Color(0xFF1E1E1E),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: completed
                  ? Icon(Icons.check_rounded, color: color, size: 18)
                  : FaIcon(icon, color: color, size: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: completed
                        ? Colors.white
                        : const Color(0xFFCCCCCC),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                          height: 5,
                          color: const Color(0xFF1E1E1E)),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$progress/$total',
                  style: TextStyle(
                      color: color.withOpacity(0.7), fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: completed
                  ? LinearGradient(
                      colors: [color.withOpacity(0.8), color])
                  : null,
              color: completed ? null : const Color(0xFF1A1A1A),
              border: completed
                  ? null
                  : Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Text(
              '+$xp XP',
              style: TextStyle(
                color: completed
                    ? Colors.white
                    : const Color(0xFF666666),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EMBLEM CARD
// ═══════════════════════════════════════════════════════════════════
class _EmblemCard extends StatefulWidget {
  final Achievement achievement;
  final bool unlocked;

  const _EmblemCard(
      {required this.achievement, required this.unlocked});

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
        vsync: this, duration: const Duration(seconds: 3));
    if (widget.unlocked) _shimmerCtrl.repeat(reverse: true);
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
    final isLeg = widget.unlocked &&
        BadgeConfig.isLegendary(widget.achievement.icon);

    return GestureDetector(
      onTap: () => _showDetail(context, color, gradient),
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.unlocked
                ? LinearGradient(
                    colors: [
                      gradient[0].withOpacity(0.18),
                      gradient[1].withOpacity(0.07)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.unlocked
                ? null
                : const Color(0xFF0D0D0D),
            border: Border.all(
              color: widget.unlocked
                  ? color.withOpacity(isLeg
                      ? 0.7
                      : 0.28 + 0.22 * _shimmerCtrl.value)
                  : const Color(0xFF1A1A1A),
              width: isLeg ? 1.5 : 1,
            ),
            boxShadow: widget.unlocked
                ? [
                    BoxShadow(
                      color: color.withOpacity(isLeg
                          ? 0.25
                          : 0.10 + 0.10 * _shimmerCtrl.value),
                      blurRadius: isLeg ? 16 : 10,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.unlocked
                      ? LinearGradient(
                          colors: [
                            gradient[0].withOpacity(0.28),
                            gradient[1].withOpacity(0.12)
                          ],
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
                          shaderCallback: (b) =>
                              LinearGradient(colors: gradient)
                                  .createShader(b),
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
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
                          blurRadius: 6)
                    ],
                  ),
                )
              else
                const FaIcon(FontAwesomeIcons.lock,
                    size: 8, color: Color(0xFF2A2A2A)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, Color color, List<Color> gradient) {
    final rarity =
        BadgeConfig.achievementRarity(widget.achievement.icon);
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
                        blurRadius: 48)
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.unlocked
                      ? LinearGradient(colors: [
                          gradient[0].withOpacity(0.3),
                          gradient[1].withOpacity(0.1)
                        ])
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
                              blurRadius: 28)
                        ]
                      : null,
                ),
                child: Center(
                  child: widget.unlocked
                      ? ShaderMask(
                          shaderCallback: (b) =>
                              LinearGradient(colors: gradient)
                                  .createShader(b),
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
              if (widget.unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: gradient),
                  ),
                  child: Text(
                    rarity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
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
                    height: 1.5),
              ),
              const SizedBox(height: 18),
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
                      : Border.all(
                          color: const Color(0xFF2A2A2A)),
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
    final color =
        isDestructive ? AppColors.emergencyRed : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
            color: isDestructive
                ? AppColors.emergencyRed.withOpacity(0.3)
                : const Color(0xFF1A1A1A),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
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
          valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryOrange),
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
            color: AppColors.emergencyRed.withOpacity(0.3)),
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
                    color:
                        AppColors.emergencyRed.withOpacity(0.3)),
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
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seu progresso e XP estão salvos.\nVocê pode entrar novamente a qualquer momento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  height: 1.5),
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
                        border: Border.all(
                            color: const Color(0xFF2A2A2A)),
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
                        color: AppColors.emergencyRed
                            .withOpacity(0.15),
                        border: Border.all(
                            color: AppColors.emergencyRed
                                .withOpacity(0.4)),
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
