import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../services/checkin_service.dart';

// ═══════════════════════════════════════════════════════════════════
// CALENDÁRIO MENSAL DE CHECK-IN — visual game/premium
// ═══════════════════════════════════════════════════════════════════
// Widget puramente visual — recebe o mês, os check-ins já carregados
// e callbacks. Não fala com o Firestore diretamente (isso fica na
// tela, que usa o CheckinService). A assinatura pública é a mesma da
// versão anterior, então a tela continua funcionando sem ajustes.
//
// Visual: vidro escuro com blur, dias feitos brilham em laranja/
// dourado, dias consecutivos são ligados por uma faixa luminosa (dá
// a sensação de "corrente" de sequência) e o dia de hoje pulsa.
class CheckinCalendar extends StatefulWidget {
  final DateTime month;
  final Map<String, CheckinDay> monthCheckins;
  final DateTime? firstPossibleDate;
  final CheckinService service;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime day, CheckinDayStatus status) onDayTap;
  final bool canGoNext;

  const CheckinCalendar({
    Key? key,
    required this.month,
    required this.monthCheckins,
    required this.firstPossibleDate,
    required this.service,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDayTap,
    required this.canGoNext,
  }) : super(key: key);

  @override
  State<CheckinCalendar> createState() => _CheckinCalendarState();
}

