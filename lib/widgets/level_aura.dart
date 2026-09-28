import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/level_badge_config.dart';

// ═══════════════════════════════════════════════════════════════════
// AURAS DE NÍVEL — 10 efeitos animados ao redor da foto de perfil
// ═══════════════════════════════════════════════════════════════════
// Uma aura por faixa de raridade (mesmas 10 faixas do LevelBadgeRarity):
//   1 Comum       → brisa suave com poeira de luz
//   2 Incomum     → cometas orbitando
//   3 Raro        → raios giratórios + vaga-lumes
//   4 Especial    → raios dourados radiantes + brilhos
//   5 Épico       → chamas + brasas subindo
//   6 Heroico     → tempestade: cometas duplos + relâmpagos
//   7 Lendário    → aurora estelar + estrelas + fogos de artifício
//   8 Mítico      → cósmico arco-íris + gemas + fogos coloridos
//   9 Supremo     → inferno: chamas em 3 camadas + ondas + faíscas
//  10 Elite       → sol supremo: raios duplos + arco-íris + fogos
//
// 100% CustomPainter, sem imagens. Tudo se repete de forma contínua
// e sem "pulo" a cada volta de 12s (todo movimento usa múltiplos
// inteiros do ciclo). A aura é desenhada ATRÁS da foto e nunca a
// cobre. Avatares pequenos (< 48px) usam uma versão mais leve.
// ═══════════════════════════════════════════════════════════════════

const double _tau = math.pi * 2;

class _AuraSpec {
  /// Quanto a aura se estende para fora da foto, em fração do tamanho
  /// do avatar, de cada lado.
  final double ext;
  final List<Color> colors;
  const _AuraSpec(this.ext, this.colors);
}

const List<_AuraSpec> _specs = [
  // 0 Comum
  _AuraSpec(0.16, [Color(0xFF90A4AE), Color(0xFF64B5F6), Color(0xFFE3F2FD)]),
  // 1 Incomum
  _AuraSpec(0.20, [Color(0xFF29B6F6), Color(0xFF26C6DA), Color(0xFF00BFA5)]),
  // 2 Raro
  _AuraSpec(0.23, [Color(0xFF66BB6A), Color(0xFF9CCC65), Color(0xFFD4E157)]),
  // 3 Especial
  _AuraSpec(0.27, [Color(0xFFFFD700), Color(0xFFFFCA28), Color(0xFFFFA726)]),
  // 4 Épico
  _AuraSpec(0.30, [Color(0xFFFF7043), Color(0xFFEC407A), Color(0xFFFFA726)]),
  // 5 Heroico
  _AuraSpec(0.32, [Color(0xFFF06292), Color(0xFFBA68C8), Color(0xFF9575CD)]),
  // 6 Lendário
  _AuraSpec(0.35, [Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFF00E5FF)]),
  // 7 Mítico
  _AuraSpec(0.38, [Color(0xFFE040FB), Color(0xFF00E5FF), Color(0xFFD500F9)]),
  // 8 Supremo
  _AuraSpec(0.40, [Color(0xFFFF1744), Color(0xFFFF3D00), Color(0xFFFFC400)]),
  // 9 Elite
  _AuraSpec(0.44, [Color(0xFFFFF176), Color(0xFFFFC400), Color(0xFFFF6D00)]),
];

_AuraSpec _specFor(LevelBadgeRarity r) => _specs[r.index];

/// Aura animada que envolve a foto de perfil. Deve ser posicionada
/// centralizada sobre o avatar, com largura/altura de
/// `avatarSize * (1 + 2 * extentFor(...))` (o [UserAvatarDisplay]
/// já faz isso automaticamente).
class LevelAura extends StatefulWidget {
  final int level;
  final double avatarSize;

  /// Multiplica o quanto a aura se estende para fora da foto.
  /// 1.0 = padrão; use menos (ex.: 0.7) se ela estiver sendo cortada
  /// em alguma tela.
  final double extentScale;
  final bool animate;

  const LevelAura({
    Key? key,
    required this.level,
    required this.avatarSize,
    this.extentScale = 1.0,
    this.animate = true,
  }) : super(key: key);

  /// Fração do tamanho do avatar que a aura ocupa fora da foto, em
  /// cada lado.
  static double extentFor(int level, double avatarSize,
      {double scale = 1.0}) {
    final spec = _specFor(LevelBadgeRarityX.fromLevel(level));
    final lite = avatarSize < 48;
    return spec.ext * scale * (lite ? 0.75 : 1.0);
  }

  @override
  State<LevelAura> createState() => _LevelAuraState();
}

