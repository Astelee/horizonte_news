import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/checkin_rewards_config.dart';

// ═══════════════════════════════════════════════════════════════════
// ARTE DAS RECOMPENSAS DE CHECK-IN — 100% CustomPainter, sem imagens
// ═══════════════════════════════════════════════════════════════════
// Sistema PRÓPRIO do Check-in (independente de premium_avatars.dart).
// Mesma filosofia visual do app: preto, laranja, branco, glow,
// partículas e profundidade — mas com desenhos e ids exclusivos.
//
// Cada recompensa é desenhada dentro de um quadrado [size]. Um único
// AnimationController (loop de 6s) alimenta todos os painters, e
// cada um deriva o movimento de `t` (0..1) — assim há 1 ticker por
// arte, sem controllers extras nem vazamento.
// ═══════════════════════════════════════════════════════════════════

/// Único ponto de entrada: dado um [CheckinRewardId], desenha a arte.
/// [locked] mostra a silhueta apagada (recompensa ainda não ganha).
/// [animate] = false congela num quadro bonito (útil em listas
/// longas, para poupar bateria).
class CheckinRewardArt extends StatefulWidget {
  final CheckinRewardId id;
  final double size;
  final bool locked;
  final bool animate;

  const CheckinRewardArt({
    Key? key,
    required this.id,
    this.size = 72,
    this.locked = false,
    this.animate = true,
  }) : super(key: key);

  @override
  State<CheckinRewardArt> createState() => _CheckinRewardArtState();
}

class _CheckinRewardArtState extends State<CheckinRewardArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animate && !widget.locked) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant CheckinRewardArt old) {
    super.didUpdateWidget(old);
    final shouldRun = widget.animate && !widget.locked;
    if (shouldRun && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!shouldRun && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  CustomPainter _painterFor(double t) {
    final def = CheckinRewardsConfig.defFor(widget.id);
    switch (widget.id) {
      case CheckinRewardId.faisca:
        return _FaiscaPainter(t, def);
      case CheckinRewardId.brasaViva:
        return _BrasaVivaPainter(t, def);
      case CheckinRewardId.anelDeFogo:
        return _AnelDeFogoPainter(t, def);
      case CheckinRewardId.chamaDupla:
        return _ChamaDuplaPainter(t, def);
      case CheckinRewardId.coroaIgnea:
        return _CoroaIgneaPainter(t, def);
      case CheckinRewardId.eclipse:
        return _EclipsePainter(t, def);
      case CheckinRewardId.fenixDeCinzas:
        return _FenixPainter(t, def);
      case CheckinRewardId.solDoHorizonte:
        return _SolPainter(t, def);
    }
  }

  @override
  Widget build(BuildContext context) {
    final art = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _painterFor(_ctrl.value),
        ),
      ),
    );

    if (!widget.locked) return SizedBox(width: widget.size, height: widget.size, child: art);

    // Bloqueada: mesma silhueta, dessaturada e escurecida — o
    // jogador vê "o que vem" sem ver a arte completa.
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

/// Halo suave (glow) — desenhado com blur de verdade.
void _glow(Canvas c, Offset center, double radius, Color color, double a) {
  final p = Paint()
    ..color = color.withOpacity(a.clamp(0.0, 1.0))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5);
  c.drawCircle(center, radius, p);
}

/// Gera um pseudo-aleatório determinístico 0..1 a partir de uma
/// semente — partículas estáveis entre quadros (sem cintilar por
/// causa de Random novo a cada paint).
double _rnd(int seed) {
  final x = math.sin(seed * 12.9898) * 43758.5453;
  return x - x.floorToDouble();
}

