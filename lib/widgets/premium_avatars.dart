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
      case PremiumAvatarId.fenixCelestial:
        return _FenixCelestialAvatar(size: size);
      case PremiumAvatarId.dragaoOnix:
        return _DragaoOnixAvatar(size: size);
      case PremiumAvatarId.coroaImperial:
        return _CoroaImperialAvatar(size: size);
      case PremiumAvatarId.tigreNeon:
        return _TigreNeonAvatar(size: size);
      case PremiumAvatarId.rainhaGelo:
        return _RainhaGeloAvatar(size: size);
      case PremiumAvatarId.panteraMistica:
        return _PanteraMisticaAvatar(size: size);
      case PremiumAvatarId.fenixOuroRosa:
        return _FenixOuroRosaAvatar(size: size);
      case PremiumAvatarId.golemMagma:
        return _GolemMagmaAvatar(size: size);
      case PremiumAvatarId.deusaEstelar:
        return _DeusaEstelarAvatar(size: size);
      case PremiumAvatarId.leaoDouradoReal:
        return _LeaoDouradoRealAvatar(size: size);
      case PremiumAvatarId.orquideaLunar:
        return _OrquideaLunarAvatar(size: size);
      case PremiumAvatarId.borboletaCristal:
        return _BorboletaCristalAvatar(size: size);
      case PremiumAvatarId.florCerejeira:
        return _FlorCerejeiraAvatar(size: size);
      case PremiumAvatarId.coracaoAurora:
        return _CoracaoAuroraAvatar(size: size);
      case PremiumAvatarId.penaCisne:
        return _PenaCisneAvatar(size: size);
      case PremiumAvatarId.jardimZafira:
        return _JardimZafiraAvatar(size: size);
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
// ═══════════════════════════════════════════════════════════════════
// ▓▓▓ COLEÇÃO ULTRA — 10 avatares exclusivos ▓▓▓
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// 7) FÊNIX CELESTIAL — penas de luz branca/dourada subindo aos céus
// ═══════════════════════════════════════════════════════════════════
class _FenixCelestialAvatar extends StatefulWidget {
  final double size;
  const _FenixCelestialAvatar({required this.size});

  @override
  State<_FenixCelestialAvatar> createState() => _FenixCelestialAvatarState();
}

class _FenixCelestialAvatarState extends State<_FenixCelestialAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _riseCtrl;
  late final AnimationController _wingCtrl;

  @override
  void initState() {
    super.initState();
    _riseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _wingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _riseCtrl.dispose();
    _wingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_riseCtrl, _wingCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FenixCelestialPainter(
            rise: _riseCtrl.value,
            wing: _wingCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _FenixCelestialPainter extends CustomPainter {
  final double rise;
  final double wing;
  _FenixCelestialPainter({required this.rise, required this.wing});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A1A2E), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Penas de luz subindo em espiral suave
    for (int i = 0; i < 10; i++) {
      final t = ((rise + i / 10) % 1.0);
      final angle = i * math.pi / 5;
      final dy = r * (0.75 - t * 1.5);
      final dx = math.sin(angle + t * 2) * r * 0.55;
      final opacity = (1.0 - t) * 0.6;
      final featherPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFD700),
          Colors.white,
          t,
        )!
            .withOpacity(opacity.clamp(0.0, 0.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + dx, center.dy + dy),
          width: 3.2,
          height: 10,
        ),
        featherPaint,
      );
    }

    // Asas majestosas — grandes arcos brancos/dourados
    final wingSpread = 0.8 + 0.2 * wing;
    for (final side in [-1.0, 1.0]) {
      final path = Path();
      path.moveTo(center.dx, center.dy + r * 0.1);
      path.quadraticBezierTo(
        center.dx + side * r * 0.75 * wingSpread,
        center.dy - r * 0.5,
        center.dx + side * r * 0.95 * wingSpread,
        center.dy - r * 0.05,
      );
      path.quadraticBezierTo(
        center.dx + side * r * 0.55,
        center.dy + r * 0.25,
        center.dx,
        center.dy + r * 0.15,
      );
      path.close();
      final wingPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFFD700).withOpacity(0.85),
            Colors.white.withOpacity(0.95),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawPath(path, wingPaint);
    }

    // Corpo central luminoso
    final bodyGlow = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, const Color(0xFFFFD700), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.4));
    canvas.drawCircle(center, r * 0.32, bodyGlow);

    final crownPaint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(center.dx, center.dy - r * 0.28), r * 0.1,
        crownPaint);
  }

  @override
  bool shouldRepaint(_FenixCelestialPainter oldDelegate) =>
      oldDelegate.rise != rise || oldDelegate.wing != wing;
}

// ═══════════════════════════════════════════════════════════════════
// 8) DRAGÃO ÔNIX — escamas negras entalhadas com fumaça violeta
// ═══════════════════════════════════════════════════════════════════
class _DragaoOnixAvatar extends StatefulWidget {
  final double size;
  const _DragaoOnixAvatar({required this.size});

  @override
  State<_DragaoOnixAvatar> createState() => _DragaoOnixAvatarState();
}

