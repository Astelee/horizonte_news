import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horizonte_news/services/backend_client.dart';
import 'package:horizonte_news/services/purchase_service.dart';
import 'package:horizonte_news/services/xp_service.dart';

/// Testes que "amarram" o app ao que está nas regras do Firestore e no
/// backend (Cloudflare Worker). Se alguém mudar um lado e esquecer o
/// outro, o `flutter test` acusa.
///
/// Enquanto o `firestore.rules` novo e a pasta `cloudflare/` ainda não
/// estiverem no repositório, os testes de "contrato" são PULADOS (com
/// aviso) em vez de reprovar o build — assim dá para aplicar os arquivos
/// aos poucos. Com tudo no lugar, passam a valer.
void main() {
  final rulesFile = File('firestore.rules');
  final workerXp = File('cloudflare/horizonte-worker/src/xp.js');
  final workerBilling = File('cloudflare/horizonte-worker/src/billing.js');

  final rulesAreNew = rulesFile.existsSync() &&
      rulesFile.readAsStringSync().contains('xpLevelThresholds');
  final skipRules = rulesAreNew
      ? false
      : 'firestore.rules novo ainda não está no repositório';
  final skipWorker = (workerXp.existsSync() && workerBilling.existsSync())
      ? false
      : 'pasta cloudflare/horizonte-worker ainda não está no repositório';

  group('BackendResponse', () {
    test('ok exige HTTP 2xx E ok != false no corpo', () {
      expect(const BackendResponse(statusCode: 200, body: {'ok': true}).ok, isTrue);
      expect(const BackendResponse(statusCode: 200, body: {}).ok, isTrue);
      expect(const BackendResponse(statusCode: 200, body: {'ok': false}).ok, isFalse);
      expect(const BackendResponse(statusCode: 403, body: {'ok': false}).ok, isFalse);
      expect(const BackendResponse(statusCode: 0, body: {}).ok, isFalse);
    });

    test('falhas transitórias (rede, 5xx, 429) valem nova tentativa', () {
      expect(const BackendResponse(statusCode: 0, body: {}).isTransient, isTrue);
      expect(const BackendResponse(statusCode: 502, body: {}).isTransient, isTrue);
      expect(const BackendResponse(statusCode: 429, body: {}).isTransient, isTrue);
      expect(const BackendResponse(statusCode: 403, body: {}).isTransient, isFalse);
      expect(const BackendResponse(statusCode: 409, body: {}).isTransient, isFalse);
    });
  });

  group('Backend desligado por padrão', () {
    test('sem --dart-define=BACKEND_URL o app mantém o comportamento antigo', () {
      // O `flutter test` não define BACKEND_URL.
      expect(BackendClient.isConfigured, isFalse);
    });
  });

  group('IDs de produto (não podem mudar)', () {
    test('IDs do Play Console', () {
      expect(PremiumProductIds.pro, 'premium_pro_mensal');
      expect(PremiumProductIds.ultra, 'premium_ultra_mensal');
    });

    test('estão presentes nas regras do Firestore', () {
      final rules = rulesFile.readAsStringSync();
      for (final id in PremiumProductIds.all) {
        expect(rules, contains("'$id'"), reason: 'firestore.rules');
      }
    }, skip: skipRules);

    test('estão presentes no backend', () {
      final worker = workerBilling.readAsStringSync();
      for (final id in PremiumProductIds.all) {
        expect(worker, contains(id), reason: 'billing.js');
      }
    }, skip: skipWorker);
  });

  group('Tabela de níveis', () {
    test('XpService.xpRequiredForLevel = tabela das regras do Firestore', () {
      final rules = rulesFile.readAsStringSync();
      final match =
          RegExp(r'function xpLevelThresholds\(\)\s*\{\s*return \[([^\]]*)\]')
              .firstMatch(rules);
      expect(match, isNotNull, reason: 'xpLevelThresholds() não encontrada');
      final table = match!
          .group(1)!
          .split(',')
          .map((e) => int.parse(e.trim()))
          .toList();
      expect(table.length, 30);
      for (var level = 1; level <= 30; level++) {
        expect(table[level - 1], XpService.xpRequiredForLevel(level),
            reason: 'nível $level');
      }
    }, skip: skipRules);

    test('XpService.xpRequiredForLevel = tabela do backend (xp.js)', () {
      final worker = workerXp.readAsStringSync();
      final match = RegExp(r'LEVEL_THRESHOLDS = \[([^\]]*)\]').firstMatch(worker);
      expect(match, isNotNull);
      final table = match!
          .group(1)!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList();
      expect(table.length, 30);
      for (var level = 1; level <= 30; level++) {
        expect(table[level - 1], XpService.xpRequiredForLevel(level));
      }
    }, skip: skipWorker);

    test('XP de curtida recebida igual no app e no backend', () {
      final worker = workerXp.readAsStringSync();
      expect(worker, contains('COMMENT_LIKE_XP = ${XpService.commentLikeXp};'));
    }, skip: skipWorker);
  });
}