/// Partículas subindo em brasa ao redor de um centro.
void _embers(
  Canvas c,
  Offset center,
  double radius,
  double t,
  int count,
  Color color, {
  double maxSize = 2.2,
}) {
  for (int i = 0; i < count; i++) {
    final phase = (t + _rnd(i * 3 + 1)) % 1.0;
    final ang = _rnd(i * 7 + 2) * math.pi * 2;
    final dist = radius * (0.35 + 0.75 * _rnd(i * 5 + 3));
    final x = center.dx + math.cos(ang) * dist * (0.6 + 0.4 * phase);
    final y = center.dy + math.sin(ang) * dist * 0.4 - phase * radius * 0.9;
    final fade = math.sin(phase * math.pi);
    final p = Paint()
      ..color = color.withOpacity(0.85 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    c.drawCircle(Offset(x, y), maxSize * (0.4 + 0.6 * fade), p);
  }
}

/// Desenha uma chama estilizada (gota com ponta) centrada em [cx],
/// com base em [baseY] e altura [h].
Path _flamePath(double cx, double baseY, double w, double h, double flick) {
  final path = Path();
  final tipX = cx + flick * w * 0.18;
  path.moveTo(cx, baseY);
  path.cubicTo(cx - w * 0.62, baseY - h * 0.10, cx - w * 0.52,
      baseY - h * 0.62, tipX, baseY - h);
  path.cubicTo(cx + w * 0.52, baseY - h * 0.62, cx + w * 0.62,
      baseY - h * 0.10, cx, baseY);
  path.close();
  return path;
}

Paint _flameFill(Rect r, List<Color> colors) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: colors,
  ).createShader(r);

// ═══════════════════════════════════════════════════════════════════
// 1) FAÍSCA — chama pequena com fagulhas (emblema, 7 dias)
// ═══════════════════════════════════════════════════════════════════
class _FaiscaPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _FaiscaPainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    final flick = math.sin(t * math.pi * 6);

    _glow(canvas, c, u * 0.34, def.accentColor, 0.30 + 0.10 * flick.abs());

    final outer = _flamePath(c.dx, c.dy + u * 0.26, u * 0.46, u * 0.62, flick);
    canvas.drawPath(
      outer,
      _flameFill(outer.getBounds(), [
        const Color(0xFFCC2200),
        def.accentColor,
        const Color(0xFFFFD54F),
      ]),
    );

    final inner = _flamePath(
        c.dx, c.dy + u * 0.26, u * 0.24, u * 0.34, -flick * 0.8);
    canvas.drawPath(
      inner,
      _flameFill(inner.getBounds(),
          [const Color(0xFFFFB300), const Color(0xFFFFFFFF)]),
    );

    _embers(canvas, c, u * 0.5, t, 8, const Color(0xFFFFCC80), maxSize: u * 0.03);
  }

  @override
  bool shouldRepaint(covariant _FaiscaPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 2) BRASA VIVA — núcleo incandescente pulsante (símbolo, 14 dias)
// ═══════════════════════════════════════════════════════════════════
class _BrasaVivaPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _BrasaVivaPainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    // Pulso tipo batimento: dois picos por ciclo.
    final beat = math.pow(math.sin(t * math.pi * 4).abs(), 3).toDouble();
    final r = u * (0.20 + 0.05 * beat);

    _glow(canvas, c, u * 0.42, def.accentColor, 0.28 + 0.22 * beat);

    // Anéis de calor que se expandem e somem.
    for (int i = 0; i < 3; i++) {
      final p = (t * 2 + i / 3) % 1.0;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.018
        ..color = def.accentColor.withOpacity(0.45 * (1 - p));
      canvas.drawCircle(c, u * (0.22 + 0.26 * p), ring);
    }

    // Núcleo: gradiente radial branco → laranja → vermelho.
    final core = Paint()
      ..shader = RadialGradient(colors: const [
        Color(0xFFFFFFFF),
        Color(0xFFFFB300),
        Color(0xFFFF6B00),
        Color(0xFF8A1500),
      ], stops: const [
        0.0,
        0.3,
        0.65,
        1.0
      ]).createShader(Rect.fromCircle(center: c, radius: r * 1.6));
    canvas.drawCircle(c, r * 1.4, core);

    // Rachaduras incandescentes na superfície.
    final crack = Paint()
      ..color = const Color(0xFFFFE0B2).withOpacity(0.55 + 0.3 * beat)
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.012
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final a = _rnd(i * 11 + 4) * math.pi * 2;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r * 0.3;
      final p2 = c + Offset(math.cos(a + 0.25), math.sin(a + 0.25)) * r * 1.2;
      canvas.drawLine(p1, p2, crack);
    }

    _embers(canvas, c, u * 0.5, t, 10, const Color(0xFFFFAB40), maxSize: u * 0.028);
  }

  @override
  bool shouldRepaint(covariant _BrasaVivaPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 3) ANEL DE FOGO — moldura giratória com partículas (30 dias)