class _DragaoOnixAvatarState extends State<_DragaoOnixAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _smokeCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _smokeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _smokeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_smokeCtrl, _pulseCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _DragaoOnixPainter(
            smoke: _smokeCtrl.value,
            pulse: _pulseCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _DragaoOnixPainter extends CustomPainter {
  final double smoke;
  final double pulse;
  _DragaoOnixPainter({required this.smoke, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A0033), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Fumaça violeta subindo
    for (int i = 0; i < 4; i++) {
      final t = (smoke + i * 0.25) % 1.0;
      final dy = r * (0.6 - t * 1.1);
      final smokePaint = Paint()
        ..color = const Color(0xFF9C27B0).withOpacity((1 - t) * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + (i.isEven ? -1 : 1) * r * 0.25,
              center.dy + dy),
          width: r * 0.7,
          height: r * 0.3,
        ),
        smokePaint,
      );
    }

    // Cabeça de dragão estilizada — geométrica, angulosa
    final s = r * 0.82;
    final headPath = Path()
      ..moveTo(center.dx, center.dy - s * 0.6)
      ..lineTo(center.dx - s * 0.5, center.dy - s * 0.25)
      ..lineTo(center.dx - s * 0.55, center.dy + s * 0.15)
      ..lineTo(center.dx - s * 0.2, center.dy + s * 0.65)
      ..lineTo(center.dx, center.dy + s * 0.45)
      ..lineTo(center.dx + s * 0.2, center.dy + s * 0.65)
      ..lineTo(center.dx + s * 0.55, center.dy + s * 0.15)
      ..lineTo(center.dx + s * 0.5, center.dy - s * 0.25)
      ..close();

    final headPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2A0845),
          Colors.black,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    canvas.drawPath(headPath, headPaint);

    // Chifres
    final hornPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFD500F9).withOpacity(0.8);
    canvas.drawLine(
      Offset(center.dx - s * 0.3, center.dy - s * 0.45),
      Offset(center.dx - s * 0.55, center.dy - s * 0.85),
      hornPaint,
    );
    canvas.drawLine(
      Offset(center.dx + s * 0.3, center.dy - s * 0.45),
      Offset(center.dx + s * 0.55, center.dy - s * 0.85),
      hornPaint,
    );

    // Linhas de escamas (entalhes)
    final scalePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFD500F9).withOpacity(0.35);
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(center.dx - s * 0.35 + i * s * 0.1,
            center.dy - s * 0.1 + i * s * 0.05),
        Offset(center.dx - s * 0.1 + i * s * 0.1, center.dy + s * 0.5),
        scalePaint,
      );
    }

    // Olhos brilhantes violeta pulsantes
    final eyeGlow = 0.55 + 0.45 * pulse;
    final eyePaint = Paint()
      ..color = const Color(0xFFD500F9).withOpacity(eyeGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(
        Offset(center.dx - s * 0.18, center.dy - s * 0.02), 3.0, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + s * 0.18, center.dy - s * 0.02), 3.0, eyePaint);
  }

  @override
  bool shouldRepaint(_DragaoOnixPainter oldDelegate) =>
      oldDelegate.smoke != smoke || oldDelegate.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════════
// 9) COROA IMPERIAL — joia real girando sobre um trono de luz
// ═══════════════════════════════════════════════════════════════════
class _CoroaImperialAvatar extends StatefulWidget {
  final double size;
  const _CoroaImperialAvatar({required this.size});

  @override
  State<_CoroaImperialAvatar> createState() => _CoroaImperialAvatarState();
}

class _CoroaImperialAvatarState extends State<_CoroaImperialAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotCtrl, _glowCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _CoroaImperialPainter(
            rotation: _rotCtrl.value,
            glow: _glowCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _CoroaImperialPainter extends CustomPainter {
  final double rotation;
  final double glow;
  _CoroaImperialPainter({required this.rotation, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2A1050), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Raios de luz real ao fundo
    for (int i = 0; i < 10; i++) {
      final a = (i / 10) * 2 * math.pi + rotation * math.pi * 0.4;
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFFD700).withOpacity(0.25);
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * r * 0.55,
            center.dy + math.sin(a) * r * 0.55),
        Offset(center.dx + math.cos(a) * r * 0.9,
            center.dy + math.sin(a) * r * 0.9),
        rayPaint,
      );
    }

    // Base da coroa
    final s = r * 0.62;
    final basePaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFFD700), const Color(0xFFB8860B)],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    final baseRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + s * 0.55),
      width: s * 1.7,
      height: s * 0.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(3)),
      basePaint,
    );

    // Pontas da coroa (5 picos)
    final crownPath = Path();
    const spikes = 5;
    for (int i = 0; i < spikes; i++) {
      final t = i / (spikes - 1);
      final x = center.dx - s * 0.85 + t * s * 1.7;
      final peakY = center.dy + s * 0.35 -
          (i.isOdd ? s * 0.75 : s * 0.5) *
              (0.85 + 0.15 * math.sin(rotation * 2 * math.pi + i));
      if (i == 0) {
        crownPath.moveTo(x, center.dy + s * 0.35);
      }
      crownPath.lineTo(x, peakY);
      crownPath.lineTo(
          x + (s * 1.7 / (spikes - 1)) / 2, center.dy + s * 0.35);
    }
    canvas.drawPath(crownPath, basePaint);

    // Joia central pulsante girando
    final jewelPulse = 0.85 + 0.15 * glow;
    final jewelCenter = Offset(center.dx, center.dy - s * 0.05);
    final jewelPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Colors.white,
          Color(0xFFE040FB),
          Color(0xFF4A148C),
        ],
      ).createShader(
          Rect.fromCircle(center: jewelCenter, radius: s * 0.3));
    canvas.drawCircle(jewelCenter, s * 0.22 * jewelPulse, jewelPaint);

    final jewelGlow = Paint()
      ..color = const Color(0xFFE040FB).withOpacity(0.4 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(jewelCenter, s * 0.35, jewelGlow);

    // Pequenas gemas nas pontas
    final gemPaint = Paint()..color = const Color(0xFF4A148C);
    for (int i = 0; i < spikes; i++) {
      final t = i / (spikes - 1);
      final x = center.dx - s * 0.85 + t * s * 1.7;
      canvas.drawCircle(Offset(x, center.dy + s * 0.35), 2.2, gemPaint);
    }
  }

  @override
  bool shouldRepaint(_CoroaImperialPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// 10) TIGRE NEON — listras cibernéticas rosa/ciano em pulso urbano
// ═══════════════════════════════════════════════════════════════════
class _TigreNeonAvatar extends StatefulWidget {
  final double size;
  const _TigreNeonAvatar({required this.size});

  @override
  State<_TigreNeonAvatar> createState() => _TigreNeonAvatarState();
}

class _TigreNeonAvatarState extends State<_TigreNeonAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _scanCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _TigreNeonPainter(
            pulse: _pulseCtrl.value,
            scan: _scanCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _TigreNeonPainter extends CustomPainter {
  final double pulse;
  final double scan;
  _TigreNeonPainter({required this.pulse, required this.scan});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF0D0221), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Cabeça de tigre geométrica facetada
    final s = r * 0.85;
    final facePath = Path()
      ..moveTo(center.dx, center.dy - s * 0.6)
      ..lineTo(center.dx - s * 0.55, center.dy - s * 0.35)
      ..lineTo(center.dx - s * 0.6, center.dy + s * 0.1)
      ..lineTo(center.dx - s * 0.3, center.dy + s * 0.6)
      ..lineTo(center.dx, center.dy + s * 0.4)
      ..lineTo(center.dx + s * 0.3, center.dy + s * 0.6)
      ..lineTo(center.dx + s * 0.6, center.dy + s * 0.1)
      ..lineTo(center.dx + s * 0.55, center.dy - s * 0.35)
      ..close();

    final facePaint = Paint()..color = const Color(0xFF0A0014);
    canvas.drawPath(facePath, facePaint);

    // Contorno neon rosa
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFFF1744)
          .withOpacity(0.6 + 0.35 * pulse);
    canvas.drawPath(facePath, outlinePaint);

    // Listras diagonais ciano/rosa alternadas
    final stripeColors = [
      const Color(0xFF00E5FF),
      const Color(0xFFFF1744),
    ];
    for (int i = 0; i < 6; i++) {
      final t = i / 5;
      final y = center.dy - s * 0.4 + t * s * 0.9;
      final stripePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = stripeColors[i % 2]
            .withOpacity(0.55 + 0.4 * ((scan + t) % 1.0 < 0.5 ? 1 : 0.3));
      canvas.drawLine(
        Offset(center.dx - s * 0.4 + t * s * 0.15, y - s * 0.06),
        Offset(center.dx + s * 0.4 - t * s * 0.15, y + s * 0.06),
        stripePaint,
      );
    }

    // Scanline horizontal percorrendo o rosto (efeito cyberpunk)
    final scanY = center.dy - s * 0.55 + (scan % 1.0) * s * 1.1;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00E5FF).withOpacity(0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(
          center.dx - s * 0.6, scanY - 3, s * 1.2, 6));
    canvas.drawRect(
        Rect.fromLTWH(center.dx - s * 0.6, scanY - 3, s * 1.2, 6),
        scanPaint);

    // Olhos neon
    final eyePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7 + 0.3 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
        Offset(center.dx - s * 0.2, center.dy - s * 0.05), 2.8, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + s * 0.2, center.dy - s * 0.05), 2.8, eyePaint);

    // Focinho
    final nosePaint = Paint()
      ..color = const Color(0xFFFF1744).withOpacity(0.75 + 0.25 * pulse);
    canvas.drawCircle(Offset(center.dx, center.dy + s * 0.28), 2.4, nosePaint);
  }

  @override
  bool shouldRepaint(_TigreNeonPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.scan != scan;
}

