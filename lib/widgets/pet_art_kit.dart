import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/pet_config.dart';

// ═══════════════════════════════════════════════════════════════════
// KIT DE DESENHO DOS PETS — 100% CustomPainter, sem imagens
// ═══════════════════════════════════════════════════════════════════
// Todas as criaturas são desenhadas num espaço normalizado [-1, 1]
// (o PetPainter faz translate + scale), então nenhuma forma depende do
// tamanho em pixels. Este kit concentra o acabamento visual que os 30
// pets compartilham: preenchimento em degradê, contorno colorido,
// brilho interno (rim light), halo luminoso, olhos de mascote, chamas,
// estrelas e partículas. Sem blur pesado: os brilhos são gradientes
// radiais e traços translúcidos, baratos de pintar.
//
// `lite` (< 44px): cores chapadas, sem halo/rim/gloss, traço mais grosso.
// `dim`  (pet bloqueado): mesma silhueta em tons escuros e apagados.
// ═══════════════════════════════════════════════════════════════════

const double kPetTau = math.pi * 2;

Color petMix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
Color petDark(Color c, [double t = 0.5]) =>
    Color.lerp(c, const Color(0xFF0B0712), t)!;
Color petLight(Color c, [double t = 0.5]) => Color.lerp(c, Colors.white, t)!;
Offset pt(double x, double y) => Offset(x, y);

double _c01(double v) => v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);

// ───────────────────────────── formas ─────────────────────────────

Path petOval(Offset c, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2));

/// Triângulo com laterais levemente curvas (orelhas, chifres, barbatanas).
/// [bulge] > 0 deixa as laterais convexas; < 0, côncavas.
Path petTri(Offset a, Offset b, Offset tip, {double bulge = 0.12}) {
  final cross = (tip.dx - a.dx) * (b.dy - tip.dy) -
      (tip.dy - a.dy) * (b.dx - tip.dx);
  final sign = cross >= 0 ? 1.0 : -1.0;
  Offset ctrl(Offset p, Offset q) {
    final d = q - p;
    final len = d.distance;
    if (len == 0) return p;
    final n = Offset(d.dy, -d.dx) / len * sign;
    return Offset.lerp(p, q, 0.5)! + n * (len * bulge);
  }

  final c1 = ctrl(a, tip);
  final c2 = ctrl(tip, b);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(c2.dx, c2.dy, b.dx, b.dy)
    ..close();
}

/// Curva suave (Catmull-Rom) passando por todos os pontos.
Path petSpline(List<Offset> p, {bool closed = true, double tension = 1 / 6}) {
  final n = p.length;
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  final last = closed ? n : n - 1;
  for (var i = 0; i < last; i++) {
    final p0 = p[closed ? (i - 1 + n) % n : math.max(i - 1, 0)];
    final p1 = p[i];
    final p2 = p[(i + 1) % n];
    final p3 = p[closed ? (i + 2) % n : math.min(i + 2, n - 1)];
    final c1 = p1 + (p2 - p0) * tension;
    final c2 = p2 - (p3 - p1) * tension;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  if (closed) path.close();
  return path;
}

/// Recebe só o lado direito (primeiro e último ponto no eixo x = 0) e
/// devolve a lista completa simétrica, pronta para [petSpline].
List<Offset> petSym(List<Offset> r) {
  final out = <Offset>[...r];
  for (var i = r.length - 2; i >= 1; i--) {
    out.add(Offset(-r[i].dx, r[i].dy));
  }
  return out;
}

/// Tubo com largura variável ao longo de uma linha central
/// (caudas, tentáculos, pescoços, tromba, serpente).
Path petTube(List<Offset> c, List<double> w) {
  final n = c.length;
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = c[math.max(i - 1, 0)];
    final b = c[math.min(i + 1, n - 1)];
    var d = b - a;
    final len = d.distance;
    d = len == 0 ? const Offset(0, -1) : d / len;
    final nx = Offset(-d.dy, d.dx);
    left.add(c[i] + nx * (w[i] / 2));
    right.add(c[i] - nx * (w[i] / 2));
  }
  return petSpline([...left, ...right.reversed]);
}

