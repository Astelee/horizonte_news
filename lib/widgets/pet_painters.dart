import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/pet_config.dart';

class PetDisplay extends StatefulWidget {
  final PetDef pet;
  final double size;
  final bool animate;
  final bool dimmed;

  const PetDisplay({
    Key? key,
    required this.pet,
    this.size = 58,
    this.animate = true,
    this.dimmed = false,
  }) : super(key: key);

  @override
  State<PetDisplay> createState() => _PetDisplayState();
}

class _PetDisplayState extends State<PetDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PetDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
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
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: PetPainter(
            pet: widget.pet,
            progress: _controller.value,
            dimmed: widget.dimmed,
          ),
        ),
      ),
    );
  }
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

  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.34;
    final pulse = 0.88 + math.sin(progress * _tau) * 0.08;
    final drift = math.sin(progress * _tau) * size.shortestSide * 0.025;
    canvas.save();
    canvas.translate(0, drift);

    final primary = dimmed ? pet.primary.withOpacity(0.18) : pet.primary;
    final secondary = dimmed ? pet.secondary.withOpacity(0.14) : pet.secondary;
    final accent = dimmed ? pet.accent.withOpacity(0.12) : pet.accent;

    _drawAura(canvas, size, c, primary, accent, pulse);
    _drawOrbitals(canvas, size, c, primary, accent);

    canvas.translate(0, -size.shortestSide * 0.015);
    _drawCreature(canvas, c, r, primary, secondary, accent);
    canvas.restore();
  }

  void _drawAura(Canvas canvas, Size size, Offset c, Color primary,
      Color accent, double pulse) {
    final aura = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withOpacity(dimmed ? 0.05 : 0.30 * pulse),
          accent.withOpacity(dimmed ? 0.02 : 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.48));
    canvas.drawCircle(c, size.width * 0.47, aura);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, size.width * 0.018)
      ..color = primary.withOpacity(dimmed ? 0.10 : 0.55);
    canvas.drawCircle(c, size.width * 0.39, ring);
  }

  void _drawOrbitals(Canvas canvas, Size size, Offset c, Color primary,
      Color accent) {
    final count = size.width < 40 ? 5 : 8;
    for (var i = 0; i < count; i++) {
      final a = progress * _tau + i * _tau / count;
      final radius = size.width * (0.34 + (i.isEven ? 0.045 : 0.075));
      final p = Offset(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius);
      final paint = Paint()
        ..color = (i.isEven ? primary : accent)
            .withOpacity(dimmed ? 0.12 : (0.35 + (i % 3) * 0.15))
        ..maskFilter = dimmed ? null : const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(p, size.width * (i % 3 == 0 ? 0.025 : 0.016), paint);
      if (!dimmed && i % 3 == 0) {
        final star = Paint()..color = Colors.white.withOpacity(0.75);
        canvas.drawCircle(p, size.width * 0.009, star);
      }
    }
  }

  void _drawCreature(Canvas canvas, Offset c, double r, Color primary,
      Color secondary, Color accent) {
    final glow = Paint()
      ..color = primary.withOpacity(dimmed ? 0.08 : 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final fill = Paint()
      ..shader = LinearGradient(
        colors: [primary, secondary, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: c, radius: r));
    final detail = Paint()
      ..color = Colors.white.withOpacity(dimmed ? 0.12 : 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, r * 0.045)
      ..strokeCap = StrokeCap.round;

    final path = Path();
    _buildBody(path, c, r, pet.species);
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);

    _drawSpeciesDetails(canvas, c, r, primary, secondary, accent, detail);
  }

  void _buildBody(Path p, Offset c, double r, PetSpecies species) {
    final bodyRx = r * 0.62;
    final bodyRy = r * 0.50;
    p.addOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * 0.08), width: bodyRx * 2, height: bodyRy * 2));

    final headR = r * 0.43;
    p.addOval(Rect.fromCenter(center: Offset(c.dx, c.dy - r * 0.34), width: headR * 2, height: headR * 1.8));

    switch (species) {
      case PetSpecies.fox:
      case PetSpecies.wolf:
      case PetSpecies.cat:
      case PetSpecies.panther:
      case PetSpecies.celestialHound:
        _ears(p, c, r, 0.38);
        _tail(p, c, r, 0.75);
        break;
      case PetSpecies.owl:
      case PetSpecies.raven:
        _wings(p, c, r, 0.70);
        break;
      case PetSpecies.falcon:
      case PetSpecies.eagle:
        _wings(p, c, r, 0.85);
        break;
      case PetSpecies.rabbit:
        p.moveTo(c.dx - r * .2, c.dy - r * .62);
        p.lineTo(c.dx - r * .26, c.dy - r * 1.15);
        p.lineTo(c.dx - r * .03, c.dy - r * .76);
        p.close();
        p.moveTo(c.dx + r * .2, c.dy - r * .62);
        p.lineTo(c.dx + r * .26, c.dy - r * 1.15);
        p.lineTo(c.dx + r * .03, c.dy - r * .76);
        p.close();
        break;
      case PetSpecies.tiger:
      case PetSpecies.lion:
      case PetSpecies.bear:
        _ears(p, c, r, 0.26);
        _tail(p, c, r, 0.58);
        break;
      case PetSpecies.deer:
        _ears(p, c, r, 0.20);
        _antlers(p, c, r);
        break;
      case PetSpecies.shark:
      case PetSpecies.dolphin:
        _fin(p, c, r);
        break;
      case PetSpecies.dragon:
      case PetSpecies.cosmicDragon:
        _dragonWings(p, c, r);
        _dragonHorns(p, c, r);
        _tail(p, c, r, 0.95);
        break;
      case PetSpecies.phoenix:
        _wings(p, c, r, 0.95);
        _tailFlames(p, c, r);
        break;
      case PetSpecies.unicorn:
        _ears(p, c, r, 0.24);
        _horn(p, c, r);
        break;
      case PetSpecies.griffin:
        _wings(p, c, r, 0.8);
        _ears(p, c, r, 0.22);
        _tail(p, c, r, 0.72);
        break;
      case PetSpecies.kraken:
        _tentacles(p, c, r);
        break;
      case PetSpecies.dinosaur:
        _dinoSpikes(p, c, r);
        _tail(p, c, r, 1.0);
        break;
      case PetSpecies.pegasus:
        _wings(p, c, r, 0.85);
        _horn(p, c, r);
        break;
      case PetSpecies.serpent:
        _serpentBody(p, c, r);
        break;
      case PetSpecies.kitsune:
        _ears(p, c, r, 0.34);
        _foxTails(p, c, r);
        break;
      case PetSpecies.raccoon:
        _ears(p, c, r, 0.25);
        _tail(p, c, r, 0.7);
        break;
      case PetSpecies.butterfly:
        _butterflyWings(p, c, r);
        break;
      case PetSpecies.turtle:
        _shell(p, c, r);
        break;
      case PetSpecies.mammoth:
        _ears(p, c, r, 0.32);
        _tusks(p, c, r);
        break;
    }
  }

  void _drawSpeciesDetails(Canvas canvas, Offset c, double r, Color primary,
      Color secondary, Color accent, Paint detail) {
    final eye = Paint()..color = Colors.white.withOpacity(dimmed ? 0.16 : 0.95);
    final pupil = Paint()..color = Colors.black.withOpacity(dimmed ? 0.1 : 0.85);
    final eyeY = c.dy - r * 0.40;
    final eyeOffset = r * 0.16;
    canvas.drawCircle(Offset(c.dx - eyeOffset, eyeY), r * .07, eye);
    canvas.drawCircle(Offset(c.dx + eyeOffset, eyeY), r * .07, eye);
    canvas.drawCircle(Offset(c.dx - eyeOffset, eyeY), r * .032, pupil);
    canvas.drawCircle(Offset(c.dx + eyeOffset, eyeY), r * .032, pupil);

    if (pet.species == PetSpecies.tiger || pet.species == PetSpecies.lion) {
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(
          Offset(c.dx + i * r * .14, c.dy - r * .12),
          Offset(c.dx + i * r * .18, c.dy + r * .12),
          detail,
        );
      }
    }

    if (pet.species == PetSpecies.dragon || pet.species == PetSpecies.cosmicDragon || pet.species == PetSpecies.phoenix) {
      final flame = Paint()
        ..color = accent.withOpacity(dimmed ? 0.08 : 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .07
        ..strokeCap = StrokeCap.round;
      final p = Path()
        ..moveTo(c.dx - r * .34, c.dy + r * .45)
        ..quadraticBezierTo(c.dx, c.dy + r * .76, c.dx + r * .34, c.dy + r * .45);
      canvas.drawPath(p, flame);
    }
  }

  void _ears(Path p, Offset c, double r, double h) {
    p.moveTo(c.dx - r * .28, c.dy - r * .57);
    p.lineTo(c.dx - r * .44, c.dy - r * (0.57 + h));
    p.lineTo(c.dx - r * .08, c.dy - r * .68);
    p.close();
    p.moveTo(c.dx + r * .28, c.dy - r * .57);
    p.lineTo(c.dx + r * .44, c.dy - r * (0.57 + h));
    p.lineTo(c.dx + r * .08, c.dy - r * .68);
    p.close();
  }

  void _tail(Path p, Offset c, double r, double length) {
    p.moveTo(c.dx + r * .42, c.dy + r * .25);
    p.cubicTo(c.dx + r * .9, c.dy + r * .1, c.dx + r * (1.0 + length * .25), c.dy + r * .5, c.dx + r * .68, c.dy + r * .7);
    p.cubicTo(c.dx + r * .45, c.dy + r * .78, c.dx + r * .55, c.dy + r * .38, c.dx + r * .42, c.dy + r * .25);
    p.close();
  }

  void _wings(Path p, Offset c, double r, double spread) {
    p.moveTo(c.dx - r * .38, c.dy - r * .02);
    p.quadraticBezierTo(c.dx - r * (0.95 + spread * .35), c.dy - r * .6, c.dx - r * (0.82 + spread * .25), c.dy + r * .42);
    p.quadraticBezierTo(c.dx - r * .58, c.dy + r * .22, c.dx - r * .38, c.dy + r * .05);
    p.close();
    p.moveTo(c.dx + r * .38, c.dy - r * .02);
    p.quadraticBezierTo(c.dx + r * (0.95 + spread * .35), c.dy - r * .6, c.dx + r * (0.82 + spread * .25), c.dy + r * .42);
    p.quadraticBezierTo(c.dx + r * .58, c.dy + r * .22, c.dx + r * .38, c.dy + r * .05);
    p.close();
  }

  void _dragonWings(Path p, Offset c, double r) => _wings(p, c, r, 0.9);

  void _dragonHorns(Path p, Offset c, double r) {
    p.moveTo(c.dx - r * .18, c.dy - r * .62);
    p.lineTo(c.dx - r * .35, c.dy - r * .98);
    p.lineTo(c.dx - r * .02, c.dy - r * .68);
    p.close();
    p.moveTo(c.dx + r * .18, c.dy - r * .62);
    p.lineTo(c.dx + r * .35, c.dy - r * .98);
    p.lineTo(c.dx + r * .02, c.dy - r * .68);
    p.close();
  }

  void _antlers(Path p, Offset c, double r) {
    for (final s in [-1.0, 1.0]) {
      p.moveTo(c.dx + s * r * .18, c.dy - r * .58);
      p.lineTo(c.dx + s * r * .42, c.dy - r * .98);
      p.moveTo(c.dx + s * r * .32, c.dy - r * .82);
      p.lineTo(c.dx + s * r * .55, c.dy - r * 1.0);
      p.moveTo(c.dx + s * r * .34, c.dy - r * .82);
      p.lineTo(c.dx + s * r * .50, c.dy - r * .62);
    }
  }

  void _fin(Path p, Offset c, double r) {
    p.moveTo(c.dx - r * .05, c.dy - r * .32);
    p.lineTo(c.dx + r * .22, c.dy - r * .82);
    p.lineTo(c.dx + r * .34, c.dy - r * .30);
    p.close();
  }

  void _horn(Path p, Offset c, double r) {
    p.moveTo(c.dx, c.dy - r * .63);
    p.lineTo(c.dx + r * .12, c.dy - r * 1.05);
    p.lineTo(c.dx + r * .22, c.dy - r * .60);
    p.close();
  }

  void _tailFlames(Path p, Offset c, double r) {
    p.moveTo(c.dx - r * .25, c.dy + r * .48);
    p.quadraticBezierTo(c.dx, c.dy + r * 1.1, c.dx + r * .1, c.dy + r * .58);
    p.quadraticBezierTo(c.dx + r * .3, c.dy + r * 1.0, c.dx + r * .35, c.dy + r * .45);
    p.close();
  }

  void _tentacles(Path p, Offset c, double r) {
    for (var i = 0; i < 6; i++) {
      final x = c.dx + (i - 2.5) * r * .22;
      p.moveTo(x, c.dy + r * .28);
      p.quadraticBezierTo(x - r * .12, c.dy + r * .75, x + r * .08, c.dy + r * .95);
      p.lineTo(x + r * .16, c.dy + r * .78);
      p.quadraticBezierTo(x + r * .05, c.dy + r * .58, x + r * .10, c.dy + r * .28);
      p.close();
    }
  }

  void _dinoSpikes(Path p, Offset c, double r) {
    for (var i = -2; i <= 2; i++) {
      final x = c.dx + i * r * .18;
      p.moveTo(x - r * .08, c.dy - r * .38);
      p.lineTo(x, c.dy - r * .72);
      p.lineTo(x + r * .08, c.dy - r * .38);
      p.close();
    }
  }

  void _serpentBody(Path p, Offset c, double r) {
    p.moveTo(c.dx - r * .35, c.dy + r * .25);
    p.cubicTo(c.dx - r * .8, c.dy + r * .5, c.dx + r * .2, c.dy + r * .85, c.dx + r * .65, c.dy + r * .45);
    p.cubicTo(c.dx + r * .85, c.dy + r * .28, c.dx + r * .55, c.dy + r * .1, c.dx + r * .35, c.dy + r * .2);
  }

  void _foxTails(Path p, Offset c, double r) {
    for (var i = -1; i <= 1; i++) {
      final x = c.dx + i * r * .2;
      p.moveTo(x, c.dy + r * .3);
      p.quadraticBezierTo(x + i * r * .45, c.dy + r * .8, x + i * r * .3, c.dy + r * 1.0);
      p.quadraticBezierTo(x - i * r * .1, c.dy + r * .72, x, c.dy + r * .3);
      p.close();
    }
  }

  void _butterflyWings(Path p, Offset c, double r) => _wings(p, c, r, 1.0);

  void _shell(Path p, Offset c, double r) {
    p.addOval(Rect.fromCenter(center: Offset(c.dx, c.dy + r * .12), width: r * 1.65, height: r * 1.25));
  }

  void _tusks(Path p, Offset c, double r) {
    p.moveTo(c.dx - r * .18, c.dy + r * .05);
    p.quadraticBezierTo(c.dx - r * .55, c.dy + r * .55, c.dx - r * .2, c.dy + r * .55);
    p.moveTo(c.dx + r * .18, c.dy + r * .05);
    p.quadraticBezierTo(c.dx + r * .55, c.dy + r * .55, c.dx + r * .2, c.dy + r * .55);
  }

  @override
  bool shouldRepaint(covariant PetPainter oldDelegate) =>
      oldDelegate.pet.id != pet.id ||
      oldDelegate.progress != progress ||
      oldDelegate.dimmed != dimmed;
}