// ═══════════════════════════════════════════════════════════════════
// 11) RAINHA DO GELO — cristais girando sobre coroa congelada
// ═══════════════════════════════════════════════════════════════════
class _RainhaGeloAvatar extends StatefulWidget {
  final double size;
  const _RainhaGeloAvatar({required this.size});

  @override
  State<_RainhaGeloAvatar> createState() => _RainhaGeloAvatarState();
}

class _RainhaGeloAvatarState extends State<_RainhaGeloAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spinCtrl, _shimmerCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RainhaGeloPainter(
            spin: _spinCtrl.value,
            shimmer: _shimmerCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _RainhaGeloPainter extends CustomPainter {
  final double spin;
  final double shimmer;
  _RainhaGeloPainter({required this.spin, required this.shimmer});

  void _drawSnowflake(Canvas canvas, Offset pos, double radius, double rot,
      Paint paint) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rot);
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      canvas.drawLine(Offset.zero, Offset(0, -radius), paint);
      canvas.drawLine(Offset(0, -radius * 0.6),
          Offset(radius * 0.25, -radius * 0.8), paint);
      canvas.drawLine(Offset(0, -radius * 0.6),
          Offset(-radius * 0.25, -radius * 0.8), paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF0A2A40), const Color(0xFF001220)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Flocos de neve orbitando
    final flakePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.5 + 0.3 * shimmer);
    for (int i = 0; i < 4; i++) {
      final a = spin * 2 * math.pi + i * math.pi / 2;
      final pos = Offset(
        center.dx + math.cos(a) * r * 0.78,
        center.dy + math.sin(a) * r * 0.78,
      );
      _drawSnowflake(canvas, pos, 5.5, a, flakePaint);
    }

    // Silhueta de coroa/rosto congelado central (formato diamante)
    final s = r * 0.6;
    final diamondPath = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s * 0.65, center.dy - s * 0.15)
      ..lineTo(center.dx, center.dy + s * 0.9)
      ..lineTo(center.dx - s * 0.65, center.dy - s * 0.15)
      ..close();

    final diamondPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.95),
          const Color(0xFF81D4FA),
          const Color(0xFF01579B),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    canvas.drawPath(diamondPath, diamondPaint);

    final facetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.6);
    canvas.drawLine(Offset(center.dx, center.dy - s),
        Offset(center.dx, center.dy + s * 0.9), facetPaint);
    canvas.drawLine(
        Offset(center.dx - s * 0.65, center.dy - s * 0.15),
        Offset(center.dx + s * 0.65, center.dy - s * 0.15),
        facetPaint);

    // Coroa pequena no topo
    final crownPaint = Paint()..color = Colors.white.withOpacity(0.9);
    for (int i = -1; i <= 1; i++) {
      canvas.drawCircle(
          Offset(center.dx + i * s * 0.28, center.dy - s * 1.05),
          2.2,
          crownPaint);
    }

    // Brilho central
    final glowPaint = Paint()
      ..color = const Color(0xFF80DEEA).withOpacity(0.3 + 0.2 * shimmer)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, s * 0.5, glowPaint);
  }

  @override
  bool shouldRepaint(_RainhaGeloPainter oldDelegate) =>
      oldDelegate.spin != spin || oldDelegate.shimmer != shimmer;
}

// ═══════════════════════════════════════════════════════════════════
// 12) PANTERA MÍSTICA — silhueta ágil, olhos violeta, névoa arcana
// ═══════════════════════════════════════════════════════════════════
class _PanteraMisticaAvatar extends StatefulWidget {
  final double size;
  const _PanteraMisticaAvatar({required this.size});

  @override
  State<_PanteraMisticaAvatar> createState() => _PanteraMisticaAvatarState();
}