// ═══════════════════════════════════════════════════════════════════
class _AnelDeFogoPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _AnelDeFogoPainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    final R = u * 0.38;

    _glow(canvas, c, R * 1.15, def.accentColor, 0.24);

    // Anel base escuro (dá profundidade).
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.07
        ..color = const Color(0xFF1A0A00),
    );

    // Arco luminoso giratório com cauda em gradiente cônico.
    final rect = Rect.fromCircle(center: c, radius: R);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawArc(
      rect,
      0,
      math.pi * 1.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = u * 0.06
        ..shader = SweepGradient(
          colors: [
            def.accentColor.withOpacity(0.0),
            def.accentColor,
            const Color(0xFFFFF3E0),
          ],
          stops: const [0.0, 0.8, 1.0],
          transform: const GradientRotation(0),
        ).createShader(rect),
    );
    canvas.restore();

    // Segundo arco, contra-rotativo, mais fino.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-t * math.pi * 2 * 0.7);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: R * 0.86),
      0,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = u * 0.025
        ..color = const Color(0xFFFFB74D).withOpacity(0.85),
    );
    canvas.restore();

    // Partículas orbitando o anel.
    for (int i = 0; i < 14; i++) {
      final a = (t * math.pi * 2) + _rnd(i * 5 + 1) * math.pi * 2;
      final rr = R + (_rnd(i * 9 + 2) - 0.5) * u * 0.14;
      final pos = c + Offset(math.cos(a), math.sin(a)) * rr;
      canvas.drawCircle(
        pos,
        u * (0.008 + 0.014 * _rnd(i * 3 + 7)),
        Paint()
          ..color = const Color(0xFFFFCC80).withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnelDeFogoPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 4) CHAMA DUPLA — duas chamas em órbita, clara e escura (60 dias)
// ═══════════════════════════════════════════════════════════════════
class _ChamaDuplaPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _ChamaDuplaPainter(this.t, this.def);

  void _flame(Canvas canvas, Offset at, double u, double flick,
      List<Color> colors, double scale) {
    final path = _flamePath(at.dx, at.dy + u * 0.10 * scale, u * 0.26 * scale,
        u * 0.40 * scale, flick);
    canvas.drawPath(path, _flameFill(path.getBounds(), colors));
  }

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    final orbit = u * 0.20;
    final a = t * math.pi * 2;

    _glow(canvas, c, u * 0.36, def.accentColor, 0.22);

    // Trilha da órbita.
    canvas.drawCircle(
      c,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.008
        ..color = Colors.white.withOpacity(0.10),
    );

    final p1 = c + Offset(math.cos(a), math.sin(a)) * orbit;
    final p2 = c + Offset(math.cos(a + math.pi), math.sin(a + math.pi)) * orbit;

    // Chama escura (atrás) e clara (na frente) — profundidade.
    final darkFront = math.sin(a) > 0;
    void drawDark() => _flame(canvas, p2, u, math.sin(t * 20),
        const [Color(0xFF3A0A00), Color(0xFFCC2200), Color(0xFFFF3D00)], 0.95);
    void drawLight() => _flame(canvas, p1, u, math.cos(t * 20),
        const [Color(0xFFFF6B00), Color(0xFFFFD54F), Color(0xFFFFFFFF)], 1.0);

    if (darkFront) {
      drawLight();
      drawDark();
    } else {
      drawDark();
      drawLight();
    }

    _embers(canvas, c, u * 0.5, t, 9, Colors.white, maxSize: u * 0.02);
  }

  @override
  bool shouldRepaint(covariant _ChamaDuplaPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 5) COROA ÍGNEA — coroa com glow (ícone, 100 dias)
