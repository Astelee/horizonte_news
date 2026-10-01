import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pet_art_kit.dart';

// ═══════════════════════════════════════════════════════════════════
// CRIATURAS ALADAS E AQUÁTICAS
// ═══════════════════════════════════════════════════════════════════

// ───────────────────────────── 2. Coruja Lunar ─────────────────────────────

void drawOwl(PetKit k) {
  final fur = k.pri;
  final deep = petDark(fur, 0.42);
  final belly = petLight(k.sec, 0.5);
  const beak = Color(0xFFFFB300);
  const moonC = Color(0xFFFFF59D);

  final moon = Path.combine(
    PathOperation.difference,
    petOval(pt(-0.66, -0.58), 0.12, 0.12),
    petOval(pt(-0.61, -0.62), 0.11, 0.11),
  );
  k.fill(moon, moonC, const Color(0xFFFFD54F), glow: true, lw: 0.7);

  k.oval(pt(0, 0.24), 0.42, 0.50, petLight(fur, 0.08), deep,
      glow: true, gloss: true);
  final chest = petOval(pt(0, 0.36), 0.26, 0.36);
  k.fill(chest, belly, petMix(belly, fur, 0.35), line: false);
  k.clipped(chest, () {
    final p = Path();
    for (var row = 0; row < 4; row++) {
      for (var i = -1; i <= 1; i++) {
        final x = i * 0.16 + (row.isOdd ? 0.08 : 0.0);
        final y = 0.12 + row * 0.12;
        p.moveTo(x - 0.06, y);
        p.quadraticBezierTo(x, y + 0.07, x + 0.06, y);
      }
    }
    k.stroke(p, petMix(fur, belly, 0.3), 0.018, a: 0.8);
  });

  k.both(() {
    final wing = petSpline([
      pt(0.38, -0.02), pt(0.58, 0.16), pt(0.58, 0.50), pt(0.42, 0.72),
      pt(0.33, 0.40), pt(0.35, 0.10),
    ]);
    k.fill(wing, petMix(fur, deep, 0.4), deep, glow: true);
    final f = Path();
    for (final y in const [0.18, 0.32, 0.46]) {
      f.moveTo(0.38, y);
      f.quadraticBezierTo(0.48, y + 0.06, 0.55, y + 0.02);
    }
    k.stroke(f, petLight(fur, 0.3), 0.016, a: 0.7);
    k.oval(pt(0.14, 0.76), 0.10, 0.05, beak, const Color(0xFFFF8F00));
  });

  k.both(() {
    k.fill(petTri(pt(0.38, -0.34), pt(0.14, -0.50), pt(0.40, -0.84), bulge: 0.08),
        fur, deep, glow: true);
  });
  final head = petCheekHead(pt(0, -0.22), 0.46, 0.32, cheek: 1.0, crown: 0.95);
  k.fill(head, petLight(fur, 0.16), fur, glow: true, gloss: true);
  k.both(() {
    k.oval(pt(0.19, -0.20), 0.22, 0.21, petLight(belly, 0.2), belly, line: false);
  });
  k.outline(head, petDark(deep, 0.4));

  k.eye(pt(-0.19, -0.20), 0.13, iris: const Color(0xFFFFD54F), glowy: true);
  k.eye(pt(0.19, -0.20), 0.13, iris: const Color(0xFFFFD54F), glowy: true);
  k.both(() => k.brow(pt(0.20, -0.38), 0.18, -0.35, col: deep));
  k.fill(petTri(pt(-0.06, -0.12), pt(0.06, -0.12), pt(0, 0.03), bulge: 0.12),
      beak, const Color(0xFFFF8F00), lw: 0.8);
}

// ───────────────────────────── 5. Falcão Solar ─────────────────────────────

