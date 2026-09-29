import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

// ═══════════════════════════════════════════════════════════════════
// DISTINTIVO EXCLUSIVO DE ASSINANTE — 100% CustomPainter
// ═══════════════════════════════════════════════════════════════════
// Completamente diferente dos distintivos de nível (BadgeConfig /
// badge_widgets.dart, que usam ícones do font_awesome_flutter com
// glow estático) e do selo de nível (LevelBadge, que flutua no canto
// superior esquerdo do avatar). Este é um selo compacto — um losango facetado com
// aura pulsante e uma varredura de brilho cruzando a superfície —
// pensado para ficar ao lado do nome/nível do assinante, sinalizando
// "assinante" independente de nível ou avatar equipado.
//
// Uso típico: SubscriberBadge(size: 18) ao lado do nome no perfil,
// ranking ou comentários de quem tem premiumTier != none.
// ═══════════════════════════════════════════════════════════════════

class SubscriberBadge extends StatefulWidget {
  final double size;

  /// Quando true, o selo ocupa no layout só `size` x `size` (o brilho e a
  /// aura continuam sendo desenhados para fora, sem clip). Evita que a
  /// área invisível de 1.8x aumente a altura da linha e empurre o nome
  /// para baixo — usado em comentários e respostas.
  final bool compact;

  const SubscriberBadge({Key? key, this.size = 20, this.compact = false})
      : super(key: key);

  @override
  State<SubscriberBadge> createState() => _SubscriberBadgeState();
}

class _SubscriberBadgeState extends State<SubscriberBadge>
    with TickerProviderStateMixin {
  late final AnimationController _auraCtrl;

  // A varredura de brilho (sweep) NÃO usa AnimationController comum.
  // Com `repeat()`, o valor faz wrap de 1.0 → 0.0 a cada 3s; como a
  // posição X da faixa de luz é calculada linearmente a partir desse
  // valor, o wrap fazia a faixa saltar instantaneamente de volta pro
  // início — um "reinício" bem visível. Aqui usamos um Ticker cru
  // que acumula o tempo decorrido sem limite (sem wrap): o valor só
  // cresce, e o `% 1.0` é aplicado só na hora de desenhar, com uma
  // margem extra fora da área clipada para que o salto do ciclo
  // aconteça fora da região visível do selo.
  late final Ticker _sweepTicker;
  double _sweepValue = 0.0; // cresce sem limite, período de 3s

  @override
  void initState() {
    super.initState();
    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _sweepTicker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        _sweepValue = elapsed.inMicroseconds / 3000000.0; // 3s por volta
      });
    })..start();
  }

  @override
  void dispose() {
    _auraCtrl.dispose();
    _sweepTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `_sweepValue` já dispara rebuild via setState no próprio
    // ticker; o AnimatedBuilder só precisa escutar o _auraCtrl.
    final full = widget.size * 1.8;
    final badge = AnimatedBuilder(
      animation: _auraCtrl,
      builder: (context, _) => CustomPaint(
        size: Size.square(full),
        painter: _SubscriberBadgePainter(
          aura: _auraCtrl.value,
          sweep: _sweepValue,
          coreSize: widget.size,
        ),
      ),
    );
    if (!widget.compact) return badge;
    return SizedBox.square(
      dimension: widget.size,
      child: OverflowBox(
        minWidth: full,
        maxWidth: full,
        minHeight: full,
        maxHeight: full,
        child: badge,
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
    // `sweep` cresce sem limite (Ticker); o `% 1.0` aqui é
    // intencional (a faixa precisa "reaparecer" à esquerda depois de
    // cruzar), mas usamos uma margem maior que o losango para que o
    // salto do ciclo aconteça fora da área clipada — invisível.
    canvas.save();
    canvas.clipPath(diamond);
    final sweepMargin = half * 0.6;
    final sweepSpan = 2 * half + sweepMargin * 2;
    final sweepPhase = sweep % 1.0;
    final sweepX = center.dx - half - sweepMargin + sweepSpan * sweepPhase;
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