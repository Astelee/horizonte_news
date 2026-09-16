import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/premium_avatars_config.dart';

// ═══════════════════════════════════════════════════════════════════
// AVATARES ANIMADOS PREMIUM — 100% CustomPainter, sem imagens
// ═══════════════════════════════════════════════════════════════════
// Cada avatar é um StatefulWidget independente com seus próprios
// AnimationControllers (sempre dispose() corretamente). Todos
// recebem [size] e desenham dentro de um círculo desse diâmetro,
// para caber perfeitamente como `child` de AvatarFrame — a mesma
// posição hoje ocupada por AppAvatar.
//
// Para adicionar um novo avatar: crie uma classe aqui + registre em
// PremiumAvatarsConfig.all + adicione o case no switch de
// PremiumAnimatedAvatar mais abaixo. Nada mais precisa mudar.
// ═══════════════════════════════════════════════════════════════════

/// Widget-fachada: dado um [PremiumAvatarId], escolhe e renderiza o
/// avatar animado correspondente. Único ponto de entrada usado pelo
/// resto do app (perfil, ranking, comentários, galeria).
class PremiumAnimatedAvatar extends StatelessWidget {
  final PremiumAvatarId avatarId;
  final double size;

  const PremiumAnimatedAvatar({
    Key? key,
    required this.avatarId,
    this.size = 84,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (avatarId) {
      case PremiumAvatarId.novaAurora:
        return _NovaAuroraAvatar(size: size);
      case PremiumAvatarId.fenixEletrica:
        return _FenixEletricaAvatar(size: size);
      case PremiumAvatarId.loboEspectral:
        return _LoboEspectralAvatar(size: size);
      case PremiumAvatarId.cristalQuantico:
        return _CristalQuanticoAvatar(size: size);
      case PremiumAvatarId.aguiaSolar:
        return _AguiaSolarAvatar(size: size);
      case PremiumAvatarId.serpenteAurora:
        return _SerpenteAuroraAvatar(size: size);
    }
  }
}

/// Base comum: fundo circular escuro + clip circular, para que todo
/// avatar tenha o mesmo "encaixe" visual dentro do AvatarFrame.
Widget _circleShell({required double size, required Widget child}) {
  return ClipOval(
    child: Container(
      width: size,
      height: size,
      color: const Color(0xFF0A0A0A),
      child: child,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// 1) NOVA AURORA — núcleo pulsante com anéis de plasma orbitando
// ═══════════════════════════════════════════════════════════════════
class _NovaAuroraAvatar extends StatefulWidget {
  final double size;
  const _NovaAuroraAvatar({required this.size});

  @override
  State<_NovaAuroraAvatar> createState() => _NovaAuroraAvatarState();
}

class _NovaAuroraAvatarState extends State<_NovaAuroraAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotCtrl, _pulseCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _NovaAuroraPainter(
            rotation: _rotCtrl.value,
            pulse: _pulseCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _NovaAuroraPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  _NovaAuroraPainter({required this.rotation, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Fundo em gradiente radial escuro-laranja
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2A0F00),
          const Color(0xFF000000),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Anéis orbitais de plasma (3 elipses rotacionadas)
    for (int i = 0; i < 3; i++) {
      final angle = rotation * 2 * math.pi + (i * math.pi / 3);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Color.lerp(
          const Color(0xFFFF6B00),
          const Color(0xFFFFD54F),
          i / 3,
        )!
            .withOpacity(0.55 + 0.25 * pulse);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: r * 1.5, height: r * 0.55),
        ringPaint,
      );
      canvas.restore();
    }

    // Núcleo pulsante
    final coreRadius = r * 0.34 * (0.9 + 0.15 * pulse);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          const Color(0xFFFFD54F),
          const Color(0xFFFF6B00),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    canvas.drawCircle(center, coreRadius, corePaint);

    final glowPaint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.35 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, coreRadius * 1.5, glowPaint);

    // Faíscas orbitando o núcleo
    for (int i = 0; i < 8; i++) {
      final a = rotation * 2 * math.pi * (i.isEven ? 1 : -1.3) +
          (i / 8) * 2 * math.pi;
      final dist = r * 0.62;
      final pos = Offset(
        center.dx + math.cos(a) * dist,
        center.dy + math.sin(a) * dist,
      );
      final sparklePaint = Paint()
        ..color = Colors.white.withOpacity(0.6 + 0.4 * pulse);
      canvas.drawCircle(pos, 1.6, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(_NovaAuroraPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════════
// 2) FÊNIX ELÉTRICA — asas de energia se recompondo em loop
// ═══════════════════════════════════════════════════════════════════
class _FenixEletricaAvatar extends StatefulWidget {
  final double size;
  const _FenixEletricaAvatar({required this.size});

  @override
  State<_FenixEletricaAvatar> createState() => _FenixEletricaAvatarState();
}

class _FenixEletricaAvatarState extends State<_FenixEletricaAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _wingCtrl;
  late final AnimationController _flickerCtrl;

  @override
  void initState() {
    super.initState();
    _wingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _wingCtrl.dispose();
    _flickerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wingCtrl, _flickerCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FenixEletricaPainter(
            wing: _wingCtrl.value,
            flicker: _flickerCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _FenixEletricaPainter extends CustomPainter {
  final double wing;
  final double flicker;
  _FenixEletricaPainter({required this.wing, required this.flicker});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2A0800), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final wingSpread = 0.75 + 0.25 * wing;

    // Asas — cada uma um leque de "penas" de energia (linhas curvas)
    for (final side in [-1.0, 1.0]) {
      for (int i = 0; i < 5; i++) {
        final t = i / 4;
        final baseAngle = side * (math.pi * 0.18 + t * math.pi * 0.28);
        final len = r * (0.55 + 0.35 * t) * wingSpread;

        final path = Path();
        path.moveTo(center.dx, center.dy + r * 0.05);
        final ctrl = Offset(
          center.dx + side * len * 0.6,
          center.dy - len * 0.35,
        );
        final end = Offset(
          center.dx + math.sin(baseAngle) * len * side.sign,
          center.dy - math.cos(baseAngle) * len * 0.7,
        );
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

        final opacity = (0.35 + 0.5 * ((flicker + t) % 1.0)) * wingSpread;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 - t * 1.1
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            const Color(0xFFFFC400),
            const Color(0xFFFF3D00),
            t,
          )!
              .withOpacity(opacity.clamp(0.15, 0.95));
        canvas.drawPath(path, paint);
      }
    }

    // Corpo central — chama estilizada
    final bodyPath = Path()
      ..moveTo(center.dx, center.dy - r * 0.55)
      ..quadraticBezierTo(
        center.dx + r * 0.22,
        center.dy - r * 0.1,
        center.dx,
        center.dy + r * 0.5,
      )
      ..quadraticBezierTo(
        center.dx - r * 0.22,
        center.dy - r * 0.1,
        center.dx,
        center.dy - r * 0.55,
      );
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.9),
          const Color(0xFFFFC400),
          const Color(0xFFFF3D00),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.6));
    canvas.drawPath(bodyPath, bodyPaint);

    final glow = Paint()
      ..color = const Color(0xFFFF5722)
          .withOpacity(0.25 + 0.15 * math.sin(flicker * 2 * math.pi))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, r * 0.5, glow);
  }

  @override
  bool shouldRepaint(_FenixEletricaPainter oldDelegate) =>
      oldDelegate.wing != wing || oldDelegate.flicker != flicker;
}

// ═══════════════════════════════════════════════════════════════════
// 3) LOBO ESPECTRAL — silhueta fantasmagórica com névoa fria
// ═══════════════════════════════════════════════════════════════════
class _LoboEspectralAvatar extends StatefulWidget {
  final double size;
  const _LoboEspectralAvatar({required this.size});

