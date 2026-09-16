import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// RARIDADE DA MOLDURA — espelha exatamente BadgeConfig.levelRarity()
// Sistema revisado para 30 níveis (antes eram 100): 10 faixas, o
// dobro de antes, para que a moldura mude de forma visível a cada
// poucos níveis em vez de ficar longos trechos igual.
// ═══════════════════════════════════════════════════════════════════
enum FrameRarity {
  common,    // 1-3
  uncommon,  // 4-6
  rare,      // 7-9
  special,   // 10-12
  epic,      // 13-15
  heroic,    // 16-18
  legendary, // 19-21
  mythic,    // 22-24
  supreme,   // 25-27
  elite,     // 28-30
}

extension FrameRarityExt on FrameRarity {
  static FrameRarity fromLevel(int level) {
    if (level >= 28) return FrameRarity.elite;
    if (level >= 25) return FrameRarity.supreme;
    if (level >= 22) return FrameRarity.mythic;
    if (level >= 19) return FrameRarity.legendary;
    if (level >= 16) return FrameRarity.heroic;
    if (level >= 13) return FrameRarity.epic;
    if (level >= 10) return FrameRarity.special;
    if (level >= 7)  return FrameRarity.rare;
    if (level >= 4)  return FrameRarity.uncommon;
    return FrameRarity.common;
  }

  String get label {
    switch (this) {
      case FrameRarity.common:    return 'Comum';
      case FrameRarity.uncommon:  return 'Incomum';
      case FrameRarity.rare:      return 'Raro';
      case FrameRarity.special:   return 'Especial';
      case FrameRarity.epic:      return 'Épico';
      case FrameRarity.heroic:    return 'Heroico';
      case FrameRarity.legendary: return 'Lendário';
      case FrameRarity.mythic:    return 'Mítico';
      case FrameRarity.supreme:   return 'Supremo';
      case FrameRarity.elite:     return 'Horizonte Elite';
    }
  }

  /// Quantidade de partículas — cresce em praticamente todas as faixas,
  /// desde o início, sem saltos bruscos, culminando num enxame denso
  /// no topo (bem mais que o dobro do sistema anterior).
  int get particleCount {
    switch (this) {
      case FrameRarity.common:    return 0;
      case FrameRarity.uncommon:  return 4;
      case FrameRarity.rare:      return 7;
      case FrameRarity.special:   return 10;
      case FrameRarity.epic:      return 13;
      case FrameRarity.heroic:    return 17;
      case FrameRarity.legendary: return 21;
      case FrameRarity.mythic:    return 26;
      case FrameRarity.supreme:   return 32;
      case FrameRarity.elite:     return 40;
    }
  }

  bool get hasRotatingRing =>
      this != FrameRarity.common; // já aparece a partir de Incomum

  /// Segundo anel contra-rotativo — some visual extra nas faixas altas.
  bool get hasSecondRing =>
      this == FrameRarity.heroic ||
      this == FrameRarity.legendary ||
      this == FrameRarity.mythic ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  bool get hasPulse =>
      this == FrameRarity.epic ||
      this == FrameRarity.heroic ||
      this == FrameRarity.legendary ||
      this == FrameRarity.mythic ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  bool get hasCosmicHalo =>
      this == FrameRarity.legendary ||
      this == FrameRarity.mythic ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  bool get is360Aura =>
      this == FrameRarity.mythic ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  /// Faíscas cintilantes extras, só nas 3 faixas mais altas.
  bool get hasSparkles =>
      this == FrameRarity.mythic ||
      this == FrameRarity.supreme ||
      this == FrameRarity.elite;

  /// Brilho crescente gradualmente desde o nível 1 — cada faixa nova
  /// já é visivelmente mais luminosa que a anterior.
  double get glowIntensity {
    switch (this) {
      case FrameRarity.common:    return 0.26;
      case FrameRarity.uncommon:  return 0.36;
      case FrameRarity.rare:      return 0.46;
      case FrameRarity.special:   return 0.56;
      case FrameRarity.epic:      return 0.66;
      case FrameRarity.heroic:    return 0.75;
      case FrameRarity.legendary: return 0.83;
      case FrameRarity.mythic:    return 0.90;
      case FrameRarity.supreme:   return 0.96;
      case FrameRarity.elite:     return 1.0;
    }
  }