class _CheckinCalendarState extends State<CheckinCalendar>
    with SingleTickerProviderStateMixin {
  // Um único controller para o pulso de "hoje" — nada de um ticker
  // por célula.
  late final AnimationController _pulse;

  static const _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool _isDone(CheckinDayStatus s) =>
      s == CheckinDayStatus.done || s == CheckinDayStatus.recovered;

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // domingo = 0

    final monthLabel =
        DateFormat.yMMMM('pt_BR').format(month).toUpperCase();

    // Pré-calcula o status de cada dia uma vez (também usado para
    // saber se o vizinho da esquerda/direita foi feito e ligar a
    // faixa de sequência).
    final statuses = <int, CheckinDayStatus>{};
    for (int d = 1; d <= daysInMonth; d++) {
      statuses[d] = widget.service.classifyDay(
        day: DateTime(month.year, month.month, d),
        monthCheckins: widget.monthCheckins,
        firstPossibleDate: widget.firstPossibleDate,
      );
    }

    int doneCount = 0;
    statuses.forEach((_, s) {
      if (_isDone(s)) doneCount++;
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A0D00).withOpacity(0.72),
                const Color(0xFF050505).withOpacity(0.86),
              ],
            ),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.10),
                blurRadius: 28,
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
                  _NavArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: widget.onPrevMonth,
                  ),
                  Column(
                    children: [
                      Text(
                        monthLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$doneCount ${doneCount == 1 ? 'dia' : 'dias'} no mês',
                        style: TextStyle(
                          color: AppColors.primaryOrange.withOpacity(0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  _NavArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: widget.canGoNext ? widget.onNextMonth : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: _weekdayLabels
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.32),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 0,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) return const SizedBox.shrink();

                  final dayNum = index - leadingBlanks + 1;
                  final day = DateTime(month.year, month.month, dayNum);
                  final status = statuses[dayNum]!;

                  // Coluna 0..6 (domingo..sábado) da célula. A faixa
                  // de sequência não atravessa a quebra de semana.
                  final col = index % 7;
                  final prevDone = col > 0 &&
                      dayNum > 1 &&
                      _isDone(statuses[dayNum - 1]!);
                  final nextDone = col < 6 &&
                      dayNum < daysInMonth &&
                      _isDone(statuses[dayNum + 1]!);

                  return _DayCell(
                    day: dayNum,
                    status: status,
                    pulse: _pulse,
                    linkLeft: _isDone(status) && prevDone,
                    linkRight: _isDone(status) && nextDone,
                    onTap: () => widget.onDayTap(day, status),
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: const [
        _LegendItem(color: Color(0xFFFF9100), label: 'Feito'),
        _LegendItem(color: Color(0xFFFF6B00), label: 'Hoje'),
        _LegendItem(color: Color(0xFFE53935), label: 'Perdido'),
        _LegendItem(color: Color(0xFF3A3A3A), label: 'Futuro'),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          color: enabled ? Colors.white70 : Colors.white24,
          size: 22,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final CheckinDayStatus status;
  final Animation<double> pulse;
  final bool linkLeft;
  final bool linkRight;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.status,
    required this.pulse,
    required this.linkLeft,
    required this.linkRight,
    required this.onTap,
  });

  bool get _isDone =>
      status == CheckinDayStatus.done || status == CheckinDayStatus.recovered;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(status);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: visual.tappable ? onTap : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final d = box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight;
          final circle = d - 4;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Faixa luminosa ligando dias consecutivos (a "corrente"
              // da sequência).
              if (_isDone && (linkLeft || linkRight))
                Positioned.fill(
                  left: linkLeft ? 0 : box.maxWidth / 2,
                  right: linkRight ? 0 : box.maxWidth / 2,
                  child: Center(
                    child: Container(
                      height: circle * 0.34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B00)
                                .withOpacity(linkLeft ? 0.32 : 0.0),
                            const Color(0xFFFF9100).withOpacity(0.32),
                            const Color(0xFFFF6B00)
                                .withOpacity(linkRight ? 0.32 : 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _circle(visual, circle),
            ],
          );
        },
      ),
    );
  }

  Widget _circle(_DayVisual v, double size) {
    // "Hoje" pulsa; os demais usam o visual estático.
    if (status == CheckinDayStatus.today) {
      return AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final t = pulse.value;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: v.bg,
              border: Border.all(color: v.border, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.25 + 0.35 * t),
                  blurRadius: 8 + 10 * t,
                  spreadRadius: 0.5 + 1.5 * t,
                ),
              ],
            ),
            child: Center(child: _label(v)),
          );
        },
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Flutter proíbe color + gradient juntos (assert): usa só um.
        color: v.gradient == null ? v.bg : null,
        gradient: v.gradient,
        border: Border.all(color: v.border, width: 1.4),
        boxShadow: v.glow != null
            ? [BoxShadow(color: v.glow!, blurRadius: 10, spreadRadius: 0.5)]
            : null,
      ),
      child: Center(child: _label(v)),
    );
  }

  Widget _label(_DayVisual v) {
    if (v.icon != null) {
      return Icon(v.icon, size: 14, color: v.fg);
    }
    return Text(
      '$day',
      style: TextStyle(
        color: v.fg,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  _DayVisual _visualFor(CheckinDayStatus status) {
    switch (status) {
      case CheckinDayStatus.done:
      case CheckinDayStatus.recovered:
        // 'recovered' tem o MESMO visual de 'done' — decisão já
        // existente do produto: check-in recuperado conta igual.
        return _DayVisual(
          bg: Colors.transparent,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9100), Color(0xFFCC4400)],
          ),
          border: const Color(0xFFFFB74D),
          fg: Colors.white,
          icon: Icons.local_fire_department_rounded,
          glow: const Color(0xFFFF6B00).withOpacity(0.45),
          tappable: false,
        );
      case CheckinDayStatus.today:
        return _DayVisual(
          bg: AppColors.primaryOrange.withOpacity(0.22),
          border: AppColors.primaryOrange,
          fg: Colors.white,
          tappable: true,
        );
      case CheckinDayStatus.missed:
        return _DayVisual(
          bg: const Color(0xFFE53935).withOpacity(0.12),
          border: const Color(0xFFE53935).withOpacity(0.65),
          fg: const Color(0xFFE53935),
          icon: Icons.close_rounded,
          tappable: true,
        );
      case CheckinDayStatus.future:
        return _DayVisual(
          bg: Colors.transparent,
          border: const Color(0xFF262626),
          fg: Colors.white24,
          tappable: false,
        );
      case CheckinDayStatus.beforeStart:
        return _DayVisual(
          bg: Colors.transparent,
          border: Colors.transparent,
          fg: Colors.white12,
          tappable: false,
        );
    }
  }
}

class _DayVisual {
  final Color bg;
  final Gradient? gradient;
  final Color border;
  final Color fg;
  final IconData? icon;
  final Color? glow;
  final bool tappable;

  _DayVisual({
    required this.bg,
    this.gradient,
    required this.border,
    required this.fg,
    this.icon,
    this.glow,
    required this.tappable,
  });
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
        ),
      ],
    );
  }
}