/// Forma de pena / folha / pétala: pontiaguda nas duas extremidades.
Path petFeather(Offset base, Offset tip, double width) {
  final d = tip - base;
  final len = d.distance;
  if (len == 0) return Path();
  final n = Offset(-d.dy, d.dx) / len * width;
  final mid = Offset.lerp(base, tip, 0.55)!;
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy)
    ..close();
}

/// Cabeça de mascote: topo arredondado, bochechas largas, queixo suave.
Path petCheekHead(Offset c, double rx, double ry,
    {double cheek = 1.1, double chin = 1.0, double crown = 1.0}) {
  return Path()
    ..moveTo(c.dx, c.dy - ry * crown)
    ..cubicTo(c.dx + rx * 0.66, c.dy - ry * crown, c.dx + rx * cheek,
        c.dy - ry * 0.46, c.dx + rx * cheek, c.dy + ry * 0.16)
    ..cubicTo(c.dx + rx * cheek, c.dy + ry * 0.70, c.dx + rx * 0.6,
        c.dy + ry * chin, c.dx, c.dy + ry * chin)
    ..cubicTo(c.dx - rx * 0.6, c.dy + ry * chin, c.dx - rx * cheek,
        c.dy + ry * 0.70, c.dx - rx * cheek, c.dy + ry * 0.16)
    ..cubicTo(c.dx - rx * cheek, c.dy - ry * 0.46, c.dx - rx * 0.66,
        c.dy - ry * crown, c.dx, c.dy - ry * crown)
    ..close();
}

Path petStar(Offset c, double outer, double inner, int points,
    [double rot = 0]) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outer : inner;
    final a = (i / (points * 2)) * kPetTau + rot - math.pi / 2;
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

// ───────────────────────────── kit ─────────────────────────────

class PetKit {
  final Canvas canvas;
  final PetDef pet;

  /// Fase do ciclo, 0..1. Todo movimento usa múltiplos inteiros dela,
  /// então o loop fecha sem "pulo".
  final double t;
  final bool lite;
  final bool dim;

  const PetKit(this.canvas, this.pet, this.t, this.lite, this.dim);

  Color get pri => pet.primary;
  Color get sec => pet.secondary;
  Color get acc => pet.accent;

  /// Cor do halo luminoso (mistura da cor principal com o destaque).
  Color get hc => petMix(pet.primary, pet.accent, 0.5);

  /// Espessura do contorno no espaço normalizado.
  double get ow => lite ? 0.06 : 0.03;

  /// Mapeia cor para o modo "bloqueado" (tons escuros e apagados).
  Color m(Color c) {
    if (!dim) return c;
    final r = Color.lerp(c, const Color(0xFF151923), 0.8)!;
    return r.withOpacity(r.opacity * 0.62);
  }

  double w(double f, [double ph = 0]) => math.sin(kPetTau * (t * f + ph));

  double loop(double f, [double ph = 0]) {
    final v = t * f + ph;
    return v - v.floorToDouble();
  }

  // ─────────── preenchimento / contorno ───────────

