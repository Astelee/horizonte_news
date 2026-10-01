import 'package:flutter/material.dart';
import 'pet_art_kit.dart';

// ═══════════════════════════════════════════════════════════════════
// CRIATURAS MÍTICAS
// ═══════════════════════════════════════════════════════════════════

Path _pear({double top = 0.12, double bot = 0.81, double w = 0.34}) {
  final h = bot - top;
  return petSpline(petSym([
    pt(0, top),
    pt(w * 0.66, top + 0.03),
    pt(w, top + h * 0.42),
    pt(w, top + h * 0.75),
    pt(w * 0.62, bot - 0.01),
    pt(0, bot),
  ]));
}

// ───────────────────────── 12 e 30. Dragões ─────────────────────────
// Mesma anatomia, acabamento diferente: o Rubi é vermelho com brasas;
// o Cósmico é índigo com asas de nebulosa, antenas de luz e juba de aurora.

void drawDragon(PetKit k) => _dragon(k, cosmic: false);
void drawCosmicDragon(PetKit k) => _dragon(k, cosmic: true);

void _dragon(PetKit k, {required bool cosmic}) {
  final body1 = cosmic ? petMix(const Color(0xFF2B1E7A), k.acc, 0.22) : k.pri;
  final body2 = petDark(body1, 0.45);
  final belly = cosmic ? k.pri : petLight(k.sec, 0.55);
  final wingA = cosmic ? petMix(k.sec, k.acc, 0.35) : petMix(k.pri, k.acc, 0.3);
  final wingB = cosmic ? petDark(k.acc, 0.35) : petDark(k.pri, 0.5);
  final eyeC = cosmic ? petLight(k.sec, 0.2) : const Color(0xFFFFD54F);
  final horn = cosmic ? petLight(k.sec, 0.4) : const Color(0xFFFFE0B2);

  // cauda
  k.sway(pt(0.2, 0.70), 0.07, () {
    final tail = petTube(
      [pt(0.18, 0.70), pt(0.46, 0.82), pt(0.70, 0.72), pt(0.82, 0.50)],
      [0.18, 0.18, 0.14, 0.07],
    );
    k.fill(tail, petLight(body1, 0.06), body2, glow: true);
    if (cosmic) {
      k.flame(pt(0.82, 0.48), 0.28, 0.08, k.pri, const Color(0xFFFFE082));
    } else {
      k.fill(petTri(pt(0.74, 0.52), pt(0.90, 0.48), pt(0.90, 0.28), bulge: 0.1),
          k.acc, petDark(k.acc, 0.3), glow: true);
    }
  });

  // asas
  k.both(() {
    k.rot(pt(0.20, 0.04), k.w(1) * 0.04, () {
      final wing = Path()
        ..moveTo(0.20, 0.04)
        ..quadraticBezierTo(0.44, -0.64, 0.90, -0.66)
        ..quadraticBezierTo(0.78, -0.52, 0.84, -0.32)
        ..quadraticBezierTo(0.70, -0.30, 0.70, -0.10)
        ..quadraticBezierTo(0.56, -0.14, 0.50, 0.06)
        ..quadraticBezierTo(0.34, 0.12, 0.20, 0.10)
        ..close();
      k.fill(wing, wingA, wingB, glow: true);
      final bones = Path()
        ..moveTo(0.22, 0.04)..lineTo(0.90, -0.66)
        ..moveTo(0.22, 0.05)..lineTo(0.84, -0.32)
        ..moveTo(0.22, 0.06)..lineTo(0.70, -0.10);
      k.stroke(bones, petDark(wingB, 0.3), 0.024);
      if (cosmic) {
        k.clipped(wing, () {
          for (final p in const [
            Offset(0.56, -0.30), Offset(0.74, -0.46), Offset(0.46, -0.12),
            Offset(0.70, -0.24), Offset(0.34, -0.20),
          ]) {
            k.sparkle(p, 0.03, Colors.white, 0.9);
          }
        });
      }
    });
  });

  // corpo
  final body = _pear();
  k.fill(body, petLight(body1, 0.08), body2, glow: true, gloss: true);
  k.clipped(body, () {
    k.ovalFlat(pt(0, 0.50), 0.16, 0.27, belly);
    final bands = Path();
    for (final y in const [0.36, 0.48, 0.60, 0.72]) {
      bands.moveTo(-0.16, y);
      bands.quadraticBezierTo(0, y + 0.05, 0.16, y);
    }
    k.stroke(bands, petDark(belly, 0.35), 0.016, a: 0.6);
    if (cosmic) {
      for (final p in const [Offset(0.24, 0.30), Offset(-0.26, 0.44), Offset(0.22, 0.62)]) {
        k.dot(p, 0.014, Colors.white, 0.9);
      }
    }
  });
  k.paws(0.78, 0.13, body1, body2);

  // chifres / antenas
  k.both(() {
    k.fill(petTube([pt(0.18, -0.40), pt(0.30, -0.60), pt(0.46, -0.78)],
        [0.11, 0.08, 0.02]), horn, petMix(horn, body1, 0.5), glow: true);
    if (cosmic) {
      k.fill(petTube([pt(0.28, -0.58), pt(0.44, -0.58), pt(0.56, -0.66)],
          [0.06, 0.05, 0.015]), horn, petMix(horn, body1, 0.5));
      k.dot(pt(0.46, -0.78), 0.026, k.sec, 0.8 + 0.2 * k.w(2));
      k.dot(pt(0.56, -0.66), 0.02, k.sec, 0.8 + 0.2 * k.w(2, 0.5));
    }
    k.fill(petTri(pt(0.38, -0.10), pt(0.40, 0.06), pt(0.62, -0.06), bulge: 0.1),
        k.acc, petDark(k.acc, 0.35), glow: true);
  });

  // crista
  if (cosmic) {
    k.flame(pt(0, -0.44), 0.34, 0.07, k.acc, k.sec);
    k.both(() => k.flame(pt(0.09, -0.43), 0.26, 0.06, k.pri, k.acc, lean: 0.3, ph: 0.3));
  } else {
    k.fill(petTri(pt(-0.06, -0.46), pt(0.06, -0.46), pt(0, -0.62), bulge: 0.1),
        k.acc, petDark(k.acc, 0.3), glow: true);
  }

  // cabeça
  final head = petCheekHead(pt(0, -0.14), 0.42, 0.35, cheek: 1.08);
  k.fill(head, petLight(body1, 0.14), body1, glow: true, gloss: true);
  k.oval(pt(0, 0.07), 0.19, 0.12, petLight(belly, 0.1), petMix(belly, body1, 0.3));
  k.dot(pt(-0.07, 0.04), 0.012, body2, 0.9);
  k.dot(pt(0.07, 0.04), 0.012, body2, 0.9);

  k.eye(pt(-0.17, -0.15), 0.085, iris: eyeC, slit: true, glowy: true);
  k.eye(pt(0.17, -0.15), 0.085, iris: eyeC, slit: true, glowy: true);
  k.both(() => k.brow(pt(0.17, -0.27), 0.15, -0.5, col: body2));
  k.mouth(pt(0, 0.11), 0.08, col: body2);
  k.both(() => k.flat(
      petTri(pt(0.05, 0.13), pt(0.085, 0.13), pt(0.067, 0.18), bulge: 0),
      Colors.white));

  if (cosmic) {
    k.both(() {
      final whisk = Path()
        ..moveTo(0.18, 0.08)
        ..quadraticBezierTo(0.42, 0.10, 0.52, 0.28);
      k.glowLine(whisk, k.sec, 0.02);
      k.dot(pt(0.52, 0.28), 0.018, k.sec, 0.9);
    });
    k.sparkle(pt(0, -0.31), 0.05, Colors.white, 0.95);
  } else {
    final u = k.loop(1);
    k.both(() {
      k.soft(pt(0.10 + u * 0.10, 0.02 - u * 0.20), 0.03 + 0.04 * u,
          const Color(0xFFB0BEC5), 0.35 * (1 - u));
    });
  }
}

