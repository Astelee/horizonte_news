import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import '../config/level_badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// ARTE DOS SELOS DE NÍVEL — 100% CustomPainter, sem imagens
// ═══════════════════════════════════════════════════════════════════
// Substitui o antigo AvatarFrame (moldura ao redor do avatar inteiro).
// Cada nível vira um selo pequeno, fechado e autocontido — desenhado
// dentro de um círculo próprio, sem depender do tamanho do avatar —
// para flutuar sobre o canto superior esquerdo do avatar, no mesmo
// espírito estrutural do CheckinRewardBadge (canto inferior direito).
//
// Mesma filosofia de checkin_reward_painters.dart: um único Ticker
// cru por selo (tempo acumulado, sem wrap — evita saltos de ângulo
// quando multiplicado por fatores fracionários de π) e tudo
// proporcional a [size], nunca em pixels fixos, para funcionar tanto
// em ~90px (preview) quanto em ~14px (avatar minúsculo).
// ═══════════════════════════════════════════════════════════════════

/// Único ponto de entrada: dado um nível (1-30), desenha o selo.
/// [locked] mostra a silhueta apagada. [animate] = false congela num
/// quadro bonito (listas longas / avatares muito pequenos).
class LevelBadgeArt extends StatefulWidget {
  final int level;
  final double size;
  final bool locked;
  final bool animate;

  const LevelBadgeArt({
    Key? key,
    required this.level,
    this.size = 28,
    this.locked = false,
    this.animate = true,
  }) : super(key: key);

  @override
  State<LevelBadgeArt> createState() => _LevelBadgeArtState();
}

class _LevelBadgeArtState extends State<LevelBadgeArt>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0.0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _t = elapsed.inMicroseconds / 6000000.0; // 6s por "volta"
      });
    });
    if (widget.animate && !widget.locked) {
      _running = true;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant LevelBadgeArt old) {
    super.didUpdateWidget(old);
    final shouldRun = widget.animate && !widget.locked;
    if (shouldRun && !_running) {
      _running = true;
      _ticker.start();
    } else if (!shouldRun && _running) {
      _running = false;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = LevelBadgeConfig.defFor(widget.level);
    final art = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _LevelBadgePainter(_t, def),
      ),
    );

    if (!widget.locked) {
      return SizedBox(width: widget.size, height: widget.size, child: art);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.12, 0.12, 0.12, 0, 0,
          0.12, 0.12, 0.12, 0, 0,
          0.12, 0.12, 0.12, 0, 0,
          0, 0, 0, 0.55, 0,
        ]),
        child: art,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// UTILITÁRIOS DE DESENHO COMPARTILHADOS
// ═══════════════════════════════════════════════════════════════════

void _glow(Canvas c, Offset center, double radius, Color color, double a) {
  final p = Paint()
    ..color = color.withOpacity(a.clamp(0.0, 1.0))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5);
  c.drawCircle(center, radius, p);
}

double _rnd(int seed) {
  final x = math.sin(seed * 12.9898) * 43758.5453;
  return x - x.floorToDouble();
}

/// Fundo circular padrão do selo: disco escuro + anel de contorno na
/// cor de destaque + halo — a "base" comum de todos os níveis, para
/// que o selo pareça uma família consistente antes da arte central.
void _badgeBase(Canvas canvas, Offset c, double r, LevelBadgeDef def,
    double glow) {
  _glow(canvas, c, r * 1.55, def.accentColor, def.rarity.glowIntensity * 0.5 * glow);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF1A1A1A),
        const Color(0xFF0A0A0A),
      ]).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  canvas.drawCircle(
    c,
    r * 0.94,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..shader = LinearGradient(colors: def.gradient)
          .createShader(Rect.fromCircle(center: c, radius: r * 0.94)),
  );
}

