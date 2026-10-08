import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/badge_3d_config.dart';
import '../services/xp_service.dart';
import 'medal_3d_painter.dart';

// ═══════════════════════════════════════════════════════════════════
// WIDGETS DAS MEDALHAS 3D
//
//  • Medal3DCanvas  — desenha uma pose (sem animação própria)
//  • Medal3D        — medalha animada: repouso, resposta ao toque, entrada
//  • Medal3DMini    — versão estática minúscula (ao lado do nome)
//  • MedalGrid      — grade de medalhas do perfil
//  • showMedalViewer— janela de detalhes com rotação por arrasto
//
// Desempenho: tudo é desenhado por código; cada medalha fica dentro de
// um RepaintBoundary; o movimento de repouso só roda enquanto a medalha
// está visível na tela, o aparelho não pediu "reduzir animações" e a
// qualidade não caiu para "baixa" (ver Medal3DPerf).
// ═══════════════════════════════════════════════════════════════════

/// Observa o tempo dos quadros enquanto há medalhas animando e reduz o
/// nível de detalhe (high → medium → low) se o aparelho não acompanhar.
/// Nunca volta sozinho para um nível maior no mesmo uso do app, para
/// evitar oscilar entre estados.
class Medal3DPerf {
  Medal3DPerf._();

  static Medal3DQuality quality = Medal3DQuality.high;

  static int _users = 0;
  static bool _listening = false;
  static int _frames = 0;
  static final List<int> _samples = [];