// ═══════════════════════════════════════════════════════════════════
class _CoroaIgneaPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _CoroaIgneaPainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);

    _glow(canvas, c, u * 0.40, def.accentColor, 0.26 + 0.14 * pulse);

    final left = c.dx - u * 0.30;
    final right = c.dx + u * 0.30;
    final baseY = c.dy + u * 0.20;
    final topY = c.dy - u * 0.20;
    final midDip = c.dy + u * 0.02;

    // Corpo da coroa: 5 pontas.
    final body = Path()
      ..moveTo(left, baseY)
      ..lineTo(left - u * 0.02, topY)
      ..lineTo(c.dx - u * 0.15, midDip)
      ..lineTo(c.dx - u * 0.07, topY - u * 0.05)
      ..lineTo(c.dx, midDip - u * 0.02)
      ..lineTo(c.dx + u * 0.07, topY - u * 0.05)
      ..lineTo(c.dx + u * 0.15, midDip)
      ..lineTo(right + u * 0.02, topY)
      ..lineTo(right, baseY)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFFF3B0),
            Color(0xFFFFC107),
            Color(0xFFFF6B00),
          ],
        ).createShader(body.getBounds()),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.014
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFE082),
    );

    // Faixa da base com "gemas".
    final band = Rect.fromLTRB(left, baseY - u * 0.05, right, baseY + u * 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(u * 0.02)),
      Paint()..color = const Color(0xFF8A2A00),
    );
    for (int i = 0; i < 5; i++) {
      final gx = left + (right - left) * (0.12 + 0.19 * i);
      canvas.drawCircle(
        Offset(gx, baseY - u * 0.005),
        u * 0.017,
        Paint()..color = Colors.white.withOpacity(0.7 + 0.3 * pulse),
      );
    }

    // Chamas nas pontas.
    final tips = [
      Offset(left - u * 0.02, topY),
      Offset(c.dx - u * 0.07, topY - u * 0.05),
      Offset(c.dx + u * 0.07, topY - u * 0.05),
      Offset(right + u * 0.02, topY),
    ];
    for (int i = 0; i < tips.length; i++) {
      final f = math.sin(t * math.pi * 8 + i);
      final fl = _flamePath(tips[i].dx, tips[i].dy + u * 0.01, u * 0.07,
          u * (0.12 + 0.03 * pulse), f);
      canvas.drawPath(
        fl,
        _flameFill(fl.getBounds(),
            [const Color(0xFFFF6B00), const Color(0xFFFFF3E0)]),
      );
    }

    // Varredura de brilho cruzando a coroa.
    final sweepX = left + (right - left) * ((t * 1.5) % 1.0);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTWH(sweepX - u * 0.05, topY - u * 0.1, u * 0.10, u * 0.5),
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.03),
    );
    canvas.restore();

    _embers(canvas, c, u * 0.5, t, 10, const Color(0xFFFFE082), maxSize: u * 0.026);
  }

  @override
  bool shouldRepaint(covariant _CoroaIgneaPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 6) ECLIPSE — disco escuro com corona laranja (moldura, 150 dias)
// ═══════════════════════════════════════════════════════════════════
class _EclipsePainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _EclipsePainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    final r = u * 0.24;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);

    // Corona externa: halo largo.
    _glow(canvas, c, u * 0.42, def.accentColor, 0.30 + 0.12 * pulse);

    // Raios da corona (giram devagar).
    final rays = 24;
    for (int i = 0; i < rays; i++) {
      final a = (i / rays) * math.pi * 2 + t * math.pi * 0.4;
      final len = u * (0.10 + 0.07 * _rnd(i * 4 + 1)) *
          (0.85 + 0.25 * math.sin(t * math.pi * 6 + i));
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r * 1.02);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r + len);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = u * 0.012
          ..color = const Color(0xFFFFB74D).withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }

    // Anel de luz fino (a "linha do eclipse").
    canvas.drawCircle(
      c,
      r * 1.06,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.02
        ..color = const Color(0xFFFFE0B2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.008),
    );

    // Disco escuro com leve gradiente para dar volume.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFF1C1208), Color(0xFF000000)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // "Anel de diamante": ponto brilhante que percorre a borda.
    final da = t * math.pi * 2;
    final dp = c + Offset(math.cos(da), math.sin(da)) * r * 1.06;
    _glow(canvas, dp, u * 0.05, Colors.white, 0.9);
    canvas.drawCircle(dp, u * 0.014, Paint()..color = Colors.white);

    _embers(canvas, c, u * 0.5, t, 8, const Color(0xFFFF9800), maxSize: u * 0.022);
  }

  @override
  bool shouldRepaint(covariant _EclipsePainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 7) FÊNIX DE CINZAS — asas em brasa que se recompõem (200 dias)