  @override
  State<_LoboEspectralAvatar> createState() => _LoboEspectralAvatarState();
}

class _LoboEspectralAvatarState extends State<_LoboEspectralAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _mistCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _mistCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _mistCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mistCtrl, _glowCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LoboEspectralPainter(
            mist: _mistCtrl.value,
            glow: _glowCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _LoboEspectralPainter extends CustomPainter {
  final double mist;
  final double glow;
  _LoboEspectralPainter({required this.mist, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF10151A), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Névoa: várias elipses translúcidas subindo e desvanecendo
    for (int i = 0; i < 5; i++) {
      final phase = (mist + i * 0.2) % 1.0;
      final dy = r * (0.7 - phase * 1.2);
      final opacity = (1.0 - phase) * 0.18;
      final mistPaint = Paint()
        ..color = const Color(0xFF90A4AE).withOpacity(opacity.clamp(0.0, 0.3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + (i.isEven ? -1 : 1) * r * 0.2, center.dy + dy),
          width: r * 0.9,
          height: r * 0.35,
        ),
        mistPaint,
      );
    }

    // Silhueta da cabeça de lobo (geométrica, estilizada) via Path
    final headPath = Path();
    final s = r * 0.85;
    headPath.moveTo(center.dx, center.dy - s * 0.55); // topo entre orelhas
    headPath.lineTo(center.dx - s * 0.42, center.dy - s * 0.7); // orelha esq ponta
    headPath.lineTo(center.dx - s * 0.28, center.dy - s * 0.15);
    headPath.lineTo(center.dx - s * 0.5, center.dy + s * 0.1);
    headPath.lineTo(center.dx - s * 0.32, center.dy + s * 0.55); // focinho esq
    headPath.lineTo(center.dx, center.dy + s * 0.68); // ponta do focinho
    headPath.lineTo(center.dx + s * 0.32, center.dy + s * 0.55);
    headPath.lineTo(center.dx + s * 0.5, center.dy + s * 0.1);
    headPath.lineTo(center.dx + s * 0.28, center.dy - s * 0.15);
    headPath.lineTo(center.dx + s * 0.42, center.dy - s * 0.7); // orelha dir ponta
    headPath.close();

    final headPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF546E7A).withOpacity(0.9),
          const Color(0xFF263238).withOpacity(0.95),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    canvas.drawPath(headPath, headPaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFCFD8DC).withOpacity(0.4);
    canvas.drawPath(headPath, outlinePaint);

    // Olhos brilhantes (âmbar espectral)
    final eyeGlow = 0.6 + 0.4 * glow;
    final eyePaint = Paint()
      ..color = const Color(0xFF64FFDA).withOpacity(eyeGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
        Offset(center.dx - s * 0.16, center.dy - s * 0.05), 2.4, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + s * 0.16, center.dy - s * 0.05), 2.4, eyePaint);
  }

  @override
  bool shouldRepaint(_LoboEspectralPainter oldDelegate) =>
      oldDelegate.mist != mist || oldDelegate.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// 4) CRISTAL QUÂNTICO — poliedro facetado girando com refrações