  /// Espessura do anel giratório — cresce junto com a raridade
  double get ringStrokeWidth {
    switch (this) {
      case FrameRarity.common:    return 0;
      case FrameRarity.uncommon:  return 1.5;
      case FrameRarity.rare:      return 1.8;
      case FrameRarity.special:   return 2.1;
      case FrameRarity.epic:      return 2.4;
      case FrameRarity.heroic:    return 2.7;
      case FrameRarity.legendary: return 3.0;
      case FrameRarity.mythic:    return 3.3;
      case FrameRarity.supreme:   return 3.6;
      case FrameRarity.elite:     return 4.0;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // MOLDURAS ESPECIAIS DESENHADAS (dragão de cristal / trono solar)
  // ═════════════════════════════════════════════════════════════════
  // Antes eram imagens (moldura_dragao_cristal.png / trono_solar.png).
  // Agora são 100% CustomPainter — sem dependência de assets — mas
  // continuam raras e visualmente distintas: são desenhadas por cima
  // de tudo, nas duas raridades mais altas.
  bool get hasCrystalDragonFrame => this == FrameRarity.mythic;
  bool get hasSolarThroneFrame => this == FrameRarity.elite;
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL — AVATAR COM MOLDURA ANIMADA
// ═══════════════════════════════════════════════════════════════════
class AvatarFrame extends StatefulWidget {
  final int level;
  final double size;
  final Widget child;
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
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
                              color: color.withOpacity(
                                  rarity.glowIntensity * _glowAnim.value),
                              blurRadius: 12 + (rarity.index * 3.5),
                              spreadRadius: 1 + (rarity.index * 0.6),
                            ),
                          ],
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
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

    if (rarity.hasSecondRing) {
      _paintSecondRing(canvas, center, ringRadius);
    }

    if (rarity.particleCount > 0) {
      _paintOrbitalParticles(canvas, center, ringRadius);
    }

    if (rarity.hasSparkles) {
      _paintSparkles(canvas, center, ringRadius);
    }

    if (rarity == FrameRarity.elite) {
      _paintEliteMark(canvas, center, ringRadius);
    }

    // ── Molduras especiais desenhadas (antes eram imagens PNG) ──────
    if (rarity.hasCrystalDragonFrame) {
      _paintCrystalDragonFrame(canvas, center, ringRadius);
    }
    if (rarity.hasSolarThroneFrame) {
      _paintSolarThroneFrame(canvas, center, ringRadius);
    }
  }

