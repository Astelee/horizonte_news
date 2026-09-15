import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estilo de animação aplicado à moldura decorativa do avatar.
enum FrameAnimationStyle {
  static_, // sem animação
  rotate, // rotação contínua lenta
  pulse, // glow pulsando (brilho "respirando")
  rotateAndPulse, // rotação + pulsar juntos
}

/// Avatar com moldura decorativa animada (estilo dragão/fênix).
///
/// A moldura (PNG com transparência real) é desenhada por cima do avatar
/// circular, girando lentamente e/ou pulsando um glow atrás dela.
///
/// `avatarFraction` controla o quanto do canvas da moldura o avatar
/// circular deve ocupar — cada arte tem uma proporção diferente porque a
/// "janela" vazia no centro não é padronizada entre as artes. Valores já
/// calibrados visualmente para os dois assets gerados:
///   - moldura_dragao_cristal.png -> 0.60
///   - trono_solar.png (fênix)    -> 0.55
///
/// Uso típico dentro do sistema de raridade existente (FrameRarityExt):
///
/// ```dart
/// AnimatedAvatarFrame(
///   avatarAssetPath: 'assets/avatars/avatar_07.png',
///   frameAssetPath: 'assets/frames/moldura_dragao_cristal.png',
///   avatarFraction: 0.60,
///   size: 96,
///   animationStyle: FrameAnimationStyle.rotateAndPulse,
///   glowColor: const Color(0xFF6FA8FF), // tom cristal-azul do dragão
/// )
/// ```
class AnimatedAvatarFrame extends StatefulWidget {
  const AnimatedAvatarFrame({
    super.key,
    required this.avatarAssetPath,
    required this.frameAssetPath,
    this.avatarFraction = 0.60,
    this.size = 96,
    this.animationStyle = FrameAnimationStyle.rotateAndPulse,
    this.glowColor = const Color(0xFF6FA8FF),
    this.rotationDuration = const Duration(seconds: 18),
    this.pulseDuration = const Duration(seconds: 2),
    this.pulseMinOpacity = 0.35,
    this.pulseMaxOpacity = 0.85,
  });

  /// Caminho do asset do avatar do usuário (ex: assets/avatars/avatar_07.png)
  final String avatarAssetPath;

  /// Caminho do asset da moldura decorativa (PNG transparente)
  final String frameAssetPath;

  /// Fração do canvas da moldura ocupada pelo círculo do avatar (0.0–1.0)
  final double avatarFraction;

  /// Tamanho total do widget (diâmetro do avatar visível em lógica px)
  final double size;

  final FrameAnimationStyle animationStyle;

  /// Cor do glow pulsante atrás da moldura
  final Color glowColor;

  final Duration rotationDuration;
  final Duration pulseDuration;
  final double pulseMinOpacity;
  final double pulseMaxOpacity;

  @override
  State<AnimatedAvatarFrame> createState() => _AnimatedAvatarFrameState();
}

class _AnimatedAvatarFrameState extends State<AnimatedAvatarFrame>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;

  bool get _wantsRotation =>
      widget.animationStyle == FrameAnimationStyle.rotate ||
      widget.animationStyle == FrameAnimationStyle.rotateAndPulse;

  bool get _wantsPulse =>
      widget.animationStyle == FrameAnimationStyle.pulse ||
      widget.animationStyle == FrameAnimationStyle.rotateAndPulse;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: widget.rotationDuration,
    );
    if (_wantsRotation) {
      _rotationController.repeat();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    );
    if (_wantsPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAvatarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationStyle != widget.animationStyle) {
      if (_wantsRotation) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
        _rotationController.reset();
      }
      if (_wantsPulse) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A moldura é renderizada num canvas um pouco maior que o avatar,
    // já que as artes (dragão/asas) se estendem para além do círculo
    // do avatar em si (picos de cristal, penas, etc).
    final frameCanvasSize = widget.size / widget.avatarFraction;

    return SizedBox(
      width: frameCanvasSize,
      height: frameCanvasSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow pulsante atrás de tudo
          if (_wantsPulse)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final t = _pulseController.value;
                final opacity = widget.pulseMinOpacity +
                    (widget.pulseMaxOpacity - widget.pulseMinOpacity) * t;
                final glowSize = widget.size * (1.05 + 0.08 * t);
                return Container(
                  width: glowSize,
                  height: glowSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor.withOpacity(opacity * 0.6),
                        blurRadius: 24 + 16 * t,
                        spreadRadius: 2 + 4 * t,
                      ),
                    ],
                  ),
                );
              },
            ),

          // Avatar circular do usuário (fica ATRÁS da moldura, sob os
          // elementos decorativos que "invadem" o centro, como os
          // diamantes do dragão ou o bico da fênix)
          ClipOval(
            child: Image.asset(
              widget.avatarAssetPath,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
            ),
          ),

          // Moldura decorativa (dragão / fênix / etc), rotacionando
          if (_wantsRotation)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: _FrameImage(
                path: widget.frameAssetPath,
                size: frameCanvasSize,
              ),
            )
          else
            _FrameImage(
              path: widget.frameAssetPath,
              size: frameCanvasSize,
            ),
        ],
      ),
    );
  }
}

class _FrameImage extends StatelessWidget {
  const _FrameImage({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}