void drawFalcon(PetKit k) {
  final gold = k.pri;
  final orange = k.acc;
  final deep = petDark(orange, 0.25);
  final cream = petLight(k.sec, 0.5);
  const dark = Color(0xFF4E342E);
  const beak = Color(0xFFFFE082);

  k.both(() => k.featherFan(pt(0.20, 0.02), -1.75, -0.25, 6, 0.60, 0.62, 0.12,
      gold, deep, glow: true));
  k.featherFan(pt(0, 0.66), 1.25, 1.89, 3, 0.26, 0.26, 0.07, gold, deep);

  final bodyP = petOval(pt(0, 0.30), 0.27, 0.44);
  k.fill(bodyP, petLight(gold, 0.1), orange, glow: true, gloss: true);
  k.clipped(bodyP, () {
    k.ovalFlat(pt(0, 0.34), 0.17, 0.32, cream);
    final p = Path();
    for (final y in const [0.18, 0.30, 0.42]) {
      p.moveTo(-0.12, y);
      p.lineTo(0, y + 0.06);
      p.lineTo(0.12, y);
    }
    k.stroke(p, orange, 0.02, a: 0.7);
  });
  k.fill(petStar(pt(0, 0.55), 0.09, 0.055, 8), const Color(0xFFFFF59D),
      const Color(0xFFFFB300), glow: true, lw: 0.6);
  k.paws(0.76, 0.10, beak, const Color(0xFFFFB300), rx: 0.09, ry: 0.05);

  final head = petCheekHead(pt(0, -0.20), 0.30, 0.27, cheek: 1.0);
  k.fill(head, petLight(gold, 0.18), gold, glow: true, gloss: true);
  k.clipped(head, () {
    k.both(() => k.ovalFlat(pt(0.14, -0.04), 0.12, 0.11, cream));
  });
  k.outline(head, petDark(deep, 0.4));
  k.both(() => k.stripe(pt(0.12, -0.10), pt(0.16, 0.05), 0.03, dark));

  k.eye(pt(-0.12, -0.22), 0.08, iris: const Color(0xFFFFB300));
  k.eye(pt(0.12, -0.22), 0.08, iris: const Color(0xFFFFB300));
  k.both(() => k.brow(pt(0.12, -0.32), 0.12, -0.5, col: dark));
  k.fill(petTri(pt(-0.07, -0.14), pt(0.07, -0.14), pt(0, 0.10), bulge: 0.25),
      beak, const Color(0xFFFFB300), lw: 0.8);
}

// ───────────────────────────── 20. Águia Celestial ─────────────────────────────

void drawEagle(PetKit k) {
  final blue = k.pri;
  final navy = petDark(blue, 0.55);
  final white = k.sec;
  final gold = k.acc;

  k.both(() => k.featherFan(pt(0.20, 0.06), -1.05, 0.55, 7, 0.56, 0.74, 0.13,
      petLight(blue, 0.1), navy, glow: true));
  k.featherFan(pt(0, 0.68), 1.2, 1.94, 3, 0.26, 0.26, 0.08, white, petMix(blue, navy, 0.5));

  final bodyP = petOval(pt(0, 0.32), 0.30, 0.44);
  k.fill(bodyP, petLight(blue, 0.1), navy, glow: true, gloss: true);
  k.clipped(bodyP, () {
    k.ovalFlat(pt(0, 0.34), 0.20, 0.34, white);
    final p = Path();
    for (var row = 0; row < 3; row++) {
      for (var i = -1; i <= 1; i++) {
        final x = i * 0.12 + (row.isOdd ? 0.06 : 0.0);
        final y = 0.18 + row * 0.13;
        p.moveTo(x - 0.05, y);
        p.quadraticBezierTo(x, y + 0.06, x + 0.05, y);
      }
    }
    k.stroke(p, petMix(blue, white, 0.4), 0.016, a: 0.8);
  });
  k.paws(0.78, 0.11, gold, petDark(gold, 0.3), rx: 0.10, ry: 0.055);
  k.both(() => k.sparkle(pt(0.58, -0.06), 0.045, white, 0.9));

  final head = petCheekHead(pt(0, -0.18), 0.30, 0.27, cheek: 1.02);
  k.fill(head, Colors.white, petMix(white, blue, 0.35), glow: true, gloss: true);
  k.eye(pt(-0.12, -0.20), 0.075, iris: const Color(0xFFFFB300));
  k.eye(pt(0.12, -0.20), 0.075, iris: const Color(0xFFFFB300));
  k.both(() => k.brow(pt(0.12, -0.30), 0.15, -0.55, width: 0.04));
  k.fill(petTri(pt(-0.10, -0.12), pt(0.10, -0.12), pt(0.01, 0.12), bulge: 0.22),
      gold, petDark(gold, 0.25), lw: 0.9);
  k.dot(pt(-0.03, -0.07), 0.012, const Color(0xFF4E342E), 0.9);
  k.dot(pt(0.03, -0.07), 0.012, const Color(0xFF4E342E), 0.9);
}

