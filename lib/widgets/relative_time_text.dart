import 'dart:async';
import 'package:flutter/material.dart';

/// Exibe o tempo relativo de um [timestamp] e se atualiza automaticamente.
///
/// Regras:
///   0s          → "Agora"
///   < 60s       → "Há alguns segundos"
///   1 min       → "Há 1 minuto"
///   2–59 min    → "Há X minutos"
///   1 h         → "Há 1 hora"
///   2–23 h      → "Há X horas"
///   1 dia       → "Há 1 dia"
///   2–6 dias    → "Há X dias"
///   ≥ 7 dias    → "08/06/2026 • 22:11"
class RelativeTimeText extends StatefulWidget {
  final DateTime timestamp;
  final TextStyle? style;

  const RelativeTimeText({
    Key? key,
    required this.timestamp,
    this.style,
  }) : super(key: key);

  @override
  State<RelativeTimeText> createState() => _RelativeTimeTextState();
}

class _RelativeTimeTextState extends State<RelativeTimeText> {
  late Timer _timer;
  late String _label;

  @override
  void initState() {
    super.initState();
    _label = _format(widget.timestamp);
    _scheduleNext();
  }

  @override
  void didUpdateWidget(RelativeTimeText old) {
    super.didUpdateWidget(old);
    if (old.timestamp != widget.timestamp) {
      _timer.cancel();
      _label = _format(widget.timestamp);
      _scheduleNext();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Intervalo de atualização baseado na antiguidade da notícia
  Duration _interval(Duration diff) {
    if (diff.inMinutes < 1) return const Duration(seconds: 5);
    if (diff.inHours < 1) return const Duration(seconds: 30);
    if (diff.inDays < 1) return const Duration(minutes: 1);
    return const Duration(minutes: 10);
  }

  void _scheduleNext() {
    final diff = DateTime.now().difference(widget.timestamp).abs();
    _timer = Timer(_interval(diff), () {
      if (!mounted) return;
      setState(() => _label = _format(widget.timestamp));
      _scheduleNext(); // agenda o próximo ciclo
    });
  }

  static String _format(DateTime timestamp) {
    // Garante comparação no horário local do dispositivo
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final diff = now.difference(local);

    // Publicações no futuro (clock skew de servidor) → "Agora"
    if (diff.isNegative || diff.inSeconds < 5) return 'Agora';

    if (diff.inSeconds < 60) return 'Há alguns segundos';

    final minutes = diff.inMinutes;
    if (minutes == 1) return 'Há 1 minuto';
    if (minutes < 60) return 'Há $minutes minutos';

    final hours = diff.inHours;
    if (hours == 1) return 'Há 1 hora';
    if (hours < 24) return 'Há $hours horas';

    final days = diff.inDays;
    if (days == 1) return 'Há 1 dia';
    if (days < 7) return 'Há $days dias';

    // ≥ 7 dias → data completa
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, style: widget.style);
  }
}

/// Função estática para usar fora de widgets (ex.: cards, tiles, etc.)
/// Não se atualiza — use [RelativeTimeText] para exibição dinâmica.
String formatRelativeTime(DateTime timestamp) {
  return _RelativeTimeTextState._format(timestamp);
}