class _PanteraMisticaAvatarState extends State<_PanteraMisticaAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _mistCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _mistCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
          painter: _PanteraMisticaPainter(
            mist: _mistCtrl.value,
            glow: _glowCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _PanteraMisticaPainter extends CustomPainter {
  final double mist;
  final double glow;
  _PanteraMisticaPainter({required this.mist, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF14002B), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Névoa arcana violeta
    for (int i = 0; i < 4; i++) {
      final phase = (mist + i * 0.25) % 1.0;
      final angle = phase * 2 * math.pi;
      final mistPaint = Paint()
        ..color = const Color(0xFF7C4DFF).withOpacity((1 - phase) * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx + math.cos(angle) * r * 0.4,
            center.dy + math.sin(angle) * r * 0.4,
          ),
          width: r * 0.7,
          height: r * 0.3,
        ),
        mistPaint,
      );
    }

    // Cabeça de pantera — silhueta suave e arredondada
    final s = r * 0.82;
    final headPath = Path()
      ..moveTo(center.dx, center.dy - s * 0.5)
      ..quadraticBezierTo(center.dx - s * 0.5, center.dy - s * 0.45,
          center.dx - s * 0.55, center.dy - s * 0.05)
      ..quadraticBezierTo(center.dx - s * 0.6, center.dy + s * 0.3,
          center.dx - s * 0.3, center.dy + s * 0.6)
      ..lineTo(center.dx, center.dy + s * 0.7)
      ..lineTo(center.dx + s * 0.3, center.dy + s * 0.6)
      ..quadraticBezierTo(center.dx + s * 0.6, center.dy + s * 0.3,
          center.dx + s * 0.55, center.dy - s * 0.05)
      ..quadraticBezierTo(center.dx + s * 0.5, center.dy - s * 0.45,
          center.dx, center.dy - s * 0.5)
      ..close();

    // Orelhas
    final earL = Path()
      ..moveTo(center.dx - s * 0.35, center.dy - s * 0.4)
      ..lineTo(center.dx - s * 0.5, center.dy - s * 0.78)
      ..lineTo(center.dx - s * 0.12, center.dy - s * 0.5)
      ..close();
    final earR = Path()
      ..moveTo(center.dx + s * 0.35, center.dy - s * 0.4)
      ..lineTo(center.dx + s * 0.5, center.dy - s * 0.78)
      ..lineTo(center.dx + s * 0.12, center.dy - s * 0.5)
      ..close();

    final silhouettePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1A0033),
          Colors.black,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    canvas.drawPath(earL, silhouettePaint);
    canvas.drawPath(earR, silhouettePaint);
    canvas.drawPath(headPath, silhouettePaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF7C4DFF).withOpacity(0.4);
    canvas.drawPath(headPath, rimPaint);

    // Olhos violeta brilhantes
    final eyeGlow = 0.6 + 0.4 * glow;
    final eyePaint = Paint()
      ..color = const Color(0xFFB388FF).withOpacity(eyeGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx - s * 0.18, center.dy - s * 0.02),
          width: 6,
          height: 3.4),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx + s * 0.18, center.dy - s * 0.02),
          width: 6,
          height: 3.4),
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(_PanteraMisticaPainter oldDelegate) =>
      oldDelegate.mist != mist || oldDelegate.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// 13) FÊNIX OURO ROSA — plumagem metálica rosé, brilho a cada batida
// ═══════════════════════════════════════════════════════════════════
class _FenixOuroRosaAvatar extends StatefulWidget {
  final double size;
  const _FenixOuroRosaAvatar({required this.size});

  @override
  State<_FenixOuroRosaAvatar> createState() => _FenixOuroRosaAvatarState();
}

class _FenixOuroRosaAvatarState extends State<_FenixOuroRosaAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _wingCtrl;
  late final AnimationController _shineCtrl;

  @override
  void initState() {
    super.initState();
    _wingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _wingCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wingCtrl, _shineCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FenixOuroRosaPainter(
            wing: _wingCtrl.value,
            shine: _shineCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _FenixOuroRosaPainter extends CustomPainter {
  final double wing;
  final double shine;
  _FenixOuroRosaPainter({required this.wing, required this.shine});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2E1A22), const Color(0xFF120A0D)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final wingLift = 0.75 + 0.25 * wing;

    // Asas em leque metálico rosé
    for (final side in [-1.0, 1.0]) {
      for (int i = 0; i < 6; i++) {
        final t = i / 5;
        final len = r * (0.5 + 0.4 * t) * wingLift;
        final baseAngle = side * (math.pi * 0.12 + t * math.pi * 0.3);
        final start = Offset(center.dx, center.dy + r * 0.05);
        final end = Offset(
          center.dx + math.sin(baseAngle) * len * side.sign,
          center.dy - math.cos(baseAngle) * len * 0.65,
        );
        final ctrl = Offset(
            center.dx + side * len * 0.55, center.dy - len * 0.3);

        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

        final shimmerPhase = (shine + t + (side > 0 ? 0.5 : 0)) % 1.0;
        final featherPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 - t * 1.2
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            const Color(0xFFF8BBD0),
            const Color(0xFFEEA6A0),
            shimmerPhase,
          )!
              .withOpacity(0.55 + 0.35 * wingLift);
        canvas.drawPath(path, featherPaint);
      }
    }

    // Corpo central metálico
    final bodyPath = Path()
      ..moveTo(center.dx, center.dy - r * 0.5)
      ..quadraticBezierTo(center.dx + r * 0.2, center.dy - r * 0.05,
          center.dx, center.dy + r * 0.48)
      ..quadraticBezierTo(center.dx - r * 0.2, center.dy - r * 0.05,
          center.dx, center.dy - r * 0.5);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.white,
          Color(0xFFF8BBD0),
          Color(0xFFEEA6A0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.55));
    canvas.drawPath(bodyPath, bodyPaint);

    // Brilho metálico que percorre o corpo
    final shinePos = -r * 0.4 + (shine % 1.0) * r * 0.8;
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
        Offset(center.dx, center.dy + shinePos), 3, shinePaint);
  }

  @override
  bool shouldRepaint(_FenixOuroRosaPainter oldDelegate) =>
      oldDelegate.wing != wing || oldDelegate.shine != shine;
}

// ═══════════════════════════════════════════════════════════════════
// 14) GOLEM DE MAGMA — rocha vulcânica com rachaduras incandescentes
// ═══════════════════════════════════════════════════════════════════
class _GolemMagmaAvatar extends StatefulWidget {
  final double size;
  const _GolemMagmaAvatar({required this.size});

  @override
  State<_GolemMagmaAvatar> createState() => _GolemMagmaAvatarState();
}

