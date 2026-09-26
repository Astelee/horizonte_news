import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_navigator.dart';

// ═══════════════════════════════════════════════════════════════════
// APP MESSENGER — sistema centralizado de feedback visual
// ═══════════════════════════════════════════════════════════════════
// Ponto único para TODA mensagem temporária do app (sucesso, erro,
// aviso, info, recompensa/XP). Objetivo: identidade visual única
// (preto/laranja/branco, glow, cantos arredondados) + controle real
// de fila, para nunca mais acumular mensagens como acontecia no
// check-in (o ScaffoldMessenger nativo enfileira SnackBars sem
// nenhum limite, então 23 ações seguidas viravam 23 mensagens de ~4s
// cada, aparecendo por quase 2 minutos depois de a ação já ter
// terminado).
//
// Por isso este sistema NÃO usa ScaffoldMessenger/SnackBar por
// baixo — usa um Overlay próprio, o que dá controle total sobre:
//   • quantas mensagens existem na tela ao mesmo tempo (no máximo 1
//     "toast" por vez, sempre no mesmo lugar);
//   • fila com agrupamento: mensagens da mesma origem (ex.: "chave"
//     'checkin_xp') ATUALIZAM a mensagem atual em vez de empilhar
//     uma nova;
//   • duração curta e consistente por tipo;
//   • cancelamento explícito quando uma tela fecha.
//
// Uso básico, de qualquer lugar do app (não precisa de context local
// se preferir usar o navigatorKey global, mas aceita context também):
//
//   AppMessenger.success('Foto enviada!');
//   AppMessenger.error('Não foi possível concluir.');
//   AppMessenger.warning('Sessão prestes a expirar.');
//   AppMessenger.info('Notificações são enviadas ao publicar.');
//   AppMessenger.reward('+50 XP', subtitle: 'Check-in realizado');
//
// Para ações repetidas rapidamente (ex.: check-in em lote), use uma
// [groupKey] estável — a mesma chave faz a mensagem existente ser
// ATUALIZADA (texto + timer de duração reiniciado) em vez de
// empilhar uma nova por cima:
//
//   AppMessenger.reward('+50 XP', subtitle: 'Check-in realizado',
//       groupKey: 'checkin_xp');
//
// Para textos que também mudam de tipo (ex.: passa a mostrar total
// acumulado), chame de novo com a mesma groupKey — o conteúdo troca
// suavemente sem gerar uma segunda mensagem na tela.
// ═══════════════════════════════════════════════════════════════════

enum AppMessageType { success, error, warning, info, reward }

class _AppMessageEntry {
  final String id;
  final String? groupKey;
  String message;
  String? subtitle;
  AppMessageType type;
  Duration duration;
  String? actionLabel;
  VoidCallback? onAction;
  Timer? _hideTimer;

  _AppMessageEntry({
    required this.id,
    required this.message,
    required this.type,
    required this.duration,
    this.groupKey,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });
}

class AppMessenger {
  AppMessenger._();

  static OverlayEntry? _overlayEntry;
  static final List<_AppMessageEntry> _queue = [];
  static _AppMessageEntry? _current;
  static Timer? _advanceTimer;

  // Duração padrão por tipo — mensagens de reward/sucesso são
  // rápidas de propósito, para não acumular em ações repetitivas
  // como check-in ou curtidas em sequência.
  static const Map<AppMessageType, Duration> _defaultDurations = {
    AppMessageType.success: Duration(milliseconds: 1800),
    AppMessageType.reward: Duration(milliseconds: 1600),
    AppMessageType.info: Duration(milliseconds: 2400),
    AppMessageType.warning: Duration(milliseconds: 2800),
    AppMessageType.error: Duration(milliseconds: 3200),
  };

  static BuildContext? get _ctx =>
      navigatorKey.currentState?.overlay?.context ?? navigatorKey.currentContext;

  // ── API pública ───────────────────────────────────────────────

  static void success(String message, {String? subtitle, String? groupKey, Duration? duration}) {
    _show(message, AppMessageType.success, subtitle: subtitle, groupKey: groupKey, duration: duration);
  }

  static void error(String message, {String? subtitle, String? groupKey, Duration? duration}) {
    _show(message, AppMessageType.error, subtitle: subtitle, groupKey: groupKey, duration: duration);
  }

  static void warning(String message,
      {String? subtitle,
      String? groupKey,
      Duration? duration,
      String? actionLabel,
      VoidCallback? onAction}) {
    _show(message, AppMessageType.warning,
        subtitle: subtitle,
        groupKey: groupKey,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction);
  }

  static void info(String message, {String? subtitle, String? groupKey, Duration? duration}) {
    _show(message, AppMessageType.info, subtitle: subtitle, groupKey: groupKey, duration: duration);
  }

  static void reward(String message, {String? subtitle, String? groupKey, Duration? duration}) {
    _show(message, AppMessageType.reward, subtitle: subtitle, groupKey: groupKey, duration: duration);
  }

  /// Remove a mensagem atual e limpa toda a fila pendente. Útil ao
  /// sair de uma tela (dispose) para garantir que nada tentará
  /// reaparecer depois que o usuário já saiu do fluxo.
  static void clearAll() {
    _queue.clear();
    _advanceTimer?.cancel();
    _current?._hideTimer?.cancel();
    _current = null;
    _removeOverlay();
  }

