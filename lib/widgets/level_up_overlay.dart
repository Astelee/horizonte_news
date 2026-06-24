import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// FUNÇÃO GLOBAL — chame de qualquer lugar para mostrar o overlay
// ═══════════════════════════════════════════════════════════════════
void showLevelUpOverlay(BuildContext context, int newLevel) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => LevelUpOverlay(
      newLevel: newLevel,
      onDone: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL DO OVERLAY
// ═══════════════════════════════════════════════════════════════════
class LevelUpOverlay extends StatefulWidget {
  final int newLevel;
  final VoidCallback onDone;

  const LevelUpOverlay({
    Key? key,
    required this.newLevel,
    required this.onDone,
  }) : super(key: key);

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with TickerProviderStateMixin {
  // ── Controladores ────────────────────────────────────────────────
  late AnimationController _entryCtrl;   // entrada do painel central
  late AnimationController _particleCtrl; // partículas/explosão
  late AnimationController _confettiCtrl; // confete caindo
  late AnimationController _auraCtrl;    // aura pulsante
  late AnimationController _exitCtrl;    // saída

  // ── Animações ────────────────────────────────────────────────────
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _exitFade;
  late Animation<double> _levelCountAnim;
  late Animation<double> _auraAnim;

  // ── Partículas ───────────────────────────────────────────────────
  final List<_Particle> _particles = [];
  final List<_ConfettiPiece> _confetti = [];
  final math.Random _rng = math.Random();

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _generateConfetti();
    _setupAnimations();
    _startSequence();
  }

  void _generateParticles() {
    final color = BadgeConfig.levelColor(widget.newLevel);
    final gradient = BadgeConfig.levelGradient(widget.newLevel);
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        angle: _rng.nextDouble() * 2 * math.pi,
        speed: 80 + _rng.nextDouble() * 220,
        size: 2 + _rng.nextDouble() * 5,
        color: i % 3 == 0
            ? Colors.white
            : i % 3 == 1
                ? color
                : gradient.last,
        fadeStart: 0.3 + _rng.nextDouble() * 0.3,
      ));
    }
  }

  void _generateConfetti() {
    const colors = [
      Color(0xFFFF6B00),
      Color(0xFFFFD700),
      Color(0xFF7289DA),
      Color(0xFF43B581),
      Color(0xFFED4245),
      Colors.white,
      Color(0xFFFF78C4),
      Color(0xFF00D4FF),
    ];
    for (int i = 0; i < 80; i++) {
      _confetti.add(_ConfettiPiece(
        x: _rng.nextDouble(),
        delay: _rng.nextDouble() * 0.5,
        speed: 0.3 + _rng.nextDouble() * 0.7,
        size: 4 + _rng.nextDouble() * 8,
        color: colors[_rng.nextInt(colors.length)],
        rotationSpeed: (_rng.nextDouble() - 0.5) * 6,
        isRect: _rng.nextBool(),
        swayAmplitude: 30 + _rng.nextDouble() * 60,
        swayFreq: 1 + _rng.nextDouble() * 3,
      ));
    }
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _auraAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _auraCtrl, curve: Curves.easeInOut),
    );

    _levelCountAnim = Tween<double>(
            begin: (widget.newLevel - 1).toDouble(),
            end: widget.newLevel.toDouble())
        .animate(CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );
  }

  Future<void> _startSequence() async {
    // 1. Explosão de partículas imediata
    _particleCtrl.forward();
    _confettiCtrl.forward();

    // 2. Painel central após 200ms
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _entryCtrl.forward();

    // 3. Aguarda usuário ver (3.5s) e sai
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    _exitCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && !_done) {
      _done = true;
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _particleCtrl.dispose();
    _confettiCtrl.dispose();
    _auraCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final color = BadgeConfig.levelColor(widget.newLevel);
    final gradient = BadgeConfig.levelGradient(widget.newLevel);
    final title = BadgeConfig.levelTitle(widget.newLevel);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryCtrl,
        _particleCtrl,
        _confettiCtrl,
        _auraCtrl,
        _exitCtrl,
      ]),
      builder: (context, _) {
        final opacity = _exitCtrl.isAnimating || _exitCtrl.isCompleted
            ? _exitFade.value
            : 1.0;

        return Opacity(
          opacity: opacity,
          child: GestureDetector(
            onTap: () {
              if (!_done) {
                _done = true;
                _exitCtrl.forward().then((_) => widget.onDone());
              }
            },
            child: Stack(
              children: [
                // ── Fundo escuro semitransparente ─────────────────
                Container(color: Colors.black.withOpacity(0.75)),

                // ── Aura de fundo ─────────────────────────────────
                Center(
                  child: Container(
                    width: size.width * 0.85 * _auraAnim.value,
                    height: size.width * 0.85 * _auraAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withOpacity(0.25 * _auraAnim.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Partículas de explosão ─────────────────────────
                CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _ExplosionPainter(
                    particles: _particles,
                    progress: _particleCtrl.value,
                    center: Offset(size.width / 2, size.height / 2),
                  ),
                ),

                // ── Confete holográfico ────────────────────────────
                CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _ConfettiPainter(
                    pieces: _confetti,
                    progress: _confettiCtrl.value,
                    screenHeight: size.height,
                    screenWidth: size.width,
                  ),
                ),

                // ── Painel central ────────────────────────────────
                Center(
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: Opacity(
                      opacity: _fadeAnim.value,
                      child: _buildPanel(color, gradient, title, size),
                    ),
                  ),
                ),

                // ── Toque para fechar ─────────────────────────────
                if (_entryCtrl.isCompleted)
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Toque para continuar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanel(
      Color color, List<Color> gradient, String title, Size size) {
    return Container(
      width: size.width * 0.82,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF080808),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35 * _auraAnim.value),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Linha "LEVEL UP!"
          ShaderMask(
            shaderCallback: (b) =>
                LinearGradient(colors: gradient).createShader(b),
            child: const Text(
              'LEVEL UP!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Número do nível animado
          AnimatedBuilder(
            animation: _levelCountAnim,
            builder: (_, __) {
              final val = _levelCountAnim.value.round();
              return ShaderMask(
                shaderCallback: (b) =>
                    LinearGradient(colors: gradient).createShader(b),
                child: Text(
                  '$val',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Título do nível
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: gradient),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Divisor com glow
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                color,
                Colors.transparent,
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Desbloqueio
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_open_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                'Desbloqueado: ${BadgeConfig.nextLevelUnlock(widget.newLevel - 1)}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Raridade da moldura
          _RarityChip(level: widget.newLevel, color: color),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHIP DE RARIDADE
// ═══════════════════════════════════════════════════════════════════
class _RarityChip extends StatelessWidget {
  final int level;
  final Color color;

  const _RarityChip({required this.level, required this.color});

  String _rarityLabel() {
    if (level >= 51) return 'Horizonte Elite';
    if (level >= 41) return 'Supremo';
    if (level >= 31) return 'Mítico';
    if (level >= 21) return 'Lendário';
    if (level >= 16) return 'Épico';
    if (level >= 11) return 'Raro';
    if (level >= 6) return 'Incomum';
    return 'Comum';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            'Moldura ${_rarityLabel()}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE PARTÍCULA
// ═══════════════════════════════════════════════════════════════════
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double fadeStart;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.fadeStart,
  });
}

// ═══════════════════════════════════════════════════════════════════
// PAINTER — EXPLOSÃO DE PARTÍCULAS
// ═══════════════════════════════════════════════════════════════════
class _ExplosionPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  const _ExplosionPainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final easedProgress =
          Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
      final dist = p.speed * easedProgress;
      final x = center.dx + math.cos(p.angle) * dist;
      final y = center.dy + math.sin(p.angle) * dist;

      final opacity = progress < p.fadeStart
          ? 1.0
          : 1.0 -
              ((progress - p.fadeStart) / (1.0 - p.fadeStart)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.3), paint);

      // Rastro luminoso
      if (opacity > 0.3) {
        final trailX = center.dx + math.cos(p.angle) * dist * 0.7;
        final trailY = center.dy + math.sin(p.angle) * dist * 0.7;
        final trailPaint = Paint()
          ..color = p.color.withOpacity(opacity * 0.3)
          ..strokeWidth = p.size * 0.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(trailX, trailY), Offset(x, y), trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ExplosionPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE CONFETE
// ═══════════════════════════════════════════════════════════════════
class _ConfettiPiece {
  final double x;
  final double delay;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;
  final bool isRect;
  final double swayAmplitude;
  final double swayFreq;

  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.isRect,
    required this.swayAmplitude,
    required this.swayFreq,
  });
}

// ═══════════════════════════════════════════════════════════════════
// PAINTER — CONFETE HOLOGRÁFICO
// ═══════════════════════════════════════════════════════════════════
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  final double screenHeight;
  final double screenWidth;

  const _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.screenHeight,
    required this.screenWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final effectiveProgress =
          ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (effectiveProgress <= 0) continue;

      final y = effectiveProgress * p.speed * screenHeight * 1.2;
      final sway = math.sin(effectiveProgress * math.pi * 2 * p.swayFreq) *
          p.swayAmplitude;
      final x = p.x * screenWidth + sway;
      final rotation = effectiveProgress * p.rotationSpeed * math.pi * 4;

      final opacity = effectiveProgress > 0.85
          ? 1.0 - ((effectiveProgress - 0.85) / 0.15).clamp(0.0, 1.0)
          : 1.0;

      final paint = Paint()..color = p.color.withOpacity(opacity * 0.9);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      } else {
        // Hexágono holográfico
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i / 6) * 2 * math.pi - math.pi / 6;
          final px = math.cos(angle) * p.size * 0.5;
          final py = math.sin(angle) * p.size * 0.5;
          i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
