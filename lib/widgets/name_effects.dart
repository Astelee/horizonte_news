import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import '../config/name_style_config.dart';

// ═══════════════════════════════════════════════════════════════════
// MOTOR DE EFEITOS DO NOME PERSONALIZADO
// ═══════════════════════════════════════════════════════════════════
// Desempenho (nomes aparecem em listas, comentários e ranking):
//
//  • UM único Ticker para o app inteiro (NameEffectClock). Nenhum nome
//    cria AnimationController próprio: cada widget só "empresta" o
//    relógio enquanto está na tela (acquire/release) e o Ticker para
//    sozinho quando não sobra nenhum nome animado.
//  • O relógio notifica no máximo ~30x por segundo (economia de
//    bateria) e só os CustomPainters se repintam — nenhum widget é
//    reconstruído a cada quadro.
//  • O texto é medido/montado UMA vez (NameTextLayout) e reaproveitado
//    em todos os quadros; a cada quadro só se desenha.
//  • Todas as posições de partículas/raios são calculadas a partir do
//    tempo + uma semente fixa (sem estado, sem listas para alocar).
//
// Cada efeito é uma NameEffectLayer independente. Para criar um efeito
// novo, basta escrever a camada e registrá-la em NameEffectRegistry.
// ═══════════════════════════════════════════════════════════════════

/// Relógio único compartilhado por todos os nomes animados.
class NameEffectClock extends ChangeNotifier {
  NameEffectClock._();

  static final NameEffectClock instance = NameEffectClock._();

  // ~30 quadros por segundo bastam para brilho/partículas e gastam
  // bem menos bateria que 60/120.
  static const Duration _minFrameGap = Duration(milliseconds: 33);

  Ticker? _ticker;
  int _holders = 0;
  double _seconds = 0;
  double _baseSeconds = 0;
  Duration _lastNotified = Duration.zero;

  /// Tempo acumulado em segundos. Só cresce (nunca "volta" ao zero),
  /// então as animações não dão salto quando o relógio para e recomeça.
  double get seconds => _seconds;

  bool get isRunning => _ticker != null;

  /// Chamado por cada nome animado que entra na tela.
  void acquire() {
    _holders++;
    if (_ticker == null) {
      _lastNotified = Duration.zero;
      _ticker = Ticker(_onTick)..start();
    }
  }

  /// Chamado quando o nome sai da tela / deixa de animar.
  void release() {
    if (_holders > 0) _holders--;
    if (_holders == 0 && _ticker != null) {
      final ticker = _ticker!;
      _ticker = null;
      _baseSeconds = _seconds;
      ticker.stop();
      ticker.dispose();
    }
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastNotified < _minFrameGap) return;
    _lastNotified = elapsed;
    _seconds = _baseSeconds + elapsed.inMicroseconds / 1000000.0;
    notifyListeners();
  }
}

/// Dados de UM quadro, entregues a cada camada na hora de desenhar.
class NameEffectFrame {
  /// Tamanho do texto (origem em 0,0).
  final Size size;

  /// Tempo em segundos (relógio compartilhado).
  final double t;
  final NameColorPreset color;

  /// Fator de intensidade (NameIntensity.factor).
  final double intensity;

  /// Semente estável por nome: dois nomes não ficam sincronizados.
  final int seed;

  const NameEffectFrame({
    required this.size,
    required this.t,
    required this.color,
    required this.intensity,
    required this.seed,
  });
}

/// Um efeito visual. Todas as camadas são sem estado (const) — o que
/// varia a cada quadro vem em [NameEffectFrame].
abstract class NameEffectLayer {
  const NameEffectLayer();

  /// Estilo de um texto "de apoio" montado UMA vez e entregue a
  /// [paintUnder] (ex.: o texto com sombra do brilho). null = não usa.
  TextStyle? underlayTextStyle(
    TextStyle base,
    NameColorPreset color,
    double intensity,
  ) =>
      null;

  /// Desenhado ANTES do texto (aura, brilho).
  void paintUnder(Canvas canvas, NameEffectFrame frame, TextPainter? underlay) {}

  /// Shader que pinta o próprio texto (ex.: gradiente). Se mais de uma
  /// camada devolver shader, vale a primeira (ordem de NameEffect).
  ui.Shader? textShader(NameEffectFrame frame) => null;

  /// Desenhado DEPOIS do texto (partículas, raios).
  void paintOver(Canvas canvas, NameEffectFrame frame) {}
}

// ───────────────────────────────────────────────────────────────────
// ✨ BRILHO PULSANTE
// ───────────────────────────────────────────────────────────────────
class GlowEffectLayer extends NameEffectLayer {
  const GlowEffectLayer();

  @override
  TextStyle? underlayTextStyle(
    TextStyle base,
    NameColorPreset color,
    double intensity,
  ) {
    // Mesmo texto (cor opaca, fica escondido sob o texto real); o que
    // "vaza" para fora das letras é a sombra colorida.
    return base.copyWith(
      color: color.primary,
      shadows: [
        Shadow(color: color.primary, blurRadius: 5 * intensity),
        Shadow(color: color.secondary, blurRadius: 13 * intensity),
      ],
    );
  }