class _LevelAuraState extends State<LevelAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.animate) {
      _ctrl.repeat();
    } else {
      _ctrl.value = 0.3;
    }
  }

  @override
  void didUpdateWidget(covariant LevelAura old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rarity = LevelBadgeRarityX.fromLevel(widget.level);
    final e = LevelAura.extentFor(
      widget.level,
      widget.avatarSize,
      scale: widget.extentScale,
    );
    final total = widget.avatarSize * (1 + 2 * e);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(total),
          painter: _AuraPainter(
            anim: _ctrl,
            avatarSize: widget.avatarSize,
            rarity: rarity,
            lite: widget.avatarSize < 48,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAINTER + CONTEXTO DE DESENHO
// ═══════════════════════════════════════════════════════════════════

class _Ctx {
  final Canvas canvas;
  final Offset c;

  /// Raio da foto.
  final double r;

  /// Raio máximo da aura (borda do canvas).
  final double mr;

  /// Tempo do ciclo, 0..1.
  final double t;
  final List<Color> col;
  final bool lite;

  _Ctx(this.canvas, this.c, this.r, this.mr, this.t, this.col, this.lite);

  double get band => mr - r;

  /// Raio na faixa da aura: f=0 borda da foto, f=1 borda externa.
  double at(double f) => r + band * f;

  int n(int count) => lite ? math.max(1, (count * 0.6).round()) : count;

  Offset pt(double rad, double ang) =>
      Offset(c.dx + math.cos(ang) * rad, c.dy + math.sin(ang) * rad);

  /// Onda 0..1 que se repete [k] vezes por ciclo (k inteiro).
  double wave(int k, [double phase = 0]) =>
      0.5 + 0.5 * math.sin(_tau * (t * k + phase));

  /// Ângulo que gira [k] voltas por ciclo (k inteiro, pode ser negativo).
  double spin(int k) => _tau * t * k;
}

class _AuraPainter extends CustomPainter {
  final Animation<double> anim;
  final double avatarSize;
  final LevelBadgeRarity rarity;
  final bool lite;

  _AuraPainter({
    required this.anim,
    required this.avatarSize,
    required this.rarity,
    required this.lite,
  }) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final x = _Ctx(
      canvas,
      Offset(size.width / 2, size.height / 2),
      avatarSize / 2,
      size.width / 2,
      anim.value,
      _specFor(rarity).colors,
      lite,
    );
    if (x.mr <= x.r + 1) return;
    switch (rarity) {
      case LevelBadgeRarity.common:
        _paintCommon(x);
        break;
      case LevelBadgeRarity.uncommon:
        _paintUncommon(x);
        break;
      case LevelBadgeRarity.rare:
        _paintRare(x);
        break;
      case LevelBadgeRarity.special:
        _paintSpecial(x);
        break;
      case LevelBadgeRarity.epic:
        _paintEpic(x);
        break;
      case LevelBadgeRarity.heroic:
        _paintHeroic(x);
        break;
      case LevelBadgeRarity.legendary:
        _paintLegendary(x);
        break;
      case LevelBadgeRarity.mythic:
        _paintMythic(x);
        break;
      case LevelBadgeRarity.supreme:
        _paintSupreme(x);
        break;
      case LevelBadgeRarity.elite:
        _paintElite(x);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) =>
      old.rarity != rarity ||
      old.avatarSize != avatarSize ||
      old.lite != lite ||
      old.anim != anim;
}

// ═══════════════════════════════════════════════════════════════════
// FERRAMENTAS DE DESENHO
// ═══════════════════════════════════════════════════════════════════

double _h(int seed) {
  final v = math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

double _frac(double v) => v - v.floorToDouble();

double _op(double a) => a.clamp(0.0, 1.0).toDouble();

void _soft(Canvas canvas, Offset c, double radius, Color color, double a) {
  if (a <= 0.01 || radius <= 0) return;
  canvas.drawCircle(
    c,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(_op(a)), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: c, radius: radius)),
  );
}

/// Brilho suave ao redor da foto.
void _halo(_Ctx x, Color color, double a) {
  final outer = x.mr;
  final s2 = math.min(0.985, x.r * 1.08 / outer);
  final s1 = math.min(x.r * 0.9 / outer, s2 - 0.01);
  x.canvas.drawCircle(
    x.c,
    outer,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(_op(a)),
          color.withOpacity(_op(a * 0.55)),
          color.withOpacity(0),
        ],
        stops: [s1, s2, 1.0],
      ).createShader(Rect.fromCircle(center: x.c, radius: outer)),
  );
}

