import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../services/checkin_service.dart';

// ═══════════════════════════════════════════════════════════════════
// CALENDÁRIO MENSAL DE CHECK-IN
// ═══════════════════════════════════════════════════════════════════
// Widget puramente visual — recebe o mês, os check-ins já carregados
// e callbacks. Não fala com o Firestore diretamente (isso fica na
// tela, que usa o CheckinService).
class CheckinCalendar extends StatelessWidget {
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

  static const _weekdayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // domingo = 0

    final monthLabel =
        DateFormat.yMMMM('pt_BR').format(month).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrevMonth),
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: canGoNext ? onNextMonth : null,
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
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
              crossAxisSpacing: 6,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();

              final dayNum = index - leadingBlanks + 1;
              final day = DateTime(month.year, month.month, dayNum);
              final status = service.classifyDay(
                day: day,
                monthCheckins: monthCheckins,
                firstPossibleDate: firstPossibleDate,
              );

              return _DayCell(
                day: dayNum,
                status: status,
                onTap: () => onDayTap(day, status),
              );
            },
          ),
          const SizedBox(height: 14),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: const [
        _LegendItem(color: Color(0xFF43B581), label: 'Feito'),
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
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(status);

    return GestureDetector(
      onTap: visual.tappable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: visual.bg,
          border: Border.all(color: visual.border, width: 1.4),
          boxShadow: visual.glow != null
              ? [BoxShadow(color: visual.glow!, blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: Center(
          child: visual.icon != null
              ? Icon(visual.icon, size: 14, color: visual.fg)
              : Text(
                  '$day',
                  style: TextStyle(
                    color: visual.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  _DayVisual _visualFor(CheckinDayStatus status) {
    switch (status) {
      case CheckinDayStatus.done:
        return _DayVisual(
          bg: const Color(0xFF43B581).withOpacity(0.18),
          border: const Color(0xFF43B581),
          fg: const Color(0xFF43B581),
          icon: Icons.check_rounded,
          tappable: false,
        );
      case CheckinDayStatus.recovered:
        // Mesmo visual de "Feito" (✓) — o usuário pediu para não
        // haver diferença de ícone entre check-in feito no dia e
        // check-in recuperado depois; ambos contam igual.
        return _DayVisual(
          bg: const Color(0xFF43B581).withOpacity(0.18),
          border: const Color(0xFF43B581),
          fg: const Color(0xFF43B581),
          icon: Icons.check_rounded,
          tappable: false,
        );
      case CheckinDayStatus.today:
        return _DayVisual(
          bg: AppColors.primaryOrange.withOpacity(0.22),
          border: AppColors.primaryOrange,
          fg: AppColors.primaryOrange,
          glow: AppColors.primaryOrange.withOpacity(0.35),
          tappable: true,
        );
      case CheckinDayStatus.missed:
        return _DayVisual(
          bg: const Color(0xFFE53935).withOpacity(0.14),
          border: const Color(0xFFE53935).withOpacity(0.7),
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
  final Color border;
  final Color fg;
  final IconData? icon;
  final Color? glow;
  final bool tappable;

  _DayVisual({
    required this.bg,
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
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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