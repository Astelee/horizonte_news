import 'dart:async';
import 'package:flutter/material.dart';

/// Exibe o tempo relativo de um [timestamp] e se atualiza automaticamente.
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

  // Define o tempo de espera antes da próxima atualização
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
      _scheduleNext();
    });
  }

  static String _format(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final diff = now.difference(local);

    // Ajuste de erro de sincronia (clock skew)
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

    // Formato final: dd/mm/aaaa • hh:mm
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