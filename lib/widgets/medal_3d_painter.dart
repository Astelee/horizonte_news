import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/badge_3d_config.dart';

// ═══════════════════════════════════════════════════════════════════
// MOTOR DE RENDERIZAÇÃO 3D DAS MEDALHAS (100% código, sem imagens)
//
// Não usa motor 3D: a medalha é um disco com espessura desenhado em
// camadas empilhadas no eixo Z, cada uma com uma matriz Matrix4 de
// perspectiva + rotação (canvas.transform). Assim a inclinação mostra
// de verdade a lateral metálica, o fundo rebaixado, o símbolo em relevo
// extrudado e — girando além de 90° — o verso da medalha.
//
// Convenção de eixos: +Z aponta para o observador (mais perto = maior).
// ═══════════════════════════════════════════════════════════════════

/// Nível de detalhe. É reduzido automaticamente quando o aparelho não
/// mantém a fluidez (ver Medal3DPerf em medal_3d_widgets.dart).
enum Medal3DQuality { high, medium, low }

class Medal3DPainter extends CustomPainter {
  final MedalSpec spec;
  final bool unlocked;

  /// Rotações em radianos: X inclina para frente/trás, Y gira na horizontal.
  final double rotX;
  final double rotY;

  /// 0..1 — posição do reflexo que percorre a borda e a face.
  final double shine;

  /// 0..1 — clarão extra (toque).
  final double flash;

  /// 0..1 — pulso da aura.
  final double glow;

  /// 0..1 — fase do cintilar das estrelinhas.
  final double sparkle;

  /// 0..1 — progresso da explosão de partículas (0 = nenhuma).
  final double burst;

  /// 0..1 — opacidade (entrada da medalha).
  final double appear;

  final Medal3DQuality quality;

  Medal3DPainter({
    required this.spec,
    required this.unlocked,
    required this.rotX,
    required this.rotY,
    this.shine = 0.15,
    this.flash = 0,
    this.glow = 0.5,
    this.sparkle = 0,
    this.burst = 0,
    this.appear = 1,
    this.quality = Medal3DQuality.high,
  });

  MedalSpec get _m => unlocked ? spec : spec.lockedVersion;

  int get _tier => unlocked ? spec.rarity.tier : 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (appear <= 0.001) return;
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.40; // raio da medalha
    final t = r * 0.20; // espessura total