  @override
  void paintUnder(Canvas canvas, NameEffectFrame frame, TextPainter? underlay) {
    if (underlay == null) return;
    // Respira a cada ~1,9 s.
    final pulse = 0.5 + 0.5 * math.sin(frame.t * 2 * math.pi / 1.9);
    final alpha = ((0.35 + 0.65 * pulse) * (0.75 + 0.25 * frame.intensity))
        .clamp(0.0, 1.0);

    final bounds = Rect.fromLTWH(
      -26,
      -26,
      frame.size.width + 52,
      frame.size.height + 52,
    );
    canvas.saveLayer(bounds, Paint()..color = Colors.white.withOpacity(alpha));
    underlay.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

// ───────────────────────────────────────────────────────────────────
// 🌈 GRADIENTE ANIMADO
// ───────────────────────────────────────────────────────────────────
class GradientEffectLayer extends NameEffectLayer {
  const GradientEffectLayer();

  @override
  ui.Shader? textShader(NameEffectFrame frame) {
    final span = math.max(frame.size.width * 1.2, 48.0);
    final speed = 26.0 + 16.0 * frame.intensity; // px por segundo
    final shift = (frame.t * speed) % span;
    // primary → secondary → primary com TileMode.repeated: o ciclo
    // fecha sem emenda, então não há "salto" quando reinicia.
    return ui.Gradient.linear(
      Offset(shift, 0),
      Offset(shift + span, 0),
      [frame.color.primary, frame.color.secondary, frame.color.primary],
      const [0.0, 0.5, 1.0],
      ui.TileMode.repeated,
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// 🌟 PARTÍCULAS FLUTUANDO
// ───────────────────────────────────────────────────────────────────
class ParticlesEffectLayer extends NameEffectLayer {
  const ParticlesEffectLayer();

  @override
  void paintOver(Canvas canvas, NameEffectFrame frame) {
    final count = (5 * frame.intensity).round().clamp(3, 9);
    final w = frame.size.width;
    final h = frame.size.height;
    final tint = Color.lerp(frame.color.secondary, Colors.white, 0.55)!;

    final fill = Paint();
    final glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final r = math.Random(frame.seed * 1009 + i * 7919 + 13);
      final x0 = r.nextDouble();
      final phase = r.nextDouble();
      final speed = 0.16 + r.nextDouble() * 0.22; // ciclos por segundo
      final baseSize = 0.9 + r.nextDouble() * 1.3;
      final wobble = r.nextDouble() * math.pi * 2;

      final p = (frame.t * speed + phase) % 1.0;
      final fade = math.sin(p * math.pi); // nasce, brilha, some
      final twinkle = 0.65 + 0.35 * math.sin(frame.t * 6 + wobble);
      final alpha = (fade * twinkle).clamp(0.0, 1.0);
      if (alpha < 0.03) continue;

      final x = x0 * w + math.sin(frame.t * 1.6 + wobble) * 2.0;
      final y = h * (1.05 - 1.2 * p); // sobe pelo nome
      final s = baseSize * (0.8 + 0.3 * frame.intensity);

      fill.color = tint.withOpacity(alpha);
      glint.color = Colors.white.withOpacity(alpha * 0.85);
      final o = Offset(x, y);
      canvas.drawCircle(o, s * 0.6, fill);
      canvas.drawLine(o.translate(-s * 1.7, 0), o.translate(s * 1.7, 0), glint);
      canvas.drawLine(o.translate(0, -s * 1.7), o.translate(0, s * 1.7), glint);
    }
  }
}

// ───────────────────────────────────────────────────────────────────
// ⚡ RAIOS / ENERGIA
// ───────────────────────────────────────────────────────────────────
class LightningEffectLayer extends NameEffectLayer {
  const LightningEffectLayer();

  @override
  void paintOver(Canvas canvas, NameEffectFrame frame) {
    final bolts = (2 * frame.intensity).round().clamp(1, 4);
    final w = frame.size.width;
    final h = frame.size.height;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < bolts; i++) {
      // Cada raio tem seu próprio ritmo; a cada "slot" nasce um
      // zigue-zague novo (semente = nome + raio + slot).
      final rate = 1.25 + i * 0.37;
      final tt = frame.t * rate + i * 0.61;
      final slot = tt.floor();
      final u = tt - slot; // 0..1 dentro do slot

      // Só pisca nos primeiros ~30% do slot; no resto o raio some.
      if (u > 0.3) continue;
      final k = u / 0.3;
      final flicker = 0.65 + 0.35 * math.sin(k * 24);
      final alpha = (math.sin(k * math.pi) * flicker).abs().clamp(0.0, 1.0);
      if (alpha < 0.05) continue;

      final r = math.Random(frame.seed * 977 + i * 131 + slot * 7);
      final startX = r.nextDouble() * w;
      final fromTop = r.nextBool();
      final dirY = fromTop ? 1.0 : -1.0;
      final startY = fromTop ? -1.5 : h + 1.5;
      final length = h * (0.55 + r.nextDouble() * 0.6);
      const segments = 4;

      final path = Path()..moveTo(startX, startY);
      var x = startX;
      var y = startY;
      for (int s = 0; s < segments; s++) {
        x += (r.nextDouble() - 0.5) * h * 0.95;
        y += dirY * length / segments;
        path.lineTo(x.clamp(-4.0, w + 4.0), y);
      }

      glowPaint.color = frame.color.secondary.withOpacity(alpha * 0.5);
      corePaint.color = Colors.white.withOpacity(alpha);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);
    }
  }
}

// ───────────────────────────────────────────────────────────────────
// REGISTRO: NameEffect → camada
// ───────────────────────────────────────────────────────────────────
class NameEffectRegistry {
  NameEffectRegistry._();

  static const Map<NameEffect, NameEffectLayer> layers = {
    NameEffect.glow: GlowEffectLayer(),
    NameEffect.gradient: GradientEffectLayer(),
    NameEffect.particles: ParticlesEffectLayer(),
    NameEffect.lightning: LightningEffectLayer(),
  };

  /// Camadas do estilo, sempre na ordem de NameEffect.values (a ordem
  /// de desenho não depende da ordem em que o usuário marcou).
  static List<NameEffectLayer> layersFor(NameStyle style) {
    final result = <NameEffectLayer>[];
    for (final effect in NameEffect.values) {
      if (!style.effects.contains(effect)) continue;
      final layer = layers[effect];
      if (layer != null) result.add(layer);
    }
    return result;
  }
}

/// Texto já medido e pronto para desenhar (montado uma vez, reusado
/// em todos os quadros da animação).
class NameTextLayout {
  final TextPainter fill;
  final Map<NameEffect, TextPainter> underlays;
  final Size size;

  NameTextLayout._(this.fill, this.underlays, this.size);

  factory NameTextLayout.build({
    required String text,
    required TextStyle style,
    required NameStyle nameStyle,
    required double maxWidth,
    required TextAlign textAlign,
    required int? maxLines,
    required TextOverflow overflow,
    required TextScaler textScaler,
  }) {
    final color = nameStyle.color;
    final intensity = nameStyle.intensity.factor;
    final baseStyle = style.copyWith(color: color.primary);

    TextPainter make(TextStyle s) {
      return TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: TextDirection.ltr,
        textAlign: textAlign,
        maxLines: maxLines,
        ellipsis: overflow == TextOverflow.ellipsis ? '\u2026' : null,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
    }

    final fill = make(baseStyle);
    final underlays = <NameEffect, TextPainter>{};
    for (final effect in nameStyle.effects) {
      final layer = NameEffectRegistry.layers[effect];
      if (layer == null) continue;
      final underlayStyle = layer.underlayTextStyle(baseStyle, color, intensity);
      if (underlayStyle != null) underlays[effect] = make(underlayStyle);
    }

    return NameTextLayout._(fill, underlays, Size(fill.width, fill.height));
  }

  void dispose() {
    fill.dispose();
    for (final painter in underlays.values) {
      painter.dispose();
    }
  }
}

/// Desenha o nome + todas as camadas de efeito. Repinta sozinho a cada
/// tick do relógio compartilhado (sem reconstruir widgets).
class NameEffectPainter extends CustomPainter {
  final NameTextLayout layout;
  final NameStyle style;
  final int seed;
  final bool animate;
  final List<NameEffectLayer> _layers;

  NameEffectPainter({
    required this.layout,
    required this.style,
    required this.seed,
    required this.animate,
  })  : _layers = NameEffectRegistry.layersFor(style),
        super(repaint: animate ? NameEffectClock.instance : null);

  @override
  void paint(Canvas canvas, Size size) {
    // Sem animação (acessibilidade "reduzir movimento" ou tela fora de
    // foco): quadro estático, já com um visual bonito.
    final t = animate ? NameEffectClock.instance.seconds : 0.9;
    final textSize = layout.size;

    final frame = NameEffectFrame(
      size: textSize,
      t: t,
      color: style.color,
      intensity: style.intensity.factor,
      seed: seed,
    );

    // 1) camadas por baixo (brilho)
    for (final effect in NameEffect.values) {
      if (!style.effects.contains(effect)) continue;
      final layer = NameEffectRegistry.layers[effect];
      layer?.paintUnder(canvas, frame, layout.underlays[effect]);
    }

    // 2) o texto (com shader, se algum efeito pinta as letras)
    ui.Shader? shader;
    for (final layer in _layers) {
      shader = layer.textShader(frame);
      if (shader != null) break;
    }

    if (shader != null) {
      final rect = (Offset.zero & textSize).inflate(2);
      canvas.saveLayer(rect, Paint());
      layout.fill.paint(canvas, Offset.zero);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
    } else {
      layout.fill.paint(canvas, Offset.zero);
    }

    // 3) camadas por cima (partículas, raios)
    for (final layer in _layers) {
      layer.paintOver(canvas, frame);
    }
  }

  @override
  bool shouldRepaint(NameEffectPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.style != style ||
      oldDelegate.seed != seed ||
      oldDelegate.animate != animate;
}