// ───────────────────────────── 27. Corvo Arcano ─────────────────────────────

void drawRaven(PetKit k) {
  final top = petDark(k.pri, 0.25);
  final bot = petDark(k.pri, 0.78);
  final sheen = petMix(k.pri, k.acc, 0.25);

  final rune = Path()
    ..addOval(Rect.fromCenter(center: pt(0, 0.80), width: 0.78, height: 0.14));
  k.glowLine(rune, k.acc, 0.02, a: 0.8);

  k.featherFan(pt(-0.34, 0.40), 2.55, 2.95, 3, 0.50, 0.46, 0.09, top, bot);

  final legs = Path()
    ..moveTo(-0.02, 0.58)..lineTo(-0.02, 0.79)
    ..moveTo(0.14, 0.58)..lineTo(0.12, 0.79);
  k.stroke(legs, const Color(0xFF37474F), 0.035);

  final bodyP = petSpline([
    pt(0.26, -0.06), pt(0.36, 0.18), pt(0.26, 0.46), pt(0.0, 0.62),
    pt(-0.30, 0.58), pt(-0.44, 0.36), pt(-0.36, 0.08), pt(-0.12, -0.10),
  ]);
  k.fill(bodyP, petLight(top, 0.1), bot, glow: true, gloss: true);

  final wing = petSpline([
    pt(0.18, 0.02), pt(0.30, 0.28), pt(0.12, 0.54), pt(-0.20, 0.58),
    pt(-0.40, 0.38), pt(-0.30, 0.10),
  ]);
  k.fill(wing, sheen, bot);
  final f = Path();
  for (final y in const [0.18, 0.30, 0.42]) {
    f.moveTo(0.10, y);
    f.quadraticBezierTo(-0.10, y + 0.08, -0.30, y + 0.04);
  }
  k.stroke(f, petLight(sheen, 0.3), 0.014, a: 0.6);

  k.oval(pt(0.22, -0.26), 0.25, 0.24, petLight(top, 0.12), bot,
      glow: true, gloss: true);
  k.fill(petTri(pt(0.40, -0.36), pt(0.42, -0.16), pt(0.80, -0.22), bulge: 0.12),
      petMix(k.pri, k.sec, 0.35), petDark(k.pri, 0.6), lw: 0.9);
  k.eye(pt(0.28, -0.30), 0.075, iris: k.acc, glowy: true);
  k.sparkle(pt(-0.52, -0.20), 0.05, k.acc, 0.6 + 0.4 * k.w(2));
}

// ───────────────────────────── 13. Fênix Flamejante ─────────────────────────────

void drawPhoenix(PetKit k) {
  final red = petMix(k.pri, k.acc, 0.4);
  final gold = k.sec;
  const beak = Color(0xFFFFB300);

  k.soft(pt(0, 0.2), 0.6, gold, 0.28);

  k.both(() {
    k.featherFan(pt(0.18, 0.06), -1.55, -0.25, 6, 0.56, 0.70, 0.12, gold, red,
        glow: true);
    k.flame(pt(0.50, -0.40), 0.22, 0.055, red, gold, ph: 0.1, lean: 0.1);
    k.flame(pt(0.80, -0.10), 0.22, 0.055, red, gold, ph: 0.35, lean: 0.15);
  });

  k.flameDown(pt(-0.14, 0.66), 0.46, 0.10, red, gold, lean: -0.15, ph: 0.0);
  k.flameDown(pt(0.14, 0.66), 0.46, 0.10, red, gold, lean: 0.15, ph: 0.4);
  k.flameDown(pt(0, 0.70), 0.62, 0.12, k.pri, gold, ph: 0.2);

  final bodyP = petOval(pt(0, 0.30), 0.27, 0.42);
  k.fill(bodyP, petLight(red, 0.1), petDark(red, 0.3), glow: true, gloss: true);
  k.clipped(bodyP, () => k.ovalFlat(pt(0, 0.34), 0.16, 0.30, gold));
  k.outline(bodyP, petDark(red, 0.6));
  k.paws(0.74, 0.10, beak, const Color(0xFFFF8F00), rx: 0.09, ry: 0.05);

  k.flame(pt(0, -0.38), 0.34, 0.08, red, gold, ph: 0.0);
  k.both(() => k.flame(pt(0.10, -0.36), 0.26, 0.065, red, gold, lean: 0.3, ph: 0.3));

  final head = petOval(pt(0, -0.20), 0.25, 0.24);
  k.fill(head, petLight(red, 0.2), red, glow: true, gloss: true);
  k.eye(pt(-0.11, -0.21), 0.07, iris: gold, glowy: true);
  k.eye(pt(0.11, -0.21), 0.07, iris: gold, glowy: true);
  k.fill(petTri(pt(-0.06, -0.12), pt(0.06, -0.12), pt(0, 0.0), bulge: 0.12),
      beak, const Color(0xFFFF8F00), lw: 0.8);
}

