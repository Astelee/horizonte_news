import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/pet_config.dart';
import 'pet_art_kit.dart';
import 'pet_creatures_air_sea.dart';
import 'pet_creatures_land.dart';
import 'pet_creatures_myth.dart';

// ═══════════════════════════════════════════════════════════════════
// PETS — 30 criaturas desenhadas 100% em código (CustomPainter)
// ═══════════════════════════════════════════════════════════════════
// • pet_art_kit.dart            → kit compartilhado (formas, brilho, olhos…)
// • pet_creatures_land.dart     → raposa, gato, lobo, coelho, tigre, cervo,
//                                 urso, leão, pantera, guaxinim, kitsune,
//                                 cão celestial, mamute
// • pet_creatures_air_sea.dart  → coruja, falcão, águia, corvo, fênix,
//                                 borboleta, tubarão, golfinho, kraken,
//                                 tartaruga, serpente
// • pet_creatures_myth.dart     → dragões, unicórnio, grifo, T-Rex, pégaso
//
// Este arquivo só cuida do widget, da aura animada e dos efeitos de
// partículas; a criatura em si não depende da aura para ser reconhecível.
// ═══════════════════════════════════════════════════════════════════

class PetDisplay extends StatefulWidget {
  final PetDef pet;
  final double size;
  final bool animate;
  final bool dimmed;

  /// Trajetória local em infinito, ativada apenas no avatar do perfil.
  final bool orbit;

  const PetDisplay({
    Key? key,
    required this.pet,
    this.size = 58,
    this.animate = true,
    this.dimmed = false,
    this.orbit = false,
  }) : super(key: key);

  @override
  State<PetDisplay> createState() => _PetDisplayState();
}

class _PetDisplayState extends State<PetDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Pet bloqueado (silhueta apagada) não precisa animar.
  bool get _run => widget.animate && !widget.dimmed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _controller.value = 0.12;
    if (_run) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PetDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_run && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Transform.translate(
          // Frequências inteiras: posição E velocidade coincidem na
          // passagem de 1 para 0. Sem easing ou pausa nas extremidades.
          offset: widget.orbit && _run
          ? Offset(
            widget.size * 0.16 * math.sin(_controller.value * math.pi * 2),
            widget.size * 0.07 * math.sin(_controller.value * math.pi * 4),
          )
          : Offset.zero,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: PetPainter(
              pet: widget.pet,
              progress: _controller.value,
              dimmed: widget.dimmed,
            ),
          ),
        ),
      ),
    );
  }
  }

enum _Fx { fire, ice, water, leaf, star, arcane, light }

_Fx _fxFor(PetSpecies s) {
  switch (s) {
    case PetSpecies.falcon:
    case PetSpecies.dragon:
    case PetSpecies.phoenix:
    case PetSpecies.kitsune:
      return _Fx.fire;
    case PetSpecies.bear:
    case PetSpecies.mammoth:
    case PetSpecies.wolf:
      return _Fx.ice;
    case PetSpecies.shark:
    case PetSpecies.dolphin:
    case PetSpecies.kraken:
      return _Fx.water;
    case PetSpecies.tiger:
    case PetSpecies.deer:
    case PetSpecies.dinosaur:
      return _Fx.leaf;
    case PetSpecies.panther:
    case PetSpecies.raven:
      return _Fx.arcane;
    case PetSpecies.fox:
    case PetSpecies.unicorn:
    case PetSpecies.griffin:
    case PetSpecies.lion:
    case PetSpecies.eagle:
    case PetSpecies.celestialHound:
      return _Fx.light;
    case PetSpecies.owl:
    case PetSpecies.cat:
    case PetSpecies.rabbit:
    case PetSpecies.raccoon:
    case PetSpecies.butterfly:
    case PetSpecies.turtle:
    case PetSpecies.serpent:
    case PetSpecies.pegasus:
    case PetSpecies.cosmicDragon:
      return _Fx.star;
  }
}

