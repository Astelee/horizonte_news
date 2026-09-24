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

  group('CheckinService.computeStreaks — reconstrução do histórico', () {
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
        ..._range(DateTime(2026, 7, 1), DateTime(2026, 8, 9)), // 40 dias
        ..._range(DateTime(2026, 9, 20), DateTime(2026, 9, 23)), // 4 dias
      };
      final r = CheckinService.computeStreaks(h, today: today);

      expect(r.current, 4);
      expect(r.longest, 40);
    });

    test('atravessa virada de ano e ano bissexto (29/fev)', () {
      final h = _range(DateTime(2027, 12, 25), DateTime(2028, 3, 2));
      final r =
          CheckinService.computeStreaks(h, today: DateTime(2028, 3, 2));

      expect(r.current, h.length);
      expect(r.longest, h.length);
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
      expect(m, [7, 14, 30, 60, 100, 150, 200, 365]);
    });

    test('bônus de XP bate com o que a regra do Firestore aceita', () {
      // Valores aceitos em isValidCheckinXp (firestore.rules).
      const aceitos = {10, 40, 70, 160, 310, 510, 260, 410, 1010};
      for (final r in CheckinRewardsConfig.all) {
        expect(aceitos.contains(CheckinService.baseXp + r.bonusXp), isTrue,
            reason:
                'marco ${r.requiredStreak} gravaria ${CheckinService.baseXp + r.bonusXp} XP, rejeitado pelas regras');
      }
    });

    test('desbloqueio depende do RECORDE, não da sequência atual', () {
      final faisca = CheckinRewardsConfig.forStreak(7)!;
      expect(CheckinRewardsConfig.isUnlocked(faisca, 6), isFalse);
      expect(CheckinRewardsConfig.isUnlocked(faisca, 7), isTrue);
      expect(CheckinRewardsConfig.isUnlocked(faisca, 40), isTrue);
    });

    test('nextLocked devolve a próxima recompensa e null ao completar tudo',
        () {
      expect(CheckinRewardsConfig.nextLocked(0)!.requiredStreak, 7);
      expect(CheckinRewardsConfig.nextLocked(7)!.requiredStreak, 14);
      expect(CheckinRewardsConfig.nextLocked(364)!.requiredStreak, 365);
      expect(CheckinRewardsConfig.nextLocked(365), isNull);
    });

    test('progressToNext fica sempre entre 0 e 1', () {
      for (final longest in [0, 3, 7, 20, 99, 100, 364, 365, 999]) {
        for (final cur in [0, 1, 5, 30, 200, 999]) {
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
      expect(CheckinService.bonusForStreak(7), 30);
      expect(CheckinService.bonusForStreak(365), 1000);
      expect(CheckinService.bonusForStreak(8), 0);
      expect(CheckinService.bonusForStreak(0), 0);
    });

    test('rótulo de bônus é nulo fora dos marcos', () {
      expect(CheckinService.bonusLabelForStreak(7), isNotNull);
      expect(CheckinService.bonusLabelForStreak(8), isNull);
    });
  });
}