    final fading = appear < 0.999;
    if (fading) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(255, 255, 255, appear.clamp(0.0, 1.0)),
      );
    }

    _paintAura(canvas, c, r);
    _paintShadow(canvas, c, r);

    // Matriz base: centro → perspectiva → rotação X → rotação Y.
    final base = Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(Matrix4.identity()..setEntry(3, 2, -1 / (r * 5.5)))
      ..multiply(Matrix4.rotationX(rotX))
      ..multiply(Matrix4.rotationY(rotY));

    final facingFront = math.cos(rotX) * math.cos(rotY) >= 0;

    _paintSide(canvas, base, r, t, facingFront);
    if (facingFront) {
      _paintFront(canvas, base, r, t);
    } else {
      _paintBack(canvas, base, r, t);
    }

    _paintSparkles(canvas, c, r);
    _paintBurst(canvas, c, r);

    if (fading) canvas.restore();
  }

  // ── utilitários ──────────────────────────────────────────────────

  void _withZ(Canvas canvas, Matrix4 base, double z, void Function() draw) {
    final m = base.clone()..translate(0.0, 0.0, z);
    canvas.save();
    canvas.transform(m.storage);
    draw();
    canvas.restore();
  }

  double get _sx => math.sin(rotY).clamp(-1.0, 1.0).toDouble();
  double get _sy => math.sin(rotX).clamp(-1.0, 1.0).toDouble();

  // ── aura e sombra (espaço de tela) ───────────────────────────────

  void _paintAura(Canvas canvas, Offset c, double r) {
    if (!unlocked || _tier < 2) return;
    final m = _m;
    final pulse = quality == Medal3DQuality.low ? 0.5 : glow;
    final strength = (0.06 + 0.035 * _tier) * (0.75 + 0.25 * pulse);
    final radius = r * (1.22 + 0.05 * pulse + (spec.supreme ? 0.12 : 0));
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            m.glow.withOpacity(strength * 2.2),
            m.glow.withOpacity(strength),
            m.glow.withOpacity(0),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // Raios giratórios exclusivos da medalha suprema.
    if (spec.supreme && quality != Medal3DQuality.low) {
      final rays = quality == Medal3DQuality.high ? 14 : 8;
      final paint = Paint()
        ..color = m.light.withOpacity(0.10 + 0.05 * pulse)
        ..style = PaintingStyle.fill;
      final rot = sparkle * math.pi * 0.5;
      for (var i = 0; i < rays; i++) {
        final a = rot + i * 2 * math.pi / rays;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a - 0.05) * r * 1.45,
              c.dy + math.sin(a - 0.05) * r * 1.45)
          ..lineTo(c.dx + math.cos(a + 0.05) * r * 1.45,
              c.dy + math.sin(a + 0.05) * r * 1.45)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _paintShadow(Canvas canvas, Offset c, double r) {
    final w = r * 1.55 * (0.72 + 0.28 * math.cos(rotY).abs());
    final h = r * 0.26;
    final rect = Rect.fromCenter(
      center: Offset(c.dx + _sx * r * 0.10, c.dy + r * 1.06),
      width: w,
      height: h,
    );
    final paint = Paint()..color = Colors.black.withOpacity(unlocked ? 0.42 : 0.30);
    if (quality != Medal3DQuality.low) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.10);
    }
    canvas.drawOval(rect, paint);
  }

  // ── lateral metálica (espessura) ─────────────────────────────────

  void _paintSide(
      Canvas canvas, Matrix4 base, double r, double t, bool facingFront) {
    final m = _m;
    final n = quality == Medal3DQuality.high
        ? 10
        : (quality == Medal3DQuality.medium ? 6 : 3);

    final shader = SweepGradient(
      colors: [
        m.dark,
        m.mid,
        m.light,
        m.mid,
        m.dark,
        m.mid,
        m.light,
        m.mid,
        m.dark,
      ],
      transform: GradientRotation(shine * 2 * math.pi + rotY * 1.4),
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));

    for (var step = 0; step < n; step++) {
      final i = facingFront ? step : (n - 1 - step); // tras → frente
      final k = n == 1 ? 1.0 : i / (n - 1); // 0 = traseira, 1 = frente
      final z = -t / 2 + t * k;
      final paint = Paint()
        ..shader = shader
        ..isAntiAlias = true
        ..colorFilter = ColorFilter.mode(
          Colors.black.withOpacity((1 - k) * 0.22),
          BlendMode.srcATop,
        );
      _withZ(canvas, base, z, () {
        canvas.drawCircle(Offset.zero, r, paint);
      });
    }
  }

  // ── bisel (anel da borda), usado na frente e no verso ───────────

  void _paintBevel(Canvas canvas, double r, {required bool back}) {
    final m = _m;
    final outer = Rect.fromCircle(center: Offset.zero, radius: r);
    final ring = Path()
      ..addOval(outer)
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.84))
      ..fillType = PathFillType.evenOdd;

    final dir = back ? -1.0 : 1.0;
    canvas.drawPath(
      ring,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment(-0.9 - _sx * 0.5 * dir, -1.0 + _sy * 0.5),
          end: Alignment(0.9 - _sx * 0.5 * dir, 1.0 + _sy * 0.5),
          colors: [m.light, m.mid, m.dark, m.mid],
          stops: const [0.0, 0.36, 0.72, 1.0],
        ).createShader(outer),
    );

    // Arestas: luz fina por fora, sombra fina por dentro.
    canvas.drawCircle(
      Offset.zero,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.022
        ..color = m.light.withOpacity(0.75),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.845,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02
        ..color = Colors.black.withOpacity(0.55),
    );

    // Reflexo especular percorrendo a borda.
    if (quality != Medal3DQuality.low) {
      const clear = Color(0x00FFFFFF);
      final peak = Colors.white.withOpacity(unlocked ? 0.85 : 0.35);
      final sweep = SweepGradient(
        colors: [clear, clear, peak, clear, clear],
        stops: const [0.0, 0.42, 0.5, 0.58, 1.0],
        transform: GradientRotation(
            shine * 2 * math.pi + rotY * 0.9 - rotX * 0.6 + (back ? math.pi : 0)),
      ).createShader(outer);
      canvas.drawCircle(
        Offset.zero,
        r * 0.915,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.11
          ..shader = sweep,
      );
    }

    // Pedrarias: aparecem nas raridades mais altas.
    if (quality != Medal3DQuality.low && _tier >= 3) {
      final count = _tier == 3 ? 4 : (_tier == 4 ? 8 : 12);
      for (var i = 0; i < count; i++) {
        final a = i * 2 * math.pi / count + math.pi / count;
        final p = Offset(math.cos(a), math.sin(a)) * (r * 0.915);
        canvas.drawCircle(
          p,
          r * 0.032,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: [m.light, m.glow, m.dark],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromCircle(center: p, radius: r * 0.032)),
        );
      }
    }
  }

  // ── frente ───────────────────────────────────────────────────────

  void _paintFront(Canvas canvas, Matrix4 base, double r, double t) {
    final m = _m;
    final zFace = t / 2;
    final recess = r * 0.06;
    final f = r * 0.78; // raio do campo rebaixado

    _withZ(canvas, base, zFace, () => _paintBevel(canvas, r, back: false));

    // Parede interna do rebaixo.
    _withZ(canvas, base, zFace - recess * 0.5, () {
      canvas.drawCircle(
        Offset.zero,
        r * 0.845,
        Paint()..color = Colors.black.withOpacity(0.62),
      );
    });

    // Campo (fundo) da medalha.
    _withZ(canvas, base, zFace - recess, () => _paintField(canvas, f));

    // Símbolo em relevo (sombra projetada + camadas extrudadas + topo).
    _paintSymbol(canvas, base, r, zFace - recess + r * 0.004);

    // Brilho de superfície por cima de tudo.
    _withZ(canvas, base, zFace - recess + r * 0.16, () => _paintGloss(canvas, f));
  }

  void _paintField(Canvas canvas, double f) {
    final m = _m;
    final rect = Rect.fromCircle(center: Offset.zero, radius: f);
    canvas.drawCircle(
      Offset.zero,
      f,
      Paint()
        ..isAntiAlias = true
        ..shader = RadialGradient(
          center: Alignment(-0.35 - _sx * 0.8, -0.45 + _sy * 0.8),
          radius: 1.05,
          colors: [m.fieldCenter, m.fieldMid, m.fieldEdge],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Facetas de cristal que cintilam.
    if (m.crystal && quality != Medal3DQuality.low) {
      for (var i = 0; i < 8; i++) {
        final a0 = i * math.pi / 4 + 0.2;
        final a1 = a0 + math.pi / 4;
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(math.cos(a0) * f, math.sin(a0) * f)
          ..lineTo(math.cos(a1) * f, math.sin(a1) * f)
          ..close();
        final twinkle = math.max(0.0, math.sin(2 * math.pi * (shine + i / 8)));
        final color = i.isEven
            ? Colors.white.withOpacity(0.04 + 0.12 * twinkle)
            : Colors.black.withOpacity(0.10);
        canvas.drawPath(path, Paint()..color = color);
      }
    }

    // Pequenos traços radiais gravados (raridades mais altas).
    if (quality == Medal3DQuality.high && _tier >= 2) {
      final ticks = Path();
      const count = 36;
      for (var i = 0; i < count; i++) {
        final a = i * 2 * math.pi / count;
        ticks
          ..moveTo(math.cos(a) * f * 0.84, math.sin(a) * f * 0.84)
          ..lineTo(math.cos(a) * f * 0.95, math.sin(a) * f * 0.95);
      }
      canvas.drawPath(
        ticks,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f * 0.012
          ..color = m.light.withOpacity(0.22),
      );
    }

    // Anel gravado (luz de um lado, sombra do outro).
    final groove = f * 0.90;
    canvas.drawCircle(
      Offset(f * 0.012, f * 0.014),
      groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f * 0.016
        ..color = Colors.black.withOpacity(0.45),
    );
    canvas.drawCircle(
      Offset(-f * 0.008, -f * 0.01),
      groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f * 0.012
        ..color = m.light.withOpacity(0.28),
    );

    // Sombra interna na parede do rebaixo.
    canvas.drawCircle(
      Offset.zero,
      f,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.28 + _sx * 0.5, 0.32 - _sy * 0.5),
          radius: 1.08,
          colors: [Colors.transparent, Colors.black.withOpacity(0.52)],
          stops: const [0.70, 1.0],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _paintSymbol(Canvas canvas, Matrix4 base, double r, double zBase) {
    final m = _m;
    final layers = quality == Medal3DQuality.high
        ? 6
        : (quality == Medal3DQuality.medium ? 3 : 1);
    final fontSize = r * 0.80;
    final set = _SymbolCache.get(m, spec.icon, fontSize, layers, unlocked);
    final dz = r * 0.024;
    final off = Offset(-set.width / 2, -set.height / 2);

    // Sombra projetada do símbolo sobre o fundo.
    _withZ(canvas, base, zBase, () {
      set.shadow.paint(canvas, off + Offset(r * 0.035, r * 0.045));
    });
    // Camadas laterais (volume do relevo).
    for (var k = 0; k < set.sides.length; k++) {
      _withZ(canvas, base, zBase + (k + 1) * dz, () {
        set.sides[k].paint(canvas, off);
      });
    }
    // Face superior com degradê metálico.
    _withZ(canvas, base, zBase + (set.sides.length + 1) * dz, () {
      set.top.paint(canvas, off);
    });
  }

  void _paintGloss(Canvas canvas, double f) {
    final rect = Rect.fromCircle(center: Offset.zero, radius: f);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Reflexo curvo no alto, que acompanha a inclinação.
    final gc = Offset(-f * 0.15 - _sx * f * 0.6, -f * 0.48 + _sy * f * 0.5);
    final glossRect = Rect.fromCenter(center: gc, width: f * 1.7, height: f * 1.0);
    canvas.drawOval(
      glossRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(unlocked ? 0.30 : 0.12),
            Colors.white.withOpacity(0),
          ],
        ).createShader(glossRect),
    );

    // Faixa de luz diagonal que percorre a face.
    if (quality != Medal3DQuality.low) {
      void band(double w, double alpha) {
        final p = -0.15 + 1.3 * w;
        double c(double v) => v.clamp(0.0, 1.0).toDouble();
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: const Alignment(-1, -1),
              end: const Alignment(1, 1),
              colors: [
                Colors.white.withOpacity(0),
                Colors.white.withOpacity(alpha),
                Colors.white.withOpacity(0),
              ],
              stops: [c(p - 0.14), c(p), c(p + 0.14)],
            ).createShader(rect),
        );
      }

      if (unlocked) band(shine, 0.16);
      if (flash > 0.01) band(flash, 0.55 * math.sin(math.pi * flash));
    }
    canvas.restore();
  }

  // ── verso ────────────────────────────────────────────────────────

  void _paintBack(Canvas canvas, Matrix4 base, double r, double t) {
    final m = _m;
    final zBack = -t / 2;
    final recess = r * 0.06;
    final f = r * 0.78;

    _withZ(canvas, base, zBack, () => _paintBevel(canvas, r, back: true));

    _withZ(canvas, base, zBack + recess * 0.5, () {
      canvas.drawCircle(
        Offset.zero,
        r * 0.845,
        Paint()..color = Colors.black.withOpacity(0.62),
      );
    });

    _withZ(canvas, base, zBack + recess, () {
      _paintField(canvas, f);
      // Estrelas gravadas conforme a raridade (1 a 6).
      final stars = spec.rarity.tier + 1;
      for (var i = 0; i < stars; i++) {
        final a = -math.pi / 2 + (i - (stars - 1) / 2) * 0.34;
        final p = Offset(math.cos(a), math.sin(a)) * (f * 0.70);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.drawPath(
          _star4(f * 0.07),
          Paint()..color = m.light.withOpacity(unlocked ? 0.85 : 0.35),
        );
        canvas.restore();
      }
    });

    // Marca "H" estampada (espelhada: lida correta de quem vê o verso).
    final mark = _SymbolCache.backMark(m, r * 0.62, unlocked);
    _withZ(canvas, base, zBack + recess + r * 0.01, () {
      canvas.save();
      canvas.scale(-1.0, 1.0);
      mark.shadow.paint(canvas,
          Offset(-mark.width / 2 + r * 0.02, -mark.height / 2 + r * 0.03));
      mark.top.paint(canvas, Offset(-mark.width / 2, -mark.height / 2));
      canvas.restore();
    });
  }

  // ── partículas e brilhos (espaço de tela) ───────────────────────

  static Path _star4(double r) {
    final k = r * 0.2;
    return Path()
      ..moveTo(0, -r)
      ..lineTo(k, -k)
      ..lineTo(r, 0)
      ..lineTo(k, k)
      ..lineTo(0, r)
      ..lineTo(-k, k)
      ..lineTo(-r, 0)
      ..lineTo(-k, -k)
      ..close();
  }

  void _paintSparkles(Canvas canvas, Offset c, double r) {
    if (!unlocked || _tier < 4 || quality == Medal3DQuality.low) return;
    final total = spec.supreme ? 7 : (_tier == 5 ? 5 : 3);
    final count = quality == Medal3DQuality.high ? total : (total + 1) ~/ 2;
    final seed = spec.id.hashCode.abs() % 97 / 97.0;
    for (var i = 0; i < count; i++) {
      final a = (i * 2.399 + seed * 6.283);
      final dist = r * (0.92 + 0.30 * ((i * 0.37 + seed) % 1.0));
      final p = c + Offset(math.cos(a), math.sin(a)) * dist;
      final tw = math.max(0.0, math.sin(2 * math.pi * (sparkle + i * 0.173)));
      final alpha = tw * tw * tw;
      if (alpha < 0.03) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.drawPath(
        _star4(r * (0.07 + 0.07 * alpha)),
        Paint()..color = Color.lerp(_m.glow, Colors.white, 0.6)!.withOpacity(alpha),
      );
      canvas.restore();
    }
  }

  void _paintBurst(Canvas canvas, Offset c, double r) {
    if (burst <= 0.001 || burst >= 0.999) return;
    final m = _m;
    final e = 1 - math.pow(1 - burst, 3).toDouble(); // easeOutCubic
    final fade = math.pow(1 - burst, 1.2).toDouble();
    final n = quality == Medal3DQuality.high
        ? 28
        : (quality == Medal3DQuality.medium ? 18 : 10);

    canvas.drawCircle(
      c,
      r * (0.55 + 0.95 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05 * (1 - burst)
        ..color = m.glow.withOpacity(0.55 * fade),
    );

    for (var i = 0; i < n; i++) {
      final jitter = ((i * 7919) % 100) / 100.0;
      final a = i * 2 * math.pi / n + jitter * 0.4;
      final dist = r * (0.45 + (0.8 + 0.5 * jitter) * e);
      final p = c + Offset(math.cos(a), math.sin(a)) * dist;
      final color = i % 3 == 0
          ? Colors.white
          : (i % 3 == 1 ? m.light : m.glow);
      final size = r * (0.045 + 0.04 * jitter) * (1 - 0.6 * burst);
      if (i % 4 == 0) {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.drawPath(_star4(size * 2.2),
            Paint()..color = color.withOpacity(fade));
        canvas.restore();
      } else {
        canvas.drawCircle(p, size, Paint()..color = color.withOpacity(fade));
      }
    }
  }

  @override
  bool shouldRepaint(covariant Medal3DPainter old) =>
      old.spec.id != spec.id ||
      old.unlocked != unlocked ||
      old.rotX != rotX ||
      old.rotY != rotY ||
      old.shine != shine ||
      old.flash != flash ||
      old.glow != glow ||
      old.sparkle != sparkle ||
      old.burst != burst ||
      old.appear != appear ||
      old.quality != quality;
}