  // ── Núcleo ────────────────────────────────────────────────────

  static void _show(
    String message,
    AppMessageType type, {
    String? subtitle,
    String? groupKey,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ctx = _ctx;
    if (ctx == null) return;

    // Uma mensagem com ação (ex.: "VER ULTRA") merece um pouco mais
    // de tempo na tela do que o padrão do tipo, para dar chance de o
    // usuário ler e tocar antes de sumir.
    final resolvedDuration = duration ??
        (actionLabel != null
            ? _defaultDurations[type]! + const Duration(seconds: 2)
            : _defaultDurations[type]!);

    // Agrupamento: se já existe uma mensagem ATUAL ou NA FILA com a
    // mesma groupKey, atualiza o conteúdo dela em vez de empilhar
    // uma nova entrada. É isso que evita a fila de 23 SnackBars do
    // check-in — a mesma "célula" visual é reaproveitada e apenas
    // seu texto/timer é atualizado.
    if (groupKey != null) {
      if (_current?.groupKey == groupKey) {
        _current!
          ..message = message
          ..subtitle = subtitle
          ..type = type
          ..duration = resolvedDuration
          ..actionLabel = actionLabel
          ..onAction = onAction;
        _current!._hideTimer?.cancel();
        _current!._hideTimer = Timer(resolvedDuration, _advance);
        _renderOverlay(ctx);
        return;
      }
      final queuedIndex = _queue.indexWhere((e) => e.groupKey == groupKey);
      if (queuedIndex != -1) {
        _queue[queuedIndex]
          ..message = message
          ..subtitle = subtitle
          ..type = type
          ..duration = resolvedDuration
          ..actionLabel = actionLabel
          ..onAction = onAction;
        return;
      }
    }

    final entry = _AppMessageEntry(
      id: UniqueKey().toString(),
      message: message,
      subtitle: subtitle,
      type: type,
      duration: resolvedDuration,
      groupKey: groupKey,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    if (_current == null) {
      _current = entry;
      _current!._hideTimer = Timer(resolvedDuration, _advance);
      _renderOverlay(ctx);
    } else {
      // Erros nunca ficam presos atrás de uma fila longa de
      // mensagens não-críticas: entram logo em seguida da atual.
      if (type == AppMessageType.error) {
        _queue.insert(0, entry);
      } else {
        _queue.add(entry);
      }
      // Nunca deixamos uma fila gigante viva na tela depois que o
      // usuário já terminou a ação — mantemos só as últimas
      // mensagens relevantes.
      while (_queue.length > 3) {
        _queue.removeAt(0);
      }
    }
  }

  static void _advance() {
    _current?._hideTimer?.cancel();
    if (_queue.isEmpty) {
      _current = null;
      _removeOverlay();
      return;
    }
    _current = _queue.removeAt(0);
    final ctx = _ctx;
    if (ctx == null) {
      _current = null;
      return;
    }
    _current!._hideTimer = Timer(_current!.duration, _advance);
    _renderOverlay(ctx);
  }

  static void _renderOverlay(BuildContext ctx) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => _AppMessageToast(
        key: ValueKey(_current!.id),
        entry: _current!,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  static void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

// ═══════════════════════════════════════════════════════════════════
// Widget visual — identidade preta/laranja/glow, sempre no mesmo
// lugar da tela (topo, abaixo da status bar), com entrada/saída
// suaves.
// ═══════════════════════════════════════════════════════════════════
class _AppMessageToast extends StatefulWidget {
  final _AppMessageEntry entry;
  const _AppMessageToast({super.key, required this.entry});

  @override
  State<_AppMessageToast> createState() => _AppMessageToastState();
}

class _AppMessageToastState extends State<_AppMessageToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _AppMessageToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mesma entry (groupKey reaproveitado) mudou de conteúdo: dá um
    // pulso curto em vez de reabrir a animação inteira, pra ficar
    // fluido durante ações repetidas (ex.: check-in em sequência).
    if (oldWidget.entry.message != widget.entry.message ||
        oldWidget.entry.subtitle != widget.entry.subtitle) {
      _ctrl.forward(from: 0.7);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ({Color color, IconData icon}) _styleFor(AppMessageType type) {
    switch (type) {
      case AppMessageType.success:
        return (color: const Color(0xFF43B581), icon: Icons.check_circle_rounded);
      case AppMessageType.error:
        return (color: AppColors.emergencyRed, icon: Icons.error_rounded);
      case AppMessageType.warning:
        return (color: const Color(0xFFFFB300), icon: Icons.warning_rounded);
      case AppMessageType.info:
        return (color: AppColors.primaryOrange, icon: Icons.info_rounded);
      case AppMessageType.reward:
        return (color: AppColors.primaryOrange, icon: Icons.star_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(widget.entry.type);
    final topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + 8,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: style.color.withOpacity(0.55), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: style.color.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                      const BoxShadow(
                        color: Colors.black87,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: style.color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(style.icon, color: style.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.entry.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.entry.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.entry.subtitle!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.entry.actionLabel != null &&
                          widget.entry.onAction != null) ...[
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () {
                            final action = widget.entry.onAction!;
                            AppMessenger._advance();
                            action();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: style.color,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.entry.actionLabel!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}