void _ring(_Ctx x, double rad, double stroke, Color color, double a) {
  x.canvas.drawCircle(
    x.c,
    rad,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, stroke)
      ..color = color.withOpacity(_op(a)),
  );
}

/// Ponto de luz com brilho.
void _dot(_Ctx x, Offset p, double rad, Color color, double a) {
  final al = _op(a);
  if (al < 0.02 || rad <= 0) return;
  if (!x.lite) {
    x.canvas.drawCircle(
      p,
      rad * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(al * 0.5), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: p, radius: rad * 2.6)),
    );
  }
  x.canvas.drawCircle(p, rad, Paint()..color = color.withOpacity(al));
  x.canvas.drawCircle(
    p,
    rad * 0.5,
    Paint()..color = Colors.white.withOpacity(al * 0.85),
  );
}

/// Brilho em cruz (4 pontas).
void _sparkle(_Ctx x, Offset p, double size, Color color, double a) {
  final al = _op(a);
  if (al < 0.03 || size <= 0) return;
  final path = Path()
    ..moveTo(p.dx, p.dy - size)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + size, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + size)
    ..quadraticBezierTo(p.dx, p.dy, p.dx - size, p.dy)
    ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - size)
    ..close();
  if (!x.lite) {
    _soft(x.canvas, p, size * 1.1, color, al * 0.6);
  }
  x.canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(al));
}

Path _starPath(Offset c, double outer, double inner, int points, double rot) {
  final path = Path();
  for (int i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outer : inner;
    final a = (i / (points * 2)) * _tau + rot - math.pi / 2;
    final px = c.dx + math.cos(a) * radius;
    final py = c.dy + math.sin(a) * radius;
    if (i == 0) {
      path.moveTo(px, py);
    } else {
      path.lineTo(px, py);
    }
  }
  path.close();
  return path;
}

List<Color> _rainbow(double t, double alpha, {int n = 7}) {
  final list = <Color>[];
  for (int i = 0; i < n; i++) {
    final hue = (i * 360.0 / n + t * 360.0) % 360.0;
    list.add(HSVColor.fromAHSV(_op(alpha), hue, 0.75, 1.0).toColor());
  }
  list.add(list.first);
  return list;
}

/// Raios radiantes (um único path, com degradê que some na ponta).
void _rays(
  _Ctx x, {
  required int count,
  required double rot,
  required double inner,
  required double outer,
  required Color color,
  required double halfW,
  double alpha = 0.7,
  double flicker = 0.0,
  int k = 3,
}) {
  if (outer <= inner) return;
  final shader = RadialGradient(
    colors: [color.withOpacity(_op(alpha)), color.withOpacity(0)],
    stops: [(inner / outer).clamp(0.0, 0.99).toDouble(), 1.0],
  ).createShader(Rect.fromCircle(center: x.c, radius: outer));
  final path = Path();
  for (int i = 0; i < count; i++) {
    final a = rot + i / count * _tau;
    final w = flicker > 0
        ? (1 - flicker) + flicker * x.wave(k, _h(i + 3))
        : 1.0;
    final len = inner + (outer - inner) * w * (0.7 + 0.3 * _h(i + 11));
    final p1 = x.pt(inner, a - halfW);
    final p2 = x.pt(inner, a + halfW);
    final tip = x.pt(len, a);
    path
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
  }
  x.canvas.drawPath(path, Paint()..shader = shader);
}

/// Línguas de fogo ao redor da foto.
void _flames(
  _Ctx x, {
  required int count,
  required double baseR,
  required double height,
  required Color a,
  required Color b,
  double alpha = 0.85,
  int k = 3,
  double rot = 0,
}) {
  final outer = baseR + height;
  final shader = RadialGradient(
    colors: [a.withOpacity(_op(alpha)), b.withOpacity(0)],
    stops: [(baseR / outer).clamp(0.0, 0.99).toDouble(), 1.0],
  ).createShader(Rect.fromCircle(center: x.c, radius: outer));
  final path = Path();
  final hw = _tau / count * 0.46;
  for (int i = 0; i < count; i++) {
    final ang = rot + i / count * _tau;
    final hh = height * (0.55 + 0.45 * x.wave(k, _h(i + 5)));
    final sway = math.sin(_tau * (x.t * k + _h(i + 9))) * hw * 0.9;
    final b1 = x.pt(baseR, ang - hw);
    final b2 = x.pt(baseR, ang + hw);
    final tip = x.pt(baseR + hh, ang + sway);
    final c1 = x.pt(baseR + hh * 0.5, ang - hw * 0.9 + sway * 0.6);
    final c2 = x.pt(baseR + hh * 0.5, ang + hw * 0.9 + sway * 0.6);
    path.moveTo(b1.dx, b1.dy);
    path.quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy);
    path.quadraticBezierTo(c2.dx, c2.dy, b2.dx, b2.dy);
    path.close();
  }
  x.canvas.drawPath(path, Paint()..shader = shader);
}