// ───────────────────────── 14. Unicórnio Prismático ─────────────────────────

void drawUnicorn(PetKit k) {
  const rainbow = [
    Color(0xFFFF6E9C), Color(0xFFFFB74D), Color(0xFFFFEE58),
    Color(0xFF69F0AE), Color(0xFF4FC3F7), Color(0xFFB388FF),
  ];
  const white = Colors.white;
  final bot = petLight(k.pri, 0.75);
  const hoof = Color(0xFFFFD54F);

  k.sway(pt(0.2, 0.70), 0.09, () {
    for (var i = 0; i < 3; i++) {
      final o = i * 0.05;
      k.fill(petTube(
          [pt(0.18, 0.70 - o), pt(0.46 + o, 0.80), pt(0.68 + o, 0.66), pt(0.74 + o, 0.40)],
          [0.12, 0.14, 0.12, 0.03]), rainbow[i * 2], petDark(rainbow[i * 2], 0.15),
          lw: 0.8);
    }
  });

  final body = _pear(w: 0.30);
  k.fill(body, white, bot, glow: true, gloss: true);
  k.paws(0.78, 0.12, hoof, const Color(0xFFFFA000), rx: 0.10, ry: 0.07);

  k.both(() {
    for (var i = 0; i < 5; i++) {
      final c = rainbow[i];
      k.fill(petTube([
        pt(0.16 + 0.03 * i, -0.44),
        pt(0.40 + 0.02 * i, -0.30 + 0.04 * i),
        pt(0.52 + 0.02 * i, -0.04 + 0.12 * i),
        pt(0.46 + 0.02 * i, 0.24 + 0.10 * i),
      ], [0.10, 0.12, 0.11, 0.03]), petLight(c, 0.2), c, lw: 0.7);
    }
  });

  k.both(() {
    k.fill(petTri(pt(0.26, -0.36), pt(0.10, -0.46), pt(0.28, -0.70), bulge: 0.08),
        white, bot);
    k.fill(petTri(pt(0.22, -0.42), pt(0.13, -0.47), pt(0.25, -0.62), bulge: 0.06),
        const Color(0xFFF8BBD0), const Color(0xFFE1A0C0), line: false);
  });

  final hornP = petTri(pt(-0.07, -0.42), pt(0.07, -0.42), pt(0, -0.98), bulge: 0.05);
  k.fill(hornP, const Color(0xFFFFF59D), const Color(0xFFFFB300), glow: true);
  k.clipped(hornP, () {
    final s = Path();
    for (final y in const [-0.50, -0.60, -0.70, -0.80]) {
      s.moveTo(-0.08, y + 0.04);
      s.lineTo(0.08, y - 0.04);
    }
    k.stroke(s, const Color(0xFFFF8F00), 0.02, a: 0.8);
  });

  final head = petCheekHead(pt(0, -0.12), 0.34, 0.40, cheek: 1.0, chin: 0.95);
  k.fill(head, white, bot, glow: true, gloss: true);
  k.oval(pt(0, 0.15), 0.21, 0.15, white, petMix(bot, k.pri, 0.2), glow: false);
  k.dot(pt(-0.07, 0.17), 0.013, petDark(k.pri, 0.5), 0.9);
  k.dot(pt(0.07, 0.17), 0.013, petDark(k.pri, 0.5), 0.9);

  k.eye(pt(-0.16, -0.14), 0.095, iris: petMix(k.pri, k.sec, 0.4), glowy: true);
  k.eye(pt(0.16, -0.14), 0.095, iris: petMix(k.pri, k.sec, 0.4), glowy: true);
  k.both(() {
    final l = Path()
      ..moveTo(0.24, -0.20)..lineTo(0.30, -0.25)
      ..moveTo(0.25, -0.15)..lineTo(0.32, -0.17);
    k.stroke(l, const Color(0xFF1B1020), 0.02);
  });
  k.blush(pt(-0.27, 0.04), 0.06, const Color(0xFFFF8AB5));
  k.blush(pt(0.27, 0.04), 0.06, const Color(0xFFFF8AB5));
  k.mouth(pt(0, 0.22), 0.06, col: petDark(k.pri, 0.5));
}

