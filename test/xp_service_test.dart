import 'package:flutter_test/flutter_test.dart';
import 'package:horizonte_news/services/xp_service.dart';

void main() {
  group('XpService - cálculo de nível a partir do XP', () {
    test('nível 1 exige 0 XP', () {
      expect(XpService.xpRequiredForLevel(1), 0);
    });

    test('XP necessário aumenta conforme o nível sobe', () {
      final xpNivel2 = XpService.xpRequiredForLevel(2);
      final xpNivel3 = XpService.xpRequiredForLevel(3);
      final xpNivel10 = XpService.xpRequiredForLevel(10);

      expect(xpNivel3, greaterThan(xpNivel2));
      expect(xpNivel10, greaterThan(xpNivel3));
    });

    test('usuário com 0 XP está no nível 1', () {
      expect(XpService.levelFromXp(0), 1);
    });

    test('usuário exatamente no limite de XP de um nível já conta como esse nível', () {
      final xpParaNivel5 = XpService.xpRequiredForLevel(5);
      expect(XpService.levelFromXp(xpParaNivel5), 5);
    });

    test('usuário 1 XP abaixo do limite ainda está no nível anterior', () {
      final xpParaNivel5 = XpService.xpRequiredForLevel(5);
      if (xpParaNivel5 > 0) {
        expect(XpService.levelFromXp(xpParaNivel5 - 1), lessThan(5));
      }
    });

    test('XP necessário para o próximo nível nunca é negativo', () {
      for (var nivel = 1; nivel <= 50; nivel++) {
        expect(XpService.xpRequiredForNextLevel(nivel), greaterThanOrEqualTo(0));
      }
    });
  });

  group('XpService - montagem dos dados de XP (buildXpData)', () {
    test('progresso começa em 0% no início de um nível', () {
      final xpDoNivel3 = XpService.xpRequiredForLevel(3);
      final dados = XpService.buildXpData(
        totalXp: xpDoNivel3,
        totalSecondsOnline: 0,
      );
      expect(dados.progressPercent, 0.0);
    });

    test('progresso nunca passa de 100%', () {
      final dados = XpService.buildXpData(
        totalXp: 999999,
        totalSecondsOnline: 0,
      );
      expect(dados.progressPercent, lessThanOrEqualTo(1.0));
    });

    test('nível calculado bate com levelFromXp quando não há override', () {
      const totalXp = 5000;
      final dados = XpService.buildXpData(
        totalXp: totalXp,
        totalSecondsOnline: 0,
      );
      expect(dados.level, XpService.levelFromXp(totalXp));
    });
  });
}
