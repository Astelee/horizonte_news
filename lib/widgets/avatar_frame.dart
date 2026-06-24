import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// RARIDADE DA MOLDURA — derivada do nível do usuário
// ═══════════════════════════════════════════════════════════════════
enum FrameRarity {
  common,    // 1-5
  uncommon,  // 6-10
  rare,      // 11-15
  epic,      // 16-20
  legendary, // 21-30
  mythic,    // 31-40
  supreme,   // 41-50
  elite,     // 50+
}

extension FrameRarityExt on FrameRarity {
  static FrameRarity fromLevel(int level) {
    if (level >= 51) return FrameRarity.elite;
    if (level >= 41) return FrameRarity.supreme;
    if (level >= 31) return FrameRarity.mythic;
    if (level >= 21) return FrameRarity.legendary;
    if (level >= 16) return FrameRarity.epic;
    if (level >= 11) return FrameRarity.rare;
    if (level >= 6) return FrameRarity.uncommon;
    return FrameRarity.common;
  }

  String get label {
    switch (this) {
      case FrameRarity.common:    return 'Comum';
      case FrameRarity.uncommon:  return 'Incomum';
      case FrameRarity.rare:      return 'Raro';
      case FrameRarity.epic:      return 'Épico';
      case FrameRarity.legendary: return 'Lendário';
      case FrameRarity.mythic:    return 'Mítico';
      case FrameRarity.supreme:   return 'Supremo';
      case FrameRarity.elite:     return 'Horizonte Elite';
    }
  }

  /// Quantidade de partículas — escala com a raridade
  int get particleCount {
    switch (this) {
      case FrameRarity.common:    return 0;
      case FrameRarity.uncommon:  return 4;
      case FrameRarity.rare:      return 0; // usa anel ao invés de partículas
      case FrameRarity.epic:      return 8;
      case FrameRarity.legendary: return 10;
      case FrameRarity.mythic:    return 14;
      case FrameRarity.supreme:   return 18;
      case FrameRarity.elite:     return 22;
    }
  }

  bool get hasRotatingRing =>
      this == FrameRarity.rare ||
      this == FrameRarity.epic ||
      this == FrameRarity.mythic ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  bool get hasPulse =>
      this == FrameRarity.legendary ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  bool get hasCosmicHalo =>
      this == FrameRarity.mythic || this == FrameRarity.elite;

  bool get is360Aura =>
      this == FrameRarity.supreme || this == FrameRarity.elite;