/// Partículas que saem da foto para fora (brasas / faíscas).
void _outflow(
  _Ctx x, {
  required int count,
  required double from,
  required double to,
  required int k,
  required double size,
  double lift = 0.0,
  double alpha = 1.0,
  int seed = 0,
}) {
  for (int i = 0; i < count; i++) {
    final p = _frac(x.t * k + _h(i * 3 + seed));
    final ang = _h(i * 7 + seed + 1) * _tau;
    final rad = from + (to - from) * p * (0.55 + 0.45 * _h(i + seed + 2));
    final base = x.pt(rad, ang);
    final pos = Offset(
      base.dx + math.sin(_tau * (p * 2 + _h(i))) * x.r * 0.05,
      base.dy - lift * x.r * p,
    );
    final a = math.sin(p * math.pi) * alpha;
    _dot(x, pos, size * (1 - 0.6 * p), x.col[i % x.col.length], a);
  }
}

/// Partículas orbitando a foto.
void _orbit(
  _Ctx x, {
  required int count,
  required double radius,
  required int speed,
  required double size,
  double wobble = 0.0,
  int wk = 2,
  int twinkle = 0,
  double alpha = 0.9,
  List<Color>? colors,
}) {
  final cols = colors ?? x.col;
  for (int i = 0; i < count; i++) {
    final a = i / count * _tau + _tau * x.t * speed;
    final rr = radius + x.band * wobble * math.sin(_tau * (x.t * wk + i * 0.21));
    final tw = twinkle > 0 ? 0.4 + 0.6 * x.wave(twinkle, i * 0.31) : 1.0;
    _dot(x, x.pt(rr, a), size, cols[i % cols.length], alpha * tw);
  }
}

/// Estrelas / gemas giratórias orbitando.
void _orbitStars(
  _Ctx x, {
  required int count,
  required double radius,
  required int speed,
  required double size,
  int points = 5,
  bool rainbow = false,
}) {
  for (int i = 0; i < count; i++) {
    final a = i / count * _tau + _tau * x.t * speed;
    final rr = radius + x.band * 0.06 * math.sin(_tau * (x.t * 2 + i * 0.3));
    final pos = x.pt(rr, a);
    final color = rainbow
        ? HSVColor.fromAHSV(
            1.0,
            (i * 360.0 / count + x.t * 360.0) % 360.0,
            0.65,
            1.0,
          ).toColor()
        : x.col[i % x.col.length];
    final rot = _tau * x.t * 2 + i;
    if (!x.lite) {
      _soft(x.canvas, pos, size * 2.2, color, 0.4);
    }
    x.canvas.drawPath(
      _starPath(pos, size, size * 0.45, points, rot),
      Paint()..color = color.withOpacity(0.95),
    );
    x.canvas.drawPath(
      _starPath(pos, size * 0.5, size * 0.22, points, rot),
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }
}

/// Brilhos que piscam em posições fixas.
void _twinkles(
  _Ctx x, {
  required int count,
  required double fromF,
  required double toF,
  required int k,
  required double size,
  int seed = 0,
}) {
  for (int i = 0; i < count; i++) {
    final ang = _h(i * 3 + 1 + seed) * _tau;
    final rad = x.at(fromF + (toF - fromF) * _h(i * 5 + 2 + seed));
    final w = x.wave(k, _h(i * 7 + seed));
    _sparkle(
      x,
      x.pt(rad, ang),
      size * (0.5 + 0.5 * w),
      x.col[i % x.col.length],
      w * w * w,
    );
  }
}

/// Cometa com cauda circulando a foto. [dir] = 1 horário, -1 anti-horário.
void _comet(
  _Ctx x, {
  required double radius,
  required double angle,
  required double tail,
  required Color color,
  required double stroke,
  int dir = 1,
  double alpha = 0.9,
}) {
  final seg = x.lite ? 5 : 10;
  final rect = Rect.fromCircle(center: x.c, radius: radius);
  final step = tail / seg;
  for (int i = 0; i < seg; i++) {
    final f = i / seg;
    final start = dir >= 0 ? angle - step * (i + 1) : angle + step * i;
    x.canvas.drawArc(
      rect,
      start,
      step * 1.15,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, stroke * (1 - f * 0.6))
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(_op(alpha * (1 - f) * (1 - f))),
    );
  }
  _dot(x, x.pt(radius, angle), stroke * 0.8, color, alpha);
}