// ───────────────────────── 15. Grifo Dourado ─────────────────────────

void drawGriffin(PetKit k) {
  final amber = k.pri;
  final deep = petDark(amber, 0.4);
  final cream = k.sec;
  final glow = k.acc;
  const talon = Color(0xFFFFD54F);

  k.both(() => k.featherFan(pt(0.20, 0.08), -1.7, -0.25, 6, 0.58, 0.66, 0.12,
      petLight(amber, 0.2), deep, glow: true));

  k.sway(pt(0.2, 0.72), 0.08, () {
    k.fill(petTube([pt(0.18, 0.72), pt(0.46, 0.82), pt(0.68, 0.70)],
        [0.09, 0.10, 0.08]), amber, deep, lw: 0.9);
    k.oval(pt(0.72, 0.66), 0.10, 0.12, glow, petDark(glow, 0.25), glow: true);
  });

  final body = _pear(w: 0.33);
  k.fill(body, petLight(amber, 0.1), deep, glow: true, gloss: true);
  k.both(() => k.oval(pt(0.36, 0.74), 0.11, 0.07, amber, deep));
  k.clipped(body, () => k.ovalFlat(pt(0, 0.52), 0.14, 0.26, petMix(cream, amber, 0.3)));

  for (var i = -3; i <= 3; i++) {
    final x = i * 0.075;
    k.fill(petFeather(pt(x, 0.08), pt(x * 1.15, 0.30 - (i.abs()) * 0.012), 0.05),
        Colors.white, petMix(cream, amber, 0.4), lw: 0.7);
  }
  k.paws(0.78, 0.12, talon, const Color(0xFFFFA000), rx: 0.10, ry: 0.06);

  k.both(() {
    k.fill(petTri(pt(0.24, -0.38), pt(0.08, -0.46), pt(0.36, -0.74), bulge: 0.1),
        amber, deep, glow: true);
  });
  final head = petCheekHead(pt(0, -0.18), 0.33, 0.30, cheek: 1.0);
  k.fill(head, Colors.white, petMix(cream, amber, 0.35), glow: true, gloss: true);

  k.eye(pt(-0.13, -0.22), 0.08, iris: const Color(0xFFFFA000), glowy: true);
  k.eye(pt(0.13, -0.22), 0.08, iris: const Color(0xFFFFA000), glowy: true);
  k.both(() => k.brow(pt(0.13, -0.33), 0.15, -0.55, col: deep, width: 0.04));
  k.fill(petTri(pt(-0.11, -0.13), pt(0.11, -0.13), pt(0.01, 0.14), bulge: 0.22),
      talon, const Color(0xFFFF8F00), lw: 0.9);
}

