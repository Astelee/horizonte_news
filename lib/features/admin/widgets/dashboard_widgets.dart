import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// NÚMERO ANIMADO — conta suavemente até o valor alvo
// ═══════════════════════════════════════════════════════════════════
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedCounter({
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
    Key? key,
  }) : super(key: key);

  String _format(int v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 10000) {
      return '${(v / 1000).toStringAsFixed(1)}K';
    }
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(
          '$prefix${_format(v.round())}$suffix',
          style: style,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE ESTATÍSTICA (KPI) — com brilho, ícone e tendência opcional
// ═══════════════════════════════════════════════════════════════════
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final String? suffix;
  final String? sublabel;
  final bool live;

  const StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.suffix,
    this.sublabel,
    this.live = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.92 + 0.08 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (live) const _LivePulseDot(),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedCounter(
              value: value,
              suffix: suffix ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 1),
              Text(
                sublabel!,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot();
  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 16 * t,
                height: 16 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF43B581)
                      .withOpacity((1 - t).clamp(0.0, 1.0) * 0.5),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF43B581),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BARRA DE PROGRESSO ANIMADA (uso genérico — distribuição, rankings)
// ═══════════════════════════════════════════════════════════════════
class AnimatedProgressBar extends StatelessWidget {
  final double percent; // 0..1
  final Color color;
  final double height;

  const AnimatedProgressBar({
    required this.percent,
    required this.color,
    this.height = 8,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: Colors.white.withOpacity(0.06),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: percent.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.7), color],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEÇÃO — cabeçalho reutilizável com ícone
// ═══════════════════════════════════════════════════════════════════
class DashSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const DashSectionTitle({
    required this.title,
    required this.icon,
    this.trailing,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primaryOrange),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD CONTAINER — casca padrão com borda sutil
// ═══════════════════════════════════════════════════════════════════
class DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SKELETON / SHIMMER — placeholder de carregamento
// ═══════════════════════════════════════════════════════════════════
class ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    required this.height,
    this.width,
    this.borderRadius,
    Key? key,
  }) : super(key: key);

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1 + _ctrl.value * 2.5, 0),
              end: Alignment(_ctrl.value * 2.5, 0),
              colors: const [
                Color(0xFF111111),
                Color(0xFF1E1E1E),
                Color(0xFF111111),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Row(
          children: [
            Expanded(child: ShimmerBox(height: 96)),
            SizedBox(width: 10),
            Expanded(child: ShimmerBox(height: 96)),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: ShimmerBox(height: 96)),
            SizedBox(width: 10),
            Expanded(child: ShimmerBox(height: 96)),
          ],
        ),
        const SizedBox(height: 16),
        const ShimmerBox(height: 180, borderRadius: BorderRadius.all(Radius.circular(16))),
        const SizedBox(height: 16),
        const ShimmerBox(height: 220, borderRadius: BorderRadius.all(Radius.circular(16))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GRÁFICO DE BARRAS ANIMADO (CustomPainter — sem dependências extras)
// ═══════════════════════════════════════════════════════════════════
class BarChartData {
  final String label;
  final double value;
  final Color color;
  const BarChartData(this.label, this.value, this.color);
}

class AnimatedBarChart extends StatefulWidget {
  final List<BarChartData> data;
  final double height;

  const AnimatedBarChart({
    required this.data,
    this.height = 140,
    Key? key,
  }) : super(key: key);

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxVal = widget.data.isEmpty
        ? 1.0
        : widget.data
            .map((e) => e.value)
            .reduce(math.max)
            .clamp(1.0, double.infinity);

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_ctrl.value);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: widget.data.map((d) {
              final fraction = (d.value / maxVal) * t;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        d.value.round().toString(),
                        style: TextStyle(
                          color: d.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── A barra precisa de um Expanded aqui em cima ──
                      // FractionallySizedBox calcula a própria altura como
                      // fração da altura do PAI. Sem um Expanded delimitando
                      // esse espaço, o Column mede tudo pelo conteúdo
                      // intrínseco e a barra fica com altura ~0 (só o
                      // número e o label apareciam, sem barra visível).
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: fraction.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  d.color.withOpacity(0.55),
                                  d.color,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: d.color.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// GRÁFICO DONUT ANIMADO (para distribuição de níveis)
// ═══════════════════════════════════════════════════════════════════
class DonutSlice {
  final double value;
  final Color color;
  final String label;
  const DonutSlice(this.value, this.color, this.label);
}

class AnimatedDonutChart extends StatefulWidget {
  final List<DonutSlice> slices;
  final double size;
  final int centerValue;
  final String centerLabel;

  const AnimatedDonutChart({
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.size = 130,
    Key? key,
  }) : super(key: key);

  @override
  State<AnimatedDonutChart> createState() => _AnimatedDonutChartState();
}

class _AnimatedDonutChartState extends State<AnimatedDonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_ctrl.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(widget.slices, t),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCounter(
                    value: widget.centerValue,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    widget.centerLabel,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double t;
  _DonutPainter(this.slices, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        0,
        2 * math.pi,
        false,
        paint,
      );
      return;
    }

    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi * t;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        start,
        sweep,
        false,
        paint,
      );
      start += (s.value / total) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.t != t || old.slices != slices;
}