class _GolemMagmaAvatarState extends State<_GolemMagmaAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _emberCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _emberCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _emberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _emberCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _GolemMagmaPainter(
            pulse: _pulseCtrl.value,
            ember: _emberCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _GolemMagmaPainter extends CustomPainter {
  final double pulse;
  final double ember;
  _GolemMagmaPainter({required this.pulse, required this.ember});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A0500), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Corpo rochoso — polígono irregular
    final s = r * 0.85;
    final rockPath = Path()
      ..moveTo(center.dx - s * 0.3, center.dy - s * 0.75)
      ..lineTo(center.dx + s * 0.35, center.dy - s * 0.6)
      ..lineTo(center.dx + s * 0.6, center.dy - s * 0.1)
      ..lineTo(center.dx + s * 0.45, center.dy + s * 0.5)
      ..lineTo(center.dx, center.dy + s * 0.75)
      ..lineTo(center.dx - s * 0.5, center.dy + s * 0.45)
      ..lineTo(center.dx - s * 0.6, center.dy - s * 0.15)
      ..close();

    final rockPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF2B1810),
          const Color(0xFF120704),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    canvas.drawPath(rockPath, rockPaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFF6E40).withOpacity(0.3);
    canvas.drawPath(rockPath, outlinePaint);

    // Rachaduras incandescentes (linhas irregulares pulsantes)
    final crackGlow = 0.5 + 0.5 * pulse;
    final crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(const Color(0xFFFF3D00), const Color(0xFFFFD54F),
              pulse)!
          .withOpacity(crackGlow);

    final crack1 = Path()
      ..moveTo(center.dx, center.dy - s * 0.6)
      ..lineTo(center.dx - s * 0.1, center.dy - s * 0.2)
      ..lineTo(center.dx + s * 0.15, center.dy)
      ..lineTo(center.dx - s * 0.05, center.dy + s * 0.35)
      ..lineTo(center.dx + s * 0.1, center.dy + s * 0.65);
    canvas.drawPath(crack1, crackPaint);

    final crack2 = Path()
      ..moveTo(center.dx - s * 0.45, center.dy - s * 0.1)
      ..lineTo(center.dx - s * 0.2, center.dy + s * 0.05)
      ..lineTo(center.dx - s * 0.3, center.dy + s * 0.35);
    canvas.drawPath(crack2, crackPaint);

    final crack3 = Path()
      ..moveTo(center.dx + s * 0.3, center.dy - s * 0.3)
      ..lineTo(center.dx + s * 0.2, center.dy)
      ..lineTo(center.dx + s * 0.35, center.dy + s * 0.25);
    canvas.drawPath(crack3, crackPaint);

    // Brilho interno geral (batimento de magma)
    final coreGlow = Paint()
      ..color = const Color(0xFFFF3D00).withOpacity(0.15 * crackGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, s * 0.5, coreGlow);

    // Faíscas/brasas subindo
    for (int i = 0; i < 5; i++) {
      final t = (ember + i * 0.2) % 1.0;
      final dx = math.sin(i * 2.1 + t * 6) * s * 0.35;
      final dy = s * (0.6 - t * 1.3);
      final emberPaint = Paint()
        ..color = const Color(0xFFFFAB40).withOpacity((1 - t) * 0.8);
      canvas.drawCircle(
          Offset(center.dx + dx, center.dy + dy), 1.4, emberPaint);
    }

    // Olhos incandescentes
    final eyePaint = Paint()
      ..color = Color.lerp(
              const Color(0xFFFF3D00), const Color(0xFFFFD54F), pulse)!
          .withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
        Offset(center.dx - s * 0.16, center.dy - s * 0.15), 2.6, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + s * 0.16, center.dy - s * 0.15), 2.6, eyePaint);
  }

  @override
  bool shouldRepaint(_GolemMagmaPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.ember != ember;
}

// ═══════════════════════════════════════════════════════════════════
// 15) DEUSA ESTELAR — constelação viva em véu de poeira cósmica
// ═══════════════════════════════════════════════════════════════════
class _DeusaEstelarAvatar extends StatefulWidget {
  final double size;
  const _DeusaEstelarAvatar({required this.size});

  @override
  State<_DeusaEstelarAvatar> createState() => _DeusaEstelarAvatarState();
}

class _DeusaEstelarAvatarState extends State<_DeusaEstelarAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _rotCtrl;
  late final AnimationController _twinkleCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _twinkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _twinkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotCtrl, _twinkleCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _DeusaEstelarPainter(
            rotation: _rotCtrl.value,
            twinkle: _twinkleCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _DeusaEstelarPainter extends CustomPainter {
  final double rotation;
  final double twinkle;
  _DeusaEstelarPainter({required this.rotation, required this.twinkle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A237E), const Color(0xFF05061A)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Silhueta feminina estilizada em véu — formato ampulheta suave
    final s = r * 0.78;
    final silhouettePath = Path()
      ..moveTo(center.dx, center.dy - s * 0.85) // topo da cabeça
      ..quadraticBezierTo(center.dx + s * 0.22, center.dy - s * 0.6,
          center.dx + s * 0.15, center.dy - s * 0.35) // pescoço/ombro
      ..quadraticBezierTo(center.dx + s * 0.5, center.dy - s * 0.1,
          center.dx + s * 0.35, center.dy + s * 0.4) // véu/manto direito
      ..quadraticBezierTo(
          center.dx + s * 0.15, center.dy + s * 0.85, center.dx, center.dy + s)
      ..quadraticBezierTo(center.dx - s * 0.15, center.dy + s * 0.85,
          center.dx - s * 0.35, center.dy + s * 0.4)
      ..quadraticBezierTo(center.dx - s * 0.5, center.dy - s * 0.1,
          center.dx - s * 0.15, center.dy - s * 0.35)
      ..quadraticBezierTo(
          center.dx - s * 0.22, center.dy - s * 0.6, center.dx, center.dy - s * 0.85)
      ..close();

    final silhouettePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF3949AB).withOpacity(0.55),
          const Color(0xFF0D1240).withOpacity(0.85),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s));
    canvas.drawPath(silhouettePath, silhouettePaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF9FA8FF).withOpacity(0.5);
    canvas.drawPath(silhouettePath, rimPaint);

    // Constelação de estrelas dentro/ao redor da silhueta, girando
    final starOffsets = <Offset>[
      const Offset(-0.12, -0.55),
      const Offset(0.14, -0.4),
      const Offset(-0.22, -0.1),
      const Offset(0.2, 0.05),
      const Offset(0.0, 0.25),
      const Offset(-0.15, 0.45),
      const Offset(0.22, 0.5),
    ];
    final starPoints = <Offset>[];
    for (int i = 0; i < starOffsets.length; i++) {
      final o = starOffsets[i];
      final wobble = math.sin(rotation * 2 * math.pi + i) * 0.015;
      final p = Offset(
        center.dx + (o.dx + wobble) * s,
        center.dy + o.dy * s,
      );
      starPoints.add(p);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF9FA8FF).withOpacity(0.35);
    for (int i = 0; i < starPoints.length - 1; i++) {
      canvas.drawLine(starPoints[i], starPoints[i + 1], linePaint);
    }

    for (int i = 0; i < starPoints.length; i++) {
      final tw = (0.5 + 0.5 * math.sin(twinkle * 2 * math.pi + i * 1.3));
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(0.5 + 0.5 * tw)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(starPoints[i], 1.6 + tw * 0.8, starPaint);
    }

    // Coroa estelar sobre a cabeça
    final crownGlow = Paint()
      ..color = const Color(0xFFE0E0FF).withOpacity(0.5 + 0.3 * twinkle)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
        Offset(center.dx, center.dy - s * 0.85), 3.0, crownGlow);
  }

  @override
  bool shouldRepaint(_DeusaEstelarPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.twinkle != twinkle;
}