void _bolt(_Ctx x, double ang, double r0, double r1, Color color,
    double stroke, int seed, double a) {
  const n = 6;
  final nrm = ang + math.pi / 2;
  final path = Path();
  for (int i = 0; i <= n; i++) {
    final f = i / n;
    final rad = r0 + (r1 - r0) * f;
    final off = (i == 0 || i == n)
        ? 0.0
        : (_h(seed * 31 + i) - 0.5) * (r1 - r0) * 0.5;
    final base = x.pt(rad, ang);
    final px = base.dx + math.cos(nrm) * off;
    final py = base.dy + math.sin(nrm) * off;
    if (i == 0) {
      path.moveTo(px, py);
    } else {
      path.lineTo(px, py);
    }
  }
  x.canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, stroke * 3.2)
      ..color = color.withOpacity(_op(a * 0.35)),
  );
  x.canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.9, stroke)
      ..color = Colors.white.withOpacity(_op(a)),
  );
}

/// Relâmpagos que surgem e somem em ângulos variados.
void _bolts(
  _Ctx x, {
  required int count,
  required double r0,
  required double r1,
  required Color color,
  double stroke = 1.4,
}) {
  for (int i = 0; i < count; i++) {
    final u = x.t * 12 + i * 4.0;
    final slot = u.floor() % 12;
    if (_h(slot * 11 + i * 7) < 0.5) continue;
    final f = _frac(u);
    final a = math.sin(f * math.pi);
    final ang = _h(slot * 5 + i * 13) * _tau;
    _bolt(x, ang, r0, r1, color, stroke, slot * 3 + i, a);
  }
}

/// Fogos de artifício: explode, espalha faíscas e some. Repete a
/// cada 4s, em 3 posições diferentes (ciclo de 12s).
void _firework(
  _Ctx x, {
  required int idx,
  required double off,
  required List<Color> colors,
  int rays = 10,
}) {
  const k = 3;
  final u = x.t * k + off;
  final p = _frac(u);
  const dur = 0.5;
  if (p > dur) return;
  final slot = u.floor() % k;
  final f = p / dur;
  final ease = 1 - math.pow(1 - f, 3).toDouble();
  final ang = _h(idx * 17 + slot * 5 + 1) * _tau;
  final o = x.pt(x.at(0.55), ang);
  final reach = x.band * 0.45;
  final fade = _op(1 - f);
  if (f < 0.25) {
    _soft(x.canvas, o, reach * 0.6, Colors.white, (1 - f / 0.25) * 0.8);
  }
  final d = reach * ease;
  final tailD = math.max(0.0, d - reach * 0.4);
  final n = x.lite ? math.max(5, rays - 3) : rays;
  final rot = _h(idx + slot) * _tau;
  for (int j = 0; j < n; j++) {
    final aj = j / n * _tau + rot;
    final dir = Offset(math.cos(aj), math.sin(aj));
    final p1 = Offset(o.dx + dir.dx * tailD, o.dy + dir.dy * tailD);
    final p2 = Offset(o.dx + dir.dx * d, o.dy + dir.dy * d);
    final color = colors[(j + idx) % colors.length];
    x.canvas.drawLine(
      p1,
      p2,
      Paint()
        ..strokeWidth = math.max(1.0, x.r * 0.035)
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(fade),
    );
    if (!x.lite) {
      _dot(x, p2, x.r * 0.03, color, fade);
    }
  }
}

/// Onda de choque que se expande e some.
void _shock(
  _Ctx x, {
  required int k,
  required double off,
  required Color color,
  double stroke = 2.0,
}) {
  final p = _frac(x.t * k + off);
  final rad = x.at(0.05 + 0.95 * p);
  final a = math.pow(1 - p, 1.6).toDouble() * 0.7;
  _ring(x, rad, stroke * (1 - p * 0.6), color, a);
}

/// Anel com degradê giratório (arco-íris / aurora).
void _sweepRing(
  _Ctx x, {
  required double radius,
  required double stroke,
  required List<Color> colors,
  required double rot,
}) {
  final rect = Rect.fromCircle(center: x.c, radius: radius);
  x.canvas.drawCircle(
    x.c,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, stroke)
      ..shader = SweepGradient(
        colors: colors,
        transform: GradientRotation(rot),
      ).createShader(rect),
  );
}

// ═══════════════════════════════════════════════════════════════════
// AS 10 AURAS
// ═══════════════════════════════════════════════════════════════════

