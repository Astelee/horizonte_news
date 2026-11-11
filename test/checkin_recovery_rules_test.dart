import 'package:flutter_test/flutter_test.dart';
import 'package:horizonte_news/config/checkin_rewards_config.dart';
import 'package:horizonte_news/services/checkin_service.dart';

void main() {
  group('Recuperação de check-in: só dias perdidos do MÊS ATUAL', () {
    test('dia passado do mesmo mês é recuperável', () {
      expect(
        CheckinService.isRecoverableDay(DateTime(2026, 11, 3), DateTime(2026, 11, 7)),
        isTrue,
      );
      expect(
        CheckinService.isRecoverableDay(DateTime(2026, 11, 1), DateTime(2026, 11, 7)),
        isTrue,
      );
    });

    test('hoje e datas futuras NÃO são recuperáveis', () {
      final today = DateTime(2026, 11, 7);
      expect(CheckinService.isRecoverableDay(today, today), isFalse);
      expect(CheckinService.isRecoverableDay(DateTime(2026, 11, 8), today), isFalse);
      expect(CheckinService.isRecoverableDay(DateTime(2026, 12, 1), today), isFalse);
      expect(CheckinService.isRecoverableDay(DateTime(2027, 11, 3), today), isFalse);
    });

    test('mês anterior (mesmo ano ou ano anterior) NÃO é recuperável', () {
      final today = DateTime(2026, 11, 7);
      expect(CheckinService.isRecoverableDay(DateTime(2026, 10, 31), today), isFalse);
      expect(CheckinService.isRecoverableDay(DateTime(2025, 11, 3), today), isFalse);
    });

    test('horas na data não mudam o resultado (compara só o dia)', () {
      expect(
        CheckinService.isRecoverableDay(
            DateTime(2026, 11, 6, 23, 59), DateTime(2026, 11, 7, 0, 1)),
        isTrue,
      );
      expect(
        CheckinService.isRecoverableDay(
            DateTime(2026, 11, 7, 0, 0), DateTime(2026, 11, 7, 23, 59)),
        isFalse,
      );
    });

    test('dia 1º do mês: nenhum dia do mês anterior pode ser recuperado', () {
      final today = DateTime(2026, 3, 1);
      for (var d = 1; d <= 28; d++) {
        expect(CheckinService.isRecoverableDay(DateTime(2026, 2, d), today), isFalse);
      }
    });
  });

  group('Meses de 28, 29, 30 e 31 dias', () {
    int recoverableCount(int year, int month, int todayDay) {
      final today = DateTime(year, month, todayDay);
      var n = 0;
      for (var d = 1; d <= CheckinRewardsConfig.daysInMonth(today); d++) {
        if (CheckinService.isRecoverableDay(DateTime(year, month, d), today)) n++;
      }
      return n;
    }

    test('quantidade de dias de cada mês', () {
      expect(CheckinRewardsConfig.daysInMonth(DateTime(2026, 2, 10)), 28); // não bissexto
      expect(CheckinRewardsConfig.daysInMonth(DateTime(2028, 2, 10)), 29); // bissexto
      expect(CheckinRewardsConfig.daysInMonth(DateTime(2100, 2, 10)), 28); // século não bissexto
      expect(CheckinRewardsConfig.daysInMonth(DateTime(2000, 2, 10)), 29); // século bissexto
      expect(CheckinRewardsConfig.daysInMonth(DateTime(2026, 4, 10)), 30);
      expect(CheckinRewardsConfig.daysInMonth(DateTime(2026, 1, 10)), 31);
    });

    test('no último dia do mês, todos os dias anteriores são recuperáveis', () {
      expect(recoverableCount(2026, 2, 28), 27);
      expect(recoverableCount(2028, 2, 29), 28);
      expect(recoverableCount(2026, 4, 30), 29);
      expect(recoverableCount(2026, 1, 31), 30);
    });

    test('29/02 só existe em ano bissexto (DateTime normaliza para 01/03)', () {
      final today = DateTime(2026, 3, 5);
      // Em 2026 "29/02" vira 01/03 — mês atual e passado, mas é o dia 1º de março.
      expect(DateTime(2026, 2, 29), DateTime(2026, 3, 1));
      expect(CheckinService.isRecoverableDay(DateTime(2026, 2, 29), today), isTrue);
      // Em 2028 o 29/02 é fevereiro de verdade: não recuperável em março.
      expect(CheckinService.isRecoverableDay(DateTime(2028, 2, 29), DateTime(2028, 3, 5)), isFalse);
    });
  });
}