// ═══════════════════════════════════════════════════════════════════
// 16) LEÃO DOURADO REAL — juba solar flamejante, olhar imponente
// ═══════════════════════════════════════════════════════════════════
class _LeaoDouradoRealAvatar extends StatefulWidget {
  final double size;
  const _LeaoDouradoRealAvatar({required this.size});

  @override
  State<_LeaoDouradoRealAvatar> createState() =>
      _LeaoDouradoRealAvatarState();
}

class _LeaoDouradoRealAvatarState extends State<_LeaoDouradoRealAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _flameCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _flameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flameCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flameCtrl, _glowCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LeaoDouradoRealPainter(
            flame: _flameCtrl.value,
            glow: _glowCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _LeaoDouradoRealPainter extends CustomPainter {
  final double flame;
  final double glow;
  _LeaoDouradoRealPainter({required this.flame, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF3A1F00), Colors.black],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    // Juba — mechas triangulares flamejantes ao redor da cabeça
    const strands = 16;
    for (int i = 0; i < strands; i++) {
      final baseAngle = (i / strands) * 2 * math.pi;
      final flicker =
          0.8 + 0.2 * math.sin(flame * 2 * math.pi + i * 0.7);
      final innerR = r * 0.42;
      final outerR = r * (0.75 + 0.12 * math.sin(flame * 2 * math.pi * 1.3 + i));

      final p1 = Offset(
        center.dx + math.cos(baseAngle - 0.09) * innerR,
        center.dy + math.sin(baseAngle - 0.09) * innerR,
      );
      final p2 = Offset(
        center.dx + math.cos(baseAngle + 0.09) * innerR,
        center.dy + math.sin(baseAngle + 0.09) * innerR,
      );
      final tip = Offset(
        center.dx + math.cos(baseAngle) * outerR,
        center.dy + math.sin(baseAngle) * outerR,
      );

      final strandPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      final strandPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF8D4E00),
            Color.lerp(const Color(0xFFFFB300), const Color(0xFFFFD54F),
                flicker)!,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: outerR));
      canvas.drawPath(strandPath, strandPaint);
    }

    // Rosto do leão — círculo dourado central
    final facePaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFFFFD54F), Color(0xFFC77800)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.42));
    canvas.drawCircle(center, r * 0.4, facePaint);

    // Focinho
    final snoutPaint = Paint()..color = const Color(0xFFFFF3E0);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + r * 0.14),
          width: r * 0.3,
          height: r * 0.22),
      snoutPaint,
    );
    final nosePaint = Paint()..color = const Color(0xFF3E2200);
    final nosePath = Path()
      ..moveTo(center.dx - r * 0.05, center.dy + r * 0.08)
      ..lineTo(center.dx + r * 0.05, center.dy + r * 0.08)
      ..lineTo(center.dx, center.dy + r * 0.14)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // Olhos imponentes com brilho
    final eyeGlow = 0.6 + 0.4 * glow;
    final eyePaint = Paint()
      ..color = const Color(0xFF3E2200).withOpacity(0.9);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx - r * 0.15, center.dy - r * 0.02),
          width: 7,
          height: 4.2),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx + r * 0.15, center.dy - r * 0.02),
          width: 7,
          height: 4.2),
      eyePaint,
    );
    final pupilGlow = Paint()
      ..color = const Color(0xFFFFECB3).withOpacity(eyeGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(
        Offset(center.dx - r * 0.15, center.dy - r * 0.02), 1.6, pupilGlow);
    canvas.drawCircle(
        Offset(center.dx + r * 0.15, center.dy - r * 0.02), 1.6, pupilGlow);

    // Coroa pequena entre os olhos (toque "real")
    final crownPaint = Paint()..color = const Color(0xFFFFF3E0);
    final crownPath = Path()
      ..moveTo(center.dx - r * 0.06, center.dy - r * 0.22)
      ..lineTo(center.dx - r * 0.03, center.dy - r * 0.3)
      ..lineTo(center.dx, center.dy - r * 0.24)
      ..lineTo(center.dx + r * 0.03, center.dy - r * 0.3)
      ..lineTo(center.dx + r * 0.06, center.dy - r * 0.22)
      ..close();
    canvas.drawPath(crownPath, crownPaint);
  }

  @override
  bool shouldRepaint(_LeaoDouradoRealPainter oldDelegate) =>
      oldDelegate.flame != flame || oldDelegate.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// 17) ORQUÍDEA LUNAR — pétalas lilás desabrochando sob luz prateada
// ═══════════════════════════════════════════════════════════════════
class _OrquideaLunarAvatar extends StatefulWidget {
  final double size;
  const _OrquideaLunarAvatar({required this.size});

  @override
  State<_OrquideaLunarAvatar> createState() => _OrquideaLunarAvatarState();
}

class _OrquideaLunarAvatarState extends State<_OrquideaLunarAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _bloomCtrl;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _bloomCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bloomCtrl, _glowCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _OrquideaLunarPainter(
            bloom: _bloomCtrl.value,
            glow: _glowCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _OrquideaLunarPainter extends CustomPainter {
  final double bloom;
  final double glow;
  _OrquideaLunarPainter({required this.bloom, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2A1A38), const Color(0xFF0F0A14)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final openness = 0.7 + 0.3 * bloom;
    const petalCount = 5;
    for (int i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * 2 * math.pi;
      final len = r * 0.62 * openness;
      final tip = Offset(
        center.dx + math.cos(angle) * len,
        center.dy + math.sin(angle) * len,
      );
      final spread = math.pi / petalCount * 0.75;
      final c1 = Offset(
        center.dx + math.cos(angle - spread) * len * 0.55,
        center.dy + math.sin(angle - spread) * len * 0.55,
      );
      final c2 = Offset(
        center.dx + math.cos(angle + spread) * len * 0.55,
        center.dy + math.sin(angle + spread) * len * 0.55,
      );

      final petal = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, center.dx, center.dy);

      final petalPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment(math.cos(angle).toDouble(), math.sin(angle).toDouble()),
          colors: const [Color(0xFFCE93D8), Color(0xFF4A148C)],
        ).createShader(Rect.fromCircle(center: center, radius: len));
      canvas.drawPath(petal, petalPaint);
    }

    // Núcleo prateado pulsante
    final glowRadius = r * (0.14 + 0.05 * math.sin(glow * 2 * math.pi));
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, const Color(0xFFE1BEE7).withOpacity(0.2)],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius * 2));
    canvas.drawCircle(center, glowRadius, corePaint);

    // Poeira de luz orbitando
    for (int i = 0; i < 6; i++) {
      final a = glow * 2 * math.pi + i * math.pi / 3;
      final d = r * 0.75;
      final p = Offset(center.dx + math.cos(a) * d, center.dy + math.sin(a) * d);
      final dust = Paint()..color = Colors.white.withOpacity(0.5);
      canvas.drawCircle(p, 1.4, dust);
    }
  }

  @override
  bool shouldRepaint(_OrquideaLunarPainter oldDelegate) =>
      oldDelegate.bloom != bloom || oldDelegate.glow != glow;
}