  static void acquire() {
    _users++;
    if (!_listening) {
      _listening = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  static void release() {
    _users = math.max(0, _users - 1);
    if (_users == 0 && _listening) {
      _listening = false;
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _samples.clear();
      _frames = 0;
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      if (_frames < 40) continue; // aquecimento
      _samples.add(t.totalSpan.inMicroseconds);
      if (_samples.length >= 60) {
        final avg = _samples.reduce((a, b) => a + b) / _samples.length;
        _samples.clear();
        if (avg > 22000 && quality != Medal3DQuality.low) {
          quality = quality == Medal3DQuality.high
              ? Medal3DQuality.medium
              : Medal3DQuality.low;
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Pose estática
// ═══════════════════════════════════════════════════════════════════

class Medal3DCanvas extends StatelessWidget {
  final MedalSpec spec;
  final double size;
  final bool unlocked;
  final double rotX;
  final double rotY;
  final double shine;
  final double flash;
  final double glow;
  final double sparkle;
  final double burst;
  final double appear;
  final Medal3DQuality quality;

  const Medal3DCanvas({
    Key? key,
    required this.spec,
    required this.size,
    required this.unlocked,
    this.rotX = 0,
    this.rotY = 0,
    this.shine = 0.18,
    this.flash = 0,
    this.glow = 0.5,
    this.sparkle = 0.25,
    this.burst = 0,
    this.appear = 1,
    this.quality = Medal3DQuality.high,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: Medal3DPainter(
          spec: spec,
          unlocked: unlocked,
          rotX: rotX,
          rotY: rotY,
          shine: shine,
          flash: flash,
          glow: glow,
          sparkle: sparkle,
          burst: burst,
          appear: appear,
          quality: quality,
        ),
      ),
    );
  }
}

/// Medalha minúscula e estática (comentários, ao lado do nome).
class Medal3DMini extends StatelessWidget {
  final String achievementId;
  final double size;

  const Medal3DMini({Key? key, required this.achievementId, this.size = 24})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Medal3DCanvas(
        spec: Badge3DConfig.specFor(achievementId),
        size: size,
        unlocked: true,
        rotX: -0.10,
        rotY: 0.24,
        quality: Medal3DQuality.low,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Medalha animada
// ═══════════════════════════════════════════════════════════════════

class Medal3D extends StatefulWidget {
  /// Chave da conquista (Achievement.icon / id).
  final String achievementId;
  final double size;
  final bool unlocked;

  /// Movimento de repouso (inclinação leve + reflexo na borda).
  final bool animate;

  /// Responde ao toque (inclina, gira rápido e reflete luz).
  final bool interactive;

  /// Toca a animação de conquista (entrada com rotação + partículas).
  final bool celebrate;

  final VoidCallback? onTap;
  final VoidCallback? onCelebrationDone;

  const Medal3D({
    Key? key,
    required this.achievementId,
    required this.size,
    required this.unlocked,
    this.animate = true,
    this.interactive = true,
    this.celebrate = false,
    this.onTap,
    this.onCelebrationDone,
  }) : super(key: key);

  @override
  State<Medal3D> createState() => _Medal3DState();
}

class _Medal3DState extends State<Medal3D> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 380),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: widget.celebrate ? 0 : 1,
  );

  ScrollPosition? _scrollPos;
  bool _visible = true;
  bool _reduceMotion = false;
  double _pressDx = 0;
  double _pressDy = 0;

  late final MedalSpec _spec = Badge3DConfig.specFor(widget.achievementId);

  @override
  void initState() {
    super.initState();
    Medal3DPerf.acquire();
    // Depois do primeiro quadro, para já saber se o aparelho pede
    // "reduzir animações".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.celebrate) _playEnter();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _scrollPos) {
      _scrollPos?.removeListener(_checkVisible);
      _scrollPos = pos;
      _scrollPos?.addListener(_checkVisible);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
    _syncIdle();
  }

  @override
  void didUpdateWidget(covariant Medal3D old) {
    super.didUpdateWidget(old);
    if (widget.celebrate && !old.celebrate) _playEnter();
    _syncIdle();
  }

  void _playEnter() {
    if (_reduceMotion) {
      _enter.value = 1;
      widget.onCelebrationDone?.call();
      return;
    }
    HapticFeedback.lightImpact();
    _enter.forward(from: 0).whenComplete(() {
      if (mounted) widget.onCelebrationDone?.call();
    });
  }

  @override
  void dispose() {
    _scrollPos?.removeListener(_checkVisible);
    _idle.dispose();
    _press.dispose();
    _spin.dispose();
    _enter.dispose();
    Medal3DPerf.release();
    super.dispose();
  }

  /// Pausa o movimento quando a medalha sai da área visível.
  void _checkVisible() {
    if (!mounted) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final top = ro.localToGlobal(Offset.zero).dy;
    final screenH = MediaQuery.sizeOf(context).height;
    final vis = top + ro.size.height > 0 && top < screenH;
    if (vis != _visible) {
      _visible = vis;
      _syncIdle();
    }
  }

  bool get _idleWanted =>
      widget.animate &&
      widget.unlocked &&
      _visible &&
      !_reduceMotion &&
      Medal3DPerf.quality != Medal3DQuality.low;

  void _syncIdle() {
    if (_idleWanted) {
      if (!_idle.isAnimating) _idle.repeat();
    } else if (_idle.isAnimating) {
      _idle.stop();
    }
  }

  double _spinAngle(double u) {
    if (_reduceMotion) return 0;
    if (u < 0.4) {
      return 1.15 * Curves.easeOut.transform(u / 0.4);
    } else if (u < 0.75) {
      final k = Curves.easeInOut.transform((u - 0.4) / 0.35);
      return 1.15 + (-0.35 - 1.15) * k;
    }
    final k = Curves.easeOut.transform((u - 0.75) / 0.25);
    return -0.35 * (1 - k);
  }

  @override
  Widget build(BuildContext context) {
    final quality = Medal3DPerf.quality;
    final listenable = Listenable.merge([_idle, _press, _spin, _enter]);

    final medal = AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        var rx = -0.06;
        var ry = 0.14;
        var shine = 0.18;
        var glow = 0.5;
        var sparkle = 0.25;

        if (_idle.isAnimating) {
          final a = _idle.value * 2 * math.pi;
          ry += 0.17 * math.sin(a);
          rx += 0.075 * math.cos(a);
          shine = _idle.value;
          glow = 0.5 + 0.5 * math.sin(a);
          sparkle = _idle.value;
        }

        final p = Curves.easeOut.transform(_press.value);
        rx += -_pressDy * 0.38 * p;
        ry += _pressDx * 0.55 * p;

        var flash = 0.0;
        if (_spin.isAnimating) {
          ry += _spinAngle(_spin.value);
          flash = _spin.value;
        }

        var appear = 1.0;
        var scale = 1.0;
        var burst = 0.0;
        if (_enter.value < 1) {
          final e = _enter.value;
          appear = Curves.easeOut.transform((e / 0.25).clamp(0.0, 1.0));
          scale = 0.25 + 0.75 * Curves.easeOutBack.transform(e.clamp(0.0, 1.0));
          ry += (1 - Curves.easeOutCubic.transform(e)) * (-math.pi * 2);
          burst = ((e - 0.35) / 0.65).clamp(0.0, 1.0);
        }

        return Transform.scale(
          scale: scale,
          child: Medal3DCanvas(
            spec: _spec,
            size: widget.size,
            unlocked: widget.unlocked,
            rotX: rx,
            rotY: ry,
            shine: shine,
            flash: flash,
            glow: glow,
            sparkle: sparkle,
            burst: burst,
            appear: appear,
            quality: quality,
          ),
        );
      },
    );

    final sized = SizedBox(width: widget.size, height: widget.size, child: medal);
    if (!widget.interactive) return sized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        _pressDx = ((d.localPosition.dx / widget.size) * 2 - 1)
            .clamp(-1.0, 1.0)
            .toDouble();
        _pressDy = ((d.localPosition.dy / widget.size) * 2 - 1)
            .clamp(-1.0, 1.0)
            .toDouble();
        _press.forward();
      },
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: () {
        HapticFeedback.selectionClick();
        if (!_reduceMotion) _spin.forward(from: 0);
        final cb = widget.onTap;
        if (cb != null) {
          // Dá tempo de ver a resposta ao toque antes de abrir os detalhes.
          Future.delayed(const Duration(milliseconds: 240), () {
            if (mounted) cb();
          });
        }
      },
      child: sized,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Etiqueta de raridade
// ═══════════════════════════════════════════════════════════════════

class MedalRarityChip extends StatelessWidget {
  final MedalRarity rarity;
  final bool filled;
  final double fontSize;

  const MedalRarityChip({
    Key? key,
    required this.rarity,
    this.filled = false,
    this.fontSize = 9,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = rarity.accent;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.9, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: filled
            ? LinearGradient(colors: [Color.lerp(c, Colors.black, 0.35)!, c])
            : null,
        border: filled ? null : Border.all(color: c.withOpacity(0.55)),
      ),
      child: Text(
        rarity.label,
        maxLines: 1,
        style: TextStyle(
          color: filled ? Colors.white : c,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Grade de medalhas (perfil)
// ═══════════════════════════════════════════════════════════════════

class MedalGrid extends StatefulWidget {
  final List<Achievement> items;
  final bool unlocked;
  final UserXpData data;

  const MedalGrid({
    Key? key,
    required this.items,
    required this.unlocked,
    required this.data,
  }) : super(key: key);

  @override
  State<MedalGrid> createState() => _MedalGridState();
}

class _MedalGridState extends State<MedalGrid> {
  Set<String> _celebrate = {};
  String _signature = '';

  String get _sig => widget.items.map((a) => a.id).join(',');

  @override
  void initState() {
    super.initState();
    _signature = _sig;
    if (widget.unlocked) _checkNew();
  }

  @override
  void didUpdateWidget(covariant MedalGrid old) {
    super.didUpdateWidget(old);
    if (widget.unlocked && _sig != _signature) {
      _signature = _sig;
      _checkNew();
    }
  }

  /// Medalhas conquistadas que o usuário ainda não "viu" tocam a
  /// animação de conquista uma única vez. Na primeira vez que a tela é
  /// aberta, tudo que já existe é marcado como visto sem animar.
  Future<void> _checkNew() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      final key = 'medals_seen_$uid';
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(key);
      final ids = widget.items.map((a) => a.id).toList();
      if (stored == null) {
        await prefs.setStringList(key, ids);
        return;
      }
      final fresh = ids.where((id) => !stored.contains(id)).toSet();
      if (fresh.isEmpty || !mounted) return;
      setState(() => _celebrate = fresh);
      Future.delayed(const Duration(milliseconds: 2400), () async {
        try {
          final p = await SharedPreferences.getInstance();
          final cur = p.getStringList(key) ?? <String>[];
          await p.setStringList(key, {...cur, ...fresh}.toList());
        } catch (_) {}
        if (mounted) setState(() => _celebrate = {});
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final cols = math.max(3, (c.maxWidth / 118).ceil());
      final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
      final medal = math.min(cellW - 12, 104.0);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: gap,
          mainAxisExtent: medal + 64,
        ),
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final a = widget.items[i];
          return _MedalCard(
            achievement: a,
            unlocked: widget.unlocked,
            medalSize: medal,
            celebrate: _celebrate.contains(a.id),
            onOpen: () => showMedalViewer(
              context,
              achievement: a,
              unlocked: widget.unlocked,
              data: widget.data,
            ),
          );
        },
      );
    });
  }
}

class _MedalCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final double medalSize;
  final bool celebrate;
  final VoidCallback onOpen;

  const _MedalCard({
    required this.achievement,
    required this.unlocked,
    required this.medalSize,
    required this.celebrate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final spec = Badge3DConfig.specFor(achievement.icon);
    final accent = spec.rarity.accent;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1);

    return Semantics(
      button: true,
      label: '${achievement.title}, ${unlocked ? 'conquistada' : 'bloqueada'}, '
          'raridade ${spec.rarity.label.toLowerCase()}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0B0B0B),
          gradient: unlocked
              ? RadialGradient(
                  center: const Alignment(0, -0.55),
                  radius: 0.95,
                  colors: [
                    accent.withOpacity(0.20),
                    const Color(0xFF0B0B0B),
                  ],
                )
              : null,
          border: Border.all(
            color: unlocked
                ? accent.withOpacity(spec.rarity.tier >= 4 ? 0.70 : 0.38)
                : const Color(0xFF1A1A1A),
            width: spec.rarity.tier >= 4 && unlocked ? 1.4 : 1,
          ),
          boxShadow: unlocked && spec.rarity.tier >= 3
              ? [BoxShadow(color: accent.withOpacity(0.16), blurRadius: 14)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Medal3D(
              achievementId: achievement.icon,
              size: medalSize,
              unlocked: unlocked,
              celebrate: celebrate,
              onTap: onOpen,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: TextStyle(
                    color: unlocked ? Colors.white : const Color(0xFF7A7A7A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 14,
              child: unlocked
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MedalRarityChip(
                          rarity: spec.rarity, fontSize: 8.5),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.lock,
                              size: 8, color: Color(0xFF666666)),
                          SizedBox(width: 4),
                          Text('BLOQUEADA',
                              style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Janela de detalhes com medalha giratória
// ═══════════════════════════════════════════════════════════════════

Future<void> showMedalViewer(
  BuildContext context, {
  required Achievement achievement,
  required bool unlocked,
  required UserXpData data,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withOpacity(0.82),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _MedalViewer(
      achievement: achievement,
      unlocked: unlocked,
      data: data,
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _MedalViewer extends StatefulWidget {
  final Achievement achievement;
  final bool unlocked;
  final UserXpData data;

  const _MedalViewer({
    required this.achievement,
    required this.unlocked,
    required this.data,
  });

  @override
  State<_MedalViewer> createState() => _MedalViewerState();
}

class _MedalViewerState extends State<_MedalViewer>
    with TickerProviderStateMixin {
  double _ry = 0.45;
  double _rx = -0.12;
  bool _dragging = false;
  bool _reduce = false;
  double _rxFrom = 0;
  double _rxTo = 0;

  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  late final AnimationController _inertia = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _relax = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    Medal3DPerf.acquire();
    _inertia.addListener(() => _ry = _inertia.value);
    _relax.addListener(() {
      _rx = _rxFrom + (_rxTo - _rxFrom) * Curves.easeOut.transform(_relax.value);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_reduce && widget.unlocked) {
      if (!_idle.isAnimating) _idle.repeat();
    } else {
      _idle.stop();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _inertia.dispose();
    _relax.dispose();
    Medal3DPerf.release();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    _inertia.stop();
    _relax.stop();
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _ry += d.delta.dx * 0.012;
      // Inclinação vertical limitada (~25°).
      _rx = (_rx - d.delta.dy * 0.008).clamp(-0.45, 0.45).toDouble();
    });
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() => _dragging = false);
    // Inércia controlada: velocidade angular limitada e atrito alto.
    final v = (d.velocity.pixelsPerSecond.dx * 0.012).clamp(-6.0, 6.0).toDouble();
    if (!_reduce && v.abs() > 0.25) {
      _inertia.animateWith(FrictionSimulation(0.02, _ry, v));
    }
    _rxFrom = _rx;
    _rxTo = -0.08;
    _relax.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final spec = Badge3DConfig.specFor(a.icon);
    final accent = spec.rarity.accent;
    final media = MediaQuery.of(context);
    final cardW = math.min(media.size.width * 0.9, 380.0);
    final medalSize = math.min(
      math.min(cardW - 40, 270.0),
      media.size.height < 640 ? 200.0 : 270.0,
    );
    final criteria = Badge3DConfig.criteriaFor(a.icon, a.description);
    final progress =
        widget.unlocked ? null : Badge3DConfig.progressFor(a.icon, widget.data);
    final quality = Medal3DPerf.quality;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardW,
            maxHeight: media.size.height * 0.92,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: const Color(0xFF0C0C0C),
              border: Border.all(
                color: widget.unlocked
                    ? accent.withOpacity(0.55)
                    : const Color(0xFF222222),
                width: 1.4,
              ),
              boxShadow: widget.unlocked
                  ? [BoxShadow(color: accent.withOpacity(0.22), blurRadius: 40)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF8A8A8A)),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                // Medalha fora da rolagem: o arrasto nunca briga com ela.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_idle, _inertia, _relax]),
                    builder: (context, _) {
                      var rx = _rx;
                      var ry = _ry;
                      var shine = 0.2 + 0.0;
                      var glow = 0.5;
                      var sparkle = 0.25;
                      if (_idle.isAnimating && !_dragging) {
                        final t = _idle.value * 2 * math.pi;
                        ry += 0.035 * math.sin(t);
                        rx += 0.03 * math.cos(t);
                        shine = _idle.value;
                        glow = 0.5 + 0.5 * math.sin(t);
                        sparkle = _idle.value;
                      }
                      return Medal3DCanvas(
                        spec: spec,
                        size: medalSize,
                        unlocked: widget.unlocked,
                        rotX: rx,
                        rotY: ry,
                        shine: shine,
                        glow: glow,
                        sparkle: sparkle,
                        quality: quality,
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Arraste para girar a medalha',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 11),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            MedalRarityChip(
                                rarity: spec.rarity, filled: true, fontSize: 10),
                            _statusChip(widget.unlocked),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          a.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.unlocked
                                ? Colors.white
                                : const Color(0xFFB0B0B0),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: const Color(0xFF1F1F1F)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COMO DESBLOQUEAR',
                                style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                criteria,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4),
                              ),
                              if (progress != null) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress.fraction,
                                    minHeight: 7,
                                    backgroundColor: const Color(0xFF1E1E1E),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryOrange),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  progress.label,
                                  style: const TextStyle(
                                    color: Color(0xFFB0B0B0),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(bool unlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: unlocked ? const Color(0xFF1E3A2B) : const Color(0xFF181818),
        border: Border.all(
          color: unlocked ? const Color(0xFF2E7D55) : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
            size: 12,
            color: unlocked ? const Color(0xFF43B581) : const Color(0xFF777777),
          ),
          const SizedBox(width: 5),
          Text(
            unlocked ? 'CONQUISTADA' : 'BLOQUEADA',
            style: TextStyle(
              color: unlocked ? const Color(0xFF43B581) : const Color(0xFF8A8A8A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}