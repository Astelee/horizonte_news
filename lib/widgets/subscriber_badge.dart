import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// DISTINTIVO EXCLUSIVO DE ASSINANTE — 100% CustomPainter
// ═══════════════════════════════════════════════════════════════════
// Completamente diferente dos distintivos de nível (BadgeConfig /
// badge_widgets.dart, que usam ícones do font_awesome_flutter com
// glow estático) e da moldura de avatar (AvatarFrame, que fica ao
// redor da foto). Este é um selo compacto — um losango facetado com
// aura pulsante e uma varredura de brilho cruzando a superfície —
// pensado para ficar ao lado do nome/nível do assinante, sinalizando
// "assinante" independente de nível ou avatar equipado.
//
// Uso típico: SubscriberBadge(size: 18) ao lado do nome no perfil,
// ranking ou comentários de quem tem premiumTier != none.
// ═══════════════════════════════════════════════════════════════════

class SubscriberBadge extends StatefulWidget {
  final double size;

  const SubscriberBadge({Key? key, this.size = 20}) : super(key: key);

  @override
  State<SubscriberBadge> createState() => _SubscriberBadgeState();
}

class _SubscriberBadgeState extends State<SubscriberBadge>
    with TickerProviderStateMixin {
  late final AnimationController _auraCtrl;
  late final AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _auraCtrl.dispose();
    _sweepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_auraCtrl, _sweepCtrl]),
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size * 1.8),
        painter: _SubscriberBadgePainter(
          aura: _auraCtrl.value,
          sweep: _sweepCtrl.value,
          coreSize: widget.size,
        ),
      ),
    );
  }
}

class _SubscriberBadgePainter extends CustomPainter {
  final double aura;
  final double sweep;
  final double coreSize;

  _SubscriberBadgePainter({
    required this.aura,
    required this.sweep,
    required this.coreSize,
  });

  static const List<Color> _gradient = [
    Color(0xFFFFD54F),
    Color(0xFFFF6B00),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final half = coreSize / 2;

    // ── Aura pulsante ao redor do losango ────────────────────────
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _gradient[0].withOpacity(0.32 * aura),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: half * 2.1));
    canvas.drawCircle(center, half * 2.1, auraPaint);

    // ── Corpo: losango facetado (diamante) ───────────────────────
    final diamond = Path()
      ..moveTo(center.dx, center.dy - half)
      ..lineTo(center.dx + half * 0.78, center.dy)
      ..lineTo(center.dx, center.dy + half)
      ..lineTo(center.dx - half * 0.78, center.dy)
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _gradient,
      ).createShader(Rect.fromCircle(center: center, radius: half));
    canvas.drawPath(diamond, bodyPaint);

    // Facetas internas (linhas do centro pros vértices, como um
    // corte de pedra preciosa)
    final facetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(0.5);
    canvas.drawLine(
        Offset(center.dx, center.dy - half), center, facetPaint);
    canvas.drawLine(
        Offset(center.dx + half * 0.78, center.dy), center, facetPaint);
    canvas.drawLine(
        Offset(center.dx, center.dy + half), center, facetPaint);
    canvas.drawLine(
        Offset(center.dx - half * 0.78, center.dy), center, facetPaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.7);
    canvas.drawPath(diamond, outlinePaint);

    // ── Varredura de brilho cruzando a superfície ────────────────
    canvas.save();
    canvas.clipPath(diamond);
    final sweepX = center.dx - half + (sweep * 2 * half);
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.75),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(sweepX - half * 0.3, center.dy - half,
          half * 0.6, coreSize));
    canvas.drawRect(
        Rect.fromLTWH(
            sweepX - half * 0.3, center.dy - half, half * 0.6, coreSize),
        sweepPaint);
    canvas.restore();

    // ── Estrela central pequena (marca de "exclusivo") ───────────
    final starPaint = Paint()..color = Colors.white.withOpacity(0.95);
    _drawStar(canvas, center, half * 0.22, starPaint);
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * 2 * math.pi;
      final outer = Offset(
          c.dx + math.cos(angle) * r, c.dy + math.sin(angle) * r);
      final innerAngle = angle + math.pi / 4;
      final inner = Offset(
        c.dx + math.cos(innerAngle) * r * 0.35,
        c.dy + math.sin(innerAngle) * r * 0.35,
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SubscriberBadgePainter oldDelegate) =>
      oldDelegate.aura != aura || oldDelegate.sweep != sweep;
}

/// Versão com rótulo "ASSINANTE" ao lado — pronta para uso em listas
/// e cabeçalhos de perfil, sem precisar remontar o layout toda vez.
class SubscriberBadgeTag extends StatelessWidget {
  final double badgeSize;
  final double fontSize;

  const SubscriberBadgeTag({
    Key? key,
    this.badgeSize = 16,
    this.fontSize = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFF6B00)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SubscriberBadge(size: badgeSize),
          const SizedBox(width: 2),
          Text(
            'ASSINANTE',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}