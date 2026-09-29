import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/app_colors.dart';
import '../services/xp_event_service.dart';

// ═══════════════════════════════════════════════════════════════════
// AVISO "XP EM DOBRO ATIVO!" (Home, logo abaixo da barra de categorias)
// ═══════════════════════════════════════════════════════════════════
// Usa o listener único do XpEventService (o mesmo do XpService), então
// não gera leituras novas no Firestore. Aparece e some na hora em que
// o admin liga/desliga o evento e também sozinho nos horários de
// início e fim (timer interno). Sem evento valendo, não ocupa espaço.
//
// O texto cita só leitura, comentário, compartilhamento e tempo
// online: check-in, curtidas recebidas e recompensas de missão não
// entram no evento.
// ═══════════════════════════════════════════════════════════════════

class XpEventBanner extends StatefulWidget {
  const XpEventBanner({Key? key}) : super(key: key);

  @override
  State<XpEventBanner> createState() => _XpEventBannerState();
}

class _XpEventBannerState extends State<XpEventBanner> {
  StreamSubscription<XpEventConfig>? _sub;
  Timer? _boundaryTimer;
  XpEventConfig _config = XpEventService().current;

  @override
  void initState() {
    super.initState();
    _scheduleBoundary();
    _sub = XpEventService().watch().listen((config) {
      if (!mounted) return;
      setState(() => _config = config);
      _scheduleBoundary();
    });
  }

  // Reavalia o aviso exatamente no próximo início/fim do evento.
  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
    final next = _config.nextChangeAfter(DateTime.now());
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
    _sub?.cancel();
    _boundaryTimer?.cancel();
    super.dispose();
  }

  static const List<String> _weekdays = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  // "até domingo à meia-noite", "até hoje às 15:30", etc.
  static String _untilText(DateTime? end, DateTime now) {
    if (end == null) return 'por tempo limitado';
    if (end.hour == 0 && end.minute == 0) {
      final lastDay = end.subtract(const Duration(minutes: 1));
      return 'até ${_weekdays[lastDay.weekday - 1]} à meia-noite';
    }
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final diffDays = endDay.difference(today).inDays;
    final hour = '${_two(end.hour)}:${_two(end.minute)}';
    if (diffDays == 0) return 'até hoje às $hour';
    if (diffDays == 1) return 'até amanhã às $hour';
    return 'até ${_weekdays[end.weekday - 1]} às $hour';
  }

  static String _title(int multiplier) {
    if (multiplier == 2) return 'XP EM DOBRO ATIVO!';
    if (multiplier == 3) return 'XP EM TRIPLO ATIVO!';
    return 'XP ${multiplier}x ATIVO!';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!_config.isActiveAt(now)) return const SizedBox.shrink();

    final multiplier = _config.multiplier;
    final until = _untilText(_config.endsAt, now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              AppColors.primaryOrange.withOpacity(0.22),
              AppColors.primaryOrange.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.18),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryOrange.withOpacity(0.2),
              ),
              alignment: Alignment.center,
              child: const FaIcon(
                FontAwesomeIcons.bolt,
                color: AppColors.primaryOrange,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title(multiplier),
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Leia, comente, compartilhe e fique online para ganhar '
                    '${multiplier}x XP — $until',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}