// ───────────────────────────── 25. Borboleta Astral ─────────────────────────────

void drawButterfly(PetKit k) {
  final violet = k.pri;
  final pink = k.sec;
  final cyan = k.acc;
  final dark = petDark(violet, 0.5);

  k.squash(pt(0, 0), 0.94 + 0.06 * k.w(2), 1, () {
    k.both(() {
      final upper = petSpline([
        pt(0.06, -0.10), pt(0.30, -0.48), pt(0.62, -0.62), pt(0.80, -0.40),
        pt(0.66, -0.06), pt(0.34, 0.08),
      ]);
      k.fill(upper, petLight(violet, 0.25), petMix(violet, cyan, 0.5), glow: true);
      k.clipped(upper, () {
        k.ovalFlat(pt(0.54, -0.34), 0.10, 0.10, Colors.white.withOpacity(0.55));
        k.ovalFlat(pt(0.36, -0.20), 0.05, 0.05, Colors.white.withOpacity(0.5));
        k.ovalFlat(pt(0.68, -0.18), 0.04, 0.04, pink.withOpacity(0.8));
        final v = Path()
          ..moveTo(0.06, -0.08)..lineTo(0.60, -0.54)
          ..moveTo(0.06, -0.06)..lineTo(0.74, -0.26);
        k.stroke(v, dark, 0.014, a: 0.45);
      });
      k.outline(upper, petDark(violet, 0.65));

      final lower = petSpline([
        pt(0.06, 0.06), pt(0.36, 0.12), pt(0.58, 0.30), pt(0.52, 0.62),
        pt(0.30, 0.66), pt(0.12, 0.40),
      ]);
      k.fill(lower, petMix(pink, violet, 0.3), petMix(violet, cyan, 0.7), glow: true);
      k.clipped(lower, () {
        k.ovalFlat(pt(0.38, 0.44), 0.08, 0.08, Colors.white.withOpacity(0.55));
        k.ovalFlat(pt(0.24, 0.30), 0.04, 0.04, Colors.white.withOpacity(0.5));
      });
      k.outline(lower, petDark(violet, 0.65));
    });
  });

  final bodyP = petTube(
    [pt(0, -0.24), pt(0, 0.0), pt(0, 0.30), pt(0, 0.54)],
    [0.14, 0.16, 0.14, 0.07],
  );
  k.fill(bodyP, petMix(dark, violet, 0.3), petDark(violet, 0.75), glow: true);
  final seg = Path();
  for (final y in const [0.06, 0.16, 0.26, 0.36]) {
    seg.moveTo(-0.06, y);
    seg.quadraticBezierTo(0, y + 0.03, 0.06, y);
  }
  k.stroke(seg, petLight(violet, 0.4), 0.012, a: 0.6);

  k.oval(pt(0, -0.31), 0.13, 0.12, petMix(dark, violet, 0.4), dark, glow: true, gloss: true);
  k.eye(pt(-0.055, -0.31), 0.05, iris: cyan);
  k.eye(pt(0.055, -0.31), 0.05, iris: cyan);
  k.both(() {
    final a = Path()
      ..moveTo(0.04, -0.40)
      ..quadraticBezierTo(0.10, -0.58, 0.24, -0.66);
    k.stroke(a, dark, 0.022);
    k.dot(pt(0.24, -0.66), 0.022, cyan, 0.9);
  });
  k.sparkle(pt(-0.62, -0.30), 0.05, pink, 0.5 + 0.5 * k.w(2));
}

// ───────────────────────────── 10. Tubarão Abissal ─────────────────────────────