// ═══════════════════════════════════════════════════════════════════
class _CristalQuanticoAvatar extends StatefulWidget {
  final double size;
  const _CristalQuanticoAvatar({required this.size});

  @override
  State<_CristalQuanticoAvatar> createState() =>
      _CristalQuanticoAvatarState();
}

class _CristalQuanticoAvatarState extends State<_CristalQuanticoAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotCtrl, _shimmerCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _CristalQuanticoPainter(
            rotation: _rotCtrl.value,
            shimmer: _shimmerCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _CristalQuanticoPainter extends CustomPainter {
  final double rotation;
  final double shimmer;
  _CristalQuanticoPainter({required this.rotation, required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF0A1A2A), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Poliedro: hexágono com linhas internas para efeito facetado,
    // "girando" via escala horizontal simulando rotação 3D.
    const sides = 6;
    final scaleX = math.cos(rotation * 2 * math.pi).abs().clamp(0.35, 1.0);
    final crystalR = r * 0.62;

    final points = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final a = (i / sides) * 2 * math.pi - math.pi / 2;
      points.add(Offset(
        center.dx + math.cos(a) * crystalR * scaleX,
        center.dy + math.sin(a) * crystalR,
      ));
    }

    final facePath = Path()..addPolygon(points, true);

    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.55 + 0.25 * shimmer),
          const Color(0xFF7C4DFF).withOpacity(0.55 + 0.25 * shimmer),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: crystalR));
    canvas.drawPath(facePath, facePaint);

    // Linhas internas (facetas) do centro até cada vértice
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.5);
    for (final p in points) {
      canvas.drawLine(center, p, linePaint);
    }

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withOpacity(0.7);
    canvas.drawPath(facePath, outlinePaint);

    // Brilho de refração — ponto de luz que percorre as faces
    final shimmerAngle = shimmer * 2 * math.pi;
    final shimmerPos = Offset(
      center.dx + math.cos(shimmerAngle) * crystalR * 0.5 * scaleX,
      center.dy + math.sin(shimmerAngle) * crystalR * 0.5,
    );
    final shimmerPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(shimmerPos, 2.6, shimmerPaint);
  }

  @override
  bool shouldRepaint(_CristalQuanticoPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.shimmer != shimmer;
}

// ═══════════════════════════════════════════════════════════════════
// 5) ÁGUIA SOLAR — silhueta em voo com sol pulsante ao fundo
// ═══════════════════════════════════════════════════════════════════
class _AguiaSolarAvatar extends StatefulWidget {
  final double size;
  const _AguiaSolarAvatar({required this.size});

  @override
  State<_AguiaSolarAvatar> createState() => _AguiaSolarAvatarState();
}