// 1 — COMUM: brisa suave com poeira de luz.
void _paintCommon(_Ctx x) {
  final col = x.col;
  _halo(x, col[1], 0.30 + 0.12 * x.wave(2));
  _ring(x, x.at(0.10), x.r * 0.045, col[0], 0.35 + 0.25 * x.wave(3));
  _orbit(x,
      count: x.n(6),
      radius: x.at(0.55),
      speed: 1,
      size: x.r * 0.05,
      wobble: 0.15,
      wk: 2,
      twinkle: 2,
      alpha: 0.85);
  _twinkles(x,
      count: x.n(3), fromF: 0.3, toF: 0.9, k: 2, size: x.r * 0.14);
}

// 2 — INCOMUM: cometas coloridos orbitando.
void _paintUncommon(_Ctx x) {
  final col = x.col;
  _halo(x, col[0], 0.38 + 0.12 * x.wave(2));
  _ring(x, x.at(0.08), x.r * 0.04, col[1], 0.4);
  const ks = [2, -1, 3];
  for (int i = 0; i < 3; i++) {
    _comet(x,
        radius: x.at(0.22 + 0.28 * i),
        angle: x.spin(ks[i]) + i * _tau / 3,
        tail: 1.3 + 0.2 * i,
        color: col[i],
        stroke: x.r * (0.07 - 0.01 * i),
        dir: ks[i] < 0 ? -1 : 1);
  }
  _orbit(x,
      count: x.n(7),
      radius: x.at(0.75),
      speed: -1,
      size: x.r * 0.045,
      wobble: 0.12,
      wk: 3,
      twinkle: 3);
  _twinkles(x,
      count: x.n(3), fromF: 0.3, toF: 0.95, k: 2, size: x.r * 0.15, seed: 4);
}

// 3 — RARO: raios giratórios + vaga-lumes.
void _paintRare(_Ctx x) {
  final col = x.col;
  _halo(x, col[0], 0.42 + 0.10 * x.wave(2));
  _rays(x,
      count: x.n(12),
      rot: x.spin(1),
      inner: x.at(0.04),
      outer: x.at(1.0),
      color: col[1],
      halfW: 0.07,
      alpha: 0.6,
      flicker: 0.35,
      k: 3);
  _ring(x, x.at(0.07), x.r * 0.05, col[0], 0.5 + 0.3 * x.wave(2));
  _orbit(x,
      count: x.n(10),
      radius: x.at(0.55),
      speed: 1,
      size: x.r * 0.06,
      wobble: 0.3,
      wk: 3,
      twinkle: 3);
  _twinkles(x,
      count: x.n(4), fromF: 0.35, toF: 0.95, k: 3, size: x.r * 0.16, seed: 9);
}

// 4 — ESPECIAL: raios dourados radiantes + brilhos.
void _paintSpecial(_Ctx x) {
  final col = x.col;
  _halo(x, col[0], 0.5 + 0.12 * x.wave(2));
  _rays(x,
      count: x.n(16),
      rot: x.spin(1),
      inner: x.at(0.03),
      outer: x.at(1.0),
      color: col[0],
      halfW: 0.06,
      alpha: 0.75,
      flicker: 0.4,
      k: 3);
  _rays(x,
      count: x.n(8),
      rot: -x.spin(2),
      inner: x.at(0.03),
      outer: x.at(0.75),
      color: col[2],
      halfW: 0.09,
      alpha: 0.55,
      flicker: 0.3,
      k: 2);
  _ring(x, x.at(0.06), x.r * 0.06, col[1], 0.55 + 0.3 * x.wave(2));
  _orbit(x,
      count: x.n(6),
      radius: x.at(0.6),
      speed: -1,
      size: x.r * 0.055,
      wobble: 0.2,
      wk: 2,
      twinkle: 2);
  _twinkles(x,
      count: x.n(6), fromF: 0.3, toF: 0.98, k: 3, size: x.r * 0.2, seed: 2);
}

// 5 — ÉPICO: chamas + brasas subindo.
void _paintEpic(_Ctx x) {
  final col = x.col;
  _halo(x, col[0], 0.55 + 0.10 * x.wave(3));
  _flames(x,
      count: x.n(14),
      baseR: x.r * 0.96,
      height: x.band * 0.95,
      a: col[0],
      b: col[1],
      alpha: 0.85,
      k: 3);
  _flames(x,
      count: x.n(14),
      baseR: x.r * 0.96,
      height: x.band * 0.6,
      a: col[2],
      b: col[0],
      alpha: 0.9,
      k: 2,
      rot: _tau / 28);
  _outflow(x,
      count: x.n(14),
      from: x.at(0.1),
      to: x.at(1.0),
      k: 2,
      size: x.r * 0.055,
      lift: 0.35,
      seed: 3);
  _ring(x, x.at(0.03), x.r * 0.06, col[2], 0.6 + 0.3 * x.wave(3));
}