// ═══════════════════════════════════════════════════════════════════
class _FenixPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _FenixPainter(this.t, this.def);

  Path _wing(Offset root, double u, double flap, bool rightSide) {
    final dir = rightSide ? 1.0 : -1.0;
    final path = Path()..moveTo(root.dx, root.dy);
    // 5 penas: cada uma mais longa/aberta, com o bater das asas.
    for (int i = 0; i < 5; i++) {
      final k = i / 4;
      final ang = (-0.55 + k * 1.05) + flap * 0.25;
      final len = u * (0.30 + 0.16 * (1 - (k - 0.35).abs()));
      final tip = Offset(
        root.dx + dir * math.cos(ang) * len,
        root.dy - math.sin(ang) * len * 0.9 + k * u * 0.10,
      );
      final ctrl = Offset(
        root.dx + dir * len * 0.45,
        root.dy - u * 0.22 * (1 - k) - flap * u * 0.05,
      );
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
      path.lineTo(root.dx, root.dy + u * 0.02 * i);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    // Ciclo: bate as asas; no fim "se recompõe" (brilho sobe).
    final flap = math.sin(t * math.pi * 2);
    final rebirth = math.pow(math.max(0, math.sin(t * math.pi * 2 - 1.2)), 2)
        .toDouble();

    _glow(canvas, c, u * 0.42, def.accentColor, 0.26 + 0.20 * rebirth);

    final root = Offset(c.dx, c.dy + u * 0.02);
    final wingColors = const [
      Color(0xFF3A0A00),
      Color(0xFFCC2200),
      Color(0xFFFF6B00),
      Color(0xFFFFC400),
    ];

    for (final right in [false, true]) {
      final w = _wing(root, u, flap, right);
      canvas.drawPath(
        w,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: wingColors,
          ).createShader(w.getBounds()),
      );
      canvas.drawPath(
        w,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.008
          ..color = const Color(0xFFFFCC80).withOpacity(0.7),
      );
    }

    // Corpo/cabeça: gota luminosa central.
    final body = _flamePath(c.dx, c.dy + u * 0.20, u * 0.15, u * 0.34, flap * 0.4);
    canvas.drawPath(
      body,
      _flameFill(body.getBounds(),
          [const Color(0xFFFF6B00), const Color(0xFFFFE082), Colors.white]),
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy - u * 0.10),
      u * 0.022,
      Paint()..color = Colors.white,
    );

    // Cinzas caindo + brasas subindo (o ciclo de renascimento).
    for (int i = 0; i < 10; i++) {
      final p = (t + _rnd(i * 6 + 1)) % 1.0;
      final x = c.dx + (_rnd(i * 4 + 2) - 0.5) * u * 0.7;
      final y = c.dy + u * 0.05 + p * u * 0.35;
      canvas.drawCircle(
        Offset(x, y),
        u * 0.012,
        Paint()..color = Colors.white.withOpacity(0.35 * (1 - p)),
      );
    }
    _embers(canvas, c, u * 0.5, t, 12, const Color(0xFFFFAB40), maxSize: u * 0.026);
  }

  @override
  bool shouldRepaint(covariant _FenixPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// 8) SOL DO HORIZONTE — coroa solar lendária (365 dias)
// ═══════════════════════════════════════════════════════════════════
class _SolPainter extends CustomPainter {
  final double t;
  final CheckinRewardDef def;
  _SolPainter(this.t, this.def);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final u = s.width;
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final r = u * 0.19;

    // Halo em camadas — profundidade máxima do catálogo.
    _glow(canvas, c, u * 0.50, const Color(0xFFFF6B00), 0.22 + 0.10 * pulse);
    _glow(canvas, c, u * 0.34, const Color(0xFFFFB300), 0.30 + 0.12 * pulse);

    // Raios longos (giram) e curtos (contra-giram).
    void rays(int n, double inner, double outer, double rot, double w,
        Color col) {
      for (int i = 0; i < n; i++) {
        final a = (i / n) * math.pi * 2 + rot;
        final wob = 0.85 + 0.25 * math.sin(t * math.pi * 4 + i * 1.7);
        final p1 = c + Offset(math.cos(a), math.sin(a)) * inner;
        final p2 = c + Offset(math.cos(a), math.sin(a)) * (inner + (outer - inner) * wob);
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w
            ..color = col,
        );
      }
    }

    rays(16, r * 1.25, u * 0.47, t * math.pi * 0.5, u * 0.018,
        const Color(0xFFFFD54F).withOpacity(0.9));
    rays(16, r * 1.20, u * 0.36, -t * math.pi * 0.7 + 0.2, u * 0.012,
        Colors.white.withOpacity(0.75));

    // Anel dourado externo.
    canvas.drawCircle(
      c,
      r * 1.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.016
        ..color = const Color(0xFFFFE082),
    );

    // Disco solar: branco → âmbar → laranja.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFFF6B00),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Mini-coroa sobre o sol (referência ao marco de 1 ano).
    final cy = c.dy - r * 1.55;
    final crown = Path()
      ..moveTo(c.dx - u * 0.10, cy + u * 0.05)
      ..lineTo(c.dx - u * 0.11, cy - u * 0.01)
      ..lineTo(c.dx - u * 0.05, cy + u * 0.02)
      ..lineTo(c.dx, cy - u * 0.05)
      ..lineTo(c.dx + u * 0.05, cy + u * 0.02)
      ..lineTo(c.dx + u * 0.11, cy - u * 0.01)
      ..lineTo(c.dx + u * 0.10, cy + u * 0.05)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFC107)],
        ).createShader(crown.getBounds()),
    );

    _embers(canvas, c, u * 0.5, t, 16, Colors.white, maxSize: u * 0.024);
  }

  @override
  bool shouldRepaint(covariant _SolPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS DE FUNDO — usadas pela tela de Check-in (atmosfera)
// ═══════════════════════════════════════════════════════════════════
/// Campo de brasas flutuando no fundo da tela. Um único controller,
/// poucas partículas (parâmetro [count]) e RepaintBoundary — barato.
class CheckinEmberField extends StatefulWidget {
  final int count;
  final Color color;
  const CheckinEmberField({
    Key? key,
    this.count = 26,
    this.color = const Color(0xFFFF6B00),
  }) : super(key: key);

  @override
  State<CheckinEmberField> createState() => _CheckinEmberFieldState();
}

class _CheckinEmberFieldState extends State<CheckinEmberField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _EmberFieldPainter(_ctrl.value, widget.count, widget.color),
          ),
        ),
      ),
    );
  }
}