  double get glowIntensity {
    switch (this) {
      case FrameRarity.common:    return 0.35;
      case FrameRarity.uncommon:  return 0.45;
      case FrameRarity.rare:      return 0.55;
      case FrameRarity.epic:      return 0.65;
      case FrameRarity.legendary: return 0.75;
      case FrameRarity.mythic:    return 0.85;
      case FrameRarity.supreme:   return 0.95;
      case FrameRarity.elite:     return 1.0;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL — AVATAR COM MOLDURA ANIMADA
// ═══════════════════════════════════════════════════════════════════
class AvatarFrame extends StatefulWidget {
  final int level;
  final double size;
  final Widget child; // conteúdo central (iniciais, ícone, etc)
  final bool enableEntryAnimation;

  const AvatarFrame({
    Key? key,
    required this.level,
    required this.child,
    this.size = 96,
    this.enableEntryAnimation = false,
  }) : super(key: key);

  @override
  State<AvatarFrame> createState() => _AvatarFrameState();
}

class _AvatarFrameState extends State<AvatarFrame>
    with TickerProviderStateMixin {
  late AnimationController _rotationCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _entryCtrl;

  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _entryScaleAnim;
  late Animation<double> _entryFadeAnim;

  @override
  void initState() {
    super.initState();

    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _entryFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );

    if (widget.enableEntryAnimation) {
      _entryCtrl.forward();
    } else {
      _entryCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = FrameRarityExt.fromLevel(widget.level);
    final gradient = BadgeConfig.levelGradient(widget.level);
    final color = BadgeConfig.levelColor(widget.level);

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_rotationCtrl, _glowCtrl, _pulseCtrl, _particleCtrl, _entryCtrl]),
      builder: (context, _) {
        final scale = widget.enableEntryAnimation
            ? _entryScaleAnim.value
            : (rarity.hasPulse ? _pulseAnim.value : 1.0);
        final opacity =
            widget.enableEntryAnimation ? _entryFadeAnim.value : 1.0;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size * 1.6,
              height: widget.size * 1.6,
              child: CustomPaint(
                painter: _FramePainter(
                  rarity: rarity,
                  color: color,
                  gradient: gradient,
                  rotation: _rotationCtrl.value,
                  glow: _glowAnim.value,
                  particleProgress: _particleCtrl.value,
                  avatarSize: widget.size,
                ),
                child: Center(
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color
                              .withOpacity(rarity.glowIntensity * _glowAnim.value),
                          blurRadius: 14 + (rarity.index * 3),
                          spreadRadius: 1 + (rarity.index * 0.5),
                        ),
                      ],
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CUSTOM PAINTER — desenha anel, partículas, halo cósmico, aura 360°
// ═══════════════════════════════════════════════════════════════════
class _FramePainter extends CustomPainter {
  final FrameRarity rarity;
  final Color color;
  final List<Color> gradient;
  final double rotation;
  final double glow;
  final double particleProgress;
  final double avatarSize;

  _FramePainter({
    required this.rarity,
    required this.color,
    required this.gradient,
    required this.rotation,
    required this.glow,
    required this.particleProgress,
    required this.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = avatarSize / 2 + 10;

    if (rarity.is360Aura) {
      _paintAura360(canvas, center, ringRadius);
    }

    if (rarity.hasCosmicHalo) {
      _paintCosmicHalo(canvas, center, ringRadius);
    }

    if (rarity.hasRotatingRing) {
      _paintRotatingRing(canvas, center, ringRadius);
    }

    if (rarity.particleCount > 0) {
      _paintOrbitalParticles(canvas, center, ringRadius);
    }

    if (rarity == FrameRarity.elite) {
      _paintEliteMark(canvas, center, ringRadius);
    }
  }

  // ── Aura dinâmica 360° (Supremo / Elite) ─────────────────────────
  void _paintAura360(Canvas canvas, Offset center, double radius) {
    final auraRadius = radius + 14;
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: rotation * 2 * math.pi,
        endAngle: rotation * 2 * math.pi + 2 * math.pi,
        colors: [
          gradient[0].withOpacity(0.0),
          gradient[0].withOpacity(0.7 * glow),
          gradient[1].withOpacity(0.9 * glow),
          gradient[0].withOpacity(0.0),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: auraRadius));

    canvas.drawCircle(center, auraRadius, sweepPaint);

    // Segunda camada girando ao contrário, mais fina
    final innerSweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -rotation * 3 * math.pi,
        endAngle: -rotation * 3 * math.pi + 2 * math.pi,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.5 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: auraRadius - 6));

    canvas.drawCircle(center, auraRadius - 6, innerSweep);
  }

  // ── Halo cósmico (Mítico / Elite) ────────────────────────────────
  void _paintCosmicHalo(Canvas canvas, Offset center, double radius) {
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          gradient[1].withOpacity(0.0),
          gradient[0].withOpacity(0.18 * glow),
          Colors.transparent,
        ],
        stops: const [0.5, 0.75, 1.0],
      ).createShader(
          Rect.fromCircle(center: center, radius: radius + 26));

    canvas.drawCircle(center, radius + 26, haloPaint);

    // Pequenas estrelas cósmicas espalhadas
    final starPaint = Paint()..color = Colors.white.withOpacity(0.8 * glow);
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi + rotation * math.pi;
      final dist = radius + 18 + (i % 2 == 0 ? 4 : -4);
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      canvas.drawCircle(pos, 1.4, starPaint);
    }
  }

  // ── Anel girando (Raro, Épico, Mítico, Supremo, Elite) ───────────
  void _paintRotatingRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: rotation * 2 * math.pi,
        endAngle: rotation * 2 * math.pi + math.pi * 1.4,
        colors: [
          Colors.transparent,
          gradient[0].withOpacity(0.9 * glow),
          gradient[1].withOpacity(0.9 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, ringPaint);

    // Pontinho brilhante na ponta do anel
    final tipAngle = rotation * 2 * math.pi + math.pi * 1.4;
    final tipPos = Offset(
      center.dx + math.cos(tipAngle) * radius,
      center.dy + math.sin(tipAngle) * radius,
    );
    final tipPaint = Paint()
      ..color = Colors.white.withOpacity(glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(tipPos, 3, tipPaint);
  }

  // ── Partículas orbitais (Incomum, Épico, Lendário, Mítico, Supremo, Elite) ──
  void _paintOrbitalParticles(Canvas canvas, Offset center, double radius) {
    final count = rarity.particleCount;
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final baseAngle = (i / count) * 2 * math.pi;
      final speedVariation = 1.0 + (i % 3) * 0.3;
      final angle = baseAngle + particleProgress * 2 * math.pi * speedVariation;

      // Órbita levemente elíptica para parecer mais orgânico
      final orbitRadius = radius + 4 + math.sin(particleProgress * 4 * math.pi + i) * 3;

      final pos = Offset(
        center.dx + math.cos(angle) * orbitRadius,
        center.dy + math.sin(angle) * orbitRadius * 0.92,
      );

      final particleSize = rarity == FrameRarity.elite
          ? 2.2
          : rarity == FrameRarity.supreme
              ? 2.0
              : 1.6;

      final pulse = (math.sin(particleProgress * 6 * math.pi + i * 2) + 1) / 2;
      final opacity = (0.4 + pulse * 0.6) * glow;

      particlePaint
        ..color = (i % 2 == 0 ? gradient[0] : gradient[1]).withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

      canvas.drawCircle(pos, particleSize, particlePaint);
    }
  }

  // ── Marca exclusiva Horizonte Elite ──────────────────────────────
  void _paintEliteMark(Canvas canvas, Offset center, double radius) {
    // Pequenos diamantes nos 4 cantos cardeais, girando lentamente
    final markPaint = Paint()
      ..color = Colors.white.withOpacity(0.85 * glow)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi + rotation * 0.5 * math.pi;
      final pos = Offset(
        center.dx + math.cos(angle) * (radius + 16),
        center.dy + math.sin(angle) * (radius + 16),
      );

      final path = Path();
      const d = 3.2;
      path.moveTo(pos.dx, pos.dy - d);
      path.lineTo(pos.dx + d, pos.dy);
      path.lineTo(pos.dx, pos.dy + d);
      path.lineTo(pos.dx - d, pos.dy);
      path.close();

      canvas.drawPath(path, markPaint);
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.glow != glow ||
      oldDelegate.particleProgress != particleProgress;
}

// ═══════════════════════════════════════════════════════════════════
// TAG DE RARIDADE — para mostrar "Raro", "Lendário" etc ao lado do nível
// ═══════════════════════════════════════════════════════════════════
class FrameRarityTag extends StatelessWidget {
  final int level;
  final double fontSize;

  const FrameRarityTag({
    Key? key,
    required this.level,
    this.fontSize = 9,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rarity = FrameRarityExt.fromLevel(level);
    final color = BadgeConfig.levelColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        rarity.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