// 6 — HEROICO: tempestade — cometas duplos + relâmpagos.
void _paintHeroic(_Ctx x) {
  final col = x.col;
  _halo(x, col[1], 0.55 + 0.10 * x.wave(2));
  _ring(x, x.at(0.06), x.r * 0.05, col[0], 0.6);
  _ring(x, x.at(0.5), x.r * 0.02, col[1], 0.3 + 0.2 * x.wave(2));
  for (int i = 0; i < 3; i++) {
    _comet(x,
        radius: x.at(0.2),
        angle: x.spin(2) + i * _tau / 3,
        tail: 1.1,
        color: col[0],
        stroke: x.r * 0.07);
    _comet(x,
        radius: x.at(0.62),
        angle: x.spin(-2) + i * _tau / 3,
        tail: 1.1,
        color: col[1],
        stroke: x.r * 0.06,
        dir: -1);
  }
  _bolts(x,
      count: 3,
      r0: x.at(0.08),
      r1: x.at(1.0),
      color: col[1],
      stroke: x.r * 0.03);
  _orbit(x,
      count: x.n(6),
      radius: x.at(0.4),
      speed: 1,
      size: x.r * 0.05,
      wobble: 0.1,
      wk: 2,
      twinkle: 2);
  _twinkles(x,
      count: x.n(5), fromF: 0.3, toF: 0.98, k: 3, size: x.r * 0.18, seed: 5);
}

// 7 — LENDÁRIO: aurora estelar + estrelas + fogos de artifício.
void _paintLegendary(_Ctx x) {
  final col = x.col;
  _halo(x, col[0], 0.6 + 0.10 * x.wave(2));
  _sweepRing(x,
      radius: x.at(0.22),
      stroke: x.band * 0.42,
      colors: [
        col[0].withOpacity(0),
        col[2].withOpacity(0.55),
        col[0].withOpacity(0.75),
        col[1].withOpacity(0.55),
        col[0].withOpacity(0),
      ],
      rot: x.spin(1));
  _sweepRing(x,
      radius: x.at(0.58),
      stroke: x.band * 0.2,
      colors: [
        col[1].withOpacity(0),
        col[2].withOpacity(0.7),
        col[0].withOpacity(0.6),
        col[1].withOpacity(0),
      ],
      rot: x.spin(-2));
  _rays(x,
      count: x.n(20),
      rot: x.spin(1),
      inner: x.at(0.05),
      outer: x.at(1.0),
      color: col[2],
      halfW: 0.035,
      alpha: 0.55,
      flicker: 0.5,
      k: 4);
  _orbitStars(x,
      count: x.n(6), radius: x.at(0.62), speed: 1, size: x.r * 0.11);
  _firework(x, idx: 1, off: 0.0, colors: col);
  _firework(x, idx: 2, off: 0.5, colors: col);
  _twinkles(x,
      count: x.n(6), fromF: 0.3, toF: 1.0, k: 2, size: x.r * 0.2, seed: 7);
  _ring(x, x.at(0.03), x.r * 0.05, col[2], 0.6 + 0.3 * x.wave(2));
}

// 8 — MÍTICO: cósmico arco-íris + gemas + fogos coloridos.
void _paintMythic(_Ctx x) {
  final col = x.col;
  final hueCol =
      HSVColor.fromAHSV(1.0, (x.t * 360.0) % 360.0, 0.7, 1.0).toColor();
  _halo(x, hueCol, 0.5 + 0.10 * x.wave(3));
  _rays(x,
      count: x.n(18),
      rot: -x.spin(1),
      inner: x.at(0.04),
      outer: x.at(1.0),
      color: col[0],
      halfW: 0.05,
      alpha: 0.6,
      flicker: 0.4,
      k: 3);
  _rays(x,
      count: x.n(9),
      rot: x.spin(2),
      inner: x.at(0.04),
      outer: x.at(0.8),
      color: col[1],
      halfW: 0.08,
      alpha: 0.5,
      k: 2);
  _sweepRing(x,
      radius: x.at(0.13),
      stroke: x.r * 0.16,
      colors: _rainbow(x.t, 0.95),
      rot: x.spin(2));
  _sweepRing(x,
      radius: x.at(0.55),
      stroke: x.r * 0.05,
      colors: _rainbow(1 - x.t, 0.7),
      rot: x.spin(-3));
  _orbitStars(x,
      count: x.n(8),
      radius: x.at(0.78),
      speed: -1,
      size: x.r * 0.1,
      points: 4,
      rainbow: true);
  final rb = _rainbow(x.t, 1.0, n: 6);
  _firework(x, idx: 1, off: 0.0, colors: rb);
  _firework(x, idx: 2, off: 0.33, colors: rb);
  _firework(x, idx: 3, off: 0.66, colors: rb);
  _twinkles(x,
      count: x.n(7), fromF: 0.3, toF: 1.0, k: 3, size: x.r * 0.2, seed: 12);
}

