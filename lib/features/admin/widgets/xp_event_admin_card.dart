import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../services/xp_event_service.dart';
import '../../../widgets/app_messenger.dart';
import '../services/admin_config_service.dart';
import 'admin_shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════════
// CARD "EVENTO DE XP EM DOBRO" (painel admin → aba Configurações)
// ═══════════════════════════════════════════════════════════════════
// Fica logo abaixo de "Comentários no app". Recebe a configuração já
// lida pelo stream da aba (não abre listener novo) e mostra o estado:
// desligado, programado, valendo agora ou encerrado.
// Todo botão de ligar pede confirmação mostrando o período, e cada
// ação é gravada no log de admin (AdminConfigService).
// ═══════════════════════════════════════════════════════════════════

class XpEventAdminCard extends StatefulWidget {
  final AdminConfigService configService;
  final XpEventConfig config;

  const XpEventAdminCard({
    required this.configService,
    required this.config,
    Key? key,
  }) : super(key: key);

  @override
  State<XpEventAdminCard> createState() => _XpEventAdminCardState();
}

class _XpEventAdminCardState extends State<XpEventAdminCard> {
  int _multiplier = 2;
  bool _multiplierSynced = false;
  bool _busy = false;
  Timer? _boundaryTimer;

  @override
  void initState() {
    super.initState();
    _syncMultiplier();
    _scheduleBoundary();
  }

  @override
  void didUpdateWidget(covariant XpEventAdminCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMultiplier();
    _scheduleBoundary();
  }

  // Na primeira vez que há um evento gravado, o seletor acompanha o
  // multiplicador dele; depois disso o admin escolhe livremente.
  void _syncMultiplier() {
    if (_multiplierSynced) return;
    if (widget.config.enabled) {
      _multiplier = widget.config.multiplier;
      _multiplierSynced = true;
    }
  }