  /// Preenche com degradê vertical, contorno escuro colorido e, se
  /// pedido, halo luminoso + rim light + brilho de gloss.
  void fill(
    Path path,
    Color top,
    Color bot, {
    bool line = true,
    bool glow = false,
    bool gloss = false,
    Color? lineColor,
    double lw = 1,
  }) {
    final b = path.getBounds();
    if (glow) halo(path);
    final paint = Paint();
    if (lite || b.width < 0.01 || b.height < 0.01) {
      paint.color = m(petMix(top, bot, 0.5));
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [m(top), m(bot)],
      ).createShader(b);
    }
    canvas.drawPath(path, paint);
    if (glow && !lite && !dim) rim(path);
    if (gloss && !lite && !dim) shine(path, b);
    if (line) {
      outline(path, lineColor ?? petDark(petMix(bot, top, 0.3), 0.62), lw);
    }
  }

  void flat(Path path, Color col,
      {bool line = false, Color? lineColor, double lw = 1}) {
    canvas.drawPath(path, Paint()..color = m(col));
    if (line) outline(path, lineColor ?? petDark(col, 0.6), lw);
  }

  void outline(Path path, Color col, [double lw = 1]) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ow * lw
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = m(col),
    );
  }

  void stroke(Path path, Color col, double width, {double a = 1}) {
    final mc = m(col);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = a == 1 ? mc : mc.withOpacity(mc.opacity * _c01(a)),
    );
  }

  /// Traço luminoso: faixa larga e translúcida + núcleo fino.
  void glowLine(Path path, Color col, double width, {double a = 1}) {
    if (!lite && !dim) stroke(path, col, width * 2.6, a: 0.18 * a);
    stroke(path, col, width, a: 0.9 * a);
  }

  void oval(Offset c, double rx, double ry, Color top, Color bot,
      {bool line = true,
      bool glow = false,
      bool gloss = false,
      double lw = 1}) {
    fill(petOval(c, rx, ry), top, bot,
        line: line, glow: glow, gloss: gloss, lw: lw);
  }

  void ovalFlat(Offset c, double rx, double ry, Color col,
      {bool line = false}) {
    flat(petOval(c, rx, ry), col, line: line);
  }

  void clipped(Path path, VoidCallback draw) {
    canvas.save();
    canvas.clipPath(path);
    draw();
    canvas.restore();
  }

  /// Forma com a ponta pintada de outra cor (cauda de raposa etc.).
  void fillTip(Path path, Color top, Color bot, Offset tipC, double tipR,
      Color tipCol,
      {bool glow = false}) {
    fill(path, top, bot, line: false, glow: glow);
    clipped(path,
        () => canvas.drawCircle(tipC, tipR, Paint()..color = m(tipCol)));
    outline(path, petDark(petMix(top, bot, 0.3), 0.62));
  }

  // ─────────── brilho (sem blur) ───────────

  void halo(Path path, {Color? color, double a = 1}) {
    if (lite || dim) return;
    final c = color ?? hc;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = ow * 7
        ..color = c.withOpacity(0.10 * a),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = ow * 3.4
        ..color = c.withOpacity(0.22 * a),
    );
  }

  /// Contorno de luz por dentro da silhueta.
  void rim(Path path, {Color? color}) {
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = ow * 3.0
        ..color = petLight(color ?? hc, 0.5).withOpacity(0.42),
    );
    canvas.restore();
  }

  void shine(Path path, Rect b) {
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(b.left + b.width * 0.32, b.top + b.height * 0.22),
        width: b.width * 0.55,
        height: b.height * 0.30,
      ),
      Paint()..color = Colors.white.withOpacity(0.16),
    );
    canvas.restore();
  }

  void soft(Offset o, double r, Color col, double a) {
    if (a <= 0.01 || r <= 0) return;
    final mc = m(col);
    canvas.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [mc.withOpacity(_c01(a)), mc.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void dot(Offset o, double r, Color col, double a) {
    if (a < 0.02 || r <= 0) return;
    if (!lite) soft(o, r * 2.6, col, a * 0.5);
    canvas.drawCircle(o, r, Paint()..color = m(col).withOpacity(_c01(a)));
    canvas.drawCircle(
        o, r * 0.5, Paint()..color = Colors.white.withOpacity(_c01(a * 0.85)));
  }

  /// Brilho em cruz de 4 pontas.
  void sparkle(Offset o, double s, Color col, double a) {
    if (a < 0.03 || s <= 0) return;
    final p = Path()
      ..moveTo(o.dx, o.dy - s)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + s, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + s)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - s, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - s)
      ..close();
    if (!lite) soft(o, s * 1.2, col, a * 0.55);
    canvas.drawPath(
        p, Paint()..color = Colors.white.withOpacity(dim ? a * 0.3 : _c01(a)));
  }

  /// Estrela de 5 pontas preenchida.
  void star(Offset o, double r, Color top, Color bot,
      {double rot = 0, bool line = true}) {
    fill(petStar(o, r, r * 0.46, 5, rot), top, bot, line: line, lw: 0.7);
  }

  /// Chama animada (ponta balança). Ponta para cima; use [flameDown] para baixo.
  void flame(Offset base, double h, double wd, Color a, Color b,
      {double ph = 0, double lean = 0, double alpha = 1, bool core = true}) {
    final sway = w(2, ph) * wd * 0.55 + lean * h;
    Path shape(double hh, double ww) {
      final tx = base.dx + sway * hh / h;
      final ty = base.dy - hh;
      return Path()
        ..moveTo(base.dx - ww, base.dy)
        ..cubicTo(base.dx - ww * 1.15, base.dy - hh * 0.5,
            base.dx + sway * 0.3 - ww * 0.25, base.dy - hh * 0.72, tx, ty)
        ..cubicTo(base.dx + sway * 0.3 + ww * 0.25, base.dy - hh * 0.72,
            base.dx + ww * 1.15, base.dy - hh * 0.5, base.dx + ww, base.dy)
        ..quadraticBezierTo(base.dx, base.dy + ww * 0.7, base.dx - ww, base.dy)
        ..close();
    }

    final outer = shape(h, wd);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            m(a).withOpacity(_c01(alpha)),
            m(b).withOpacity(_c01(alpha * 0.85)),
          ],
        ).createShader(outer.getBounds()),
    );
    if (core && !lite) {
      final inner = shape(h * 0.6, wd * 0.52);
      canvas.drawPath(
        inner,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              m(petLight(b, 0.25)).withOpacity(_c01(alpha)),
              Colors.white.withOpacity(dim ? 0.1 : _c01(alpha * 0.9)),
            ],
          ).createShader(inner.getBounds()),
      );
    }
  }

  void flameDown(Offset base, double h, double wd, Color a, Color b,
      {double ph = 0, double lean = 0, double alpha = 1}) {
    rot(base, math.pi, () {
      flame(base, h, wd, a, b, ph: ph, lean: lean, alpha: alpha);
    });
  }

  // ─────────── transformações ───────────

  /// Desenha [f] e depois o espelho dele no eixo x = 0.
  void both(VoidCallback f) {
    f();
    canvas.save();
    canvas.scale(-1, 1);
    f();
    canvas.restore();
  }

  void rot(Offset pivot, double ang, VoidCallback f) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(ang);
    canvas.translate(-pivot.dx, -pivot.dy);
    f();
    canvas.restore();
  }

  /// Balanço suave em torno de [pivot] (caudas, orelhas, tentáculos).
  void sway(Offset pivot, double amp, VoidCallback f,
      {double freq = 1, double ph = 0}) {
    rot(pivot, w(freq, ph) * amp, f);
  }

  void squash(Offset pivot, double sx, double sy, VoidCallback f) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(sx, sy);
    canvas.translate(-pivot.dx, -pivot.dy);
    f();
    canvas.restore();
  }

  // ─────────── rosto ───────────

  /// Olho de mascote: fundo escuro, íris em degradê, pupila e 2 brilhos.
  void eye(
    Offset o,
    double r, {
    Color iris = const Color(0xFF6B3A1E),
    bool slit = false,
    Offset look = Offset.zero,
    double squash = 1.0,
    bool glowy = false,
  }) {
    if (glowy && !lite && !dim) soft(o, r * 2.6, iris, 0.45);
    final rx = r * 0.9;
    final ry = r * squash;
    canvas.drawOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2),
        Paint()..color = m(const Color(0xFF120C18)));
    final io = o + Offset(look.dx * r * 0.12, look.dy * r * 0.12);
    final irx = rx * 0.78;
    final iry = ry * 0.86;
    final ir = Rect.fromCenter(center: io, width: irx * 2, height: iry * 2);
    final ip = Paint()..color = m(iris);
    if (!lite) {
      ip.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [m(petDark(iris, 0.35)), m(petLight(iris, 0.3))],
      ).createShader(ir);
    }
    canvas.drawOval(ir, ip);
    final pw = slit ? irx * 0.22 : irx * 0.46;
    final ph = slit ? iry * 0.92 : iry * 0.52;
    canvas.drawOval(Rect.fromCenter(center: io, width: pw * 2, height: ph * 2),
        Paint()..color = m(const Color(0xFF0B0710)));
    final hi = Colors.white.withOpacity(dim ? 0.25 : 0.95);
    canvas.drawCircle(Offset(o.dx - r * 0.28, o.dy - r * 0.32), r * 0.26,
        Paint()..color = hi);
    if (!lite) {
      canvas.drawCircle(Offset(o.dx + r * 0.3, o.dy + r * 0.3), r * 0.12,
          Paint()..color = Colors.white.withOpacity(dim ? 0.15 : 0.8));
    }
  }

  void brow(Offset o, double len, double tilt,
      {Color col = const Color(0xFF1B1020), double width = 0.03}) {
    if (lite) return;
    final d = Offset(len / 2, len / 2 * tilt);
    stroke(Path()
      ..moveTo(o.dx - d.dx, o.dy - d.dy)
      ..lineTo(o.dx + d.dx, o.dy + d.dy), col, width);
  }

  void nose(Offset o, double w, [Color col = const Color(0xFF2A1420)]) {
    final p = Path()
      ..moveTo(o.dx - w, o.dy - w * 0.45)
      ..quadraticBezierTo(o.dx, o.dy - w * 0.8, o.dx + w, o.dy - w * 0.45)
      ..quadraticBezierTo(
          o.dx + w * 0.7, o.dy + w * 0.5, o.dx, o.dy + w * 0.8)
      ..quadraticBezierTo(
          o.dx - w * 0.7, o.dy + w * 0.5, o.dx - w, o.dy - w * 0.45)
      ..close();
    flat(p, col);
    if (!lite) {
      canvas.drawCircle(Offset(o.dx - w * 0.3, o.dy - w * 0.25), w * 0.2,
          Paint()..color = Colors.white.withOpacity(dim ? 0.1 : 0.65));
    }
  }

  void mouth(Offset o, double w, {Color col = const Color(0xFF2A1420)}) {
    stroke(
        Path()
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(o.dx - w * 0.25, o.dy + w * 0.55, o.dx - w,
              o.dy + w * 0.25)
          ..moveTo(o.dx, o.dy)
          ..quadraticBezierTo(o.dx + w * 0.25, o.dy + w * 0.55, o.dx + w,
              o.dy + w * 0.25),
        col,
        ow * 0.9);
  }

  void whiskers(Offset o, double len, {Color? col, double spread = 0.07}) {
    if (lite) return;
    final c = col ?? Colors.white.withOpacity(0.75);
    final p = Path();
    for (final s in const [-1.0, 1.0]) {
      for (var i = -1; i <= 1; i++) {
        p.moveTo(o.dx + s * len * 0.12, o.dy + i * spread * 0.3);
        p.quadraticBezierTo(o.dx + s * len * 0.6, o.dy + i * spread * 0.9,
            o.dx + s * len, o.dy + i * spread * 1.7);
      }
    }
    stroke(p, c, ow * 0.45);
  }

  void blush(Offset o, double r, Color col) {
    if (lite) return;
    canvas.drawOval(
        Rect.fromCenter(center: o, width: r * 2.2, height: r * 1.4),
        Paint()..color = m(col).withOpacity(dim ? 0.1 : 0.38));
  }

  /// Par de patinhas (dedinhos discretos).
  void paws(double y, double dx, Color top, Color bot,
      {double rx = 0.12, double ry = 0.08}) {
    for (final s in const [-1.0, 1.0]) {
      oval(pt(s * dx, y), rx, ry, top, bot);
      if (!lite) {
        final p = Path();
        for (final i in const [-1.0, 1.0]) {
          p.moveTo(s * dx + i * rx * 0.36, y + ry * 0.15);
          p.lineTo(s * dx + i * rx * 0.36, y + ry * 0.75);
        }
        stroke(p, petDark(bot, 0.5), ow * 0.6, a: 0.6);
      }
    }
  }

  /// Leque de penas saindo de [root]; ângulo 0 = direita, -π/2 = cima.
  void featherFan(Offset root, double a0, double a1, int n, double len0,
      double len1, double wd, Color top, Color bot,
      {bool glow = false}) {
    for (var i = 0; i < n; i++) {
      final f = n == 1 ? 0.0 : i / (n - 1);
      final a = a0 + (a1 - a0) * f;
      final len = len0 + (len1 - len0) * f;
      final tip = root + Offset(math.cos(a), math.sin(a)) * len;
      fill(petFeather(root, tip, wd), top, bot,
          glow: glow && i == n ~/ 2, lw: 0.8);
    }
  }

  /// Listra/mancha afilada.
  void stripe(Offset a, Offset b, double wd, Color col) {
    flat(petFeather(a, b, wd), col);
  }
}