double _hash(int i) {
  final v = math.sin(i * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

class PetPainter extends CustomPainter {
  final PetDef pet;
  final double progress;
  final bool dimmed;

  const PetPainter({
    required this.pet,
    required this.progress,
    this.dimmed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final k = PetKit(canvas, pet, progress, s < 44, dimmed);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s / 2, s / 2); // espaço normalizado [-1, 1]

    _aura(k);
    canvas.save();
    canvas.translate(0, k.w(1) * 0.02); // respiração leve
    _creature(k, pet.species);
    canvas.restore();
    _front(k);

    canvas.restore();
  }

  // ───────────── aura: brilho, anel, arcos de energia, sombra ─────────────

  void _aura(PetKit k) {
    final c = k.canvas;
    final pulse = 0.9 + 0.1 * k.w(1);

    // sombra/brilho no chão
    c.drawOval(
      Rect.fromCenter(center: pt(0, 0.86), width: 1.0, height: 0.20),
      Paint()..color = k.pri.withOpacity(k.dim ? 0.05 : 0.16),
    );
    c.drawOval(
      Rect.fromCenter(center: pt(0, 0.86), width: 0.80, height: 0.12),
      Paint()..color = Colors.black.withOpacity(k.dim ? 0.12 : 0.22),
    );

    if (k.dim) {
      k.soft(Offset.zero, 0.95, k.pri, 0.10);
      return;
    }

    k.soft(Offset.zero, 0.98, k.pri, 0.34 * pulse);
    k.soft(pt(0, 0.12), 0.70, k.acc, 0.16);

    final rect = Rect.fromCircle(center: Offset.zero, radius: 0.88);
    c.drawCircle(
      Offset.zero,
      0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = k.ow * 0.8
        ..color = k.pri.withOpacity(0.32),
    );
    final a0 = kPetTau * k.t;
    c.drawArc(
      rect,
      a0,
      1.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = k.ow * 1.7
        ..color = k.acc.withOpacity(0.75),
    );
    if (!k.lite) {
      c.drawArc(
        rect,
        a0 + math.pi,
        0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = k.ow * 1.3
          ..color = k.sec.withOpacity(0.6),
      );
    }
    _fx(k, _fxFor(pet.species));
  }

  // ───────────── partículas do elemento (6 no máximo) ─────────────

  void _fx(PetKit k, _Fx fx) {
    if (k.lite) return;
    const n = 6;
    for (var i = 0; i < n; i++) {
      final hx = _hash(i);
      final u = k.loop(1, i / n);
      final a = math.sin(math.pi * u);
      final x = -0.7 + hx * 1.4 + math.sin(kPetTau * (u + hx)) * 0.04;
      switch (fx) {
        case _Fx.fire:
          k.dot(pt(x * 0.8, 0.75 - u * 1.4), 0.014 + 0.012 * hx,
              i.isEven ? k.acc : k.sec, a * 0.9);
          break;
        case _Fx.ice:
          _snow(k, pt(x, -0.8 + u * 1.5), 0.03 + 0.012 * hx, a * 0.85);
          break;
        case _Fx.water:
          k.canvas.drawCircle(
            pt(x * 0.85, 0.75 - u * 1.4),
            0.02 + 0.016 * hx,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = k.ow * 0.6
              ..color = k.sec.withOpacity(0.7 * a),
          );
          break;
        case _Fx.leaf: {
          final p = pt(x + math.sin(kPetTau * u * 2) * 0.05, -0.8 + u * 1.5);
          k.flat(petFeather(p, p + const Offset(0.06, 0.035), 0.02),
              i.isEven ? k.acc : k.sec.withOpacity(0.9));
          }
          break;
        case _Fx.star: {
          final ang = hx * kPetTau;
          final r = 0.78 + 0.12 * _hash(i + 9);
          k.sparkle(pt(math.cos(ang) * r, math.sin(ang) * r * 0.9),
              0.03 + 0.02 * hx, i.isEven ? k.sec : k.acc,
              math.max(0.0, math.sin(kPetTau * (k.t * 2 + hx))));
          }
          break;
        case _Fx.arcane: {
          final ang = kPetTau * (k.t + i / n);
          final p = pt(math.cos(ang) * 0.82, math.sin(ang) * 0.74);
          final d = Path()
            ..moveTo(p.dx, p.dy - 0.035)
            ..lineTo(p.dx + 0.022, p.dy)
            ..lineTo(p.dx, p.dy + 0.035)
            ..lineTo(p.dx - 0.022, p.dy)
            ..close();
          k.soft(p, 0.06, k.acc, 0.35);
          k.canvas.drawPath(d, Paint()..color = k.acc.withOpacity(0.85));
          }
          break;
        case _Fx.light:
          k.sparkle(pt(x, 0.6 - u * 1.2), 0.028 + 0.02 * hx,
              i.isEven ? k.sec : k.acc, a);
          break;
      }
    }
  }

  void _snow(PetKit k, Offset p, double r, double a) {
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final ang = i * math.pi / 3;
      final d = Offset(math.cos(ang), math.sin(ang)) * r;
      path.moveTo(p.dx - d.dx, p.dy - d.dy);
      path.lineTo(p.dx + d.dx, p.dy + d.dy);
    }
    k.stroke(path, Colors.white, k.ow * 0.6, a: a);
  }

  /// Brilhos pequenos à frente da criatura.
  void _front(PetKit k) {
    if (k.lite || k.dim) return;
    k.sparkle(pt(-0.74, -0.50), 0.045, k.sec,
        math.max(0.0, math.sin(kPetTau * (k.t * 2 + 0.1))));
    k.sparkle(pt(0.76, -0.22), 0.04, k.acc,
        math.max(0.0, math.sin(kPetTau * (k.t * 2 + 0.45))));
    k.sparkle(pt(-0.64, 0.50), 0.035, Colors.white,
        math.max(0.0, math.sin(kPetTau * (k.t * 2 + 0.75))));
  }

  void _creature(PetKit k, PetSpecies s) {
    switch (s) {
      case PetSpecies.fox:
        drawFox(k);
        break;
      case PetSpecies.owl:
        drawOwl(k);
        break;
      case PetSpecies.cat:
        drawCat(k);
        break;
      case PetSpecies.wolf:
        drawWolf(k);
        break;
      case PetSpecies.falcon:
        drawFalcon(k);
        break;
      case PetSpecies.rabbit:
        drawRabbit(k);
        break;
      case PetSpecies.tiger:
        drawTiger(k);
        break;
      case PetSpecies.deer:
        drawDeer(k);
        break;
      case PetSpecies.bear:
        drawBear(k);
        break;
      case PetSpecies.shark:
        drawShark(k);
        break;
      case PetSpecies.dolphin:
        drawDolphin(k);
        break;
      case PetSpecies.dragon:
        drawDragon(k);
        break;
      case PetSpecies.phoenix:
        drawPhoenix(k);
        break;
      case PetSpecies.unicorn:
        drawUnicorn(k);
        break;
      case PetSpecies.griffin:
        drawGriffin(k);
        break;
      case PetSpecies.kraken:
        drawKraken(k);
        break;
      case PetSpecies.dinosaur:
        drawDinosaur(k);
        break;
      case PetSpecies.lion:
        drawLion(k);
        break;
      case PetSpecies.panther:
        drawPanther(k);
        break;
      case PetSpecies.eagle:
        drawEagle(k);
        break;
      case PetSpecies.pegasus:
        drawPegasus(k);
        break;
      case PetSpecies.serpent:
        drawSerpent(k);
        break;
      case PetSpecies.kitsune:
        drawKitsune(k);
        break;
      case PetSpecies.raccoon:
        drawRaccoon(k);
        break;
      case PetSpecies.butterfly:
        drawButterfly(k);
        break;
      case PetSpecies.turtle:
        drawTurtle(k);
        break;
      case PetSpecies.raven:
        drawRaven(k);
        break;
      case PetSpecies.mammoth:
        drawMammoth(k);
        break;
      case PetSpecies.celestialHound:
        drawCelestialHound(k);
        break;
      case PetSpecies.cosmicDragon:
        drawCosmicDragon(k);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant PetPainter old) =>
      old.progress != progress || old.pet != pet || old.dimmed != dimmed;
}