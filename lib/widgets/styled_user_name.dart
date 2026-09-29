import 'dart:async';
import 'package:flutter/material.dart';
import '../config/name_style_config.dart';
import 'name_effects.dart';

// ═══════════════════════════════════════════════════════════════════
// NOME PERSONALIZADO DE ASSINANTE — WIDGET CENTRAL
// ═══════════════════════════════════════════════════════════════════
// Único ponto do app que desenha o NOME de um usuário. Qualquer tela
// (comentários, respostas, ranking, pódio, perfil, listas...) usa este
// widget em vez de um Text solto, e o efeito aparece igual para todo
// mundo — o estilo vem do DONO do nome (NameStyle.fromUserData), nunca
// de quem está olhando.
//
// • nameStyle == null (não assinante, plano vencido ou nada escolhido):
//   é literalmente um Text com o [style] recebido — zero custo extra.
// • nameStyle sem efeitos: Text com a cor escolhida.
// • nameStyle com efeitos: texto medido uma vez + CustomPainter ligado
//   ao relógio único NameEffectClock (ver name_effects.dart).
//
// O selo (SubscriberBadge) NÃO faz parte deste widget: continua sendo
// colocado ao lado do nome, exatamente como antes.
// ═══════════════════════════════════════════════════════════════════

class StyledUserName extends StatefulWidget {
  final String name;

  /// Estilo base do texto (tamanho, peso, cor padrão do local). Com um
  /// [nameStyle] ativo, a cor escolhida pelo dono substitui a cor daqui.
  final TextStyle style;

  /// Personalização do dono do nome (null = visual padrão).
  final NameStyle? nameStyle;

  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  const StyledUserName(
    this.name, {
    Key? key,
    required this.style,
    this.nameStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
  }) : super(key: key);

  @override
  State<StyledUserName> createState() => _StyledUserNameState();
}

class _StyledUserNameState extends State<StyledUserName> {
  NameTextLayout? _layout;
  String? _layoutName;
  TextStyle? _layoutTextStyle;
  NameStyle? _layoutNameStyle;
  double? _layoutMaxWidth;
  TextAlign? _layoutTextAlign;
  int? _layoutMaxLines;
  TextOverflow? _layoutOverflow;
  TextScaler? _layoutTextScaler;

  bool _clockHeld = false;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;
  Timer? _expiryTimer;

  /// Estilo efetivo AGORA: null se não há estilo ou se o plano venceu.
  NameStyle? get _active {
    final s = widget.nameStyle;
    if (s == null || !s.isActive) return null;
    return s;
  }

  bool get _animated {
    final s = _active;
    return s != null && s.hasEffects && _tickerEnabled && !_reduceMotion;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tela coberta por outra rota (TickerMode desligado) ou usuário
    // com "reduzir animações" no sistema: não gasta relógio.
    _tickerEnabled = TickerMode.of(context);
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncClock();
    _syncExpiryTimer();
  }

  @override
  void didUpdateWidget(StyledUserName oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
    if (oldWidget.nameStyle != widget.nameStyle) _syncExpiryTimer();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    if (_clockHeld) {
      NameEffectClock.instance.release();
      _clockHeld = false;
    }
    _layout?.dispose();
    _layout = null;
    super.dispose();
  }

  void _syncClock() {
    final need = _animated;
    if (need && !_clockHeld) {
      NameEffectClock.instance.acquire();
      _clockHeld = true;
    } else if (!need && _clockHeld) {
      NameEffectClock.instance.release();
      _clockHeld = false;
    }
  }

  // Quando o plano vence com a tela aberta, desliga os efeitos na hora
  // (sem esperar alguém reconstruir a lista). Espera no máximo 6 h por
  // vez e reagenda, para não depender de um Timer gigante.
  void _syncExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    final expires = widget.nameStyle?.premiumExpiresAt;
    if (expires == null) return;

    var delay = expires.difference(DateTime.now()) + const Duration(seconds: 1);
    if (delay.isNegative) return;
    const maxDelay = Duration(hours: 6);
    if (delay > maxDelay) delay = maxDelay;

    _expiryTimer = Timer(delay, () {
      if (!mounted) return;
      _syncClock();
      _syncExpiryTimer();
      setState(() {});
    });
  }

  NameTextLayout _layoutFor(
    NameStyle style,
    double maxWidth,
    TextScaler textScaler,
  ) {
    final reusable = _layout != null &&
        _layoutName == widget.name &&
        _layoutTextStyle == widget.style &&
        _layoutNameStyle == style &&
        _layoutMaxWidth == maxWidth &&
        _layoutTextAlign == widget.textAlign &&
        _layoutMaxLines == widget.maxLines &&
        _layoutOverflow == widget.overflow &&
        _layoutTextScaler == textScaler;
    if (reusable) return _layout!;

    _layout?.dispose();
    final layout = NameTextLayout.build(
      text: widget.name,
      style: widget.style,
      nameStyle: style,
      maxWidth: maxWidth,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textScaler: textScaler,
    );
    _layout = layout;
    _layoutName = widget.name;
    _layoutTextStyle = widget.style;
    _layoutNameStyle = style;
    _layoutMaxWidth = maxWidth;
    _layoutTextAlign = widget.textAlign;
    _layoutMaxLines = widget.maxLines;
    _layoutOverflow = widget.overflow;
    _layoutTextScaler = textScaler;
    return layout;
  }

  Alignment _alignmentFor(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return Alignment.centerLeft;
    }
  }

  Widget _plainText(TextStyle style) {
    return Text(
      widget.name,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameStyle = _active;

    // Visual padrão (não assinante / plano vencido / sem escolha).
    if (nameStyle == null) return _plainText(widget.style);

    // Só a cor escolhida, sem animação.
    if (!nameStyle.hasEffects) {
      return _plainText(widget.style.copyWith(color: nameStyle.color.primary));
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final animated = _animated;
    final seed = widget.name.hashCode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _layoutFor(nameStyle, constraints.maxWidth, textScaler);
        return Semantics(
          label: widget.name,
          excludeSemantics: true,
          child: Align(
            alignment: _alignmentFor(widget.textAlign),
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: RepaintBoundary(
              child: CustomPaint(
                size: layout.size,
                painter: NameEffectPainter(
                  layout: layout,
                  style: nameStyle,
                  seed: seed,
                  animate: animated,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}