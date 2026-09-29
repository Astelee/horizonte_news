// ═══════════════════════════════════════════════════════════════════
// PLANEJAMENTO DO LEMBRETE DE SEQUÊNCIA DO CHECK-IN (lógica pura)
// ═══════════════════════════════════════════════════════════════════
// Este arquivo NÃO acessa Firestore, relógio nem plugin de
// notificação: recebe o "agora" e os dados do resumo do check-in
// (checkinStreak e lastCheckinDate, os mesmos campos que o
// CheckinService já mantém) e devolve QUANDO e COM QUAL número
// avisar — ou null quando não deve avisar. Por ser puro, é testável
// com datas fixas (ver test/checkin_reminder_plan_test.dart).
//
// Regras (espelham a regra de mês civil do CheckinService):
//  • Sem sequência ativa (streak <= 0) ou sem último dia: não avisa.
//  • Último dia coberto == HOJE (já fez o check-in): o risco é o dia
//    de AMANHÃ. Só agenda se amanhã ainda for do MESMO mês — na
//    virada de mês a sequência reinicia por regra, então não há o
//    que proteger.
//  • Último dia coberto == ONTEM (mesmo mês de hoje) e hoje sem
//    check-in: o risco é HOJE.
//  • Qualquer outro caso (sequência já quebrada, data no futuro):
//    não avisa.
//  • O aviso é sempre às 20h do dia de risco; se esse horário já
//    passou, não agenda nada.

class ReminderPlan {
  /// Momento (horário local do aparelho) em que o aviso deve aparecer.
  final DateTime fireAt;

  /// Tamanho da sequência que está em risco.
  final int streak;

  const ReminderPlan({required this.fireAt, required this.streak});
}

class CheckinReminderPlanner {
  CheckinReminderPlanner._();

  /// Hora local do aviso ("por volta das 20h").
  static const int reminderHour = 20;
  static const int reminderMinute = 0;

  static DateTime? _parseKey(String key) {
    try {
      final p = key.split('-');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  static ReminderPlan? planFor({
    required DateTime now,
    required int streak,
    required String? lastCheckinDate,
  }) {
    if (streak <= 0 || lastCheckinDate == null) return null;

    final last = _parseKey(lastCheckinDate);
    if (last == null) return null;

    // Datas montadas por Y/M/D (sem Duration), como no CheckinService,
    // para o horário de verão nunca deslocar o dia.
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final DateTime riskDay;
    if (last == today) {
      // Já fez o check-in hoje: protege amanhã, se ainda for o mesmo
      // mês (senão a sequência reinicia de qualquer jeito).
      if (tomorrow.year != today.year || tomorrow.month != today.month) {
        return null;
      }
      riskDay = tomorrow;
    } else if (last == yesterday &&
        yesterday.year == today.year &&
        yesterday.month == today.month) {
      // Sequência viva e hoje ainda sem check-in: o risco é hoje.
      riskDay = today;
    } else {
      return null;
    }

    final fireAt = DateTime(
      riskDay.year,
      riskDay.month,
      riskDay.day,
      reminderHour,
      reminderMinute,
    );

    // Horário de hoje já passou: não há o que agendar.
    if (!fireAt.isAfter(now)) return null;

    return ReminderPlan(fireAt: fireAt, streak: streak);
  }

  /// Texto do aviso.
  static String bodyFor(int streak) {
    final dias = streak == 1 ? '1 dia' : '$streak dias';
    return '🔥 Sua sequência de $dias acaba hoje! '
        'Faça seu check-in antes do fim do dia.';
  }
}