// ═══════════════════════════════════════════════════════════════════
// Símbolos pré-medidos (TextPainter por camada) — criados uma vez e
// reaproveitados por todos os desenhos, para não refazer layout a cada
// quadro.
// ═══════════════════════════════════════════════════════════════════

class _SymbolSet {
  final List<TextPainter> sides;
  final TextPainter top;
  final TextPainter shadow;
  final double width;
  final double height;

  _SymbolSet(this.sides, this.top, this.shadow, this.width, this.height);
}

class _SymbolCache {
  static final Map<String, _SymbolSet> _cache = {};

  static TextPainter _glyph(
    IconData icon,
    double size, {
    Color? color,
    Paint? foreground,
  }) {
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: foreground == null ? color : null,
          foreground: foreground,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static _SymbolSet get(
    MedalSpec m,
    IconData icon,
    double size,
    int layers,
    bool unlocked,
  ) {
    final q = (size * 2).round() / 2; // evita infinitas variações
    final key = '${m.id}|$unlocked|$q|$layers|${m.mid.value}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 150) _cache.clear();

    final probe = _glyph(icon, q, color: Colors.black);
    final w = probe.width;
    final h = probe.height;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);

    final sides = <TextPainter>[
      for (var k = 0; k < layers; k++)
        _glyph(
          icon,
          q,
          color: Color.lerp(
              m.symbolSide, m.symbolMid, layers == 1 ? 0.0 : k / (layers - 1) * 0.55)!,
        ),
    ];
    final top = _glyph(
      icon,
      q,
      foreground: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [m.symbolTop, m.symbolMid, Color.lerp(m.mid, m.dark, 0.35)!],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    final shadow = _glyph(icon, q, color: Colors.black.withOpacity(0.40));

    final set = _SymbolSet(sides, top, shadow, w, h);
    _cache[key] = set;
    return set;
  }

  static final Map<String, _SymbolSet> _backCache = {};

  /// Letra "H" (Horizonte) estampada no verso.
  static _SymbolSet backMark(MedalSpec m, double size, bool unlocked) {
    final q = (size * 2).round() / 2;
    final key = '${m.id}|$unlocked|$q|${m.mid.value}';
    final hit = _backCache[key];
    if (hit != null) return hit;
    if (_backCache.length > 60) _backCache.clear();

    TextPainter letter({Color? color, Paint? fg}) => TextPainter(
          text: TextSpan(
            text: 'H',
            style: TextStyle(
              fontSize: q,
              fontWeight: FontWeight.w900,
              color: fg == null ? color : null,
              foreground: fg,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final probe = letter(color: Colors.black);
    final rect = Rect.fromCenter(
        center: Offset.zero, width: probe.width, height: probe.height);
    final set = _SymbolSet(
      const [],
      letter(
        fg: Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [m.symbolTop, m.symbolMid, m.symbolSide],
          ).createShader(rect),
      ),
      letter(color: Colors.black.withOpacity(0.45)),
      probe.width,
      probe.height,
    );
    _backCache[key] = set;
    return set;
  }
}