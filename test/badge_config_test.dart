import 'package:flutter_test/flutter_test.dart';
import 'package:horizonte_news/config/badge_config.dart';

void main() {
  group('BadgeConfig - título por nível', () {
    test('nível 1 é Visitante', () {
      expect(BadgeConfig.levelTitle(1), 'Visitante');
    });

    test('nível 0 ou negativo não quebra (cai no menor título)', () {
      expect(BadgeConfig.levelTitle(0), 'Visitante');
      expect(BadgeConfig.levelTitle(-5), 'Visitante');
    });

    test('nível muito alto (100+) sempre retorna um título válido', () {
      expect(BadgeConfig.levelTitle(100), 'Horizonte Elite');
      expect(BadgeConfig.levelTitle(9999), 'Horizonte Elite');
    });

    test('todo nível de 1 a 100 retorna um título não vazio', () {
      for (var nivel = 1; nivel <= 100; nivel++) {
        expect(BadgeConfig.levelTitle(nivel), isNotEmpty);
      }
    });
  });

  group('BadgeConfig - ícone e cor por nível', () {
    test('todo nível de 1 a 100 retorna um ícone e uma cor', () {
      for (var nivel = 1; nivel <= 100; nivel++) {
        expect(BadgeConfig.levelIcon(nivel), isNotNull);
        expect(BadgeConfig.levelColor(nivel), isNotNull);
      }
    });
  });
}