// ═══════════════════════════════════════════════════════════════════
// 18) BORBOLETA DE CRISTAL — asas translúcidas batendo suavemente
// ═══════════════════════════════════════════════════════════════════
class _BorboletaCristalAvatar extends StatefulWidget {
  final double size;
  const _BorboletaCristalAvatar({required this.size});

  @override
  State<_BorboletaCristalAvatar> createState() =>
      _BorboletaCristalAvatarState();
}

class _BorboletaCristalAvatarState extends State<_BorboletaCristalAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _wingCtrl;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _wingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _wingCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wingCtrl, _shimmerCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _BorboletaCristalPainter(
            wing: _wingCtrl.value,
            shimmer: _shimmerCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _BorboletaCristalPainter extends CustomPainter {
  final double wing;
  final double shimmer;
  _BorboletaCristalPainter({required this.wing, required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF14262B), const Color(0xFF0A1114)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final flap = 0.35 + 0.65 * wing;

    for (final side in [-1.0, 1.0]) {
      // Asa superior
      final upperTip = Offset(
        center.dx + side * r * 0.85 * flap,
        center.dy - r * 0.45,
      );
      final upperPath = Path()
        ..moveTo(center.dx, center.dy - r * 0.1)
        ..quadraticBezierTo(
            center.dx + side * r * 0.5, center.dy - r * 0.75,
            upperTip.dx, upperTip.dy)
        ..quadraticBezierTo(
            center.dx + side * r * 0.35, center.dy - r * 0.15,
            center.dx, center.dy - r * 0.1);
      final upperPaint = Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF80DEEA), Color(0xFFF48FB1)],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..color = Colors.white.withOpacity(0.75 * flap + 0.15);
      canvas.drawPath(upperPath, upperPaint);

      // Asa inferior
      final lowerTip = Offset(
        center.dx + side * r * 0.55 * flap,
        center.dy + r * 0.55,
      );
      final lowerPath = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
            center.dx + side * r * 0.4, center.dy + r * 0.4,
            lowerTip.dx, lowerTip.dy)
        ..quadraticBezierTo(
            center.dx + side * r * 0.2, center.dy + r * 0.1,
            center.dx, center.dy);
      final lowerPaint = Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFFF48FB1), Color(0xFF80DEEA)],
        ).createShader(Rect.fromCircle(center: center, radius: r))
        ..color = Colors.white.withOpacity(0.6 * flap + 0.15);
      canvas.drawPath(lowerPath, lowerPaint);

      // Veios de brilho
      final veinPhase = (shimmer + (side > 0 ? 0.5 : 0)) % 1.0;
      final veinPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withOpacity(0.3 + 0.3 * veinPhase);
      canvas.drawLine(
          Offset(center.dx, center.dy - r * 0.1), upperTip, veinPaint);
    }

    // Corpo central
    final bodyPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 0.1, height: r * 0.9),
      bodyPaint,
    );
  }

  @override
  bool shouldRepaint(_BorboletaCristalPainter oldDelegate) =>
      oldDelegate.wing != wing || oldDelegate.shimmer != shimmer;
}

// ═══════════════════════════════════════════════════════════════════
// 19) FLOR DE CEREJEIRA — pétalas rosadas flutuando em espiral
// ═══════════════════════════════════════════════════════════════════
class _FlorCerejeiraAvatar extends StatefulWidget {
  final double size;
  const _FlorCerejeiraAvatar({required this.size});

  @override
  State<_FlorCerejeiraAvatar> createState() => _FlorCerejeiraAvatarState();
}

class _FlorCerejeiraAvatarState extends State<_FlorCerejeiraAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _driftCtrl;

  @override
  void initState() {
    super.initState();
    _driftCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _driftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: _driftCtrl,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _FlorCerejeiraPainter(drift: _driftCtrl.value),
        ),
      ),
    );
  }
}

class _FlorCerejeiraPainter extends CustomPainter {
  final double drift;
  _FlorCerejeiraPainter({required this.drift});

  void _drawBlossom(Canvas canvas, Offset pos, double scale, double rot) {
    for (int i = 0; i < 5; i++) {
      final angle = rot + (i / 5) * 2 * math.pi;
      final petalCenter = Offset(
        pos.dx + math.cos(angle) * scale * 0.5,
        pos.dy + math.sin(angle) * scale * 0.5,
      );
      final petalPaint = Paint()
        ..color = const Color(0xFFF06292).withOpacity(0.85);
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: scale * 0.55, height: scale * 0.35),
        petalPaint,
      );
      canvas.restore();
    }
    canvas.drawCircle(pos, scale * 0.18, Paint()..color = const Color(0xFFFFF0F3));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2E1520), const Color(0xFF120A0E)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    _drawBlossom(canvas, center, r * 0.65, drift * 2 * math.pi);

    // Pétalas soltas flutuando em espiral ao redor
    for (int i = 0; i < 7; i++) {
      final t = ((drift + i / 7) % 1.0);
      final angle = t * 2 * math.pi * 1.6;
      final dist = r * (0.35 + 0.55 * t);
      final p = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final petalScale = r * (0.16 - 0.06 * t);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle * 1.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: petalScale, height: petalScale * 0.6),
        Paint()..color = const Color(0xFFFFCDD2).withOpacity(0.8 * (1 - t) + 0.15),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlorCerejeiraPainter oldDelegate) =>
      oldDelegate.drift != drift;
}

// ═══════════════════════════════════════════════════════════════════
// 20) CORAÇÃO AURORA — núcleo em forma de coração pulsando em pastel
// ═══════════════════════════════════════════════════════════════════
class _CoracaoAuroraAvatar extends StatefulWidget {
  final double size;
  const _CoracaoAuroraAvatar({required this.size});