void drawShark(PetKit k) {
  final top = k.pri;
  final deep = petDark(k.pri, 0.35);
  final belly = petLight(k.sec, 0.55);

  k.fill(petTri(pt(-0.44, -0.10), pt(-0.50, 0.02), pt(-0.84, -0.54), bulge: 0.15),
      top, deep, glow: true);
  k.fill(petTri(pt(-0.44, 0.0), pt(-0.50, 0.10), pt(-0.76, 0.38), bulge: 0.15),
      top, deep);
  k.fill(petTri(pt(-0.06, -0.28), pt(0.30, -0.28), pt(-0.02, -0.76), bulge: 0.14),
      top, deep, glow: true);

  final bodyP = petSpline([
    pt(0.74, 0.02), pt(0.52, -0.22), pt(0.14, -0.34), pt(-0.26, -0.26),
    pt(-0.52, -0.08), pt(-0.26, 0.16), pt(0.14, 0.30), pt(0.52, 0.24),
  ]);
  k.fill(bodyP, top, belly, glow: true, gloss: true);
  k.fill(petTri(pt(0.14, 0.20), pt(0.40, 0.22), pt(0.0, 0.58), bulge: 0.14),
      top, deep);

  final gills = Path();
  for (final x in const [0.10, 0.18, 0.26]) {
    gills.moveTo(x, -0.10);
    gills.quadraticBezierTo(x - 0.03, 0.0, x, 0.10);
  }
  k.stroke(gills, deep, 0.018, a: 0.7);

  final mouthP = Path()
    ..moveTo(0.70, 0.07)
    ..quadraticBezierTo(0.56, 0.17, 0.40, 0.14);
  k.stroke(mouthP, petDark(deep, 0.5), 0.022);
  for (var i = 0; i < 4; i++) {
    final x = 0.64 - i * 0.065;
    final y = 0.07 + (0.70 - x) * 0.2;
    k.flat(petTri(pt(x, y), pt(x + 0.05, y - 0.005), pt(x + 0.025, y + 0.05),
        bulge: 0), Colors.white);
  }

  k.eye(pt(0.50, -0.07), 0.075, iris: k.acc, glowy: true);
  k.blush(pt(0.40, 0.06), 0.045, const Color(0xFFFF8AB5));
  for (final p in const [Offset(0.34, 0.20), Offset(0.14, 0.26), Offset(-0.08, 0.22), Offset(-0.28, 0.12)]) {
    k.dot(p, 0.014, k.acc, 0.8);
  }
}

// ───────────────────────────── 11. Golfinho Azul ─────────────────────────────

void drawDolphin(PetKit k) {
  final top = k.pri;
  final deep = petDark(k.pri, 0.35);
  final belly = petLight(k.sec, 0.5);

  for (final r in const [0.46, 0.34]) {
    final ring = Path()
      ..addOval(Rect.fromCenter(center: pt(0, 0.80), width: r * 2, height: r * 0.30));
    k.glowLine(ring, k.acc, 0.014, a: r > 0.4 ? 0.5 : 0.8);
  }

  k.oval(pt(0.70, -0.08), 0.15, 0.055, petMix(belly, top, 0.3), belly);
  k.fill(petTri(pt(-0.30, -0.02), pt(0.02, -0.10), pt(-0.26, -0.40), bulge: 0.15),
      top, deep, glow: true);
  k.fill(petTri(pt(-0.62, 0.36), pt(-0.56, 0.46), pt(-0.86, 0.32), bulge: 0.12),
      top, deep);
  k.fill(petTri(pt(-0.62, 0.40), pt(-0.55, 0.47), pt(-0.50, 0.70), bulge: 0.12),
      top, deep);

  final bodyP = petTube(
    [pt(-0.60, 0.42), pt(-0.40, 0.18), pt(-0.10, 0.0), pt(0.22, -0.10), pt(0.52, -0.12)],
    [0.08, 0.22, 0.32, 0.30, 0.20],
  );
  k.fill(bodyP, top, belly, glow: true, gloss: true);
  k.fill(petTri(pt(0.10, 0.12), pt(0.30, 0.05), pt(0.05, 0.42), bulge: 0.14),
      top, deep);

  k.eye(pt(0.54, -0.16), 0.06, iris: const Color(0xFF0D47A1));
  final smile = Path()
    ..moveTo(0.82, -0.06)
    ..quadraticBezierTo(0.66, 0.0, 0.52, -0.03);
  k.stroke(smile, petDark(deep, 0.5), 0.02);
  k.blush(pt(0.44, -0.04), 0.04, const Color(0xFFFF8AB5));
  for (final p in const [Offset(-0.10, 0.30), Offset(0.12, 0.34), Offset(0.34, 0.14)]) {
    k.dot(p, 0.014, k.acc, 0.7 + 0.3 * k.w(2));
  }
}