// 9 — SUPREMO: inferno — chamas em 3 camadas + ondas + faíscas.
void _paintSupreme(_Ctx x) {
  final col = x.col;
  _halo(x, col[1], 0.65 + 0.15 * x.wave(4));
  _shock(x, k: 2, off: 0.0, color: col[1], stroke: x.r * 0.06);
  _shock(x, k: 2, off: 0.5, color: col[2], stroke: x.r * 0.05);
  _rays(x,
      count: x.n(14),
      rot: x.spin(1),
      inner: x.at(0.05),
      outer: x.at(1.0),
      color: col[2],
      halfW: 0.04,
      alpha: 0.45,
      flicker: 0.4,
      k: 3);
  _flames(x,
      count: x.n(18),
      baseR: x.r * 0.96,
      height: x.band * 1.0,
      a: col[1],
      b: col[0],
      alpha: 0.9,
      k: 4);
  _flames(x,
      count: x.n(18),
      baseR: x.r * 0.96,
      height: x.band * 0.72,
      a: col[2],
      b: col[1],
      alpha: 0.9,
      k: 3,
      rot: _tau / 36);
  _flames(x,
      count: x.n(18),
      baseR: x.r * 0.96,
      height: x.band * 0.42,
      a: const Color(0xFFFFF3C4),
      b: col[2],
      alpha: 0.95,
      k: 5);
  _outflow(x,
      count: x.n(18),
      from: x.at(0.1),
      to: x.at(1.0),
      k: 3,
      size: x.r * 0.05,
      lift: 0.4,
      seed: 11);
  _bolts(x,
      count: 2,
      r0: x.at(0.08),
      r1: x.at(1.0),
      color: col[2],
      stroke: x.r * 0.035);
  _ring(x, x.at(0.03), x.r * 0.06, col[2], 0.7);
}

// 10 — ELITE: sol supremo — raios duplos + arco-íris + fogos + relâmpagos.
void _paintElite(_Ctx x) {
  final col = x.col;
  _halo(x, col[1], 0.75 + 0.15 * x.wave(3));
  _rays(x,
      count: x.n(24),
      rot: x.spin(1),
      inner: x.at(0.03),
      outer: x.at(1.0),
      color: col[1],
      halfW: 0.045,
      alpha: 0.85,
      flicker: 0.4,
      k: 4);
  _rays(x,
      count: x.n(12),
      rot: -x.spin(2),
      inner: x.at(0.03),
      outer: x.at(0.8),
      color: col[0],
      halfW: 0.08,
      alpha: 0.65,
      flicker: 0.3,
      k: 2);
  _shock(x, k: 2, off: 0.0, color: col[0], stroke: x.r * 0.05);
  _shock(x, k: 2, off: 0.5, color: col[1], stroke: x.r * 0.04);
  _flames(x,
      count: x.n(20),
      baseR: x.r * 0.96,
      height: x.band * 0.42,
      a: col[2],
      b: col[1],
      alpha: 0.85,
      k: 3);
  _sweepRing(x,
      radius: x.at(0.12),
      stroke: x.r * 0.12,
      colors: _rainbow(x.t, 1.0),
      rot: x.spin(3));
  _bolts(x,
      count: 3,
      r0: x.at(0.15),
      r1: x.at(1.0),
      color: col[0],
      stroke: x.r * 0.035);
  final rb = _rainbow(x.t, 1.0, n: 6);
  _firework(x, idx: 1, off: 0.0, colors: rb);
  _firework(x, idx: 2, off: 0.25, colors: rb);
  _firework(x, idx: 3, off: 0.5, colors: rb);
  _firework(x, idx: 4, off: 0.75, colors: rb);
  _orbit(x,
      count: x.n(14),
      radius: x.at(0.55),
      speed: 1,
      size: x.r * 0.055,
      wobble: 0.12,
      wk: 3,
      twinkle: 3,
      colors: rb);
  _twinkles(x,
      count: x.n(8), fromF: 0.3, toF: 1.0, k: 3, size: x.r * 0.22, seed: 3);
  _ring(x, x.at(0.04), x.r * 0.07, col[0], 0.8);
}