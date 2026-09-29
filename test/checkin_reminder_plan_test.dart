import 'package:flutter_test/flutter_test.dart';
import 'package:horizonte_news/services/checkin_reminder_plan.dart';

void main() {
  // Quarta, 23/09/2026, 10h da manhã.
  final morning = DateTime(2026, 9, 23, 10, 0);

  group('CheckinReminderPlanner.planFor', () {
    test('já fez check-in hoje: avisa amanhã às 20h com a sequência atual',
        () {
      final p = CheckinReminderPlanner.planFor(
        now: morning,
        streak: 23,
        lastCheckinDate: '2026-09-23',
      );
      expect(p, isNotNull);
      expect(p!.fireAt, DateTime(2026, 9, 24, 20, 0));
      expect(p.streak, 23);
    });

    test('sequência viva e hoje sem check-in: avisa hoje às 20h', () {
      final p = CheckinReminderPlanner.planFor(
        now: morning,
        streak: 22,
        lastCheckinDate: '2026-09-22',
      );
      expect(p, isNotNull);
      expect(p!.fireAt, DateTime(2026, 9, 23, 20, 0));
      expect(p.streak, 22);
    });

    test('depois das 20h de hoje sem check-in: não agenda nada', () {
      final p = CheckinReminderPlanner.planFor(
        now: DateTime(2026, 9, 23, 21, 0),
        streak: 22,
        lastCheckinDate: '2026-09-22',
      );
      expect(p, isNull);
    });

    test('exatamente às 20h: não agenda (horário já chegou)', () {
      final p = CheckinReminderPlanner.planFor(
        now: DateTime(2026, 9, 23, 20, 0),
        streak: 22,
        lastCheckinDate: '2026-09-22',
      );
      expect(p, isNull);
    });

    test('sequência já quebrada (último dia foi anteontem): não avisa', () {
      final p = CheckinReminderPlanner.planFor(
        now: morning,
        streak: 21,
        lastCheckinDate: '2026-09-21',
      );
      expect(p, isNull);
    });

    test('sem sequência ativa: não avisa', () {
      expect(
        CheckinReminderPlanner.planFor(
          now: morning,
          streak: 0,
          lastCheckinDate: '2026-09-22',
        ),
        isNull,
      );
    });

    test('sem último check-in: não avisa', () {
      expect(
        CheckinReminderPlanner.planFor(
          now: morning,
          streak: 5,
          lastCheckinDate: null,
        ),
        isNull,
      );
    });

    test('data inválida ou no futuro: não avisa', () {
      expect(
        CheckinReminderPlanner.planFor(
          now: morning,
          streak: 5,
          lastCheckinDate: 'lixo',
        ),
        isNull,
      );
      expect(
        CheckinReminderPlanner.planFor(
          now: morning,
          streak: 5,
          lastCheckinDate: '2026-09-25',
        ),
        isNull,
      );
    });

    test('último dia do mês, check-in feito: amanhã é outro mês, não avisa',
        () {
      final p = CheckinReminderPlanner.planFor(
        now: DateTime(2026, 9, 30, 10, 0),
        streak: 30,
        lastCheckinDate: '2026-09-30',
      );
      expect(p, isNull);
    });

    test('dia 1, último check-in foi no mês anterior: sequência já zerou',
        () {
      final p = CheckinReminderPlanner.planFor(
        now: DateTime(2026, 10, 1, 10, 0),
        streak: 30,
        lastCheckinDate: '2026-09-30',
      );
      expect(p, isNull);
    });

    test('dia 30, check-in feito: ainda protege o dia 31 quando existe', () {
      final p = CheckinReminderPlanner.planFor(
        now: DateTime(2026, 10, 30, 10, 0),
        streak: 30,
        lastCheckinDate: '2026-10-30',
      );
      expect(p, isNotNull);
      expect(p!.fireAt, DateTime(2026, 10, 31, 20, 0));
    });
  });

  group('CheckinReminderPlanner.bodyFor', () {
    test('texto pedido', () {
      expect(
        CheckinReminderPlanner.bodyFor(22),
        '🔥 Sua sequência de 22 dias acaba hoje! '
        'Faça seu check-in antes do fim do dia.',
      );
    });

    test('singular para 1 dia', () {
      expect(
        CheckinReminderPlanner.bodyFor(1),
        '🔥 Sua sequência de 1 dia acaba hoje! '
        'Faça seu check-in antes do fim do dia.',
      );
    });
  });
}