import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// SPLASH
// ═══════════════════════════════════════════════════════════════════
class SplashLoading extends StatefulWidget {
  const SplashLoading({Key? key}) : super(key: key);

  @override
  State<SplashLoading> createState() => _SplashLoadingState();
}

class _SplashLoadingState extends State<SplashLoading>
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
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..forward();

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return false;
      _textCtrl.reset();
      setState(() => _fraseIndex = (_fraseIndex + 1) % _frases.length);
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
                        scale: _pulseAnim.value, child: child),
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
                          child: const Icon(Icons.public,
                              size: 52, color: Colors.white),
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
