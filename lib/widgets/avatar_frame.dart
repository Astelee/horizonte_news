import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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
  // ── _rotationCtrl e _particleCtrl NÃO usam AnimationController comum.
  // Vários painters multiplicam `rotation`/`particleProgress` por
  // fatores fracionários (ex: rotation * 2π * 0.4) para dar velocidades
  // diferentes a cada camada. Com um AnimationController normal em
  // repeat(), o valor faz wrap de 1.0 → 0.0 a cada volta; como
  // fator_fracionário * 2π não é múltiplo de 2π, esse wrap produz um
  // salto de ângulo visível ("reinício" da animação) toda vez que o
  // controller completa um ciclo. Por isso usamos aqui um Ticker cru
  // que acumula o tempo decorrido sem limite (sem wrap): o valor só
  // cresce, então rotation*k é sempre contínuo, para qualquer k.
  late Ticker _rotationTicker;
  late Ticker _particleTicker;
  double _rotationValue = 0.0; // cresce sem limite, período de 8s
  double _particleValue = 0.0; // cresce sem limite, período de 6s

  late AnimationController _glowCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;

  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _entryScaleAnim;
  late Animation<double> _entryFadeAnim;

  @override
  void initState() {
    super.initState();

    _rotationTicker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _rotationValue = elapsed.inMicroseconds / 8000000.0; // 8s por volta
      });
    })..start();

    _particleTicker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _particleValue = elapsed.inMicroseconds / 6000000.0; // 6s por volta
      });
    })..start();

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
    _rotationTicker.dispose();
    _particleTicker.dispose();
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = FrameRarityExt.fromLevel(widget.level);
    final gradient = BadgeConfig.levelGradient(widget.level);
    final color = BadgeConfig.levelColor(widget.level);

    return AnimatedBuilder(
      // _rotationValue/_particleValue já disparam rebuild via setState
      // nos próprios tickers; aqui só precisamos escutar os
      // AnimationControllers que restaram (glow, pulse, entrada).
      animation: Listenable.merge([_glowCtrl, _pulseCtrl, _entryCtrl]),
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
                    painter: _buildPainterForRarity(
                      level: widget.level,
                      rarity: rarity,
                      color: color,
                      gradient: gradient,
                      // Valores acumulados sem wrap (ver initState) —
                      // continuam crescendo, então `rotation * k` nunca
                      // salta, para qualquer k fracionário usado pelos
                      // painters.
                      rotation: _rotationValue,
                      glow: _glowAnim.value,
                      particleProgress: _particleValue,
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
// FACTORY — escolhe o painter certo para a faixa do nível
// ═══════════════════════════════════════════════════════════════════
// Cada faixa de raridade tem sua própria classe CustomPainter, com
// composição gráfica exclusiva (não é o mesmo anel genérico com cor
// trocada). Dentro de cada faixa, os 3 níveis também têm desenhos
// distintos entre si — o painter recebe `level` e usa `levelInBand`
// (0, 1 ou 2) para adicionar/mudar elementos geométricos, não só
// intensidade de cor. As 3 propriedades animadas (rotation/glow/
// particleProgress) continuam vindo dos AnimationControllers já
// existentes em _AvatarFrameState — nenhum painter cria controller
// próprio.
CustomPainter _buildPainterForRarity({
  required int level,
  required FrameRarity rarity,
  required Color color,
  required List<Color> gradient,
  required double rotation,
  required double glow,
  required double particleProgress,
  required double avatarSize,
}) {
  switch (rarity) {
    case FrameRarity.common:
      return _CommonFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.uncommon:
      return _UncommonFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.rare:
      return _RareFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.special:
      return _SpecialFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.epic:
      return _EpicFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.heroic:
      return _HeroicFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.legendary:
      return _LegendaryFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.mythic:
      return _MythicFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.supreme:
      return _SupremeFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
    case FrameRarity.elite:
      return _EliteFramePainter(
          level: level, rarity: rarity, color: color, gradient: gradient,
          rotation: rotation, glow: glow,
          particleProgress: particleProgress, avatarSize: avatarSize);
  }
}

// ═══════════════════════════════════════════════════════════════════
// BASE COMPARTILHADA — carrega os campos comuns, calcula `levelInBand`
// (posição do nível dentro da faixa: 0, 1 ou 2) e faz o shouldRepaint
// padrão. Cada faixa estende isso e implementa paint() do zero, usando
// `levelInBand` para variar a FORMA entre os 3 níveis, não só a cor.
// ═══════════════════════════════════════════════════════════════════
abstract class _BaseFramePainter extends CustomPainter {
  final int level;
  final FrameRarity rarity;
  final Color color;
  final List<Color> gradient;
  final double rotation;
  final double glow;
  final double particleProgress;
  final double avatarSize;

  _BaseFramePainter({
    required this.level,
    required this.rarity,
    required this.color,
    required this.gradient,
    required this.rotation,
    required this.glow,
    required this.particleProgress,
    required this.avatarSize,
  });

  /// Posição do nível dentro da faixa de 3: 0 (mais baixo), 1 (meio),
  /// 2 (mais alto). Usado para acrescentar elementos geométricos
  /// extras nível a nível, não apenas mudar cor/intensidade.
  int get levelInBand => (level - 1) % 3;

  @override
  bool shouldRepaint(covariant _BaseFramePainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.rotation != rotation ||
      oldDelegate.glow != glow ||
      oldDelegate.particleProgress != particleProgress;
}

// ═══════════════════════════════════════════════════════════════════
// 1 · COMUM (níveis 1-3) — traços tracejados que ganham corpo a cada
// nível: nível 1 só os tracinhos; nível 2 ganha um arco fino; nível 3
// ganha um segundo conjunto de tracinhos internos + leve brilho.
// ═══════════════════════════════════════════════════════════════════
class _CommonFramePainter extends _BaseFramePainter {
  _CommonFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = avatarSize / 2 + 8;
    final band = levelInBand;
    final tickCount = 8 + band * 2;

    final tickPaint = Paint()
      ..color = color.withOpacity(0.32 + 0.12 * glow + band * 0.06)
      ..strokeWidth = 1.3 + band * 0.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < tickCount; i++) {
      final a = (i / tickCount) * 2 * math.pi;
      final inner = Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius);
      final outer = Offset(center.dx + math.cos(a) * (radius + 4 + band), center.dy + math.sin(a) * (radius + 4 + band));
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Nível 2 (band 1): arco fino parcial aparece, marcando o início
    // de movimento na moldura.
    if (band >= 1) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(0.4 * glow);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        rotation * 2 * math.pi, math.pi * 0.6, false, arcPaint,
      );
    }

    // Nível 3 (band 2): segundo anel de tracinhos internos, mais
    // curtos, alternados com os externos — já antecipa a textura de
    // "faceta" que a próxima faixa vai desenvolver.
    if (band >= 2) {
      final innerTickPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 * glow)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      const innerCount = 8;
      for (int i = 0; i < innerCount; i++) {
        final a = (i / innerCount) * 2 * math.pi + math.pi / innerCount;
        final inner = Offset(center.dx + math.cos(a) * (radius - 5), center.dy + math.sin(a) * (radius - 5));
        final outer = Offset(center.dx + math.cos(a) * (radius - 2), center.dy + math.sin(a) * (radius - 2));
        canvas.drawLine(inner, outer, innerTickPaint);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2 · INCOMUM (níveis 4-6) — moldura poligonal facetada, que ganha
// lados a cada nível: nível 4 é um pentágono; nível 5 vira hexágono
// com vértices duplos; nível 6 ganha um segundo polígono interno
// contra-rotativo.
// ═══════════════════════════════════════════════════════════════════
class _UncommonFramePainter extends _BaseFramePainter {
  _UncommonFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  Path _polygon(Offset center, double r, int sides, double angleOffset) {
    final path = Path();
    for (int i = 0; i <= sides; i++) {
      final a = (i / sides) * 2 * math.pi + angleOffset;
      final p = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = avatarSize / 2 + 10;
    final band = levelInBand;
    final sides = 5 + band; // 5, 6, 7 lados
    final breathe = math.sin(particleProgress * 2 * math.pi) * 1.6;
    final r = baseRadius + breathe;
    final angleOffset = rotation * 2 * math.pi * 0.25;

    final path = _polygon(center, r, sides, angleOffset);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color.withOpacity(0.25 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: gradient)
          .createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(path, strokePaint);

    final vertexPaint = Paint()..color = Colors.white.withOpacity(0.7 * glow);
    for (int i = 0; i < sides; i++) {
      final a = (i / sides) * 2 * math.pi + angleOffset;
      final p = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      canvas.drawCircle(p, band >= 1 ? 1.6 : 1.3, vertexPaint);
      // Nível 5+ (band 1): vértice duplo, uma segunda marca logo atrás.
      if (band >= 1) {
        final p2 = Offset(center.dx + math.cos(a) * (r - 4), center.dy + math.sin(a) * (r - 4));
        canvas.drawCircle(p2, 0.9, vertexPaint);
      }
    }

    // Nível 6 (band 2): segundo polígono interno, contra-rotativo,
    // criando um efeito de "engrenagem dupla".
    if (band >= 2) {
      final innerPath = _polygon(center, r - 9, sides - 1, -rotation * 2 * math.pi * 0.4);
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withOpacity(0.35 * glow);
      canvas.drawPath(innerPath, innerPaint);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3 · RARO (níveis 7-9) — losangos orbitando em trilhas elípticas.
// Nível 7: 1 losango. Nível 8: 2 losangos cruzados. Nível 9: 3
// losangos formando um pequeno triângulo orbital.
// ═══════════════════════════════════════════════════════════════════
class _RareFramePainter extends _BaseFramePainter {
  _RareFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  void _drawDiamond(Canvas canvas, Offset pos, double s, Paint paint) {
    final path = Path()
      ..moveTo(pos.dx, pos.dy - s)
      ..lineTo(pos.dx + s * 0.65, pos.dy)
      ..lineTo(pos.dx, pos.dy + s)
      ..lineTo(pos.dx - s * 0.65, pos.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rx = avatarSize / 2 + 12;
    final band = levelInBand;
    final gemCount = 1 + band; // 1, 2, 3

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withOpacity(0.22 * glow);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: rx * 1.1), basePaint);
    canvas.restore();

    for (int i = 0; i < gemCount; i++) {
      final tilt = (i - (gemCount - 1) / 2) * 0.35;
      final speed = (i.isEven ? 1.0 : -1.3) * (1.0 + i * 0.15);
      final angle = rotation * 2 * math.pi * speed + i * (2 * math.pi / gemCount);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(tilt);
      final pos = Offset(math.cos(angle) * rx, math.sin(angle) * rx * 0.55);

      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = gradient[i % gradient.length].withOpacity(0.3 * glow);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: rx * 1.1), trailPaint);

      final gemPaint = Paint()
        ..shader = LinearGradient(colors: [gradient[0], gradient[1]])
            .createShader(Rect.fromCircle(center: pos, radius: 6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
      _drawDiamond(canvas, pos, 4.2 + rarity.index * 0.2, gemPaint);

      final corePaint = Paint()..color = Colors.white.withOpacity(0.8 * glow);
      canvas.drawCircle(pos, 1.2, corePaint);

      canvas.restore();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4 · ESPECIAL (níveis 10-12) — anel segmentado tipo "engrenagem de
// luz". Nível 10: 8 segmentos. Nível 11: 10 segmentos + dentes.
// Nível 12: 12 segmentos + halo de núcleo mais forte.
// ═══════════════════════════════════════════════════════════════════
class _SpecialFramePainter extends _BaseFramePainter {
  _SpecialFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = avatarSize / 2 + 11;
    final band = levelInBand;
    final segments = 8 + band * 2; // 8, 10, 12
    const gapFraction = 0.35;
    final segAngle = (2 * math.pi / segments) * (1 - gapFraction);

    final segPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + band * 0.3
      ..strokeCap = StrokeCap.butt
      ..shader = LinearGradient(colors: gradient)
          .createShader(Rect.fromCircle(center: center, radius: radius));

    for (int i = 0; i < segments; i++) {
      final start = (i / segments) * 2 * math.pi + rotation * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, segAngle, false, segPaint);
    }

    // Dentes radiais aparecem a partir do nível 11 (band >= 1).
    if (band >= 1) {
      final teethPaint = Paint()
        ..color = Colors.white.withOpacity(0.55 * glow)
        ..strokeWidth = 1.6;
      for (int i = 0; i < segments; i++) {
        final start = (i / segments) * 2 * math.pi + rotation * 2 * math.pi;
        for (final off in [0.0, segAngle]) {
          final a = start + off;
          final p1 = Offset(center.dx + math.cos(a) * (radius - 2), center.dy + math.sin(a) * (radius - 2));
          final p2 = Offset(center.dx + math.cos(a) * (radius + 3), center.dy + math.sin(a) * (radius + 3));
          canvas.drawLine(p1, p2, teethPaint);
        }
      }
    }

    // Núcleo de brilho — mais forte no nível 12 (band 2).
    final corePaint = Paint()
      ..shader = RadialGradient(colors: [
        color.withOpacity((band >= 2 ? 0.28 : 0.16) * glow), Colors.transparent,
      ]).createShader(Rect.fromCircle(center: center, radius: radius + 6));
    canvas.drawCircle(center, radius + 6, corePaint);

    // Nível 12: segundo anel fino, bem interno, girando ao contrário.
    if (band >= 2) {
      final innerRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(0.4 * glow);
      canvas.drawCircle(center, radius - 6, innerRingPaint);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 5 · ÉPICO (níveis 13-15) — espiral(is) áurea pulsante. Nível 13:
// 1 braço. Nível 14: 2 braços (dupla espiral). Nível 15: 3 braços +
// anel-guia mais definido.
// ═══════════════════════════════════════════════════════════════════
class _EpicFramePainter extends _BaseFramePainter {
  _EpicFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = avatarSize / 2 + 16;
    final minR = avatarSize / 2 + 4;
    final band = levelInBand;
    final arms = 1 + band; // 1, 2, 3
    const dotsPerArm = 9;

    for (int arm = 0; arm < arms; arm++) {
      final armOffset = arm * (2 * math.pi / arms);
      for (int i = 0; i < dotsPerArm; i++) {
        final t = i / (dotsPerArm - 1);
        const spiralTurns = 1.3;
        final a = armOffset + rotation * 2 * math.pi + t * spiralTurns * 2 * math.pi;
        final r = minR + (maxR - minR) * t;
        final pos = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);

        final dotSize = 3.2 - t * 2.0;
        final pulse = (math.sin(particleProgress * 2 * math.pi + i * 0.6) + 1) / 2;
        final opacity = (0.35 + 0.65 * pulse) * glow;

        final dotPaint = Paint()
          ..color = Color.lerp(gradient[0], gradient[1], t)!.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
        canvas.drawCircle(pos, dotSize, dotPaint);
      }
    }

    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = band >= 2 ? 1.4 : 1.0
      ..color = Colors.white.withOpacity((band >= 2 ? 0.4 : 0.25) * glow);
    canvas.drawCircle(center, minR - 2, linkPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════
// 6 · HEROICO (níveis 16-18) — escudo de facetas triangulares. Nível
// 16: coroa de 10 pontas. Nível 17: 12 pontas + anel contra-rotativo.
// Nível 18: 14 pontas + segundo anel interno cravejado.
// ═══════════════════════════════════════════════════════════════════
class _HeroicFramePainter extends _BaseFramePainter {
  _HeroicFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = avatarSize / 2 + 10;
    final band = levelInBand;
    final teeth = 10 + band * 2; // 10, 12, 14

    // Anel externo contra-rotativo a partir do nível 17 (band >= 1).
    if (band >= 1) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = SweepGradient(
          startAngle: -rotation * 1.6 * math.pi,
          endAngle: -rotation * 1.6 * math.pi + math.pi * 1.2,
          colors: [Colors.transparent, gradient[1].withOpacity(0.7 * glow), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 9));
      canvas.drawCircle(center, radius + 9, ringPaint);
    }

    final crownPath = Path();
    for (int i = 0; i <= teeth; i++) {
      final a = (i / teeth) * 2 * math.pi + rotation * 2 * math.pi * 0.4;
      final isOut = i.isEven;
      final r = radius + (isOut ? 6.0 : 0.0);
      final p = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        crownPath.moveTo(p.dx, p.dy);
      } else {
        crownPath.lineTo(p.dx, p.dy);
      }
    }
    crownPath.close();

    final crownGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withOpacity(0.3 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(crownPath, crownGlow);

    final crownPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: gradient)
          .createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(crownPath, crownPaint);

    final tipPaint = Paint()..color = Colors.white.withOpacity(0.75 * glow);
    for (int i = 0; i < teeth; i += 2) {
      final a = (i / teeth) * 2 * math.pi + rotation * 2 * math.pi * 0.4;
      final p = Offset(center.dx + math.cos(a) * (radius + 6), center.dy + math.sin(a) * (radius + 6));
      canvas.drawCircle(p, 1.4, tipPaint);
    }

    // Nível 18 (band 2): segundo anel interno "cravejado" com pontos
    // pequenos entre o avatar e a coroa.
    if (band >= 2) {
      final studPaint = Paint()..color = Colors.white.withOpacity(0.5 * glow);
      const studs = 8;
      for (int i = 0; i < studs; i++) {
        final a = (i / studs) * 2 * math.pi - rotation * 2 * math.pi * 0.3;
        final p = Offset(center.dx + math.cos(a) * (radius - 5), center.dy + math.sin(a) * (radius - 5));
        canvas.drawCircle(p, 1.0, studPaint);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 7 · LENDÁRIO (níveis 19-21) — constelação de estrelas conectadas.
// Nível 19: 6 estrelas. Nível 20: 8 estrelas. Nível 21: 10 estrelas +
// halo mais amplo.
// ═══════════════════════════════════════════════════════════════════
class _LegendaryFramePainter extends _BaseFramePainter {
  _LegendaryFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = avatarSize / 2 + 13;
    final band = levelInBand;
    final starCount = 6 + band * 2; // 6, 8, 10

    final haloPaint = Paint()
      ..shader = RadialGradient(colors: [
        gradient[0].withOpacity((0.14 + band * 0.02) * glow), Colors.transparent,
      ]).createShader(Rect.fromCircle(center: center, radius: radius + 14 + band * 2));
    canvas.drawCircle(center, radius + 14 + band * 2, haloPaint);

    final points = <Offset>[];
    for (int i = 0; i < starCount; i++) {
      final a = (i * 2.399) % (2 * math.pi) + rotation * 2 * math.pi * 0.15;
      final r = radius * (0.7 + 0.3 * ((i * 0.618) % 1.0));
      points.add(Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r));
    }

    final linkPaint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < starCount; i++) {
      final next = (i + 1) % starCount;
      final phase = ((particleProgress * starCount - i) % starCount);
      final lit = phase >= 0 && phase < 1.0;
      linkPaint.color = Colors.white.withOpacity((lit ? 0.55 : 0.12) * glow);
      canvas.drawLine(points[i], points[next], linkPaint);
    }

    // Nível 21 (band 2): linhas extras cruzando o centro, ligando
    // estrelas opostas — a constelação "fecha" visualmente.
    if (band >= 2) {
      final crossPaint = Paint()
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withOpacity(0.18 * glow);
      for (int i = 0; i < starCount; i += 2) {
        final opp = (i + starCount ~/ 2) % starCount;
        canvas.drawLine(points[i], points[opp], crossPaint);
      }
    }

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < starCount; i++) {
      final twinkle = (math.sin(particleProgress * 4 * math.pi + i * 1.1) + 1) / 2;
      starPaint
        ..color = Color.lerp(gradient[0], gradient[1], i / starCount)!
            .withOpacity((0.5 + 0.5 * twinkle) * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
      canvas.drawCircle(points[i], 1.8 + twinkle * 1.2, starPaint);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 8 · MÍTICO (níveis 22-24) — Dragão de Cristal + véu de fumaça
// facetada. Nível 22: dragão + véu de 1 camada. Nível 23: véu de 2
// camadas. Nível 24: véu de 2 camadas + arco de energia fria extra.
// ═══════════════════════════════════════════════════════════════════
class _MythicFramePainter extends _BaseFramePainter {
  _MythicFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = avatarSize / 2 + 10;
    final band = levelInBand;

    _paintCrystalVeil(canvas, center, radius, band);
    _paintCrystalDragonFrame(canvas, center, radius);

    // Nível 24 (band 2): arco de energia fria adicional, contornando
    // por fora do véu — reforça a sensação de topo da faixa.
    if (band >= 2) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: rotation * 1.8 * math.pi,
          endAngle: rotation * 1.8 * math.pi + math.pi * 0.9,
          colors: [
            Colors.transparent,
            const Color(0xFF00E5FF).withOpacity(0.8 * glow),
            const Color(0xFF7C4DFF).withOpacity(0.8 * glow),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 30));
      canvas.drawCircle(center, radius + 30, arcPaint);
    }
  }

  void _paintCrystalVeil(Canvas canvas, Offset center, double radius, int band) {
    final layerCount = band >= 1 ? 2 : 1;
    for (int layer = 0; layer < layerCount; layer++) {
      final count = 5 + layer * 3;
      final r = radius + 4 + layer * 9.0;
      final speed = layer == 0 ? 1.0 : -0.6;
      for (int i = 0; i < count; i++) {
        final a = (i / count) * 2 * math.pi + rotation * 2 * math.pi * speed;
        final pos = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r * 0.85);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a);
        final s = 2.6 - layer * 0.4;
        final shardPath = Path()
          ..moveTo(0, -s)
          ..lineTo(s * 0.6, 0)
          ..lineTo(0, s)
          ..lineTo(-s * 0.6, 0)
          ..close();
        final shardPaint = Paint()
          ..color = const Color(0xFF00E5FF).withOpacity((0.25 + layer * 0.1) * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
        canvas.drawPath(shardPath, shardPaint);
        canvas.restore();
      }
    }
  }

  void _paintCrystalDragonFrame(Canvas canvas, Offset center, double radius) {
    final dragonRadius = radius + 20;

    final mistPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.12 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: dragonRadius + 12));
    canvas.drawCircle(center, dragonRadius + 12, mistPaint);

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

      final eyePaint = Paint()..color = Colors.white.withOpacity(glow);
      canvas.drawCircle(Offset(2 * side, -1), 1.4, eyePaint);

      canvas.restore();
    }

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
}

// ═══════════════════════════════════════════════════════════════════
// 9 · SUPREMO (níveis 25-27) — anéis poligonais concêntricos girando
// em velocidades diferentes. Nível 25: 2 camadas (triângulo +
// quadrado). Nível 26: 3 camadas (+ octógono). Nível 27: 3 camadas +
// núcleo pulsante mais forte e vértices duplos no anel externo.
// ═══════════════════════════════════════════════════════════════════
class _SupremeFramePainter extends _BaseFramePainter {
  _SupremeFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  Path _polygon(Offset center, double r, int sides, double angleOffset) {
    final path = Path();
    for (int i = 0; i <= sides; i++) {
      final a = (i / sides) * 2 * math.pi + angleOffset;
      final p = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = avatarSize / 2 + 9;
    final band = levelInBand;

    final allLayers = [
      (sides: 3, r: base + 2, speed: 1.0, width: 1.6),
      (sides: 4, r: base + 9, speed: -0.7, width: 1.8),
      (sides: 8, r: base + 17, speed: 0.45, width: 1.4),
    ];
    final layers = band >= 1 ? allLayers : allLayers.sublist(0, 2);

    for (int i = 0; i < layers.length; i++) {
      final l = layers[i];
      final path = _polygon(center, l.r, l.sides, rotation * 2 * math.pi * l.speed);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.width + 2.5
        ..color = Color.lerp(gradient[0], gradient[1], i / layers.length)!
            .withOpacity(0.22 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, glowPaint);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.width
        ..strokeJoin = StrokeJoin.round
        ..shader = SweepGradient(
          startAngle: rotation * 2 * math.pi * l.speed,
          endAngle: rotation * 2 * math.pi * l.speed + 2 * math.pi,
          colors: [
            Colors.transparent,
            gradient[0].withOpacity(0.85 * glow),
            gradient[1].withOpacity(0.85 * glow),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: l.r));
      canvas.drawPath(path, strokePaint);
    }

    final pulse = (math.sin(particleProgress * 2 * math.pi) + 1) / 2;
    final corePaint = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withOpacity((band >= 2 ? 0.16 : 0.10) * glow * (0.5 + pulse * 0.5)),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: center, radius: base - 2));
    canvas.drawCircle(center, base - 2, corePaint);

    final outer = layers.last;
    final vertexPaint = Paint()..color = Colors.white.withOpacity(0.75 * glow);
    for (int i = 0; i < outer.sides; i++) {
      final a = (i / outer.sides) * 2 * math.pi + rotation * 2 * math.pi * outer.speed;
      final p = Offset(center.dx + math.cos(a) * outer.r, center.dy + math.sin(a) * outer.r);
      canvas.drawCircle(p, 1.3, vertexPaint);
      // Nível 27 (band 2): vértices duplos no anel externo.
      if (band >= 2) {
        final p2 = Offset(center.dx + math.cos(a) * (outer.r + 4), center.dy + math.sin(a) * (outer.r + 4));
        canvas.drawCircle(p2, 0.8, vertexPaint);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 10 · HORIZONTE ELITE (níveis 28-30) — Trono Solar. Nível 28: coroa
// facetada + raios solares (a versão "sol" plena começa aqui). Nível
// 29: + marcadores cardeais. Nível 30 — ÁPICE ABSOLUTO: sol pleno
// completo — coroa dupla, raios mais longos e densos, arco duplo de
// energia dourada e núcleo radiante central, o desenho mais elaborado
// de toda a progressão.
// ═══════════════════════════════════════════════════════════════════
class _EliteFramePainter extends _BaseFramePainter {
  _EliteFramePainter({
    required super.level, required super.rarity, required super.color,
    required super.gradient, required super.rotation, required super.glow,
    required super.particleProgress, required super.avatarSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = avatarSize / 2 + 10;
    final band = levelInBand; // 0=28, 1=29, 2=30

    _paintSolarThroneFrame(canvas, center, radius, band);
    _paintFacetedCrown(canvas, center, radius, band);
    if (band >= 1) _paintCardinalMarks(canvas, center, radius);
    if (band >= 2) _paintSunCore(canvas, center, radius);
  }

  // Coroa de facetas douradas — dobra de densidade no nível 30 (sol
  // pleno), formando uma coroa dupla.
  void _paintFacetedCrown(Canvas canvas, Offset center, double radius, int band) {
    final facets = band >= 2 ? 20 : 14;
    for (int i = 0; i < facets; i++) {
      final a = (i / facets) * 2 * math.pi - rotation * 2 * math.pi * 0.5;
      final r = radius + 3;
      final pos = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a);
      final s = 2.4;
      final facetPath = Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.7, s * 0.4)
        ..lineTo(-s * 0.7, s * 0.4)
        ..close();
      final facetPaint = Paint()
        ..shader = LinearGradient(colors: [
          const Color(0xFFFFD700), const Color(0xFFFFF176),
        ]).createShader(Rect.fromCircle(center: Offset.zero, radius: s))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
      canvas.drawPath(facetPath, facetPaint);
      canvas.restore();
    }

    // Nível 30: segunda camada de facetas, um pouco mais externa e
    // mais espaçada — a "coroa dupla" do sol pleno.
    if (band >= 2) {
      const outerFacets = 10;
      for (int i = 0; i < outerFacets; i++) {
        final a = (i / outerFacets) * 2 * math.pi + rotation * 2 * math.pi * 0.35;
        final r = radius + 34;
        final pos = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + math.pi);
        const s = 3.2;
        final facetPath = Path()
          ..moveTo(0, -s)
          ..lineTo(s * 0.7, s * 0.4)
          ..lineTo(-s * 0.7, s * 0.4)
          ..close();
        final facetPaint = Paint()
          ..color = const Color(0xFFFFF176).withOpacity(0.75 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);
        canvas.drawPath(facetPath, facetPaint);
        canvas.restore();
      }
    }
  }

  void _paintCardinalMarks(Canvas canvas, Offset center, double radius) {
    final pulse = (math.sin(particleProgress * 2 * math.pi) + 1) / 2;
    final markPaint = Paint()
      ..color = Colors.white.withOpacity((0.6 + 0.4 * pulse) * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    for (int i = 0; i < 4; i++) {
      final a = (i / 4) * 2 * math.pi;
      final pos = Offset(center.dx + math.cos(a) * (radius + 26), center.dy + math.sin(a) * (radius + 26));
      const d = 3.6;
      final path = Path()
        ..moveTo(pos.dx, pos.dy - d)
        ..lineTo(pos.dx + d, pos.dy)
        ..lineTo(pos.dx, pos.dy + d)
        ..lineTo(pos.dx - d, pos.dy)
        ..close();
      canvas.drawPath(path, markPaint);
    }
  }

  // Núcleo radiante — exclusivo do nível 30. Um brilho central intenso
  // por trás do avatar, como o próprio disco solar, culminando a
  // progressão inteira de 30 níveis.
  void _paintSunCore(Canvas canvas, Offset center, double radius) {
    final pulse = (math.sin(particleProgress * 2 * math.pi) + 1) / 2;
    final corePaint = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFF9C4).withOpacity(0.35 * glow * (0.6 + pulse * 0.4)),
        const Color(0xFFFFD700).withOpacity(0.18 * glow),
        Colors.transparent,
      ], stops: const [0.0, 0.5, 1.0])
          .createShader(Rect.fromCircle(center: center, radius: radius + 6));
    canvas.drawCircle(center, radius + 6, corePaint);

    // Segundo arco dourado, contra-rotativo em relação ao arco do
    // trono solar, reforçando a leitura de "sol pleno".
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: rotation * 1.7 * math.pi,
        endAngle: rotation * 1.7 * math.pi + math.pi * 1.3,
        colors: [
          Colors.transparent,
          const Color(0xFFFFF9C4).withOpacity(0.85 * glow),
          const Color(0xFFFFD700).withOpacity(0.85 * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 38));
    canvas.drawCircle(center, radius + 38, arcPaint);
  }

  void _paintSolarThroneFrame(Canvas canvas, Offset center, double radius, int band) {
    final throneRadius = radius + 22;
    final isFullSun = band >= 2;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withOpacity((isFullSun ? 0.30 : 0.22) * glow),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: throneRadius + 16));
    canvas.drawCircle(center, throneRadius + 16, haloPaint);

    final rayCount = isFullSun ? 24 : 16;
    for (int i = 0; i < rayCount; i++) {
      final a = (i / rayCount) * 2 * math.pi + rotation * 0.3 * math.pi;
      final isLong = i.isEven;
      final len = isLong ? throneRadius + (isFullSun ? 22 : 16) : throneRadius + (isFullSun ? 12 : 8);
      final width = isLong ? (isFullSun ? 6.0 : 5.0) : (isFullSun ? 3.6 : 3.0);

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