import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pet_art_kit.dart';

// ═══════════════════════════════════════════════════════════════════
// CRIATURAS TERRESTRES — desenhadas em espaço normalizado [-1, 1]
// Ordem de pintura: cauda → corpo → patas → orelhas → cabeça → rosto.
// ═══════════════════════════════════════════════════════════════════

/// Corpo sentado em forma de pera (cabeça fica por cima).
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

// ───────────────────────────── 1. Raposa ─────────────────────────────

void drawFox(PetKit k) {
  final orange = k.pri;
  final deep = petDark(orange, 0.28);
  final cream = petLight(k.sec, 0.62);
  const brown = Color(0xFF4A2315);

  k.sway(pt(0.2, 0.62), 0.08, () {
    final tail = petSpline([
      pt(0.16, 0.68), pt(0.44, 0.72), pt(0.68, 0.54), pt(0.80, 0.24),
      pt(0.74, -0.08), pt(0.60, 0.08), pt(0.50, 0.24), pt(0.36, 0.38),
      pt(0.22, 0.44),
    ]);
    k.fillTip(tail, petLight(orange, 0.08), deep, pt(0.76, -0.04), 0.21,
        cream, glow: true);
  });

  final body = _pear();
  k.fill(body, petLight(orange, 0.05), deep, glow: true, gloss: true);
  k.clipped(body, () => k.ovalFlat(pt(0, 0.49), 0.17, 0.27, cream));
  k.paws(0.78, 0.13, brown, petDark(brown, 0.3));

  k.both(() {
    k.fill(petTri(pt(0.44, -0.20), pt(0.10, -0.50), pt(0.42, -0.88),
        bulge: 0.1), brown, orange, glow: true);
    k.fill(petTri(pt(0.36, -0.27), pt(0.18, -0.44), pt(0.39, -0.74),
        bulge: 0.08), cream, petMix(cream, orange, 0.5), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.43, 0.35, cheek: 1.14);
  k.fill(head, petLight(orange, 0.12), orange, glow: true, gloss: true);
  k.clipped(head, () {
    k.ovalFlat(pt(-0.27, 0.07), 0.23, 0.15, cream);
    k.ovalFlat(pt(0.27, 0.07), 0.23, 0.15, cream);
    k.ovalFlat(pt(0, 0.10), 0.17, 0.13, cream);
  });
  k.outline(head, petDark(deep, 0.4));

  k.eye(pt(-0.17, -0.13), 0.085, iris: const Color(0xFFFFB300));
  k.eye(pt(0.17, -0.13), 0.085, iris: const Color(0xFFFFB300));
  k.nose(pt(0, 0.07), 0.05);
  k.mouth(pt(0, 0.11), 0.08);
  k.sparkle(pt(0, -0.31), 0.05, k.sec, 0.95);
}

// ───────────────────────────── 3. Gato Estelar ─────────────────────────────

void drawCat(PetKit k) {
  final fur = k.pri;
  final deep = petDark(fur, 0.32);
  final belly = petLight(k.sec, 0.55);
  const gold = Color(0xFFFFE082);

  k.sway(pt(0.2, 0.7), 0.09, () {
    final tail = petTube(
      [pt(0.18, 0.70), pt(0.46, 0.78), pt(0.68, 0.62), pt(0.74, 0.36), pt(0.62, 0.14)],
      [0.18, 0.17, 0.15, 0.14, 0.12],
    );
    k.fill(tail, fur, deep, glow: true);
    k.star(pt(0.60, 0.10), 0.10, const Color(0xFFFFF59D), const Color(0xFFFFB300));
  });

  final body = _pear();
  k.fill(body, petLight(fur, 0.06), deep, glow: true, gloss: true);
  k.clipped(body, () => k.ovalFlat(pt(0, 0.50), 0.16, 0.27, belly));
  k.star(pt(0, 0.52), 0.085, const Color(0xFFFFF59D), const Color(0xFFFFB300));
  k.paws(0.78, 0.13, belly, petMix(belly, fur, 0.5));

  k.both(() {
    k.fill(petTri(pt(0.42, -0.22), pt(0.12, -0.48), pt(0.38, -0.82), bulge: 0.08),
        fur, deep, glow: true);
    k.fill(petTri(pt(0.35, -0.29), pt(0.19, -0.45), pt(0.36, -0.70), bulge: 0.06),
        const Color(0xFFF8BBD0), const Color(0xFFE1A0C0), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.43, 0.35, cheek: 1.06);
  k.fill(head, petLight(fur, 0.14), fur, glow: true, gloss: true);
  k.clipped(head, () => k.ovalFlat(pt(0, 0.10), 0.17, 0.12, belly));
  k.outline(head, petDark(deep, 0.4));

  k.star(pt(0, -0.34), 0.05, const Color(0xFFFFF59D), gold);
  k.star(pt(-0.13, -0.30), 0.03, const Color(0xFFFFF59D), gold);
  k.star(pt(0.13, -0.30), 0.03, const Color(0xFFFFF59D), gold);

  k.eye(pt(-0.17, -0.12), 0.09, iris: const Color(0xFFFFD54F), slit: true);
  k.eye(pt(0.17, -0.12), 0.09, iris: const Color(0xFFFFD54F), slit: true);
  k.nose(pt(0, 0.06), 0.04, const Color(0xFFE57399));
  k.mouth(pt(0, 0.095), 0.07);
  k.blush(pt(-0.30, 0.05), 0.06, const Color(0xFFFF8AB5));
  k.blush(pt(0.30, 0.05), 0.06, const Color(0xFFFF8AB5));
  k.whiskers(pt(0, 0.08), 0.30);
}

// ───────────────────────────── 4. Lobo Boreal ─────────────────────────────

void drawWolf(PetKit k) {
  final fur = petMix(const Color(0xFF6D7F92), k.pri, 0.22);
  final deep = petDark(fur, 0.35);
  final light = petMix(const Color(0xFFDCE6EC), k.sec, 0.35);

  k.sway(pt(0.2, 0.7), 0.07, () {
    final tail = petTube(
      [pt(0.16, 0.70), pt(0.44, 0.80), pt(0.68, 0.70), pt(0.78, 0.52)],
      [0.20, 0.24, 0.20, 0.10],
    );
    k.fillTip(tail, fur, deep, pt(0.78, 0.52), 0.14, light, glow: true);
  });

  final body = _pear(w: 0.36);
  k.fill(body, petLight(fur, 0.1), deep, glow: true, gloss: true);
  k.paws(0.78, 0.14, light, petMix(light, fur, 0.5));

  final ruff = Path()
    ..moveTo(-0.44, 0.16)
    ..lineTo(-0.54, 0.34)
    ..lineTo(-0.32, 0.30)
    ..lineTo(-0.30, 0.50)
    ..lineTo(-0.13, 0.40)
    ..lineTo(0, 0.56)
    ..lineTo(0.13, 0.40)
    ..lineTo(0.30, 0.50)
    ..lineTo(0.32, 0.30)
    ..lineTo(0.54, 0.34)
    ..lineTo(0.44, 0.16)
    ..close();
  k.fill(ruff, light, petMix(light, fur, 0.3), glow: true);

  k.both(() {
    k.fill(petTri(pt(0.40, -0.20), pt(0.12, -0.50), pt(0.36, -0.92), bulge: 0.08),
        petLight(fur, 0.05), deep, glow: true);
    k.fill(petTri(pt(0.33, -0.28), pt(0.18, -0.46), pt(0.34, -0.76), bulge: 0.06),
        petDark(fur, 0.5), petDark(fur, 0.7), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.42, 0.35, cheek: 1.12);
  k.fill(head, petLight(fur, 0.14), fur, glow: true, gloss: true);
  k.clipped(head, () {
    k.ovalFlat(pt(-0.25, 0.08), 0.22, 0.16, light);
    k.ovalFlat(pt(0.25, 0.08), 0.22, 0.16, light);
    k.ovalFlat(pt(0, 0.09), 0.17, 0.14, light);
  });
  k.outline(head, petDark(deep, 0.4));

  k.eye(pt(-0.17, -0.14), 0.085, iris: k.acc, glowy: true);
  k.eye(pt(0.17, -0.14), 0.085, iris: k.acc, glowy: true);
  k.both(() => k.brow(pt(0.17, -0.25), 0.14, -0.5));
  k.nose(pt(0, 0.02), 0.055, const Color(0xFF1C2A36));
  k.mouth(pt(0, 0.09), 0.09);
  k.both(() => k.flat(
      petTri(pt(0.035, 0.125), pt(0.07, 0.125), pt(0.05, 0.185), bulge: 0),
      Colors.white));
  k.sparkle(pt(0, -0.33), 0.055, k.acc, 0.95);
}

// ───────────────────────────── 6. Coelho Celeste ─────────────────────────────

void drawRabbit(PetKit k) {
  final fur = k.pri;
  final deep = petMix(k.pri, k.sec, 0.75);
  const pink = Color(0xFFFFC1E3);

  k.oval(pt(0.30, 0.70), 0.13, 0.12, Colors.white, petLight(deep, 0.3));

  final body = _pear(w: 0.33);
  k.fill(body, Colors.white, deep, glow: true, gloss: true);
  k.paws(0.78, 0.12, Colors.white, petLight(deep, 0.3), rx: 0.11);

  k.both(() {
    k.sway(pt(0.17, -0.36), 0.05, () {
      k.fill(petTube([pt(0.17, -0.36), pt(0.24, -0.64), pt(0.30, -0.92)],
          [0.17, 0.20, 0.10]), Colors.white, deep, glow: true);
      k.fill(petTube([pt(0.17, -0.38), pt(0.24, -0.63), pt(0.29, -0.86)],
          [0.08, 0.11, 0.04]), pink, petMix(pink, deep, 0.4), line: false);
    });
  });

  final head = petCheekHead(pt(0, -0.10), 0.42, 0.34, cheek: 1.06);
  k.fill(head, Colors.white, petLight(deep, 0.25), glow: true, gloss: true);

  k.eye(pt(-0.17, -0.10), 0.09, iris: const Color(0xFF2E9C96));
  k.eye(pt(0.17, -0.10), 0.09, iris: const Color(0xFF2E9C96));
  k.nose(pt(0, 0.04), 0.035, const Color(0xFFF48FB1));
  k.mouth(pt(0, 0.075), 0.06);
  k.oval(pt(-0.022, 0.135), 0.024, 0.032, Colors.white, petLight(deep, 0.4), line: false);
  k.oval(pt(0.022, 0.135), 0.024, 0.032, Colors.white, petLight(deep, 0.4), line: false);
  k.blush(pt(-0.29, 0.05), 0.065, const Color(0xFFFF8AB5));
  k.blush(pt(0.29, 0.05), 0.065, const Color(0xFFFF8AB5));
  k.star(pt(0, -0.30), 0.05, const Color(0xFFB2EBF2), k.acc);
  k.star(pt(0, 0.50), 0.07, const Color(0xFFB2EBF2), k.acc);
}

// ───────────────────────────── 7. Tigre Esmeralda ─────────────────────────────

void drawTiger(PetKit k) {
  final fur = k.pri;
  final deep = petDark(fur, 0.3);
  final dark = petDark(fur, 0.72);
  final cream = petLight(k.sec, 0.7);

  k.sway(pt(0.2, 0.7), 0.08, () {
    final tail = petTube(
      [pt(0.18, 0.70), pt(0.48, 0.80), pt(0.72, 0.66), pt(0.80, 0.40)],
      [0.17, 0.18, 0.16, 0.12],
    );
    k.fillTip(tail, fur, deep, pt(0.80, 0.40), 0.10, dark, glow: true);
    k.clipped(tail, () {
      final p = Path()
        ..moveTo(0.42, 0.70)..lineTo(0.46, 0.92)
        ..moveTo(0.58, 0.66)..lineTo(0.64, 0.88)
        ..moveTo(0.72, 0.52)..lineTo(0.86, 0.60);
      k.stroke(p, dark, 0.05);
    });
  });

  final body = _pear(w: 0.36);
  k.fill(body, petLight(fur, 0.08), deep, glow: true, gloss: true);
  k.clipped(body, () {
    k.ovalFlat(pt(0, 0.52), 0.15, 0.26, cream);
    for (final y in const [0.34, 0.48, 0.62]) {
      k.both(() => k.stripe(pt(0.42, y), pt(0.19, y + 0.04), 0.035, dark));
    }
  });
  k.paws(0.78, 0.13, fur, deep);

  k.both(() {
    k.oval(pt(0.33, -0.40), 0.13, 0.12, fur, deep, glow: true);
    k.oval(pt(0.33, -0.39), 0.07, 0.065, cream, petMix(cream, fur, 0.5), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.43, 0.35, cheek: 1.15);
  k.fill(head, petLight(fur, 0.14), fur, glow: true, gloss: true);
  k.clipped(head, () {
    k.ovalFlat(pt(-0.14, 0.10), 0.14, 0.11, cream);
    k.ovalFlat(pt(0.14, 0.10), 0.14, 0.11, cream);
    k.ovalFlat(pt(0, 0.17), 0.10, 0.07, cream);
    k.stripe(pt(0, -0.48), pt(0, -0.30), 0.03, dark);
    k.both(() {
      k.stripe(pt(0.14, -0.46), pt(0.11, -0.31), 0.028, dark);
      k.stripe(pt(0.52, 0.0), pt(0.34, 0.03), 0.03, dark);
      k.stripe(pt(0.52, 0.11), pt(0.36, 0.11), 0.03, dark);
    });
  });
  k.outline(head, petDark(deep, 0.4));

  k.eye(pt(-0.17, -0.13), 0.085, iris: const Color(0xFFFFEE58), glowy: true);
  k.eye(pt(0.17, -0.13), 0.085, iris: const Color(0xFFFFEE58), glowy: true);
  k.both(() => k.brow(pt(0.17, -0.25), 0.14, -0.4));
  k.nose(pt(0, 0.05), 0.05, const Color(0xFFE57399));
  k.mouth(pt(0, 0.09), 0.09);
  k.whiskers(pt(0, 0.09), 0.26);
}

// ───────────────────────────── 8. Cervo Encantado ─────────────────────────────

void drawDeer(PetKit k) {
  final fur = petMix(k.pri, const Color(0xFFC89F7A), 0.45);
  final deep = petDark(fur, 0.3);
  final cream = petLight(k.sec, 0.55);
  const orb = Color(0xFFFFE57F);

  k.both(() {
    final main = Path()
      ..moveTo(0.15, -0.42)
      ..quadraticBezierTo(0.27, -0.66, 0.29, -0.93);
    final b1 = Path()
      ..moveTo(0.24, -0.62)
      ..quadraticBezierTo(0.40, -0.66, 0.50, -0.82);
    final b2 = Path()
      ..moveTo(0.19, -0.52)
      ..quadraticBezierTo(0.36, -0.52, 0.47, -0.60);
    for (final p in [main, b1, b2]) {
      k.stroke(p, orb, 0.13, a: 0.16);
      k.stroke(p, petDark(fur, 0.55), 0.065);
      k.stroke(p, cream, 0.038);
    }
    final a = 0.75 + 0.25 * k.w(2);
    k.dot(pt(0.29, -0.93), 0.03, orb, a);
    k.dot(pt(0.50, -0.82), 0.026, orb, a);
    k.dot(pt(0.47, -0.60), 0.024, orb, a);
  });

  final body = _pear(w: 0.32);
  k.fill(body, petLight(fur, 0.06), deep, glow: true, gloss: true);
  k.clipped(body, () {
    k.ovalFlat(pt(0, 0.52), 0.14, 0.26, cream);
    for (final p in const [
      Offset(0.20, 0.30), Offset(-0.12, 0.40), Offset(0.24, 0.52),
      Offset(-0.22, 0.58), Offset(0.06, 0.70),
    ]) {
      k.ovalFlat(p, 0.03, 0.03, cream);
    }
  });
  k.paws(0.78, 0.12, const Color(0xFF5D4037), const Color(0xFF3E2723),
      rx: 0.10, ry: 0.07);

  k.both(() {
    k.fill(petFeather(pt(0.30, -0.28), pt(0.66, -0.46), 0.10), fur, deep, glow: true);
    k.fill(petFeather(pt(0.33, -0.29), pt(0.58, -0.43), 0.055),
        const Color(0xFFF8BBD0), const Color(0xFFE1A0C0), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.36, 0.36, cheek: 1.0, chin: 0.96);
  k.fill(head, petLight(fur, 0.14), fur, glow: true, gloss: true);
  k.clipped(head, () => k.ovalFlat(pt(0, 0.12), 0.18, 0.14, cream));
  k.outline(head, petDark(deep, 0.4));

  k.eye(pt(-0.15, -0.15), 0.09, iris: const Color(0xFF5D4037));
  k.eye(pt(0.15, -0.15), 0.09, iris: const Color(0xFF5D4037));
  k.nose(pt(0, 0.06), 0.06, const Color(0xFF3E2723));
  k.mouth(pt(0, 0.11), 0.07);
  k.blush(pt(-0.27, 0.0), 0.055, const Color(0xFFFF8AB5));
  k.blush(pt(0.27, 0.0), 0.055, const Color(0xFFFF8AB5));
  k.sparkle(pt(0, -0.34), 0.05, orb, 0.95);
}

// ───────────────────────────── 9. Urso Ártico ─────────────────────────────

void drawBear(PetKit k) {
  final top = k.sec;
  final bot = k.pri;
  final ice = k.acc;

  final body = _pear(top: 0.10, w: 0.40);
  k.fill(body, top, bot, glow: true, gloss: true);
  k.paws(0.77, 0.17, top, petMix(top, bot, 0.6), rx: 0.15, ry: 0.09);
  k.sparkle(pt(0, 0.46), 0.08, ice, 0.95);

  k.both(() {
    final crystal = Path()
      ..moveTo(0.40, 0.22)
      ..lineTo(0.46, 0.08)
      ..lineTo(0.53, 0.22)
      ..lineTo(0.46, 0.38)
      ..close();
    k.fill(crystal, const Color(0xCCE1F5FE), const Color(0xCC64B5F6), glow: true);
    k.oval(pt(0.33, -0.40), 0.12, 0.11, top, bot, glow: true);
    k.oval(pt(0.33, -0.39), 0.065, 0.06, const Color(0xFFCFD8DC),
        const Color(0xFF9FB4BE), line: false);
  });

  final head = petCheekHead(pt(0, -0.10), 0.42, 0.35, cheek: 1.04);
  k.fill(head, top, petMix(top, bot, 0.7), glow: true, gloss: true);
  k.oval(pt(0, 0.07), 0.18, 0.13, Colors.white, petMix(top, bot, 0.3), line: false);

  k.eye(pt(-0.19, -0.12), 0.075, iris: const Color(0xFF37474F));
  k.eye(pt(0.19, -0.12), 0.075, iris: const Color(0xFF37474F));
  k.nose(pt(0, 0.01), 0.06, const Color(0xFF263238));
  k.mouth(pt(0, 0.08), 0.08);
  k.blush(pt(-0.30, 0.04), 0.06, const Color(0xFF90CAF9));
  k.blush(pt(0.30, 0.04), 0.06, const Color(0xFF90CAF9));
}

// ───────────────────────────── 18. Leão Imperial ─────────────────────────────

void drawLion(PetKit k) {
  final mc = pt(0, -0.10);
  const tan = Color(0xFFFFCC80);
  final orange = k.pri;
  final deepTan = petMix(const Color(0xFFFFA726), orange, 0.4);

  k.sway(pt(0.2, 0.72), 0.08, () {
    k.fill(petTube([pt(0.18, 0.72), pt(0.46, 0.82), pt(0.68, 0.70)],
        [0.09, 0.10, 0.08]), tan, deepTan, lw: 0.9);
    k.oval(pt(0.72, 0.66), 0.10, 0.12, k.acc, petDark(orange, 0.2), glow: true);
  });

  final body = _pear(top: 0.22, w: 0.34);
  k.fill(body, tan, deepTan, glow: true, gloss: true);
  k.paws(0.78, 0.13, tan, deepTan);

  k.soft(mc, 0.92, k.acc, 0.32);
  k.rot(mc, k.w(1) * 0.03, () {
    k.fill(petStar(mc, 0.72, 0.57, 12), k.acc, petDark(orange, 0.25),
        glow: true);
  });
  k.rot(mc, -k.w(1) * 0.03, () {
    k.fill(petStar(mc, 0.63, 0.50, 12, math.pi / 12), petLight(k.sec, 0.25),
        petMix(k.acc, orange, 0.5));
  });

  k.both(() {
    k.oval(pt(0.36, -0.36), 0.10, 0.09, tan, deepTan);
    k.oval(pt(0.36, -0.36), 0.05, 0.045, const Color(0xFFF8BBD0),
        const Color(0xFFE1A0C0), line: false);
  });

  final face = petOval(pt(0, -0.08), 0.33, 0.30);
  k.fill(face, petLight(tan, 0.3), tan, glow: true, gloss: true);
  k.clipped(face, () {
    k.ovalFlat(pt(-0.12, 0.07), 0.13, 0.10, petLight(k.sec, 0.75));
    k.ovalFlat(pt(0.12, 0.07), 0.13, 0.10, petLight(k.sec, 0.75));
  });
  k.outline(face, petDark(deepTan, 0.5));

  k.eye(pt(-0.15, -0.14), 0.075, iris: const Color(0xFFFFA000));
  k.eye(pt(0.15, -0.14), 0.075, iris: const Color(0xFFFFA000));
  k.both(() => k.brow(pt(0.15, -0.24), 0.13, -0.4));
  k.nose(pt(0, 0.0), 0.055, const Color(0xFF8D4B3A));
  k.mouth(pt(0, 0.05), 0.08);

  final crown = Path()
    ..moveTo(-0.16, -0.82)
    ..lineTo(-0.17, -0.95)
    ..lineTo(-0.085, -0.89)
    ..lineTo(0, -0.97)
    ..lineTo(0.085, -0.89)
    ..lineTo(0.17, -0.95)
    ..lineTo(0.16, -0.82)
    ..close();
  k.fill(crown, const Color(0xFFFFF59D), const Color(0xFFFFB300), glow: true);
  k.dot(pt(0, -0.88), 0.02, const Color(0xFFFF5252), 1);
  k.dot(pt(-0.095, -0.915), 0.016, const Color(0xFF40C4FF), 1);
  k.dot(pt(0.095, -0.915), 0.016, const Color(0xFF40C4FF), 1);
}

// ───────────────────────────── 19. Pantera Sombria ─────────────────────────────

void drawPanther(PetKit k) {
  final top = petDark(k.pri, 0.45);
  final bot = petDark(k.pri, 0.78);
  final lilac = petMix(top, k.sec, 0.3);
  final eyeC = petLight(k.acc, 0.2);

  k.sway(pt(0.2, 0.74), 0.08, () {
    final tail = petTube(
      [pt(0.18, 0.74), pt(0.52, 0.84), pt(0.78, 0.66), pt(0.80, 0.36), pt(0.66, 0.14)],
      [0.13, 0.13, 0.11, 0.10, 0.07],
    );
    k.fill(tail, top, bot, glow: true);
    k.flame(pt(0.66, 0.14), 0.26, 0.07, k.acc, petLight(k.sec, 0.2));
  });

  final body = _pear(top: 0.14, w: 0.30);
  k.fill(body, top, bot, glow: true, gloss: true);
  k.sparkle(pt(0, 0.50), 0.07, eyeC, 0.95);
  k.paws(0.78, 0.12, top, bot, rx: 0.11);

  k.both(() {
    k.fill(petTri(pt(0.36, -0.26), pt(0.10, -0.50), pt(0.30, -0.92), bulge: 0.08),
        top, bot, glow: true);
    k.fill(petTri(pt(0.29, -0.34), pt(0.15, -0.49), pt(0.28, -0.76), bulge: 0.06),
        petMix(k.acc, bot, 0.3), petDark(k.acc, 0.6), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.40, 0.33, cheek: 1.04);
  k.fill(head, petLight(top, 0.1), bot, glow: true, gloss: true);
  k.clipped(head, () => k.ovalFlat(pt(0, 0.09), 0.18, 0.12, lilac));
  k.outline(head, petDark(bot, 0.3));

  k.eye(pt(-0.16, -0.13), 0.085, iris: eyeC, slit: true, glowy: true);
  k.eye(pt(0.16, -0.13), 0.085, iris: eyeC, slit: true, glowy: true);
  k.nose(pt(0, 0.05), 0.04, k.acc);
  k.mouth(pt(0, 0.085), 0.07, col: petLight(k.sec, 0.3));
  k.whiskers(pt(0, 0.08), 0.30, col: petLight(k.sec, 0.4).withOpacity(0.8));
}

// ───────────────────────────── 24. Guaxinim Nebuloso ─────────────────────────────

void drawRaccoon(PetKit k) {
  final fur = k.pri;
  final deep = petDark(fur, 0.3);
  final light = k.sec;
  const mask = Color(0xFF263238);

  k.sway(pt(0.2, 0.7), 0.08, () {
    final tail = petTube(
      [pt(0.18, 0.70), pt(0.46, 0.82), pt(0.70, 0.72), pt(0.80, 0.50)],
      [0.20, 0.22, 0.20, 0.16],
    );
    k.fillTip(tail, light, petMix(light, fur, 0.5), pt(0.80, 0.50), 0.12,
        mask, glow: true);
    k.clipped(tail, () {
      final p = Path()
        ..moveTo(0.38, 0.66)..lineTo(0.44, 0.96)
        ..moveTo(0.54, 0.62)..lineTo(0.62, 0.92)
        ..moveTo(0.68, 0.52)..lineTo(0.88, 0.66);
      k.stroke(p, mask, 0.07, a: 0.85);
    });
  });

  final body = _pear(w: 0.36);
  k.fill(body, petLight(fur, 0.08), deep, glow: true, gloss: true);
  k.clipped(body, () => k.ovalFlat(pt(0, 0.52), 0.16, 0.27, light));
  k.star(pt(0, 0.52), 0.07, petLight(k.acc, 0.4), k.acc);
  k.paws(0.78, 0.13, mask, petDark(mask, 0.3));

  k.both(() {
    k.fill(petTri(pt(0.44, -0.02), pt(0.42, 0.14), pt(0.60, 0.13), bulge: 0.1),
        light, fur);
    k.oval(pt(0.30, -0.44), 0.12, 0.12, fur, deep, glow: true);
    k.oval(pt(0.30, -0.44), 0.07, 0.07, mask, petDark(mask, 0.3), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.42, 0.35, cheek: 1.12);
  k.fill(head, petLight(fur, 0.16), fur, glow: true, gloss: true);
  k.clipped(head, () {
    k.ovalFlat(pt(0, 0.08), 0.30, 0.20, light);
    k.stripe(pt(0, -0.50), pt(0, -0.20), 0.05, light);
  });
  final maskPath = petSpline(petSym([
    pt(0, -0.20), pt(0.17, -0.24), pt(0.36, -0.17), pt(0.44, -0.04),
    pt(0.30, 0.04), pt(0.14, -0.03), pt(0, -0.05),
  ]));
  k.flat(maskPath, mask);
  k.outline(head, petDark(deep, 0.4));

  k.eye(pt(-0.19, -0.12), 0.075, iris: const Color(0xFFFFD54F));
  k.eye(pt(0.19, -0.12), 0.075, iris: const Color(0xFFFFD54F));
  k.oval(pt(0, 0.10), 0.13, 0.09, Colors.white, light, line: false);
  k.nose(pt(0, 0.06), 0.05, const Color(0xFF1C1C24));
  k.mouth(pt(0, 0.11), 0.07);
  k.whiskers(pt(0, 0.10), 0.28);
}

// ───────────────────────────── 23. Kitsune de Fogo ─────────────────────────────

void drawKitsune(PetKit k) {
  final cream = petLight(k.sec, 0.72);
  const white = Color(0xFFFFF8F0);
  final red = k.acc;
  const gold = Color(0xFFFFD54F);

  k.both(() {
    k.flame(pt(0.24, 0.70), 0.60, 0.17, red, gold, lean: 0.8, ph: 0.0);
    k.flame(pt(0.14, 0.74), 0.82, 0.18, k.pri, const Color(0xFFFFE082),
        lean: 0.5, ph: 0.25);
  });

  final body = _pear();
  k.fill(body, white, cream, glow: true, gloss: true);
  k.clipped(body, () => k.ovalFlat(pt(0, 0.50), 0.14, 0.26, Colors.white));
  k.paws(0.78, 0.13, petDark(red, 0.45), petDark(red, 0.7));

  k.both(() {
    k.fill(petTri(pt(0.44, -0.20), pt(0.10, -0.50), pt(0.42, -0.90), bulge: 0.1),
        red, cream, glow: true);
    k.fill(petTri(pt(0.36, -0.27), pt(0.18, -0.44), pt(0.39, -0.74), bulge: 0.08),
        const Color(0xFFFFE0E0), const Color(0xFFFFC1C8), line: false);
  });

  final head = petCheekHead(pt(0, -0.14), 0.43, 0.35, cheek: 1.14);
  k.fill(head, Colors.white, cream, glow: true, gloss: true);
  k.clipped(head, () {
    k.both(() {
      k.stripe(pt(0.52, 0.0), pt(0.32, 0.05), 0.035, red);
      k.stripe(pt(0.50, 0.11), pt(0.33, 0.12), 0.03, red);
    });
  });
  k.outline(head, petDark(cream, 0.5));

  k.fill(petStar(pt(0, -0.34), 0.075, 0.03, 4), red, petDark(red, 0.2),
      glow: true, lw: 0.6);
  k.eye(pt(-0.17, -0.12), 0.085, iris: const Color(0xFFFF6E40), slit: true, glowy: true);
  k.eye(pt(0.17, -0.12), 0.085, iris: const Color(0xFFFF6E40), slit: true, glowy: true);
  k.nose(pt(0, 0.07), 0.045);
  k.mouth(pt(0, 0.11), 0.08);
}

// ───────────────────────────── 29. Cão Celestial ─────────────────────────────

void drawCelestialHound(PetKit k) {
  final gold = k.pri;
  final cream = k.sec;
  final deep = petDark(gold, 0.3);

  k.sway(pt(0.22, 0.70), 0.22, () {
    final tail = petTube(
      [pt(0.20, 0.72), pt(0.48, 0.76), pt(0.68, 0.58), pt(0.72, 0.36)],
      [0.14, 0.15, 0.13, 0.10],
    );
    k.fillTip(tail, gold, deep, pt(0.72, 0.36), 0.11, cream, glow: true);
  }, freq: 2);

  final body = _pear(w: 0.35);
  k.fill(body, petLight(gold, 0.08), deep, glow: true, gloss: true);
  k.clipped(body, () => k.ovalFlat(pt(0, 0.47), 0.17, 0.27, cream));
  k.paws(0.78, 0.13, cream, petMix(cream, gold, 0.5));

  final collar = Path()
    ..moveTo(-0.27, 0.19)
    ..quadraticBezierTo(0, 0.36, 0.27, 0.19);
  k.glowLine(collar, k.acc, 0.06);
  k.star(pt(0, 0.33), 0.06, const Color(0xFFFFF59D), const Color(0xFFFFB300));

  k.both(() {
    final ear = petSpline([
      pt(0.28, -0.44), pt(0.50, -0.36), pt(0.58, -0.10), pt(0.52, 0.10),
      pt(0.40, 0.06), pt(0.32, -0.14),
    ]);
    k.fill(ear, petMix(deep, gold, 0.3), petDark(deep, 0.25), glow: true);
  });

  final head = petCheekHead(pt(0, -0.14), 0.40, 0.34, cheek: 1.06);
  k.fill(head, petLight(gold, 0.14), gold, glow: true, gloss: true);
  k.clipped(head, () => k.ovalFlat(pt(0, 0.09), 0.20, 0.15, cream));
  k.outline(head, petDark(deep, 0.4));

  k.fill(petStar(pt(0, -0.33), 0.07, 0.03, 5), const Color(0xFFFFF59D), cream,
      glow: true, lw: 0.6);
  final halo = Path()
    ..addOval(Rect.fromCenter(center: pt(0, -0.64), width: 0.50, height: 0.12));
  k.glowLine(halo, const Color(0xFFFFF59D), 0.03);

  k.eye(pt(-0.16, -0.14), 0.085, iris: const Color(0xFF6D4C41));
  k.eye(pt(0.16, -0.14), 0.085, iris: const Color(0xFF6D4C41));
  k.nose(pt(0, 0.05), 0.06, const Color(0xFF2B1B16));
  k.mouth(pt(0, 0.10), 0.08);
  k.oval(pt(0, 0.175), 0.04, 0.05, const Color(0xFFFF8FA3), const Color(0xFFE0607A), lw: 0.7);
}

// ───────────────────────────── 28. Mamute Ancestral ─────────────────────────────

void drawMammoth(PetKit k) {
  final fur = k.pri;
  final deep = petDark(fur, 0.35);
  final light = petMix(k.sec, fur, 0.3);
  const ivory = Color(0xFFFFF8E1);

  final body = _pear(top: 0.18, bot: 0.82, w: 0.42);
  k.fill(body, petLight(fur, 0.05), deep, glow: true, gloss: true);
  k.paws(0.78, 0.18, fur, deep, rx: 0.15, ry: 0.09);

  k.both(() {
    final ear = petSpline([
      pt(0.36, -0.40), pt(0.62, -0.38), pt(0.74, -0.10), pt(0.66, 0.14),
      pt(0.46, 0.10), pt(0.36, -0.10),
    ]);
    k.fill(ear, fur, deep, glow: true);
    k.oval(pt(0.56, -0.12), 0.09, 0.15, const Color(0xFFD7A9A0),
        const Color(0xFFB48A84), line: false);
    final crystal = Path()
      ..moveTo(0.48, 0.30)
      ..lineTo(0.54, 0.16)
      ..lineTo(0.60, 0.30)
      ..lineTo(0.54, 0.46)
      ..close();
    k.fill(crystal, const Color(0xCCE0F7FA), const Color(0xCC80DEEA), glow: true);
  });

  final head = petCheekHead(pt(0, -0.12), 0.44, 0.38, cheek: 1.06);
  k.fill(head, light, fur, glow: true, gloss: true);

  final tuft = petSpline([
    pt(-0.24, -0.38), pt(-0.14, -0.60), pt(-0.04, -0.52), pt(0.0, -0.70),
    pt(0.06, -0.52), pt(0.16, -0.62), pt(0.24, -0.38),
  ]);
  k.fill(tuft, fur, deep, glow: true);

  final trunk = petTube(
    [pt(0, 0.0), pt(0, 0.20), pt(0.02, 0.42), pt(0.14, 0.56), pt(0.26, 0.52)],
    [0.18, 0.17, 0.15, 0.13, 0.09],
  );
  k.fill(trunk, light, petMix(light, fur, 0.6));
  k.clipped(trunk, () {
    final r = Path();
    for (final y in const [0.10, 0.22, 0.34]) {
      r.moveTo(-0.09, y);
      r.quadraticBezierTo(0, y + 0.03, 0.09, y);
    }
    k.stroke(r, deep, 0.014, a: 0.5);
  });

  k.both(() {
    k.fill(petTube([pt(0.17, 0.12), pt(0.36, 0.30), pt(0.46, 0.50), pt(0.36, 0.68)],
        [0.10, 0.09, 0.07, 0.02]), ivory, petMix(ivory, fur, 0.25), glow: true);
  });

  k.eye(pt(-0.21, -0.14), 0.07, iris: const Color(0xFF4E342E));
  k.eye(pt(0.21, -0.14), 0.07, iris: const Color(0xFF4E342E));
  k.brow(pt(-0.21, -0.25), 0.12, 0.3, col: deep);
  k.brow(pt(0.21, -0.25), 0.12, -0.3, col: deep);
  k.blush(pt(-0.33, 0.0), 0.06, const Color(0xFFFF8AB5));
  k.blush(pt(0.33, 0.0), 0.06, const Color(0xFFFF8AB5));
}