// ───────────────────────────── 16. Kraken Cósmico ─────────────────────────────

void drawKraken(PetKit k) {
  final top = k.pri;
  final deep = petDark(k.pri, 0.4);
  final pink = k.sec;

  const order = [0, 5, 1, 4, 2, 3];
  for (final i in order) {
    final x0 = -0.35 + i * 0.14;
    final s = x0 < 0 ? -1.0 : 1.0;
    k.sway(pt(x0, 0.14), 0.07, () {
      final c = [
        pt(x0, 0.14),
        pt(x0 * 1.25, 0.40),
        pt(x0 * 1.7 + s * 0.05, 0.60),
        pt(x0 * 1.7 + s * 0.15, 0.72),
      ];
      k.fill(petTube(c, [0.16, 0.14, 0.10, 0.03]), petLight(top, 0.1), deep, glow: true);
      k.ovalFlat(c[1], 0.022, 0.022, pink.withOpacity(0.8));
      k.ovalFlat(pt(c[2].dx, c[2].dy - 0.03), 0.018, 0.018, pink.withOpacity(0.8));
    }, ph: i * 0.17);
  }

  final dome = petOval(pt(0, -0.18), 0.48, 0.42);
  k.fill(dome, petLight(top, 0.18), deep, glow: true, gloss: true);
  k.clipped(dome, () {
    k.ovalFlat(pt(0.20, -0.40), 0.05, 0.05, pink.withOpacity(0.35));
    k.ovalFlat(pt(-0.30, -0.26), 0.04, 0.04, pink.withOpacity(0.3));
  });
  k.sparkle(pt(-0.22, -0.42), 0.05, k.acc, 0.6 + 0.4 * k.w(2));
  k.sparkle(pt(0.22, -0.44), 0.04, k.acc, 0.6 + 0.4 * k.w(2, 0.5));
  k.sparkle(pt(0, -0.34), 0.035, Colors.white, 0.9);

  k.eye(pt(-0.19, -0.10), 0.11, iris: k.acc, glowy: true);
  k.eye(pt(0.19, -0.10), 0.11, iris: k.acc, glowy: true);
  k.both(() => k.brow(pt(0.19, -0.26), 0.16, -0.35, col: deep));
  k.mouth(pt(0, 0.05), 0.09, col: petDark(deep, 0.4));
  k.blush(pt(-0.34, 0.02), 0.06, const Color(0xFFFF8AB5));
  k.blush(pt(0.34, 0.02), 0.06, const Color(0xFFFF8AB5));
}

// ───────────────────────────── 26. Tartaruga Cósmica ─────────────────────────────

