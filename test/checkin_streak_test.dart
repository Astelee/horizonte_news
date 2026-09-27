import 'package:flutter_test/flutter_test.dart';
import 'package:horizonte_news/config/checkin_rewards_config.dart';
import 'package:horizonte_news/services/checkin_service.dart';

/// Gera um mapa dateKey -> status para um intervalo contínuo de dias.
Map<String, String> _range(DateTime start, DateTime end,
    {String status = 'done'}) {
  final out = <String, String>{};
  var d = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!d.isAfter(last)) {
    final k =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    out[k] = status;
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return out;
}

void main() {
  final today = DateTime(2026, 9, 23);

  group('CheckinService.computeStreaks — mês civil (não atravessa virada de mês)',
      () {
    test('caso real: check-ins do dia 1 ao 23 => sequência de 23', () {
      final h = _range(DateTime(2026, 9, 1), DateTime(2026, 9, 23));
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 23);
      expect(r.longest, 23);
      expect(r.firstDate, '2026-09-01');
      expect(r.lastDate, '2026-09-23');
      expect(r.totalDays, 23);
    });

    test('hoje ainda sem check-in: sequência de ontem continua válida', () {
      final h = _range(DateTime(2026, 9, 1), DateTime(2026, 9, 22));
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 22);
      expect(r.longest, 22);
    });

    test('último dia foi anteontem: sequência atual quebrada, recorde fica',
        () {
      final h = _range(DateTime(2026, 9, 1), DateTime(2026, 9, 21));
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 0);
      expect(r.longest, 21);
    });

    test('lacuna no meio quebra a sequência atual', () {
      final h = {
        ..._range(DateTime(2026, 9, 1), DateTime(2026, 9, 10)),
        ..._range(DateTime(2026, 9, 12), DateTime(2026, 9, 23)),
      };
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 12);
      expect(r.longest, 12);
    });

    test('dia RECUPERADO emenda a lacuna e conta igual a um dia feito', () {
      final h = {
        ..._range(DateTime(2026, 9, 1), DateTime(2026, 9, 10)),
        '2026-09-11': 'recovered',
        ..._range(DateTime(2026, 9, 12), DateTime(2026, 9, 23)),
      };
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 23);
      expect(r.longest, 23);
      expect(r.recoveredDays, 1);
    });

    test('recorde antigo maior que a sequência atual é preservado', () {
      final h = {
        ..._range(DateTime(2026, 7, 1), DateTime(2026, 7, 31)), // 31 dias
        ..._range(DateTime(2026, 9, 20), DateTime(2026, 9, 23)), // 4 dias
      };
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 4);
      expect(r.longest, 31);
    });

    test('31/01 → sequência 31; 01/02 → sequência reinicia em 1', () {
      final h = {
        ..._range(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
        '2026-02-01': 'done',
      };
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2026, 2, 1));

      expect(r.current, 1);
      // Recorde continua sendo o de janeiro (31), mesmo com fevereiro
      // já tendo começado.
      expect(r.longest, 31);
    });

    test('30/04 → sequência 30; 01/05 → sequência reinicia em 1', () {
      final h = {
        ..._range(DateTime(2026, 4, 1), DateTime(2026, 4, 30)),
        '2026-05-01': 'done',
      };
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2026, 5, 1));

      expect(r.current, 1);
      expect(r.longest, 30);
    });

    test('28/02 (não bissexto) → sequência 28; 01/03 → reinicia em 1', () {
      final h = {
        ..._range(DateTime(2026, 2, 1), DateTime(2026, 2, 28)),
        '2026-03-01': 'done',
      };
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2026, 3, 1));

      expect(r.current, 1);
      expect(r.longest, 28);
    });

    test('29/02 (bissexto) → sequência 29; 01/03 → reinicia em 1', () {
      final h = {
        ..._range(DateTime(2028, 2, 1), DateTime(2028, 2, 29)),
        '2028-03-01': 'done',
      };
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2028, 3, 1));

      expect(r.current, 1);
      expect(r.longest, 29);
    });

    test(
        'recorde histórico entre meses: jan=25, fev=28, mar=31 => recorde 31',
        () {
      final h = {
        ..._range(DateTime(2026, 1, 1), DateTime(2026, 1, 25)),
        ..._range(DateTime(2026, 2, 1), DateTime(2026, 2, 28)),
        ..._range(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
      };
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2026, 3, 31));

      expect(r.longest, 31);
      expect(r.current, 31);
    });

    test('mesmo com dias de calendário adjacentes, meses diferentes nunca emendam',
        () {
      // 31/01 e 01/02 são "dia seguinte" no calendário, mas NUNCA
      // devem contar como sequência contínua.
      final h = {
        '2026-01-30': 'done',
        '2026-01-31': 'done',
        '2026-02-01': 'done',
        '2026-02-02': 'done',
      };
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2026, 2, 2));

      // A sequência atual deve ser só os dias de fevereiro (2), não 4.
      expect(r.current, 2);
      // O maior trecho DENTRO de um único mês também é 2 (não 4).
      expect(r.longest, 2);
    });

    test('histórico vazio não inventa nada', () {
      final r = CheckinService.computeStreaks({}, today: today);

      expect(r.current, 0);
      expect(r.longest, 0);
      expect(r.lastDate, isNull);
      expect(r.firstDate, isNull);
      expect(r.totalDays, 0);
    });

    test('IDs que não são data são ignorados', () {
      final h = {
        'lixo': 'done',
        '2026-09-23': 'done',
      };
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.totalDays, 1);
      expect(r.current, 1);
    });

    test('a ordem de inserção do mapa não altera o resultado', () {
      final base = _range(DateTime(2026, 9, 1), DateTime(2026, 9, 23));
      final reversed = Map<String, String>.fromEntries(
          base.entries.toList().reversed);
      final r = CheckinService.computeStreaks(reversed, today: today);

      expect(r.current, 23);
      expect(r.longest, 23);
    });
  });

  group('CheckinRewardsConfig — catálogo e progressão', () {
    test('marcos estão em ordem estritamente crescente', () {
      final m = CheckinRewardsConfig.milestones;
      for (var i = 1; i < m.length; i++) {
        expect(m[i], greaterThan(m[i - 1]));
      }
      expect(m, [3, 5, 7, 10, 14, 18, 24, 31]);
    });

    test('bônus de XP bate com o que a regra do Firestore aceita', () {
      // Valores aceitos em isValidCheckinXp (firestore.rules).
      const aceitos = {10, 25, 35, 50, 70, 100, 140, 210, 360};
      for (final r in CheckinRewardsConfig.all) {
        expect(aceitos.contains(CheckinService.baseXp + r.bonusXp), isTrue,
            reason:
                'marco ${r.requiredStreak} gravaria ${CheckinService.baseXp + r.bonusXp} XP, rejeitado pelas regras');
      }
    });

    test('desbloqueio depende do RECORDE, não da sequência atual', () {
      final faisca = CheckinRewardsConfig.forStreak(3)!;
      expect(CheckinRewardsConfig.isUnlocked(faisca, 2), isFalse);
      expect(CheckinRewardsConfig.isUnlocked(faisca, 3), isTrue);
      expect(CheckinRewardsConfig.isUnlocked(faisca, 31), isTrue);
    });

    test('nextLocked devolve a próxima recompensa e null ao completar tudo',
        () {
      expect(CheckinRewardsConfig.nextLocked(0)!.requiredStreak, 3);
      expect(CheckinRewardsConfig.nextLocked(3)!.requiredStreak, 5);
      expect(CheckinRewardsConfig.nextLocked(30)!.requiredStreak, 31);
      expect(CheckinRewardsConfig.nextLocked(31), isNull);
    });

    test('progressToNext fica sempre entre 0 e 1', () {
      for (final longest in [0, 2, 3, 7, 20, 24, 30, 31]) {
        for (final cur in [0, 1, 5, 15, 20, 31]) {
          final p = CheckinRewardsConfig.progressToNext(cur, longest);
          expect(p, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('storageKey é único e faz round-trip', () {
      final keys = <String>{};
      for (final id in CheckinRewardId.values) {
        expect(keys.add(id.storageKey), isTrue,
            reason: 'storageKey duplicada: ${id.storageKey}');
        expect(CheckinRewardIdX.fromStorageKey(id.storageKey), id);
      }
      expect(CheckinRewardIdX.fromStorageKey('inexistente'), isNull);
      expect(CheckinRewardIdX.fromStorageKey(null), isNull);
    });

    test('recompensas do Check-in não colidem com chaves dos avatares VIP',
        () {
      for (final id in CheckinRewardId.values) {
        expect(id.storageKey.startsWith('checkin_'), isTrue);
        expect(id.storageKey.startsWith('premium_'), isFalse);
      }
    });
  });

  group('CheckinService — marcos e rótulos', () {
    test('bônus só existe nos marcos do catálogo', () {
      expect(CheckinService.bonusForStreak(3), 15);
      expect(CheckinService.bonusForStreak(31), 350);
      expect(CheckinService.bonusForStreak(8), 0);
      expect(CheckinService.bonusForStreak(0), 0);
    });

    test('rótulo de bônus é nulo fora dos marcos', () {
      expect(CheckinService.bonusLabelForStreak(3), isNotNull);
      expect(CheckinService.bonusLabelForStreak(8), isNull);
    });
  });
}