  @override
  State<_CoracaoAuroraAvatar> createState() => _CoracaoAuroraAvatarState();
}

class _CoracaoAuroraAvatarState extends State<_CoracaoAuroraAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _hueCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _hueCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _hueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _hueCtrl]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _CoracaoAuroraPainter(
            pulse: _pulseCtrl.value,
            hue: _hueCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _CoracaoAuroraPainter extends CustomPainter {
  final double pulse;
  final double hue;
  _CoracaoAuroraPainter({required this.pulse, required this.hue});

  Path _heartPath(Offset center, double s) {
    return Path()
      ..moveTo(center.dx, center.dy + s * 0.35)
      ..cubicTo(
        center.dx - s * 0.9, center.dy - s * 0.35,
        center.dx - s * 0.35, center.dy - s * 0.95,
        center.dx, center.dy - s * 0.4,
      )
      ..cubicTo(
        center.dx + s * 0.35, center.dy - s * 0.95,
        center.dx + s * 0.9, center.dy - s * 0.35,
        center.dx, center.dy + s * 0.35,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF2A1A24), const Color(0xFF120A10)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final beat = 0.85 + 0.15 * pulse;
    final heart = _heartPath(Offset(center.dx, center.dy + r * 0.05), r * 0.62 * beat);

    final colorA = Color.lerp(
        const Color(0xFFF8BBD0), const Color(0xFFCE93D8), (math.sin(hue * 2 * math.pi) + 1) / 2)!;
    final heartPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, colorA],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.65));
    canvas.drawPath(heart, heartPaint);

    // Halo suave ao redor
    final haloPaint = Paint()
      ..color = colorA.withOpacity(0.25 * beat)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, r * 0.7 * beat, haloPaint);

    // Partículas de aurora orbitando
    for (int i = 0; i < 5; i++) {
      final a = hue * 2 * math.pi + i * (2 * math.pi / 5);
      final d = r * 0.82;
      final p = Offset(center.dx + math.cos(a) * d, center.dy + math.sin(a) * d);
      canvas.drawCircle(p, 1.6, Paint()..color = Colors.white.withOpacity(0.6));
    }
  }

  @override
  bool shouldRepaint(_CoracaoAuroraPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.hue != hue;
}

// ═══════════════════════════════════════════════════════════════════
// 21) PENA DE CISNE — plumagem branca leve flutuando sobre névoa
// ═══════════════════════════════════════════════════════════════════
class _PenaCisneAvatar extends StatefulWidget {
  final double size;
  const _PenaCisneAvatar({required this.size});

  @override
  State<_PenaCisneAvatar> createState() => _PenaCisneAvatarState();
}

class _PenaCisneAvatarState extends State<_PenaCisneAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _PenaCisnePainter(float: _floatCtrl.value),
        ),
      ),
    );
  }
}

class _PenaCisnePainter extends CustomPainter {
  final double float;
  _PenaCisnePainter({required this.float});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1A2630), const Color(0xFF0A1014)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final bob = math.sin(float * 2 * math.pi) * r * 0.06;
    final tilt = math.sin(float * 2 * math.pi) * 0.15;

    canvas.save();
    canvas.translate(center.dx, center.dy + bob);
    canvas.rotate(tilt);

    // Haste central
    final shaftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFB3E5FC);
    canvas.drawLine(Offset(0, -r * 0.7), Offset(0, r * 0.6), shaftPaint);

    // Barbas da pena
    for (final side in [-1.0, 1.0]) {
      for (int i = 0; i < 10; i++) {
        final t = i / 9;
        final y = -r * 0.65 + t * r * 1.2;
        final len = r * 0.45 * math.sin(t * math.pi) ;
        final start = Offset(0, y);
        final end = Offset(side * len, y + len * 0.3);
        final barbPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(0.75 - t * 0.3);
        canvas.drawLine(start, end, barbPaint);
      }
    }
    canvas.restore();

    // Névoa suave na base
    final mistPaint = Paint()
      ..color = const Color(0xFFE1F5FE).withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(center.dx, center.dy + r * 0.5), r * 0.5, mistPaint);
  }

  @override
  bool shouldRepaint(_PenaCisnePainter oldDelegate) =>
      oldDelegate.float != float;
}

// ═══════════════════════════════════════════════════════════════════
// 22) JARDIM ZAFIRA — flores azuis desabrochando em ciclo contínuo
// ═══════════════════════════════════════════════════════════════════
class _JardimZafiraAvatar extends StatefulWidget {
  final double size;
  const _JardimZafiraAvatar({required this.size});

  @override
  State<_JardimZafiraAvatar> createState() => _JardimZafiraAvatarState();
}

class _JardimZafiraAvatarState extends State<_JardimZafiraAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _cycleCtrl;

  @override
  void initState() {
    super.initState();
    _cycleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _cycleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _circleShell(
      size: widget.size,
      child: AnimatedBuilder(
        animation: _cycleCtrl,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _JardimZafiraPainter(cycle: _cycleCtrl.value),
        ),
      ),
    );
  }
}

class _JardimZafiraPainter extends CustomPainter {
  final double cycle;
  _JardimZafiraPainter({required this.cycle});

  void _drawFlower(Canvas canvas, Offset pos, double bloomT) {
    final scale = (0.3 + 0.7 * bloomT);
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi;
      final petalCenter = Offset(
        pos.dx + math.cos(angle) * scale * 6,
        pos.dy + math.sin(angle) * scale * 6,
      );
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: scale * 9, height: scale * 5),
        Paint()..color = const Color(0xFF64B5F6).withOpacity(0.4 + 0.5 * bloomT),
      );
      canvas.restore();
    }
    canvas.drawCircle(pos, scale * 3, Paint()..color = const Color(0xFFE3F2FD));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF122238), const Color(0xFF080E18)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bgPaint);

    final positions = [
      Offset(center.dx, center.dy - r * 0.32),
      Offset(center.dx - r * 0.42, center.dy + r * 0.18),
      Offset(center.dx + r * 0.42, center.dy + r * 0.18),
      Offset(center.dx, center.dy + r * 0.5),
    ];

    for (int i = 0; i < positions.length; i++) {
      final phase = (cycle + i * 0.25) % 1.0;
      final bloomT = (math.sin(phase * 2 * math.pi) + 1) / 2;
      canvas.save();
      canvas.translate(positions[i].dx, positions[i].dy);
      canvas.scale(r / 60);
      _drawFlower(canvas, Offset.zero, bloomT);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_JardimZafiraPainter oldDelegate) =>
      oldDelegate.cycle != cycle;
}