import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_colors.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/app_avatar.dart';
import '../widgets/badge_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO
// ═══════════════════════════════════════════════════════════════════
class _RankUser {
  final String uid;
  final String name;
  final int totalXp;
  final int level;
  final String avatarId;

  _RankUser({
    required this.uid,
    required this.name,
    required this.totalXp,
    required this.level,
    required this.avatarId,
  });

  factory _RankUser.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final displayName = (data['displayName'] as String?)?.trim() ?? '';
    final email = (data['email'] as String?) ?? '';
    final name = displayName.isNotEmpty
        ? displayName
        : (email.isNotEmpty ? email.split('@').first : 'Usuário');
    return _RankUser(
      uid: doc.id,
      name: name,
      totalXp: (data['totalXp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      avatarId: (data['avatarId'] as String?) ?? 'animais_01',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TELA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
class RankingScreen extends StatefulWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin {
  late AnimationController _particleCtrl;
  late AnimationController _fireCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _fireCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
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
    _particleCtrl.dispose();
    _fireCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RankingParticlePainter(_particleCtrl.value),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users_xp')
                        .orderBy('totalXp', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return _buildLoading();

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) return _buildEmpty();

                      final users =
                          docs.map((d) => _RankUser.fromDoc(d)).toList();
                      final myIndex =
                          users.indexWhere((u) => u.uid == _myUid);

                      final top3 = users.take(3).toList();
                      final rest = users.length > 3
                          ? users.sublist(3)
                          : <_RankUser>[];

                      return Stack(
                        children: [
                          CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                  child: _buildPodium(top3)),
                              SliverToBoxAdapter(
                                  child: _buildListHeader(users.length)),
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                    16, 0, 16, myIndex >= 3 ? 96 : 24),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _RankTile(
                                      rank: index + 4,
                                      user: rest[index],
                                      isMe: rest[index].uid == _myUid,
                                      delay: (index * 40).clamp(0, 500),
                                    ),
                                    childCount: rest.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (myIndex >= 3)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 12,
                              child: _MyPositionBar(
                                user: users[myIndex],
                                rank: myIndex + 1,
                                glowCtrl: _glowCtrl,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 20, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Icon(
              FontAwesomeIcons.trophy,
              color: AppColors.primaryOrange
                  .withOpacity(0.7 + 0.3 * _glowAnim.value),
              size: 17,
              shadows: [
                Shadow(
                  color: AppColors.primaryOrange
                      .withOpacity(0.6 * _glowAnim.value),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFFF6D00), Color(0xFFFFB74D)],
            ).createShader(b),
            child: const Text(
              'RANKING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppColors.orangeVertical,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'CLASSIFICAÇÃO GERAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          Text(
            'Top $total',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryOrange,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.trophy,
              color: AppColors.primaryOrange.withOpacity(0.3), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Nenhum usuário no ranking ainda',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── PÓDIO TOP 3 ─────────────────────────────────────────────────
  Widget _buildPodium(List<_RankUser> top3) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second != null
                ? _PodiumSpot(
                    user: second,
                    rank: 2,
                    isMe: second.uid == _myUid,
                    height: 110,
                    avatarSize: 58,
                    medalColor: const Color(0xFFB0BEC5),
                    fireCtrl: _fireCtrl,
                    glowCtrl: _glowCtrl,
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: first != null
                ? _PodiumSpot(
                    user: first,
                    rank: 1,
                    isMe: first.uid == _myUid,
                    height: 142,
                    avatarSize: 76,
                    medalColor: const Color(0xFFFFD700),
                    fireCtrl: _fireCtrl,
                    glowCtrl: _glowCtrl,
                    isChampion: true,
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: third != null
                ? _PodiumSpot(
                    user: third,
                    rank: 3,
                    isMe: third.uid == _myUid,
                    height: 92,
                    avatarSize: 52,
                    medalColor: const Color(0xFFCD7F32),
                    fireCtrl: _fireCtrl,
                    glowCtrl: _glowCtrl,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SPOT DO PÓDIO (1º, 2º, 3º)
// ═══════════════════════════════════════════════════════════════════
class _PodiumSpot extends StatefulWidget {
  final _RankUser user;
  final int rank;
  final bool isMe;
  final double height;
  final double avatarSize;
  final Color medalColor;
  final AnimationController fireCtrl;
  final AnimationController glowCtrl;
  final bool isChampion;

  const _PodiumSpot({
    required this.user,
    required this.rank,
    required this.isMe,
    required this.height,
    required this.avatarSize,
    required this.medalColor,
    required this.fireCtrl,
    required this.glowCtrl,
    this.isChampion = false,
  });

  @override
  State<_PodiumSpot> createState() => _PodiumSpotState();
}

class _PodiumSpotState extends State<_PodiumSpot>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: 150 + widget.rank * 120), () {
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
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isChampion)
              AnimatedBuilder(
                animation: widget.fireCtrl,
                builder: (_, __) => Icon(
                  FontAwesomeIcons.crown,
                  color: widget.medalColor
                      .withOpacity(0.85 + 0.15 * widget.fireCtrl.value),
                  size: 22,
                  shadows: [
                    Shadow(
                      color: widget.medalColor.withOpacity(0.8),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),

            // Avatar + fogo por trás do campeão
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (widget.isChampion)
                  AnimatedBuilder(
                    animation: widget.fireCtrl,
                    builder: (_, __) => Container(
                      width: widget.avatarSize * 2.0,
                      height: widget.avatarSize * 2.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF6B00)
                                .withOpacity(0.32 * widget.fireCtrl.value),
                            const Color(0xFFFF2200)
                                .withOpacity(0.14 * widget.fireCtrl.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                AvatarFrame(
                  level: widget.user.level,
                  size: widget.avatarSize,
                  child: AppAvatar(
                    avatarId: widget.user.avatarId,
                    size: widget.avatarSize,
                  ),
                ),
                Positioned(
                  bottom: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          widget.medalColor,
                          widget.medalColor.withOpacity(0.7)
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.medalColor.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      '#${widget.rank}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              widget.user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isMe ? AppColors.primaryOrange : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.user.totalXp} XP',
              style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 10),
            ),
            const SizedBox(height: 4),
            FrameRarityTag(level: widget.user.level, fontSize: 7),
            const SizedBox(height: 10),

            // Base do pódio
            AnimatedBuilder(
              animation: widget.glowCtrl,
              builder: (_, __) => Container(
                width: double.infinity,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(
                    colors: [
                      widget.medalColor.withOpacity(0.22),
                      widget.medalColor.withOpacity(0.06),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: widget.medalColor
                        .withOpacity(0.4 + 0.2 * widget.glowCtrl.value),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.rank}º',
                    style: TextStyle(
                      color: widget.medalColor,
                      fontSize: widget.isChampion ? 32 : 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ITEM DA LISTA (4º em diante)
// ═══════════════════════════════════════════════════════════════════
class _RankTile extends StatefulWidget {
  final int rank;
  final _RankUser user;
  final bool isMe;
  final int delay;

  const _RankTile({
    required this.rank,
    required this.user,
    required this.isMe,
    required this.delay,
  });

  @override
  State<_RankTile> createState() => _RankTileState();
}

class _RankTileState extends State<_RankTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.isMe
                ? AppColors.primaryOrange.withOpacity(0.08)
                : const Color(0xFF0D0D0D),
            border: Border.all(
              color: widget.isMe
                  ? AppColors.primaryOrange.withOpacity(0.5)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '${widget.rank}º',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isMe
                        ? AppColors.primaryOrange
                        : const Color(0xFF666666),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AvatarFrame(
                level: widget.user.level,
                size: 40,
                child: AppAvatar(avatarId: widget.user.avatarId, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.isMe
                                  ? AppColors.primaryOrange
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (widget.isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: AppColors.primaryOrange.withOpacity(0.15),
                            ),
                            child: const Text(
                              'VOCÊ',
                              style: TextStyle(
                                color: AppColors.primaryOrange,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        LevelBadgeInline(level: widget.user.level),
                        const SizedBox(width: 6),
                        FrameRarityTag(level: widget.user.level, fontSize: 8),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.user.totalXp}\nXP',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
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
// BARRA "SUA POSIÇÃO" (fixa embaixo)
// ═══════════════════════════════════════════════════════════════════
class _MyPositionBar extends StatelessWidget {
  final _RankUser user;
  final int rank;
  final AnimationController glowCtrl;

  const _MyPositionBar({
    required this.user,
    required this.rank,
    required this.glowCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowCtrl,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0C0C0C),
          border: Border.all(
            color: AppColors.primaryOrange
                .withOpacity(0.5 + 0.2 * glowCtrl.value),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.25 * glowCtrl.value),
              blurRadius: 20,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '$rankº',
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            AvatarFrame(
              level: user.level,
              size: 36,
              child: AppAvatar(avatarId: user.avatarId, size: 36),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SUA POSIÇÃO',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${user.totalXp} XP',
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DE FOGO DE FUNDO
// ═══════════════════════════════════════════════════════════════════
class _RankingParticlePainter extends CustomPainter {
  final double t;
  _RankingParticlePainter(this.t);

  static final _rng = math.Random(77);
  static final _particles = List.generate(
    35,
    (i) => _RPData(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 0.5 + _rng.nextDouble() * 1.6,
      speed: 0.015 + _rng.nextDouble() * 0.035,
      opacity: 0.06 + _rng.nextDouble() * 0.22,
      phase: _rng.nextDouble(),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF6B00).withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.15),
        radius: size.width * 0.8,
      ));
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.15),
      size.width * 0.8,
      orbPaint,
    );

    for (final p in _particles) {
      final dy = 1.0 - ((p.y + t * p.speed + p.phase) % 1.0);
      final dx =
          p.x + 0.02 * math.sin((t * 2 * math.pi * 0.6) + p.phase * 6.28);
      final fireRatio = 1.0 - dy;
      final color = Color.lerp(
        const Color(0xFFFF6B00),
        const Color(0xFFFF2200),
        fireRatio,
      )!;
      final opacity = p.opacity *
          (0.5 + 0.5 * math.sin(t * 2 * math.pi * p.speed * 10 + p.phase));

      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.size,
        Paint()..color = color.withOpacity(opacity.clamp(0.0, 0.3)),
      );
    }
  }

  @override
  bool shouldRepaint(_RankingParticlePainter old) => old.t != t;
}

class _RPData {
  final double x, y, size, speed, opacity, phase;
  const _RPData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}