// ───────────────────────── 17. Tiranossauro Ancestral ─────────────────────────

void drawDinosaur(PetKit k) {
  final top = k.pri;
  final deep = petDark(k.pri, 0.38);
  final belly = k.sec;
  final glow = k.acc;

  k.sway(pt(-0.34, 0.40), 0.05, () {
    final tail = petTube(
      [pt(-0.34, 0.40), pt(-0.58, 0.52), pt(-0.78, 0.44), pt(-0.88, 0.26)],
      [0.30, 0.22, 0.14, 0.04],
    );
    k.fill(tail, top, deep, glow: true);
  });

  for (var i = 0; i < 5; i++) {
    final t = i / 4;
    final b = Offset.lerp(pt(0.10, -0.18), pt(-0.38, 0.20), t)!;
    k.fill(petTri(pt(b.dx - 0.05, b.dy - 0.01), pt(b.dx + 0.05, b.dy - 0.02),
        pt(b.dx - 0.02, b.dy - 0.15), bulge: 0.1),
        petLight(glow, 0.2), petDark(glow, 0.2), glow: true, lw: 0.8);
  }

  final bodyP = petSpline([
    pt(0.28, -0.20), pt(0.32, 0.10), pt(0.28, 0.42), pt(0.06, 0.62),
    pt(-0.24, 0.66), pt(-0.46, 0.50), pt(-0.42, 0.26), pt(-0.18, 0.02),
    pt(0.06, -0.18),
  ]);
  k.fill(bodyP, petLight(top, 0.1), deep, glow: true, gloss: true);
  k.clipped(bodyP, () {
    k.ovalFlat(pt(0.12, 0.38), 0.26, 0.26, belly);
    final g = Path()
      ..moveTo(-0.34, 0.20)
      ..quadraticBezierTo(-0.24, 0.10, -0.14, 0.22)
      ..moveTo(-0.38, 0.38)
      ..quadraticBezierTo(-0.26, 0.28, -0.14, 0.40);
    k.glowLine(g, glow, 0.02, a: 0.8);
  });
  k.outline(bodyP, petDark(deep, 0.4));

  k.oval(pt(0.02, 0.52), 0.22, 0.22, petLight(top, 0.05), deep, glow: true);
  k.oval(pt(0.14, 0.78), 0.20, 0.065, top, deep);
  for (final x in const [0.26, 0.31, 0.36]) {
    k.flat(petTri(pt(x, 0.775), pt(x + 0.03, 0.775), pt(x + 0.045, 0.84), bulge: 0),
        Colors.white);
  }
  k.oval(pt(0.36, 0.18), 0.08, 0.04, top, deep);
  k.oval(pt(0.30, 0.24), 0.07, 0.035, top, deep);

  final jaw = petSpline([
    pt(0.42, -0.10), pt(0.72, -0.10), pt(0.76, 0.02), pt(0.52, 0.07), pt(0.38, 0.0),
  ]);
  k.fill(jaw, belly, petMix(belly, top, 0.5));
  final upper = petSpline([
    pt(0.28, -0.50), pt(0.58, -0.52), pt(0.80, -0.38), pt(0.84, -0.20),
    pt(0.70, -0.14), pt(0.44, -0.12), pt(0.26, -0.20),
  ]);
  k.fill(upper, petLight(top, 0.14), top, glow: true, gloss: true);
  for (final x in const [0.48, 0.57, 0.66, 0.75]) {
    k.flat(petTri(pt(x, -0.135), pt(x + 0.045, -0.135), pt(x + 0.022, -0.085), bulge: 0),
        Colors.white, line: true, lineColor: deep, lw: 0.5);
  }
  k.eye(pt(0.52, -0.34), 0.075, iris: const Color(0xFFD4E157), glowy: true);
  k.brow(pt(0.52, -0.45), 0.14, 0.45, col: deep);
  k.dot(pt(0.77, -0.32), 0.012, deep, 0.9);
  k.blush(pt(0.56, -0.22), 0.04, const Color(0xFFFF8AB5));
}