  // Atualiza o estado exibido no instante em que o evento começa/termina.
  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
    final next = widget.config.nextChangeAfter(DateTime.now());
    if (next == null) return;
    var delay = next.difference(DateTime.now());
    if (delay.isNegative) delay = Duration.zero;
    _boundaryTimer = Timer(delay + const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {});
      _scheduleBoundary();
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }

  // ── Formatação ──────────────────────────────────────────────────
  static const List<String> _weekdaysShort = [
    'seg',
    'ter',
    'qua',
    'qui',
    'sex',
    'sáb',
    'dom',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(DateTime d) =>
      '${_weekdaysShort[d.weekday - 1]} ${_two(d.day)}/${_two(d.month)} '
      'às ${_two(d.hour)}:${_two(d.minute)}';

  // ── Ações ───────────────────────────────────────────────────────
  Future<void> _turnOn({
    required String mode,
    required String modeLabel,
    required XpEventPeriod period,
  }) async {
    if (_busy) return;
    final now = DateTime.now();
    final startsNow = !period.startsAt.isAfter(now);
    final startText = startsNow ? 'agora' : _fmt(period.startsAt);
    final endText =
        period.endsAt == null ? 'sem data de fim' : _fmt(period.endsAt!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Ligar XP em ${_multiplier}x?',
        message: '$modeLabel\n\n'
            'Multiplicador: ${_multiplier}x\n'
            'Início: $startText\n'
            'Fim: $endText'
            '${period.endsAt == null ? '\n\nFica ligado até você desligar.' : ''}',
        confirmLabel: 'Ligar',
        confirmColor: AppColors.primaryOrange,
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.configService.setXpEvent(
        multiplier: _multiplier,
        startsAt: period.startsAt,
        endsAt: period.endsAt,
        mode: mode,
      );
      AppMessenger.success(startsNow
          ? 'Evento de XP ${_multiplier}x ligado!'
          : 'Evento de XP ${_multiplier}x programado!');
    } catch (_) {
      AppMessenger.error('Não foi possível salvar o evento.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Desligar evento de XP?',
        message: 'O XP volta ao normal (1x) imediatamente para todos os '
            'usuários.',
        confirmLabel: 'Desligar',
        confirmColor: const Color(0xFFEF5350),
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.configService.clearXpEvent();
      AppMessenger.success('Evento de XP desligado.');
    } catch (_) {
      AppMessenger.error('Não foi possível desligar o evento.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final config = widget.config;
    final status = config.statusAt(now);

    late final String statusLabel;
    late final String statusDetail;
    late final Color statusColor;
    switch (status) {
      case XpEventStatus.off:
        statusLabel = 'Desligado';
        statusDetail = 'O XP está normal (1x) para todos os usuários.';
        statusColor = AppColors.textSecondary;
        break;
      case XpEventStatus.scheduled:
        statusLabel = 'Programado';
        statusDetail = 'XP ${config.multiplier}x começa em '
            '${_fmt(config.startsAt!)}'
            '${config.endsAt == null ? ', sem data de fim.' : ' e termina em ${_fmt(config.endsAt!)}.'}';
        statusColor = const Color(0xFFFFB300);
        break;
      case XpEventStatus.active:
        statusLabel = 'Valendo agora';
        statusDetail = 'XP ${config.multiplier}x ativo '
            '${config.endsAt == null ? 'sem data de fim — fica ligado até você desligar.' : 'até ${_fmt(config.endsAt!)}.'}';
        statusColor = const Color(0xFF66BB6A);
        break;
      case XpEventStatus.ended:
        statusLabel = 'Já encerrado';
        statusDetail = 'O último evento (${config.multiplier}x) terminou em '
            '${_fmt(config.endsAt!)}.';
        statusColor = AppColors.textSecondary;
        break;
    }

    final canTurnOff =
        status == XpEventStatus.scheduled || status == XpEventStatus.active;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: statusColor, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Evento de XP em dobro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: statusColor.withOpacity(0.15),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusDetail,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          const Text(
            'Multiplicador',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _multiplierChip(2),
              const SizedBox(width: 8),
              _multiplierChip(3),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                icon: Icons.weekend_rounded,
                label: 'Fim de semana',
                onTap: () => _turnOn(
                  mode: 'weekend',
                  modeLabel: 'Fim de semana (sábado 00:00 até segunda '
                      '00:00, desliga sozinho).',
                  period: XpEventPeriod.weekend(DateTime.now()),
                ),
              ),
              _actionButton(
                icon: Icons.timer_rounded,
                label: 'Ligar por 24h',
                onTap: () => _turnOn(
                  mode: '24h',
                  modeLabel: 'Vale agora e desliga sozinho depois de 24 '
                      'horas.',
                  period: XpEventPeriod.next24h(DateTime.now()),
                ),
              ),
              _actionButton(
                icon: Icons.all_inclusive_rounded,
                label: 'Sem data de fim',
                onTap: () => _turnOn(
                  mode: 'open_ended',
                  modeLabel: 'Vale agora e só desliga quando você '
                      'desligar.',
                  period: XpEventPeriod.openEnded(DateTime.now()),
                ),
              ),
              if (canTurnOff)
                _actionButton(
                  icon: Icons.power_settings_new_rounded,
                  label: 'Desligar evento',
                  color: const Color(0xFFEF5350),
                  onTap: _turnOff,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Vale para leitura, comentário, compartilhamento e tempo '
            'online. Check-in, curtidas recebidas e recompensas de missão '
            'não entram no evento. O multiplicador do plano PRO/ULTRA '
            'continua valendo por cima.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 11.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _multiplierChip(int value) {
    final selected = _multiplier == value;
    return GestureDetector(
      onTap: _busy ? null : () => setState(() => _multiplier = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? AppColors.primaryOrange.withOpacity(0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primaryOrange : AppColors.borderDark,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '${value}x',
          style: TextStyle(
            color: selected ? AppColors.primaryOrange : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primaryOrange,
  }) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}