class _AguiaSolarAvatarState extends State<_AguiaSolarAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _flapCtrl;
  late final AnimationController _sunCtrl;

  @override
  void initState() {
    super.initState();
    _flapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _sunCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _flapCtrl.dispose();
    _sunCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flapCtrl, _sunCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _AguiaSolarPainter(
            flap: _flapCtrl.value,
            sunT: _sunCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _AguiaSolarPainter extends CustomPainter {
  final double flap;
  final double sunT;
  _AguiaSolarPainter({required this.flap, required this.sunT});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2A1400), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Sol pulsante ao fundo
    final sunPulse = 0.85 + 0.15 * math.sin(sunT * 2 * math.pi);
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD740).withOpacity(0.9),
          const Color(0xFFFF6D00).withOpacity(0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.9));
    canvas.drawCircle(center, r * 0.75 * sunPulse, sunPaint);

    // Raios do sol
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * math.pi + sunT * math.pi * 0.5;
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFD740).withOpacity(0.35);
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * r * 0.7,
            center.dy + math.sin(a) * r * 0.7),
        Offset(center.dx + math.cos(a) * r * 0.92,
            center.dy + math.sin(a) * r * 0.92),
        rayPaint,
      );
    }

    // Silhueta da águia em voo: corpo + asas que batem (flap)
    final wingLift = math.sin(flap * math.pi) * r * 0.3;
    final eagleColor = Colors.black.withOpacity(0.82);
    final eaglePaint = Paint()..color = eagleColor;

    // Corpo
    final bodyPath = Path()
      ..moveTo(center.dx, center.dy - r * 0.3)
      ..quadraticBezierTo(
          center.dx + r * 0.08, center.dy, center.dx, center.dy + r * 0.45)
      ..quadraticBezierTo(
          center.dx - r * 0.08, center.dy, center.dx, center.dy - r * 0.3);
    canvas.drawPath(bodyPath, eaglePaint);

    // Asa esquerda
    final leftWing = Path()
      ..moveTo(center.dx, center.dy - r * 0.05)
      ..quadraticBezierTo(
        center.dx - r * 0.55,
        center.dy - r * 0.1 - wingLift,
        center.dx - r * 0.9,
        center.dy - wingLift * 0.5,
      )
      ..quadraticBezierTo(
        center.dx - r * 0.5,
        center.dy + r * 0.15,
        center.dx,
        center.dy + r * 0.1,
      )
      ..close();
    canvas.drawPath(leftWing, eaglePaint);

    // Asa direita (espelhada)
    final rightWing = Path()
      ..moveTo(center.dx, center.dy - r * 0.05)
      ..quadraticBezierTo(
        center.dx + r * 0.55,
        center.dy - r * 0.1 - wingLift,
        center.dx + r * 0.9,
        center.dy - wingLift * 0.5,
      )
      ..quadraticBezierTo(
        center.dx + r * 0.5,
        center.dy + r * 0.15,
        center.dx,
        center.dy + r * 0.1,
      )
      ..close();
    canvas.drawPath(rightWing, eaglePaint);
  }

  @override
  bool shouldRepaint(_AguiaSolarPainter oldDelegate) =>
      oldDelegate.flap != flap || oldDelegate.sunT != sunT;
}

// ═══════════════════════════════════════════════════════════════════
// 6) SERPENTE AURORA — fita luminosa serpenteante em espiral
// ═══════════════════════════════════════════════════════════════════
class _SerpenteAuroraAvatar extends StatefulWidget {
  final double size;
  const _SerpenteAuroraAvatar({required this.size});

  @override
  State<_SerpenteAuroraAvatar> createState() => _SerpenteAuroraAvatarState();
}

class _SerpenteAuroraAvatarState extends State<_SerpenteAuroraAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _flowCtrl;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: _flowCtrl,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _SerpenteAuroraPainter(flow: _flowCtrl.value),
        ),
      ),
    );
  }
}

class _SerpenteAuroraPainter extends CustomPainter {
  final double flow;
  _SerpenteAuroraPainter({required this.flow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF04201C), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Fita em espiral: pontos ao longo de uma curva espiral animada
    const segments = 60;
    final path = Path();
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final angle = t * 4 * math.pi + flow * 2 * math.pi;
      final radius = r * 0.15 + t * r * 0.68;
      final pos = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius * 0.92,
      );
      if (i == 0) {
        path.moveTo(pos.dx, pos.dy);
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }

    final ribbonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(flow * 2 * math.pi),
        colors: const [
          Color(0xFF00BFA5),
          Color(0xFF00E5FF),
          Color(0xFF7C4DFF),
          Color(0xFF00BFA5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(path, ribbonPaint);

    // Brilho externo da fita
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF64FFDA).withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    // "Cabeça" da serpente — ponto de luz na extremidade externa
    final headAngle = 4 * math.pi + flow * 2 * math.pi;
    final headPos = Offset(
      center.dx + math.cos(headAngle) * r * 0.83,
      center.dy + math.sin(headAngle) * r * 0.83 * 0.92,
    );
    final headPaint = Paint()..color = Colors.white.withOpacity(0.9);
    canvas.drawCircle(headPos, 3.2, headPaint);
    final headGlow = Paint()
      ..color = const Color(0xFF64FFDA).withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(headPos, 5.5, headGlow);
  }

  @override
  bool shouldRepaint(_SerpenteAuroraPainter oldDelegate) =>
      oldDelegate.flow != flow;
}