// ───────────────────────── 21. Pégaso Lunar ─────────────────────────

void drawPegasus(PetKit k) {
  final body1 = k.pri;
  final top = Colors.white;
  final deep = petDark(k.pri, 0.35);
  final glow = k.acc;
  const hoof = Color(0xFFFFD54F);

  k.featherFan(pt(-0.12, 0.08), -2.5, -1.0, 6, 0.62, 0.74, 0.12, k.sec,
      petMix(k.sec, body1, 0.6), glow: true);

  k.sway(pt(-0.60, 0.20), 0.07, () {
    k.fill(petTube([pt(-0.60, 0.20), pt(-0.78, 0.34), pt(-0.80, 0.58), pt(-0.70, 0.80)],
        [0.10, 0.16, 0.14, 0.03]), k.sec, petMix(glow, body1, 0.4), glow: true);
  });

  for (final x in const [-0.40, 0.04]) {
    k.fill(petTube([pt(x, 0.50), pt(x, 0.82)], [0.12, 0.09]), body1, deep, lw: 0.9);
    k.oval(pt(x, 0.84), 0.06, 0.03, hoof, const Color(0xFFFFA000), lw: 0.7);
  }

  final bodyP = petSpline([
    pt(-0.54, 0.10), pt(-0.20, 0.02), pt(0.12, 0.10), pt(0.26, 0.34),
    pt(0.14, 0.56), pt(-0.30, 0.62), pt(-0.58, 0.50), pt(-0.64, 0.28),
  ]);
  k.fill(bodyP, top, petMix(k.sec, body1, 0.5), glow: true, gloss: true);
  final moon = Path.combine(
    PathOperation.difference,
    petOval(pt(-0.24, 0.34), 0.07, 0.07),
    petOval(pt(-0.21, 0.32), 0.06, 0.06),
  );
  k.flat(moon, glow, line: true, lineColor: deep, lw: 0.5);

  for (final x in const [-0.28, 0.18]) {
    k.fill(petTube([pt(x, 0.50), pt(x, 0.84)], [0.12, 0.09]), top, body1, lw: 0.9);
    k.oval(pt(x, 0.86), 0.06, 0.03, hoof, const Color(0xFFFFA000), lw: 0.7);
  }

  k.fill(petTube([pt(0.02, 0.30), pt(0.14, 0.04), pt(0.26, -0.20), pt(0.34, -0.36)],
      [0.40, 0.34, 0.28, 0.24]), top, petMix(k.sec, body1, 0.4), glow: true);

  k.sway(pt(0.1, -0.5), 0.04, () {
    k.fill(petTube([pt(0.12, -0.50), pt(-0.02, -0.30), pt(-0.14, 0.0), pt(-0.20, 0.30)],
        [0.12, 0.20, 0.22, 0.08]), k.sec, glow, glow: true, lw: 0.8);
    k.fill(petTube([pt(0.16, -0.46), pt(0.04, -0.26), pt(-0.06, 0.04)],
        [0.07, 0.12, 0.05]), Colors.white, k.sec, line: false);
  }, freq: 2);

  final head = petSpline([
    pt(0.18, -0.46), pt(0.44, -0.54), pt(0.62, -0.40), pt(0.78, -0.16),
    pt(0.78, -0.04), pt(0.64, 0.0), pt(0.44, -0.04), pt(0.26, -0.14),
    pt(0.12, -0.28),
  ]);
  k.fill(petTri(pt(0.20, -0.50), pt(0.36, -0.54), pt(0.26, -0.82), bulge: 0.1),
      top, body1, glow: true);
  k.fill(head, top, petMix(k.sec, body1, 0.4), glow: true, gloss: true);
  k.eye(pt(0.46, -0.34), 0.075, iris: const Color(0xFF00897B), glowy: true);
  k.dot(pt(0.73, -0.10), 0.012, deep, 0.9);
  final smile = Path()
    ..moveTo(0.76, -0.03)
    ..quadraticBezierTo(0.68, 0.0, 0.62, -0.02);
  k.stroke(smile, deep, 0.016);
  k.blush(pt(0.52, -0.18), 0.045, const Color(0xFFFF8AB5));
  k.sparkle(pt(0.56, -0.74), 0.05, glow, 0.5 + 0.5 * k.w(2));
}