  // ── MOLDURA DRAGÃO DE CRISTAL (Mítico) ────────────────────────────
  // Recompensa rara: duas "cabeças de dragão" facetadas guardando o
  // avatar nas laterais, com cristais orbitando e respiro de energia
  // fria. Desenhada 100% em código — sem depender de nenhuma imagem.
  void _paintCrystalDragonFrame(Canvas canvas, Offset center, double radius) {
    final dragonRadius = radius + 20;

    // Névoa cristalina de fundo
    final mistPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.12 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: dragonRadius + 12));
    canvas.drawCircle(center, dragonRadius + 12, mistPaint);

    // Duas cabeças de dragão estilizadas (esquerda/direita), feitas de
    // triângulos facetados apontando para o avatar central.
    for (final side in [-1.0, 1.0]) {
      final baseAngle = side < 0 ? math.pi * 0.82 : math.pi * 0.18;
      final sway = math.sin(rotation * 2 * math.pi) * 0.05;
      final angle = baseAngle + sway * side;

      final headCenter = Offset(
        center.dx + math.cos(angle) * dragonRadius,
        center.dy - math.sin(angle) * dragonRadius * 0.7,
      );

      canvas.save();
      canvas.translate(headCenter.dx, headCenter.dy);
      canvas.rotate(-angle * side);

      final headPath = Path()
        ..moveTo(0, -9)
        ..lineTo(14 * side, 0)
        ..lineTo(6 * side, 6)
        ..lineTo(-6 * side, 10)
        ..lineTo(-10 * side, 0)
        ..close();

      final headPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.85 * glow),
            const Color(0xFF7C4DFF).withOpacity(0.85 * glow),
          ],
        ).createShader(const Rect.fromLTWH(-14, -9, 28, 19));
      canvas.drawPath(headPath, headPaint);

      final headOutline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(0.7 * glow);
      canvas.drawPath(headPath, headOutline);

      // "Olho" do dragão
      final eyePaint = Paint()..color = Colors.white.withOpacity(glow);
      canvas.drawCircle(Offset(2 * side, -1), 1.4, eyePaint);

      canvas.restore();
    }

    // Cristais pequenos orbitando entre as duas cabeças
    for (int i = 0; i < 6; i++) {
      final a = (i / 6) * 2 * math.pi + rotation * 2 * math.pi;
      final pos = Offset(
        center.dx + math.cos(a) * (dragonRadius + 6),
        center.dy + math.sin(a) * (dragonRadius + 6) * 0.6,
      );
      final crystalPaint = Paint()
        ..color = Color.lerp(
                const Color(0xFF00E5FF), const Color(0xFF7C4DFF), i / 6)!
            .withOpacity(0.7 * glow);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a);
      final crystalPath = Path()
        ..moveTo(0, -3.5)
        ..lineTo(2.2, 0)
        ..lineTo(0, 3.5)
        ..lineTo(-2.2, 0)
        ..close();
      canvas.drawPath(crystalPath, crystalPaint);
      canvas.restore();
    }
  }

  // ── MOLDURA TRONO SOLAR (Horizonte Elite) ─────────────────────────
  // Recompensa máxima: raios solares geométricos irradiando atrás do
  // avatar, como o encosto de um trono, com um arco duplo de energia
  // dourada circulando por cima. 100% código, sem imagem.
  void _paintSolarThroneFrame(Canvas canvas, Offset center, double radius) {
    final throneRadius = radius + 22;

    // Resplendor solar de fundo (glow amplo)
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withOpacity(0.22 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: throneRadius + 16));
    canvas.drawCircle(center, throneRadius + 16, haloPaint);

    // Raios triangulares alternando comprimento, como o encosto de um
    // trono solar — desenhados em leque atrás do avatar.
    const rayCount = 16;
    for (int i = 0; i < rayCount; i++) {
      final a = (i / rayCount) * 2 * math.pi + rotation * 0.3 * math.pi;
      final isLong = i.isEven;
      final len = isLong ? throneRadius + 16 : throneRadius + 8;
      final width = isLong ? 5.0 : 3.0;

      final dir = Offset(math.cos(a), math.sin(a));
      final base = center + dir * throneRadius * 0.92;
      final tip = center + dir * len;
      final normal = Offset(-dir.dy, dir.dx) * width;

      final rayPath = Path()
        ..moveTo(base.dx - normal.dx, base.dy - normal.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx + normal.dx, base.dy + normal.dy)
        ..close();

      final rayPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.85 * glow),
            const Color(0xFFFF6D00).withOpacity(0.15 * glow),
          ],
        ).createShader(Rect.fromPoints(base, tip));
      canvas.drawPath(rayPath, rayPaint);
    }

    // Arco duplo de energia dourada circulando por cima dos raios
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -rotation * 2.2 * math.pi,
        endAngle: -rotation * 2.2 * math.pi + math.pi * 1.1,
        colors: [
          Colors.transparent,
          const Color(0xFFFFF176).withOpacity(0.9 * glow),
          const Color(0xFFFFD700).withOpacity(0.9 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: throneRadius + 4));
    canvas.drawCircle(center, throneRadius + 4, arcPaint);

    // Pequeno brasão central no topo, marcando o "trono"
    final crestCenter = Offset(center.dx, center.dy - throneRadius - 4);
    final crestPaint = Paint()
      ..color = Colors.white.withOpacity(0.9 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final crestPath = Path()
      ..moveTo(crestCenter.dx, crestCenter.dy - 5)
      ..lineTo(crestCenter.dx + 4, crestCenter.dy + 3)
      ..lineTo(crestCenter.dx, crestCenter.dy + 1)
      ..lineTo(crestCenter.dx - 4, crestCenter.dy + 3)
      ..close();
    canvas.drawPath(crestPath, crestPaint);
  }

  // ── Aura dinâmica 360° (Mítico / Supremo / Elite) ────────────────
  void _paintAura360(Canvas canvas, Offset center, double radius) {
    final auraRadius = radius + 14;
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + (rarity.index - FrameRarity.mythic.index) * 1.2
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

  // ── Halo cósmico (Lendário / Mítico / Supremo / Elite) ───────────
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

    final starCount = 4 + (rarity.index - FrameRarity.legendary.index) * 2;
    final starPaint = Paint()..color = Colors.white.withOpacity(0.8 * glow);
    for (int i = 0; i < starCount; i++) {
      final angle = (i / starCount) * 2 * math.pi + rotation * math.pi;
      final dist = radius + 18 + (i % 2 == 0 ? 4 : -4);
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      canvas.drawCircle(pos, 1.4, starPaint);
    }
  }

  // ── Anel girando (a partir de Incomum) ───────────────────────────
  void _paintRotatingRing(Canvas canvas, Offset center, double radius) {
    final strokeW = rarity.ringStrokeWidth;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
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

    final tipAngle = rotation * 2 * math.pi + math.pi * 1.4;
    final tipPos = Offset(
      center.dx + math.cos(tipAngle) * radius,
      center.dy + math.sin(tipAngle) * radius,
    );
    final tipPaint = Paint()
      ..color = Colors.white.withOpacity(glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(tipPos, 2 + strokeW * 0.4, tipPaint);
  }

  // ── Segundo anel — gira em sentido contrário, um pouco mais externo
  // (a partir de Heroico) para dar profundidade extra à moldura ──────
  void _paintSecondRing(Canvas canvas, Offset center, double radius) {
    final outerRadius = radius + 7;
    final strokeW = rarity.ringStrokeWidth * 0.6;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: -rotation * 1.6 * math.pi,
        endAngle: -rotation * 1.6 * math.pi + math.pi * 0.9,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.5 * glow),
          gradient[1].withOpacity(0.7 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

    canvas.drawCircle(center, outerRadius, ringPaint);
  }

  // ── Partículas orbitais — presentes desde Incomum, crescem sempre,
  // agora com paleta variada (não só as 2 pontas do gradiente) ───────
  void _paintOrbitalParticles(Canvas canvas, Offset center, double radius) {
    final count = rarity.particleCount;
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final mid = Color.lerp(gradient[0], gradient[1], 0.5)!;
    final palette = [gradient[0], mid, gradient[1], Colors.white];

    for (int i = 0; i < count; i++) {
      final baseAngle = (i / count) * 2 * math.pi;
      final speedVariation = 1.0 + (i % 3) * 0.3;
      final angle = baseAngle + particleProgress * 2 * math.pi * speedVariation;

      final orbitRadius =
          radius + 4 + math.sin(particleProgress * 4 * math.pi + i) * 3;

      final pos = Offset(
        center.dx + math.cos(angle) * orbitRadius,
        center.dy + math.sin(angle) * orbitRadius * 0.92,
      );

      final particleSize = 1.2 + (rarity.index * 0.15);

      final pulse = (math.sin(particleProgress * 6 * math.pi + i * 2) + 1) / 2;
      final opacity = (0.4 + pulse * 0.6) * glow;

      particlePaint
        ..color = palette[i % palette.length].withOpacity(
            i % palette.length == 3 ? opacity * 0.85 : opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

      canvas.drawCircle(pos, particleSize, particlePaint);
    }
  }

  // ── Faíscas cintilantes — pequenos brilhos em posições fixas que
  // aparecem/somem rapidamente (Mítico, Supremo, Elite) ─────────────
  void _paintSparkles(Canvas canvas, Offset center, double radius) {
    final sparkleCount = 6 + (rarity.index - FrameRarity.mythic.index) * 3;
    final sparklePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < sparkleCount; i++) {
      // Posição fixa por índice (não gira), só a fase do brilho muda.
      final fixedAngle = (i * 2.399) % (2 * math.pi); // espiral áurea
      final dist = radius * (0.55 + 0.4 * ((i * 0.618) % 1.0));
      final pos = Offset(
        center.dx + math.cos(fixedAngle) * dist,
        center.dy + math.sin(fixedAngle) * dist,
      );

      final phase = (particleProgress * 3 + i * 0.37) % 1.0;
      final twinkle = (math.sin(phase * 2 * math.pi) + 1) / 2;
      if (twinkle < 0.55) continue; // pisca — só visível parte do tempo

      final opacity = ((twinkle - 0.55) / 0.45) * glow;
      sparklePaint
        ..color = Colors.white.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

      _drawStarShape(canvas, pos, 2.0 + twinkle * 1.5, sparklePaint);
    }
  }

  void _drawStarShape(Canvas canvas, Offset pos, double size, Paint paint) {
    final path = Path();
    path.moveTo(pos.dx, pos.dy - size);
    path.lineTo(pos.dx + size * 0.3, pos.dy - size * 0.3);
    path.lineTo(pos.dx + size, pos.dy);
    path.lineTo(pos.dx + size * 0.3, pos.dy + size * 0.3);
    path.lineTo(pos.dx, pos.dy + size);
    path.lineTo(pos.dx - size * 0.3, pos.dy + size * 0.3);
    path.lineTo(pos.dx - size, pos.dy);
    path.lineTo(pos.dx - size * 0.3, pos.dy - size * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  // ── Marca exclusiva Horizonte Elite ──────────────────────────────
  void _paintEliteMark(Canvas canvas, Offset center, double radius) {
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
// TAG DE RARIDADE
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