void drawTurtle(PetKit k) {
  final shellTop = petLight(k.pri, 0.1);
  final shellBot = petDark(k.pri, 0.4);
  final skin = petMix(k.sec, k.pri, 0.2);
  final skinD = petDark(skin, 0.3);

  k.oval(pt(-0.34, 0.42), 0.13, 0.10, skinD, petDark(skinD, 0.3));
  k.oval(pt(0.26, 0.44), 0.13, 0.10, skinD, petDark(skinD, 0.3));
  k.fill(petTri(pt(-0.54, 0.20), pt(-0.54, 0.32), pt(-0.76, 0.32), bulge: 0.12),
      skin, skinD);

  k.oval(pt(0.02, 0.27), 0.58, 0.09, petLight(k.sec, 0.4), skin);
  final shell = petSpline([
    pt(-0.54, 0.24), pt(-0.50, -0.04), pt(-0.30, -0.32), pt(0.04, -0.44),
    pt(0.36, -0.32), pt(0.54, -0.04), pt(0.58, 0.24),
  ]);
  k.fill(shell, shellTop, shellBot, glow: true, gloss: true);
  k.clipped(shell, () {
    const c = Offset(0.04, -0.10);
    final hex = Path();
    final lines = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      final v = c + Offset(math.cos(a), math.sin(a)) * 0.17;
      final e = c + Offset(math.cos(a), math.sin(a)) * 0.7;
      if (i == 0) {
        hex.moveTo(v.dx, v.dy);
      } else {
        hex.lineTo(v.dx, v.dy);
      }
      lines.moveTo(v.dx, v.dy);
      lines.lineTo(e.dx, e.dy);
    }
    hex.close();
    k.stroke(lines, k.acc, 0.02, a: 0.55);
    k.glowLine(hex, k.acc, 0.022, a: 0.9);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      k.dot(c + Offset(math.cos(a), math.sin(a)) * 0.17, 0.014, k.acc, 0.8 + 0.2 * k.w(2, i / 6));
    }
  });
  k.outline(shell, petDark(shellBot, 0.5));

  k.oval(pt(0.54, 0.18), 0.14, 0.12, skin, skinD);
  k.oval(pt(0.66, 0.10), 0.20, 0.17, petLight(skin, 0.15), skin, glow: true, gloss: true);
  k.eye(pt(0.72, 0.05), 0.055, iris: const Color(0xFF33691E));
  final smile = Path()
    ..moveTo(0.74, 0.15)
    ..quadraticBezierTo(0.68, 0.20, 0.60, 0.16);
  k.stroke(smile, petDark(skinD, 0.5), 0.016);
  k.blush(pt(0.62, 0.12), 0.035, const Color(0xFFFF8AB5));
  k.sparkle(pt(-0.62, -0.38), 0.05, k.acc, 0.5 + 0.5 * k.w(2));
}

// ───────────────────────────── 22. Serpente Astral ─────────────────────────────

void drawSerpent(PetKit k) {
  final top = petLight(k.pri, 0.1);
  final deep = petDark(k.pri, 0.45);
  final belly = petLight(k.sec, 0.4);
  final gold = k.acc;

  final c = [
    pt(0.62, 0.58), pt(0.38, 0.80), pt(-0.10, 0.85), pt(-0.50, 0.72),
    pt(-0.58, 0.48), pt(-0.36, 0.32), pt(0.0, 0.30), pt(0.30, 0.22),
    pt(0.38, 0.0), pt(0.28, -0.18), pt(0.10, -0.28),
  ];
  const w = [0.03, 0.10, 0.18, 0.24, 0.26, 0.26, 0.26, 0.24, 0.22, 0.20, 0.19];
  final bodyP = petTube(c, w);
  k.fill(bodyP, top, deep, glow: true, gloss: true);
  k.clipped(bodyP, () {
    for (var i = 1; i < c.length - 1; i++) {
      k.ovalFlat(c[i], w[i] * 0.2, w[i] * 0.13, gold.withOpacity(0.6));
      k.ovalFlat(c[i] + Offset(0, w[i] * 0.3), w[i] * 0.3, w[i] * 0.08,
          belly.withOpacity(0.7));
    }
  });
  k.outline(bodyP, petDark(deep, 0.4));
  k.sparkle(pt(-0.50, 0.58), 0.045, gold, 0.5 + 0.5 * k.w(2));
  k.sparkle(pt(0.34, 0.60), 0.04, gold, 0.5 + 0.5 * k.w(2, 0.4));

  final hood = petOval(pt(0.08, -0.26), 0.36, 0.32);
  k.fill(hood, petMix(top, deep, 0.5), deep, glow: true);
  k.glowLine(
      Path()..addArc(Rect.fromCenter(center: pt(0.08, -0.26), width: 0.58, height: 0.52), 0.5, 2.1),
      gold, 0.02, a: 0.8);

  final head = petOval(pt(0.08, -0.30), 0.25, 0.21);
  k.fill(head, petLight(top, 0.12), top, glow: true, gloss: true);
  k.eye(pt(-0.03, -0.34), 0.075, iris: gold, slit: true, glowy: true);
  k.eye(pt(0.19, -0.34), 0.075, iris: gold, slit: true, glowy: true);
  k.mouth(pt(0.08, -0.20), 0.07, col: petDark(deep, 0.5));
  final tongue = Path()
    ..moveTo(0.08, -0.17)
    ..lineTo(0.08, -0.08)
    ..moveTo(0.08, -0.08)
    ..lineTo(0.04, -0.04)
    ..moveTo(0.08, -0.08)
    ..lineTo(0.12, -0.04);
  k.stroke(tongue, const Color(0xFFFF5252), 0.016);
}