class _EmberFieldPainter extends CustomPainter {
  final double t;
  final int count;
  final Color color;
  _EmberFieldPainter(this.t, this.count, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    for (int i = 0; i < count; i++) {
      final speed = 0.5 + _rnd(i * 3 + 1);
      final p = (t * speed + _rnd(i * 7 + 2)) % 1.0;
      final x = _rnd(i * 5 + 3) * s.width +
          math.sin((t * math.pi * 2 * speed) + i) * 10;
      final y = s.height * (1.05 - p * 1.15);
      final fade = math.sin(p * math.pi);
      final size = 1.0 + 2.2 * _rnd(i * 11 + 4);
      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = color.withOpacity(0.55 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmberFieldPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// EMBLEMA DA RECOMPENSA EQUIPADA — pronto para usar em qualquer tela
// ═══════════════════════════════════════════════════════════════════
/// Mostra a recompensa de Check-in equipada por um usuário. Recebe a
/// chave salva em `users_xp/{uid}.equippedCheckinRewardId`
/// (`UserXpData.equippedCheckinRewardId`). Se a chave for nula ou
/// desconhecida, não desenha nada (SizedBox.shrink) — então é seguro
/// colocar em qualquer lugar sem `if`.
///
/// Exemplo (ex.: ao lado do nome no perfil):
///   CheckinRewardBadge(
///     storageKey: data.equippedCheckinRewardId,
///     size: 28,
///   )
class CheckinRewardBadge extends StatelessWidget {
  final String? storageKey;
  final double size;
  final bool animate;

  const CheckinRewardBadge({
    Key? key,
    required this.storageKey,
    this.size = 28,
    this.animate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final id = CheckinRewardIdX.fromStorageKey(storageKey);
    if (id == null) return const SizedBox.shrink();
    return CheckinRewardArt(id: id, size: size, animate: animate);
  }
}