/// Anel giratório fino — usado a partir de "Incomum".
void _rotatingRing(Canvas canvas, Offset c, double r, double rotation,
    Color color, double strokeWidth, double glow) {
  final arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..shader = SweepGradient(
      startAngle: rotation * 2 * math.pi,
      endAngle: rotation * 2 * math.pi + math.pi * 1.3,
      colors: [
        Colors.transparent,
        color.withOpacity(0.85 * glow),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(center: c, radius: r));
  canvas.drawCircle(c, r, arcPaint);
}

/// Partículas orbitais simples em volta do selo — cresce em contagem
/// conforme a raridade.
void _orbitParticles(Canvas canvas, Offset c, double r, double t, int count,
    Color color, double glow) {
  for (int i = 0; i < count; i++) {
    final a = (i / count) * 2 * math.pi + t * 2 * math.pi * 0.5;
    final wob = 0.9 + 0.1 * math.sin(t * math.pi * 3 + i * 1.9);
    final pr = r * 1.18 * wob;
    final pos = Offset(c.dx + math.cos(a) * pr, c.dy + math.sin(a) * pr);
    canvas.drawCircle(
      pos,
      r * 0.045,
      Paint()
        ..color = color.withOpacity(0.8 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
  }
}

/// Faíscas cintilantes — só nas 3 faixas mais altas.
void _sparkles(Canvas canvas, Offset c, double r, double t, Color color) {
  for (int i = 0; i < 6; i++) {
    final phase = (t * 0.7 + _rnd(i * 9 + 4)) % 1.0;
    final a = _rnd(i * 5 + 1) * 2 * math.pi;
    final dist = r * (0.55 + 0.5 * _rnd(i * 3 + 2));
    final pos = Offset(c.dx + math.cos(a) * dist, c.dy + math.sin(a) * dist);
    final fade = math.sin(phase * math.pi);
    canvas.drawCircle(
      pos,
      r * 0.05 * fade,
      Paint()..color = Colors.white.withOpacity(0.9 * fade),
    );
  }
}

Path _star(Offset c, double outerR, double innerR, int points, double rot) {
  final path = Path();
  for (int i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outerR : innerR;
    final a = (i / (points * 2)) * 2 * math.pi + rot;
    final p = Offset(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

Path _polygon(Offset c, double r, int sides, double rot) {
  final path = Path();
  for (int i = 0; i < sides; i++) {
    final a = (i / sides) * 2 * math.pi + rot;
    final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

// ═══════════════════════════════════════════════════════════════════
// DESPACHANTE — escolhe o desenho central conforme o arquétipo
// ═══════════════════════════════════════════════════════════════════
class _LevelBadgePainter extends CustomPainter {
  final double t;
  final LevelBadgeDef def;
  _LevelBadgePainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width * 0.42;
    final rarity = def.rarity;
    final glow = 0.6 + 0.4 * rarity.glowIntensity;
    final rotation = t * 0.12; // fração de volta por "tick" de 6s

    _badgeBase(canvas, c, r, def, glow);

    if (rarity.hasRotatingRing) {
      _rotatingRing(canvas, c, r * 1.08, rotation, def.accentColor,
          r * (0.05 + 0.02 * rarity.index), rarity.glowIntensity);
    }
    if (rarity.hasSecondRing) {
      _rotatingRing(canvas, c, r * 1.22, -rotation * 1.4, Colors.white,
          r * 0.03, rarity.glowIntensity * 0.7);
    }
    if (rarity.particleCount > 0) {
      _orbitParticles(canvas, c, r, t, rarity.particleCount, def.accentColor,
          rarity.glowIntensity);
    }
    if (rarity.hasSparkles) {
      _sparkles(canvas, c, r * 1.3, t, def.accentColor);
    }

    _paintArchetype(canvas, c, r * 0.66, t, def);
  }

  void _paintArchetype(
      Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
    switch (def.archetype) {
      case LevelBadgeArchetype.eye:
        _paintEye(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.openBook:
        _paintOpenBook(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.compassStar:
        _paintCompassStar(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.bookmarkShield:
        _paintBookmarkShield(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.windRose:
        _paintWindRose(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.emberSpark:
        _paintEmberSpark(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.feather:
        _paintFeather(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.brainFacets:
        _paintBrainFacets(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.starBurst:
        _paintStarBurst(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.trophyCrest:
        _paintTrophyCrest(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.laurelMedal:
        _paintLaurelMedal(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.ascendArrow:
        _paintAscendArrow(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.scrollSeal:
        _paintScrollSeal(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.signalWaves:
        _paintSignalWaves(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.quillInk:
        _paintQuillInk(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.megaphoneRing:
        _paintMegaphoneRing(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.shieldEmblem:
        _paintShieldEmblem(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.hourglassOrbit:
        _paintHourglassOrbit(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.infinityLoop:
        _paintInfinityLoop(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.sentinelEye:
        _paintSentinelEye(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.wandSparkle:
        _paintWandSparkle(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.gemCut:
        _paintGemCut(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.meteorTrail:
        _paintMeteorTrail(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.royalCrownSmall:
        _paintRoyalCrownSmall(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.crackedCore:
        _paintCrackedCore(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.phoenixFlame:
        _paintPhoenixFlame(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.flameCrown:
        _paintFlameCrown(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.radiantSun:
        _paintRadiantSun(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.boltCore:
        _paintBoltCore(canvas, c, u, t, def);
        break;
      case LevelBadgeArchetype.supremeCrown:
        _paintSupremeCrown(canvas, c, u, t, def);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LevelBadgePainter old) =>
      old.t != t || old.def.level != def.level;
}

// ═══════════════════════════════════════════════════════════════════
// COMUM (1-3) — formas simples, sem brilho extra
// ═══════════════════════════════════════════════════════════════════

// 1) Visitante — olho aberto, simples, atento.
void _paintEye(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final openness = 0.75 + 0.25 * math.sin(t * math.pi * 0.6);
  final eyeRect = Rect.fromCenter(center: c, width: u * 1.5, height: u * 0.85 * openness);
  final eyePath = Path()
    ..moveTo(eyeRect.left, eyeRect.center.dy)
    ..quadraticBezierTo(c.dx, eyeRect.top, eyeRect.right, eyeRect.center.dy)
    ..quadraticBezierTo(c.dx, eyeRect.bottom, eyeRect.left, eyeRect.center.dy)
    ..close();
  canvas.drawPath(
    eyePath,
    Paint()..shader = LinearGradient(colors: def.gradient).createShader(eyeRect),
  );
  canvas.drawCircle(c, u * 0.26, Paint()..color = const Color(0xFF0A0A0A));
  canvas.drawCircle(c, u * 0.13, Paint()..color = Colors.white.withOpacity(0.9));
}

// 2) Leitor Iniciante — livro aberto com páginas simétricas.
void _paintOpenBook(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final flip = 0.9 + 0.1 * math.sin(t * math.pi * 0.8);
  final left = Path()
    ..moveTo(c.dx, c.dy - u * 0.55)
    ..lineTo(c.dx - u * 0.7 * flip, c.dy - u * 0.32)
    ..lineTo(c.dx - u * 0.7 * flip, c.dy + u * 0.45)
    ..lineTo(c.dx, c.dy + u * 0.62)
    ..close();
  final right = Path()
    ..moveTo(c.dx, c.dy - u * 0.55)
    ..lineTo(c.dx + u * 0.7 * flip, c.dy - u * 0.32)
    ..lineTo(c.dx + u * 0.7 * flip, c.dy + u * 0.45)
    ..lineTo(c.dx, c.dy + u * 0.62)
    ..close();
  canvas.drawPath(
    left,
    Paint()..shader = LinearGradient(colors: def.gradient)
        .createShader(Rect.fromCircle(center: c, radius: u * 0.8)),
  );
  canvas.drawPath(
    right,
    Paint()..shader = LinearGradient(colors: def.gradient.reversed.toList())
        .createShader(Rect.fromCircle(center: c, radius: u * 0.8)),
  );
  canvas.drawLine(
    Offset(c.dx, c.dy - u * 0.55),
    Offset(c.dx, c.dy + u * 0.62),
    Paint()
      ..color = const Color(0xFF0A0A0A)
      ..strokeWidth = u * 0.05,
  );
}

// 3) Leitor Curioso — bússola com estrela de 4 pontas central.
void _paintCompassStar(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final rot = t * 0.3;
  canvas.drawCircle(
    c,
    u * 0.78,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.05
      ..color = def.accentColor.withOpacity(0.7),
  );
  final star = _star(c, u * 0.62, u * 0.22, 4, rot);
  canvas.drawPath(
    star,
    Paint()..shader = LinearGradient(colors: def.gradient).createShader(star.getBounds()),
  );
  canvas.drawCircle(c, u * 0.12, Paint()..color = Colors.white.withOpacity(0.85));
}

// ═══════════════════════════════════════════════════════════════════
// INCOMUM (4-6) — anel giratório fino aparece a partir daqui
// ═══════════════════════════════════════════════════════════════════

// 4) Acompanhante — marcador/bookmark com recorte em escudo.
void _paintBookmarkShield(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final sway = math.sin(t * math.pi * 0.7) * u * 0.03;
  final path = Path()
    ..moveTo(c.dx - u * 0.42, c.dy - u * 0.65)
    ..lineTo(c.dx + u * 0.42, c.dy - u * 0.65)
    ..lineTo(c.dx + u * 0.42 + sway, c.dy + u * 0.55)
    ..lineTo(c.dx, c.dy + u * 0.2)
    ..lineTo(c.dx - u * 0.42 + sway, c.dy + u * 0.55)
    ..close();
  canvas.drawPath(
    path,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: def.gradient,
    ).createShader(path.getBounds()),
  );
  canvas.drawCircle(
    Offset(c.dx, c.dy - u * 0.15),
    u * 0.14,
    Paint()..color = Colors.white.withOpacity(0.85),
  );
}

// 5) Seguidor Assíduo — rosa dos ventos de 8 pontas.
void _paintWindRose(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final rot = t * 0.25;
  for (int i = 0; i < 8; i++) {
    final a = (i / 8) * 2 * math.pi + rot;
    final isLong = i.isEven;
    final len = isLong ? u * 0.72 : u * 0.42;
    final w = isLong ? u * 0.13 : u * 0.08;
    final dir = Offset(math.cos(a), math.sin(a));
    final tip = c + dir * len;
    final normal = Offset(-dir.dy, dir.dx) * w;
    final base1 = c + normal;
    final base2 = c - normal;
    final petal = Path()
      ..moveTo(base1.dx, base1.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(base2.dx, base2.dy)
      ..close();
    canvas.drawPath(
      petal,
      Paint()..color = (isLong ? def.gradient.last : def.gradient.first)
          .withOpacity(isLong ? 0.95 : 0.6),
    );
  }
  canvas.drawCircle(c, u * 0.15, Paint()..color = Colors.white.withOpacity(0.9));
}

// 6) Entusiasta — faísca/chama pequena com brilho pulsante.
void _paintEmberSpark(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final flick = math.sin(t * math.pi * 5);
  final tipX = c.dx + flick * u * 0.12;
  final path = Path()
    ..moveTo(c.dx, c.dy + u * 0.55)
    ..cubicTo(c.dx - u * 0.5, c.dy + u * 0.1, c.dx - u * 0.4, c.dy - u * 0.4,
        tipX, c.dy - u * 0.68)
    ..cubicTo(c.dx + u * 0.4, c.dy - u * 0.4, c.dx + u * 0.5, c.dy + u * 0.1,
        c.dx, c.dy + u * 0.55)
    ..close();
  canvas.drawPath(
    path,
    Paint()..shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [def.gradient.first, def.gradient.last, Colors.white],
    ).createShader(path.getBounds()),
  );
}

// ═══════════════════════════════════════════════════════════════════
// RARO (7-9) — mais partículas orbitais, cores mais vivas
// ═══════════════════════════════════════════════════════════════════

// 7) Explorador — pena estilizada, inclinada.
void _paintFeather(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-0.45 + math.sin(t * math.pi * 0.5) * 0.04);
  final quill = Path()
    ..moveTo(0, u * 0.75)
    ..quadraticBezierTo(u * 0.35, u * 0.1, 0, -u * 0.8)
    ..quadraticBezierTo(-u * 0.35, u * 0.1, 0, u * 0.75)
    ..close();
  canvas.drawPath(
    quill,
    Paint()..shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: def.gradient,
    ).createShader(quill.getBounds()),
  );
  final shaft = Paint()
    ..color = Colors.white.withOpacity(0.75)
    ..strokeWidth = u * 0.045;
  canvas.drawLine(Offset.zero, Offset(0, -u * 0.8), shaft);
  for (int i = 1; i <= 4; i++) {
    final y = -u * 0.8 + (u * 1.5) * (i / 5);
    canvas.drawLine(Offset(0, y), Offset(u * 0.22 * (1 - i / 6), y + u * 0.12),
        Paint()..color = Colors.white.withOpacity(0.35)..strokeWidth = u * 0.02);
  }
  canvas.restore();
}

// 8) Investigador — cérebro facetado em polígonos (raciocínio).
void _paintBrainFacets(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final pulse = 0.9 + 0.1 * math.sin(t * math.pi * 0.8);
  final hexes = <Offset>[
    Offset(-u * 0.32, -u * 0.15),
    Offset(u * 0.32, -u * 0.15),
    Offset(-u * 0.42, u * 0.3),
    Offset(u * 0.42, u * 0.3),
    Offset(0, u * 0.5),
    Offset(0, -u * 0.4),
  ];
  for (int i = 0; i < hexes.length; i++) {
    final poly = _polygon(c + hexes[i] * pulse, u * 0.32, 6, t * 0.2 + i);
    canvas.drawPath(
      poly,
      Paint()..color = (i.isEven ? def.gradient.first : def.gradient.last)
          .withOpacity(0.55),
    );
  }
  canvas.drawCircle(c, u * 0.2, Paint()..color = Colors.white.withOpacity(0.85));
}

// 9) Super Leitor — explosão de estrela de 6 pontas com raios.
void _paintStarBurst(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final rot = t * 0.35;
  for (int i = 0; i < 6; i++) {
    final a = (i / 6) * 2 * math.pi + rot;
    final p1 = c + Offset(math.cos(a), math.sin(a)) * u * 0.15;
    final p2 = c + Offset(math.cos(a), math.sin(a)) * u * 0.85;
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = u * 0.07
        ..color = def.accentColor.withOpacity(0.85),
    );
  }
  final star = _star(c, u * 0.5, u * 0.22, 6, -rot * 1.3);
  canvas.drawPath(
    star,
    Paint()..shader = LinearGradient(colors: def.gradient).createShader(star.getBounds()),
  );
}

// ═══════════════════════════════════════════════════════════════════
// ESPECIAL (10-12) — glow dourado mais intenso, primeiro "troféu"
// ═══════════════════════════════════════════════════════════════════

// 10) Fã da Informação — taça/troféu dourado.
void _paintTrophyCrest(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final shine = 0.5 + 0.5 * math.sin(t * math.pi * 0.9);
  final cup = Path()
    ..moveTo(c.dx - u * 0.42, c.dy - u * 0.55)
    ..quadraticBezierTo(c.dx - u * 0.5, c.dy - u * 0.05, c.dx - u * 0.14, c.dy + u * 0.05)
    ..lineTo(c.dx - u * 0.14, c.dy + u * 0.3)
    ..lineTo(c.dx - u * 0.32, c.dy + u * 0.42)
    ..lineTo(c.dx + u * 0.32, c.dy + u * 0.42)
    ..lineTo(c.dx + u * 0.14, c.dy + u * 0.3)
    ..lineTo(c.dx + u * 0.14, c.dy + u * 0.05)
    ..quadraticBezierTo(c.dx + u * 0.5, c.dy - u * 0.05, c.dx + u * 0.42, c.dy - u * 0.55)
    ..close();
  canvas.drawPath(
    cup,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: def.gradient,
    ).createShader(cup.getBounds()),
  );
  canvas.drawCircle(
    Offset(c.dx - u * 0.12, c.dy - u * 0.25),
    u * 0.06,
    Paint()..color = Colors.white.withOpacity(0.5 + 0.4 * shine),
  );
}

// 11) Membro Destaque — medalha com coroa de louros lateral.
void _paintLaurelMedal(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final sway = math.sin(t * math.pi * 0.6) * 0.05;
  for (final side in [-1.0, 1.0]) {
    for (int i = 0; i < 4; i++) {
      final a = math.pi * 0.5 + side * (0.35 + i * 0.28) + sway * side;
      final base = c + Offset(math.cos(a), math.sin(a)) * u * 0.35;
      final tip = c + Offset(math.cos(a), math.sin(a)) * u * (0.75 + i * 0.05);
      canvas.drawOval(
        Rect.fromPoints(
          base + Offset(-u * 0.05 * side, 0),
          tip + Offset(u * 0.05 * side, 0),
        ),
        Paint()..color = def.gradient.last.withOpacity(0.8),
      );
    }
  }
  canvas.drawCircle(
    c,
    u * 0.4,
    Paint()..shader = LinearGradient(colors: def.gradient)
        .createShader(Rect.fromCircle(center: c, radius: u * 0.4)),
  );
  canvas.drawCircle(c, u * 0.2, Paint()..color = Colors.white.withOpacity(0.85));
}

// 12) Analista Júnior — seta ascendente com trilha de gráfico.
void _paintAscendArrow(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final rise = math.sin(t * math.pi * 0.6) * u * 0.04;
  final path = Path()
    ..moveTo(c.dx - u * 0.55, c.dy + u * 0.35)
    ..lineTo(c.dx - u * 0.15, c.dy - u * 0.05)
    ..lineTo(c.dx + u * 0.1, c.dy + u * 0.2)
    ..lineTo(c.dx + u * 0.55, c.dy - u * 0.4 - rise);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(colors: def.gradient).createShader(path.getBounds()),
  );
  final head = Path()
    ..moveTo(c.dx + u * 0.55, c.dy - u * 0.4 - rise)
    ..lineTo(c.dx + u * 0.3, c.dy - u * 0.38 - rise)
    ..lineTo(c.dx + u * 0.52, c.dy - u * 0.16 - rise)
    ..close();
  canvas.drawPath(head, Paint()..color = Colors.white.withOpacity(0.9));
}

// ═══════════════════════════════════════════════════════════════════
// ÉPICO (13-15) — segundo anel contra-rotativo, mais partículas
// ═══════════════════════════════════════════════════════════════════

// 13) Analista — pergaminho selado com fita cruzada.
void _paintScrollSeal(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final unroll = 0.92 + 0.08 * math.sin(t * math.pi * 0.5);
  final scroll = RRect.fromRectAndRadius(
    Rect.fromCenter(center: c, width: u * 1.3 * unroll, height: u * 0.9),
    Radius.circular(u * 0.14),
  );
  canvas.drawRRect(
    scroll,
    Paint()..shader = LinearGradient(colors: def.gradient).createShader(scroll.outerRect),
  );
  canvas.drawCircle(c, u * 0.42, Paint()..color = const Color(0xFF0A0A0A).withOpacity(0.55));
  final seal = _star(c, u * 0.3, u * 0.16, 5, t * 0.2);
  canvas.drawPath(seal, Paint()..color = Colors.white.withOpacity(0.9));
}

// 14) Correspondente — ondas de sinal irradiando de um ponto.
void _paintSignalWaves(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  for (int i = 0; i < 3; i++) {
    final phase = (t * 0.5 + i / 3) % 1.0;
    final r = u * 0.25 + phase * u * 0.6;
    final fade = 1 - phase;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.06
        ..color = def.accentColor.withOpacity(0.7 * fade),
    );
  }
  canvas.drawCircle(
    c,
    u * 0.22,
    Paint()..shader = LinearGradient(colors: def.gradient)
        .createShader(Rect.fromCircle(center: c, radius: u * 0.22)),
  );
}

// 15) Cronista — pena de pato escrevendo, gota de tinta.
void _paintQuillInk(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-0.5);
  final quill = Path()
    ..moveTo(0, u * 0.7)
    ..quadraticBezierTo(u * 0.4, 0, -u * 0.05, -u * 0.75)
    ..quadraticBezierTo(-u * 0.28, 0, 0, u * 0.7)
    ..close();
  canvas.drawPath(
    quill,
    Paint()..shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: def.gradient,
    ).createShader(quill.getBounds()),
  );
  canvas.restore();
  final drop = 0.5 + 0.5 * math.sin(t * math.pi * 1.2);
  canvas.drawCircle(
    Offset(c.dx - u * 0.25, c.dy + u * 0.5 + drop * u * 0.08),
    u * 0.09,
    Paint()..color = def.accentColor.withOpacity(0.85),
  );
}

// ═══════════════════════════════════════════════════════════════════
// HEROICO (16-18) — pulso visível no glow, mais presença
// ═══════════════════════════════════════════════════════════════════

double _heroicPulse(double t) => 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * math.pi * 1.5));

// 16) Editor Amador — megafone com ondas de alcance.
void _paintMegaphoneRing(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final pulse = _heroicPulse(t);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-0.15);
  final body = Path()
    ..moveTo(-u * 0.5, -u * 0.18)
    ..lineTo(-u * 0.15, -u * 0.18)
    ..lineTo(u * 0.45, -u * 0.55)
    ..lineTo(u * 0.45, u * 0.55)
    ..lineTo(-u * 0.15, u * 0.18)
    ..lineTo(-u * 0.5, u * 0.18)
    ..close();
  canvas.drawPath(
    body,
    Paint()..shader = LinearGradient(colors: def.gradient).createShader(body.getBounds()),
  );
  canvas.restore();
  for (int i = 0; i < 3; i++) {
    final r = u * (0.65 + i * 0.15) * pulse;
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(u * 0.35, 0), radius: r),
      -0.5,
      1.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.05
        ..strokeCap = StrokeCap.round
        ..color = def.accentColor.withOpacity(0.7 * (1 - i * 0.25)),
    );
  }
}

// 17) Guardião das Notícias — escudo com fenda central luminosa.
void _paintShieldEmblem(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final pulse = _heroicPulse(t);
  final shield = Path()
    ..moveTo(c.dx, c.dy - u * 0.65)
    ..lineTo(c.dx + u * 0.5, c.dy - u * 0.4)
    ..lineTo(c.dx + u * 0.5, c.dy + u * 0.1)
    ..quadraticBezierTo(c.dx + u * 0.5, c.dy + u * 0.55, c.dx, c.dy + u * 0.75)
    ..quadraticBezierTo(c.dx - u * 0.5, c.dy + u * 0.55, c.dx - u * 0.5, c.dy + u * 0.1)
    ..lineTo(c.dx - u * 0.5, c.dy - u * 0.4)
    ..close();
  canvas.drawPath(
    shield,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: def.gradient,
    ).createShader(shield.getBounds()),
  );
  canvas.drawLine(
    Offset(c.dx, c.dy - u * 0.45),
    Offset(c.dx, c.dy + u * 0.5),
    Paint()
      ..color = Colors.white.withOpacity(0.6 * pulse)
      ..strokeWidth = u * 0.07,
  );
}

// 18) Vanguarda — ampulheta orbitada por um anel de tempo.
void _paintHourglassOrbit(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final flow = (t * 0.4) % 1.0;
  final glass = Path()
    ..moveTo(c.dx - u * 0.38, c.dy - u * 0.62)
    ..lineTo(c.dx + u * 0.38, c.dy - u * 0.62)
    ..lineTo(c.dx + u * 0.08, c.dy)
    ..lineTo(c.dx + u * 0.38, c.dy + u * 0.62)
    ..lineTo(c.dx - u * 0.38, c.dy + u * 0.62)
    ..lineTo(c.dx - u * 0.08, c.dy)
    ..close();
  canvas.drawPath(
    glass,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.08
      ..shader = LinearGradient(colors: def.gradient).createShader(glass.getBounds()),
  );
  final sandY = c.dy - u * 0.5 + flow * u;
  canvas.drawCircle(
    Offset(c.dx, sandY.clamp(c.dy - u * 0.5, c.dy + u * 0.5)),
    u * 0.09,
    Paint()..color = def.accentColor.withOpacity(0.9),
  );
}

// ═══════════════════════════════════════════════════════════════════
// LENDÁRIO (19-21) — halo cósmico com mini-constelação de fundo
// ═══════════════════════════════════════════════════════════════════

void _constellation(Canvas canvas, Offset c, double u, double t, Color color) {
  for (int i = 0; i < 5; i++) {
    final a = (i / 5) * 2 * math.pi + t * 0.15;
    final r = u * (0.95 + 0.1 * _rnd(i * 3));
    final pos = c + Offset(math.cos(a), math.sin(a)) * r;
    final tw = 0.5 + 0.5 * math.sin(t * math.pi * 2 + i * 1.3);
    canvas.drawCircle(pos, u * 0.035 * tw, Paint()..color = color.withOpacity(0.8 * tw));
  }
}

// 19) Mestre da Informação — laço do infinito duplo.
void _paintInfinityLoop(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _constellation(canvas, c, u, t, def.accentColor);
  final rot = t * 0.3;
  final path = Path();
  for (double a = 0; a <= 2 * math.pi; a += 0.05) {
    final scale = math.sin(a);
    final x = c.dx + u * 0.55 * math.sin(a * 2 + rot) ;
    final y = c.dy + u * 0.28 * scale;
    if (a == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.13
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: def.gradient).createShader(path.getBounds()),
  );
}

// 20) Sentinela — olho vigilante dentro de um losango.
void _paintSentinelEye(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _constellation(canvas, c, u, t, def.accentColor);
  final diamond = _polygon(c, u * 0.75, 4, math.pi / 4);
  canvas.drawPath(
    diamond,
    Paint()..shader = LinearGradient(colors: def.gradient).createShader(diamond.getBounds()),
  );
  final openness = 0.7 + 0.3 * math.sin(t * math.pi * 0.5);
  canvas.drawOval(
    Rect.fromCenter(center: c, width: u * 0.75, height: u * 0.4 * openness),
    Paint()..color = const Color(0xFF0A0A0A),
  );
  canvas.drawCircle(c, u * 0.12, Paint()..color = Colors.white.withOpacity(0.9));
}

// 21) Visionário — varinha com faísca de energia na ponta.
void _paintWandSparkle(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _constellation(canvas, c, u, t, def.accentColor);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-0.6);
  canvas.drawLine(
    Offset(0, u * 0.7),
    Offset(0, -u * 0.4),
    Paint()
      ..strokeWidth = u * 0.09
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: def.gradient)
          .createShader(Rect.fromPoints(Offset(0, u * 0.7), Offset(0, -u * 0.4))),
  );
  canvas.restore();
  final twinkle = 0.6 + 0.4 * math.sin(t * math.pi * 2.5);
  final tip = Offset(c.dx + u * 0.4 * math.sin(0.6), c.dy - u * 0.4 * math.cos(0.6));
  final star = _star(tip, u * 0.32 * twinkle, u * 0.12, 4, t * 0.5);
  canvas.drawPath(star, Paint()..color = Colors.white.withOpacity(0.9));
  canvas.drawPath(star, Paint()..color = def.accentColor.withOpacity(0.4)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.06));
}

// ═══════════════════════════════════════════════════════════════════
// MÍTICO (22-24) — aura 360°, facetas cristalinas, mais partículas
// ═══════════════════════════════════════════════════════════════════

void _cosmicAura(Canvas canvas, Offset c, double u, double t, Color color) {
  final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 0.8);
  _glow(canvas, c, u * 1.5, color, 0.18 + 0.1 * pulse);
}

// 22) Oráculo — cristal facetado multicolor.
void _paintGemCut(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _cosmicAura(canvas, c, u, t, def.accentColor);
  final rot = t * 0.2;
  final gem = Path()
    ..moveTo(c.dx, c.dy - u * 0.8)
    ..lineTo(c.dx + u * 0.55, c.dy - u * 0.15)
    ..lineTo(c.dx + u * 0.32, c.dy + u * 0.7)
    ..lineTo(c.dx - u * 0.32, c.dy + u * 0.7)
    ..lineTo(c.dx - u * 0.55, c.dy - u * 0.15)
    ..close();
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(math.sin(rot) * 0.06);
  canvas.translate(-c.dx, -c.dy);
  canvas.drawPath(
    gem,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, ...def.gradient],
    ).createShader(gem.getBounds()),
  );
  canvas.drawLine(Offset(c.dx, c.dy - u * 0.8), Offset(c.dx, c.dy + u * 0.7),
      Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = u * 0.02);
  canvas.drawLine(Offset(c.dx - u * 0.55, c.dy - u * 0.15), Offset(c.dx + u * 0.55, c.dy - u * 0.15),
      Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = u * 0.02);
  canvas.restore();
}

// 23) Fenômeno — meteoro com rasto cintilante.
void _paintMeteorTrail(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _cosmicAura(canvas, c, u, t, def.accentColor);
  final rot = -0.7;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rot);
  final trail = Path()
    ..moveTo(-u * 0.75, u * 0.1)
    ..quadraticBezierTo(0, u * 0.28, u * 0.45, 0)
    ..quadraticBezierTo(0, -u * 0.05, -u * 0.75, -u * 0.12)
    ..close();
  canvas.drawPath(
    trail,
    Paint()..shader = LinearGradient(colors: [Colors.transparent, ...def.gradient])
        .createShader(trail.getBounds()),
  );
  canvas.drawCircle(Offset(u * 0.45, 0), u * 0.22,
      Paint()..shader = RadialGradient(colors: [Colors.white, def.gradient.last])
          .createShader(Rect.fromCircle(center: Offset(u * 0.45, 0), radius: u * 0.22)));
  canvas.restore();
  for (int i = 0; i < 3; i++) {
    final phase = (t * 0.6 + i / 3) % 1.0;
    canvas.drawCircle(
      c + Offset(math.cos(rot) * u * 0.5, math.sin(rot) * u * 0.5) * (1 - phase),
      u * 0.05 * (1 - phase),
      Paint()..color = Colors.white.withOpacity(0.7 * (1 - phase)),
    );
  }
}

// 24) Lendário Absoluto — coroa pequena sobre facho de luz vertical.
void _paintRoyalCrownSmall(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _cosmicAura(canvas, c, u, t, def.accentColor);
  final beamPulse = 0.6 + 0.4 * math.sin(t * math.pi * 1.1);
  canvas.drawRect(
    Rect.fromCenter(center: c, width: u * 0.14, height: u * 1.6),
    Paint()
      ..color = def.accentColor.withOpacity(0.35 * beamPulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.08),
  );
  final crown = Path()
    ..moveTo(c.dx - u * 0.5, c.dy + u * 0.35)
    ..lineTo(c.dx - u * 0.52, c.dy - u * 0.05)
    ..lineTo(c.dx - u * 0.24, c.dy + u * 0.12)
    ..lineTo(c.dx, c.dy - u * 0.4)
    ..lineTo(c.dx + u * 0.24, c.dy + u * 0.12)
    ..lineTo(c.dx + u * 0.52, c.dy - u * 0.05)
    ..lineTo(c.dx + u * 0.5, c.dy + u * 0.35)
    ..close();
  canvas.drawPath(
    crown,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: def.gradient,
    ).createShader(crown.getBounds()),
  );
  canvas.drawCircle(Offset(c.dx, c.dy - u * 0.42), u * 0.07,
      Paint()..color = Colors.white.withOpacity(0.9));
}

// ═══════════════════════════════════════════════════════════════════
// SUPREMO (25-27) — núcleo fissurado incandescente, marca exclusiva
// ═══════════════════════════════════════════════════════════════════

void _supremeCore(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 1.4);
  _glow(canvas, c, u * 1.1, def.accentColor, 0.35 + 0.2 * pulse);
}

// 25) Mítico — núcleo esférico com fissuras de luz.
void _paintCrackedCore(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _supremeCore(canvas, c, u, t, def);
  canvas.drawCircle(
    c,
    u * 0.68,
    Paint()..shader = RadialGradient(colors: [
      const Color(0xFF1A0A00),
      const Color(0xFF0A0A0A),
    ]).createShader(Rect.fromCircle(center: c, radius: u * 0.68)),
  );
  final crackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = u * 0.05
    ..strokeCap = StrokeCap.round
    ..shader = LinearGradient(colors: def.gradient)
        .createShader(Rect.fromCircle(center: c, radius: u * 0.68));
  final rot = t * 0.15;
  for (int i = 0; i < 5; i++) {
    final a = (i / 5) * 2 * math.pi + rot;
    final mid = c + Offset(math.cos(a), math.sin(a)) * u * 0.35;
    final tip = c + Offset(math.cos(a + 0.3), math.sin(a + 0.3)) * u * 0.65;
    canvas.drawLine(c, mid, crackPaint);
    canvas.drawLine(mid, tip, crackPaint);
  }
  final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 1.4);
  canvas.drawCircle(c, u * 0.16 * (0.9 + 0.1 * pulse),
      Paint()..color = Colors.white.withOpacity(0.9));
}

// 26) Ícone do Horizonte — fênix estilizada em pleno voo.
void _paintPhoenixFlame(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _supremeCore(canvas, c, u, t, def);
  final flap = math.sin(t * math.pi * 1.6);
  for (final side in [-1.0, 1.0]) {
    final wing = Path()
      ..moveTo(c.dx, c.dy - u * 0.1)
      ..quadraticBezierTo(
        c.dx + side * u * 0.55,
        c.dy - u * 0.5 - flap * side * u * 0.08,
        c.dx + side * u * 0.85,
        c.dy - u * 0.05,
      )
      ..quadraticBezierTo(
        c.dx + side * u * 0.5,
        c.dy + u * 0.12,
        c.dx,
        c.dy + u * 0.1,
      )
      ..close();
    canvas.drawPath(
      wing,
      Paint()..shader = LinearGradient(colors: def.gradient)
          .createShader(wing.getBounds()),
    );
  }
  final body = Path()
    ..moveTo(c.dx, c.dy - u * 0.55)
    ..quadraticBezierTo(c.dx + u * 0.14, c.dy, c.dx, c.dy + u * 0.62)
    ..quadraticBezierTo(c.dx - u * 0.14, c.dy, c.dx, c.dy - u * 0.55)
    ..close();
  canvas.drawPath(
    body,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, def.gradient.last],
    ).createShader(body.getBounds()),
  );
}

// 27) Chama Suprema — coroa de fogo com pontas trêmulas.
void _paintFlameCrown(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _supremeCore(canvas, c, u, t, def);
  for (int i = 0; i < 5; i++) {
    final baseX = c.dx + (i - 2) * u * 0.28;
    final flick = math.sin(t * math.pi * 3 + i * 1.4);
    final h = u * (0.55 + 0.15 * (i == 2 ? 1 : 0));
    final tipX = baseX + flick * u * 0.06;
    final flame = Path()
      ..moveTo(baseX - u * 0.12, c.dy + u * 0.4)
      ..cubicTo(baseX - u * 0.16, c.dy + u * 0.1, baseX - u * 0.1, c.dy - h * 0.4,
          tipX, c.dy - h)
      ..cubicTo(baseX + u * 0.1, c.dy - h * 0.4, baseX + u * 0.16, c.dy + u * 0.1,
          baseX + u * 0.12, c.dy + u * 0.4)
      ..close();
    canvas.drawPath(
      flame,
      Paint()..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: i == 2 ? [def.gradient.first, def.gradient.last, Colors.white] : def.gradient,
      ).createShader(flame.getBounds()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HORIZONTE ELITE (28-30) — máximo de brilho, partículas e prestígio
// ═══════════════════════════════════════════════════════════════════

void _eliteAura(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 1.2);
  _glow(canvas, c, u * 1.7, def.accentColor, 0.32 + 0.18 * pulse);
  _glow(canvas, c, u * 1.1, Colors.white, 0.12 + 0.08 * pulse);
}

// 28) Elite Flamejante — disco solar com raios longos e curtos.
void _paintRadiantSun(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _eliteAura(canvas, c, u, t, def);
  final rot = t * 0.25;
  void rays(int n, double inner, double outer, double rotation, double w, Color col) {
    for (int i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi + rotation;
      final wob = 0.85 + 0.25 * math.sin(t * math.pi * 4 + i * 1.7);
      final p1 = c + Offset(math.cos(a), math.sin(a)) * inner;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (inner + (outer - inner) * wob);
      canvas.drawLine(p1, p2, Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w
        ..color = col);
    }
  }
  rays(12, u * 0.5, u * 1.15, rot, u * 0.06, def.gradient.last.withOpacity(0.9));
  rays(12, u * 0.48, u * 0.85, -rot * 1.3 + 0.25, u * 0.035, Colors.white.withOpacity(0.7));
  canvas.drawCircle(
    c,
    u * 0.42,
    Paint()..shader = RadialGradient(colors: [
      Colors.white,
      def.gradient.first,
      def.gradient.last,
    ], stops: const [0.0, 0.5, 1.0]).createShader(Rect.fromCircle(center: c, radius: u * 0.42)),
  );
}

// 29) Elite Radiante — núcleo elétrico com raio central.
void _paintBoltCore(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _eliteAura(canvas, c, u, t, def);
  final flicker = 0.75 + 0.25 * math.sin(t * math.pi * 6);
  canvas.drawCircle(
    c,
    u * 0.7,
    Paint()..shader = RadialGradient(colors: [
      def.gradient.last.withOpacity(0.5 * flicker),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: c, radius: u * 0.7)),
  );
  final bolt = Path()
    ..moveTo(c.dx + u * 0.12, c.dy - u * 0.75)
    ..lineTo(c.dx - u * 0.25, c.dy + u * 0.05)
    ..lineTo(c.dx, c.dy + u * 0.05)
    ..lineTo(c.dx - u * 0.12, c.dy + u * 0.75)
    ..lineTo(c.dx + u * 0.3, c.dy - u * 0.1)
    ..lineTo(c.dx + u * 0.02, c.dy - u * 0.1)
    ..close();
  canvas.drawPath(
    bolt,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, ...def.gradient],
    ).createShader(bolt.getBounds()),
  );
  for (int i = 0; i < 4; i++) {
    final a = (i / 4) * 2 * math.pi + t * 0.4;
    final r = u * 0.9;
    canvas.drawCircle(
      c + Offset(math.cos(a), math.sin(a)) * r,
      u * 0.05,
      Paint()..color = Colors.white.withOpacity(0.6 + 0.4 * flicker),
    );
  }
}

// 30) Horizonte Supremo — coroa dourada dupla sobre núcleo radiante.
// O selo máximo da progressão: reúne o maior número de camadas
// (halo, disco, raios duplos, coroa dupla, marcas cardeais).
void _paintSupremeCrown(Canvas canvas, Offset c, double u, double t, LevelBadgeDef def) {
  _eliteAura(canvas, c, u, t, def);
  final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 1.3);
  final rot = t * 0.2;

  // Núcleo radiante.
  canvas.drawCircle(
    c,
    u * 0.34,
    Paint()..shader = RadialGradient(colors: [
      const Color(0xFFFFFFFF),
      const Color(0xFFFFF9C4),
      def.gradient.first,
    ]).createShader(Rect.fromCircle(center: c, radius: u * 0.34)),
  );

  // Raios duplos contra-rotativos.
  for (int i = 0; i < 10; i++) {
    final a = (i / 10) * 2 * math.pi + rot;
    final p1 = c + Offset(math.cos(a), math.sin(a)) * u * 0.4;
    final p2 = c + Offset(math.cos(a), math.sin(a)) * u * 0.95;
    canvas.drawLine(p1, p2, Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = u * 0.045
      ..color = def.gradient.last.withOpacity(0.85));
  }

  // Marcas cardeais pulsantes.
  for (int i = 0; i < 4; i++) {
    final a = (i / 4) * 2 * math.pi;
    final pos = c + Offset(math.cos(a), math.sin(a)) * u * 1.05;
    canvas.drawCircle(pos, u * 0.05 * (0.8 + 0.2 * pulse),
        Paint()..color = Colors.white.withOpacity(0.8));
  }

  // Coroa dupla no topo, marca do nível máximo.
  final crownY = c.dy - u * 0.95;
  final crown = Path()
    ..moveTo(c.dx - u * 0.32, crownY + u * 0.18)
    ..lineTo(c.dx - u * 0.34, crownY - u * 0.04)
    ..lineTo(c.dx - u * 0.15, crownY + u * 0.08)
    ..lineTo(c.dx, crownY - u * 0.2)
    ..lineTo(c.dx + u * 0.15, crownY + u * 0.08)
    ..lineTo(c.dx + u * 0.34, crownY - u * 0.04)
    ..lineTo(c.dx + u * 0.32, crownY + u * 0.18)
    ..close();
  canvas.drawPath(
    crown,
    Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white, def.gradient.last],
    ).createShader(crown.getBounds()),
  );
}

// ═══════════════════════════════════════════════════════════════════
// SELO DE NÍVEL PRONTO PARA USO — em qualquer tela
// ═══════════════════════════════════════════════════════════════════
/// Mostra o selo do nível do usuário. Recebe diretamente o [level]
/// (UserXpData.level). Sempre desenha algo — não há "sem nível"
/// como existe para recompensas de check-in opcionais — então não
/// tem variante nula.
///
/// Exemplo (posicionado sobre o canto superior esquerdo do avatar):
///   LevelBadge(level: data.level, size: 20)
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  final bool animate;

  const LevelBadge({
    Key? key,
    required this.level,
    this.size = 22,
    this.animate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LevelBadgeArt(level: level, size: size, animate: animate);
  }
}