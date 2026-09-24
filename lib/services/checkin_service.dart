import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/checkin_rewards_config.dart';

// ═══════════════════════════════════════════════════════════════════
// STATUS DE UM DIA NO CALENDÁRIO
// ═══════════════════════════════════════════════════════════════════
enum CheckinDayStatus {
  done,       // 🟢 check-in feito no dia certo
  recovered,  // 🟢 (com indicação) — recuperado via anúncio/Premium
  missed,     // 🔴 perdido, ainda recuperável
  today,      // 🟠 hoje, ainda sem check-in
  future,     // ⚪ dia futuro, bloqueado
  beforeStart,// dias antes do piso de recuperação
}

class CheckinDay {
  final DateTime date;
  final CheckinDayStatus status;
  final int xpAwarded;

  const CheckinDay({
    required this.date,
    required this.status,
    this.xpAwarded = 0,
  });
}

// ═══════════════════════════════════════════════════════════════════
// RESULTADO DE UMA AÇÃO DE CHECK-IN (para acionar animação/snackbar)
// ═══════════════════════════════════════════════════════════════════
class CheckinResult {
  final bool success;
  final int xpGained;
  final int bonusXp;
  final int streak;
  final String? bonusLabel; // ex.: "Sequência de 7 dias!"
  final String? error;

  /// Recompensa visual desbloqueada por esta ação (marco atingido
  /// pela PRIMEIRA vez), ou null.
  final CheckinRewardDef? unlockedReward;

  const CheckinResult({
    required this.success,
    this.xpGained = 0,
    this.bonusXp = 0,
    this.streak = 0,
    this.bonusLabel,
    this.error,
    this.unlockedReward,
  });
}

// ═══════════════════════════════════════════════════════════════════
// RESULTADO PURO DO CÁLCULO DE SEQUÊNCIA
// ═══════════════════════════════════════════════════════════════════
/// Saída de [CheckinService.computeStreaks]. Contém só números e
/// datas — não toca no Firestore, então é 100% testável.
class StreakComputation {
  /// Sequência atual (termina hoje, ou ontem se hoje ainda não foi
  /// feito). Zero se o último dia coberto foi antes de ontem.
  final int current;

  /// Maior sequência encontrada em TODO o histórico.
  final int longest;

  /// Último dia coberto ('yyyy-MM-dd'), ou null se não há registros.
  final String? lastDate;

  /// Primeiro dia coberto ('yyyy-MM-dd'), ou null.
  final String? firstDate;

  /// Quantos dias distintos existem no histórico.
  final int totalDays;

  /// Quantos desses dias são 'recovered'.
  final int recoveredDays;

  const StreakComputation({
    required this.current,
    required this.longest,
    required this.lastDate,
    required this.firstDate,
    required this.totalDays,
    required this.recoveredDays,
  });
}

/// Relatório de uma reconstrução, para que nada seja alterado
/// "às escuras".
class RebuildReport {
  final bool ran;
  final bool changed;
  final int daysFound;
  final int recoveredDaysFound;
  final String? firstDate;
  final String? lastDate;
  final int oldStreak;
  final int newStreak;
  final int oldLongest;
  final int newLongest;
  final String? error;

  const RebuildReport({
    required this.ran,
    required this.changed,
    this.daysFound = 0,
    this.recoveredDaysFound = 0,
    this.firstDate,
    this.lastDate,
    this.oldStreak = 0,
    this.newStreak = 0,
    this.oldLongest = 0,
    this.newLongest = 0,
    this.error,
  });

  const RebuildReport.skipped()
      : ran = false,
        changed = false,
        daysFound = 0,
        recoveredDaysFound = 0,
        firstDate = null,
        lastDate = null,
        oldStreak = 0,
        newStreak = 0,
        oldLongest = 0,
        newLongest = 0,
        error = null;
}

// ═══════════════════════════════════════════════════════════════════
// SERVIÇO DE CHECK-IN DIÁRIO
// ═══════════════════════════════════════════════════════════════════
// Estrutura no Firestore (não interfere no restante de
// users_xp/{uid}):
//
//   users_xp/{uid}
//     checkinStreak        (int)    — dias consecutivos atuais
//     longestCheckinStreak (int)    — recorde pessoal
//     lastCheckinDate      (string) — 'yyyy-MM-dd' do último dia
//                                     coberto (feito OU recuperado)
//     checkinFirstDate     (string) — 'yyyy-MM-dd' do 1º dia coberto
//     equippedCheckinRewardId (string) — recompensa equipada
//
//   users_xp/{uid}/checkins/{yyyy-MM-dd}   (subcoleção)
//     status      'done' | 'recovered'
//     xpAwarded   int
//     timestamp   serverTimestamp()
//
// Fonte da verdade: a SUBCOLEÇÃO. Os campos-resumo do doc principal
// são só cache para não reler tudo a toda hora — e podem ser
// recalculados a qualquer momento por rebuildStreakFromHistory().
class CheckinService {
  static final CheckinService _instance = CheckinService._internal();
  factory CheckinService() => _instance;
  CheckinService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── XP base por check-in e bônus de marco de sequência ────────────
  // Os mesmos valores estão espelhados na regra do Firestore
  // (isValidCheckinXp) para que o cliente nunca possa gravar um
  // valor diferente do esperado. Os bônus vêm do catálogo de
  // recompensas (CheckinRewardsConfig), fonte única de verdade.
  static const int baseXp = 10;

  static int bonusForStreak(int streak) =>
      CheckinRewardsConfig.bonusForStreak(streak);

  static String? bonusLabelForStreak(int streak) {
    final reward = CheckinRewardsConfig.forStreak(streak);
    if (reward == null) return null;
    if (streak >= 365) {
      return 'Um ano inteiro de sequência — Sol do Horizonte! ☀️';
    }
    if (streak >= 100) return 'Sequência de $streak dias — ${reward.name}! 🏆';
    return 'Sequência de $streak dias! 🔥';
  }

  // Marco especial: conquista permanente além do XP.
  static bool isSpecialMilestone(int streak) => streak == 100;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users_xp').doc(uid);
  }

  CollectionReference<Map<String, dynamic>>? get _checkinsCol {
    final doc = _userDoc;
    if (doc == null) return null;
    return doc.collection('checkins');
  }

  String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Piso a partir de onde os dias perdidos podem ser recuperados.
  // Regra atual (PRESERVADA): qualquer dia do MÊS ATUAL é
  // recuperável para todo mundo. Meses anteriores continuam fora da
  // janela de recuperação — mas os check-ins que EXISTEM neles
  // continuam contando para a sequência e para o recorde.
  DateTime _recoverableFloor(DateTime today, DateTime? firstPossibleDate) {
    return DateTime(today.year, today.month, 1);
  }

  DateTime? _parseKey(String key) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) return null;
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // CÁLCULO PURO DA SEQUÊNCIA
  // ═════════════════════════════════════════════════════════════════
  /// Calcula sequência atual, recorde, primeiro/último dia a partir
  /// de um mapa `dateKey -> status` ('done' | 'recovered').
  ///
  /// Regras (idênticas às já usadas pelo app):
  ///  • 'done' e 'recovered' contam IGUAL para a sequência.
  ///  • Dias consecutivos = dias de calendário adjacentes.
  ///  • A sequência ATUAL só é válida se o último dia coberto for
  ///    HOJE ou ONTEM; caso contrário está quebrada (current = 0).
  ///  • O recorde é o maior trecho consecutivo de TODO o histórico.
  ///
  /// Função pura e estática: não acessa Firestore nem relógio (o
  /// "hoje" é injetado), então pode ser testada com dados fixos.
  static StreakComputation computeStreaks(
    Map<String, String> statusByDateKey, {
    required DateTime today,
  }) {
    DateTime? parse(String k) {
      try {
        final p = k.split('-');
        if (p.length != 3) return null;
        return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      } catch (_) {
        return null;
      }
    }

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final dates = <DateTime>[];
    int recovered = 0;
    statusByDateKey.forEach((k, status) {
      final d = parse(k);
      if (d == null) return;
      dates.add(d);
      if (status == 'recovered') recovered++;
    });

    if (dates.isEmpty) {
      return const StreakComputation(
        current: 0,
        longest: 0,
        lastDate: null,
        firstDate: null,
        totalDays: 0,
        recoveredDays: 0,
      );
    }

    dates.sort();

    // "Dia seguinte" por reconstrução Y/M/D — não usa Duration, então
    // horário de verão não quebra a comparação.
    bool isNextDay(DateTime prev, DateTime cur) =>
        cur == DateTime(prev.year, prev.month, prev.day + 1);

    int longest = 1;
    int run = 1;
    for (int i = 1; i < dates.length; i++) {
      if (isNextDay(dates[i - 1], dates[i])) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    // Sequência atual: o trecho que termina no último dia coberto,
    // mas só vale se esse dia for hoje ou ontem.
    final last = dates.last;
    final todayD = DateTime(today.year, today.month, today.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    int current = 0;
    if (last == todayD || last == yesterday) {
      current = 1;
      for (int i = dates.length - 1; i > 0; i--) {
        if (isNextDay(dates[i - 1], dates[i])) {
          current++;
        } else {
          break;
        }
      }
    }

    return StreakComputation(
      current: current,
      longest: longest,
      lastDate: fmt(last),
      firstDate: fmt(dates.first),
      totalDays: dates.length,
      recoveredDays: recovered,
    );
  }

  // ── Stream do resumo (streak, lastCheckinDate) ────────────────────
  // ÚNICO listener do doc de check-in. A tela e o drawer reaproveitam
  // este mesmo stream — não criar outro listener em users_xp/{uid}.
  Stream<Map<String, dynamic>> watchSummary() {
    final doc = _userDoc;
    if (doc == null) return const Stream.empty();
    return doc.snapshots().map((snap) => snap.data() ?? {});
  }

  // ── Carrega os check-ins de um mês (para pintar o calendário) ─────
  Future<Map<String, CheckinDay>> loadMonth(DateTime month) async {
    final col = _checkinsCol;
    if (col == null) return {};

    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    final snap = await col
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: dateKey(first))
        .where(FieldPath.documentId, isLessThanOrEqualTo: dateKey(last))
        .get();

    final result = <String, CheckinDay>{};
    for (final d in snap.docs) {
      final data = d.data();
      final date = _parseKey(d.id);
      if (date == null) continue;
      final statusStr = data['status'] as String? ?? 'done';
      result[d.id] = CheckinDay(
        date: date,
        status: statusStr == 'recovered'
            ? CheckinDayStatus.recovered
            : CheckinDayStatus.done,
        xpAwarded: (data['xpAwarded'] as num?)?.toInt() ?? 0,
      );
    }
    return result;
  }

  // ── Classifica um dia do calendário, cruzando os check-ins já
  // carregados com hoje/streak/data de início ────────────────────────
  CheckinDayStatus classifyDay({
    required DateTime day,
    required Map<String, CheckinDay> monthCheckins,
    required DateTime? firstPossibleDate,
  }) {
    final today = _todayDate();
    final key = dateKey(day);
    final recoverableFrom = _recoverableFloor(today, firstPossibleDate);

    if (day.isAfter(today)) return CheckinDayStatus.future;

    // Se existe um registro REAL para o dia, ele sempre é mostrado —
    // inclusive em meses anteriores (histórico verdadeiro). Só dias
    // SEM registro antes do piso ficam apagados (não recuperáveis).
    final existing = monthCheckins[key];
    if (existing != null) return existing.status;

    if (day.isBefore(recoverableFrom)) {
      return CheckinDayStatus.beforeStart;
    }

    if (day.isAtSameMomentAs(today)) return CheckinDayStatus.today;
    return CheckinDayStatus.missed;
  }

  // ═════════════════════════════════════════════════════════════════
  // RECONSTRUÇÃO HISTÓRICA
  // ═════════════════════════════════════════════════════════════════
  /// Relê TODOS os documentos reais de `checkins/` (uma única query)
  /// e recalcula sequência atual, recorde e último dia.
  ///
  /// Garantias:
  ///  • NUNCA cria check-ins: só usa documentos que já existem.
  ///  • NUNCA reduz o recorde já salvo.
  ///  • Só escreve no Firestore se algum valor realmente mudou.
  ///  • Não altera XP, nível nem conquistas — é só o resumo.
  ///  • Se a subcoleção estiver vazia, não sobrescreve nada.
  ///
  /// Custo: 1 leitura de coleção + 1 leitura do doc pai + no máximo
  /// 1 escrita. Por isso a tela só chama isto UMA vez por sessão
  /// (ver [ensureHistoryRebuilt]).
  Future<RebuildReport> rebuildStreakFromHistory() async {
    final doc = _userDoc;
    final col = _checkinsCol;
    if (doc == null || col == null) {
      return const RebuildReport(
          ran: false, changed: false, error: 'not_logged_in');
    }

    try {
      final userSnap = await doc.get();
      final user = userSnap.data() ?? {};

      final oldStreak = (user['checkinStreak'] as num?)?.toInt() ?? 0;
      final oldLongest = (user['longestCheckinStreak'] as num?)?.toInt() ?? 0;
      final oldLast = user['lastCheckinDate'] as String?;
      final oldFirst = user['checkinFirstDate'] as String?;

      // O ID do documento É a data — 1 query traz o histórico todo.
      final snap = await col.get();

      final statuses = <String, String>{};
      for (final d in snap.docs) {
        if (_parseKey(d.id) == null) continue; // ignora IDs que não são data
        statuses[d.id] = (d.data()['status'] as String?) ?? 'done';
      }

      // Sem nenhum documento real: nada a reconstruir. Não mexemos
      // no resumo existente (poderia apagar um dado legítimo).
      if (statuses.isEmpty) {
        return RebuildReport(
          ran: true,
          changed: false,
          daysFound: 0,
          oldStreak: oldStreak,
          newStreak: oldStreak,
          oldLongest: oldLongest,
          newLongest: oldLongest,
        );
      }

      final calc = computeStreaks(statuses, today: _todayDate());

      // Recorde nunca diminui.
      final newLongest =
          calc.longest > oldLongest ? calc.longest : oldLongest;
      final newStreak = calc.current;
      final newLast = calc.lastDate;
      final newFirst = calc.firstDate;

      final update = <String, dynamic>{};
      if (newStreak != oldStreak) update['checkinStreak'] = newStreak;
      if (newLongest != oldLongest) {
        update['longestCheckinStreak'] = newLongest;
      }
      if (newLast != null && newLast != oldLast) {
        update['lastCheckinDate'] = newLast;
      }
      // O 1º dia só recua (nunca avança): é o mais antigo conhecido.
      if (newFirst != null &&
          (oldFirst == null || newFirst.compareTo(oldFirst) < 0)) {
        update['checkinFirstDate'] = newFirst;
      }

      final changed = update.isNotEmpty;
      if (changed) {
        await doc.update(update);
      }

      return RebuildReport(
        ran: true,
        changed: changed,
        daysFound: calc.totalDays,
        recoveredDaysFound: calc.recoveredDays,
        firstDate: calc.firstDate,
        lastDate: calc.lastDate,
        oldStreak: oldStreak,
        newStreak: newStreak,
        oldLongest: oldLongest,
        newLongest: newLongest,
      );
    } catch (e) {
      return RebuildReport(ran: false, changed: false, error: e.toString());
    }
  }

  bool _rebuiltThisSession = false;

  /// Garante que a reconstrução rode no máximo UMA vez por sessão do
  /// app (evita reler a subcoleção a cada abertura da tela).
  Future<RebuildReport> ensureHistoryRebuilt() async {
    if (_rebuiltThisSession) return const RebuildReport.skipped();
    _rebuiltThisSession = true;
    final report = await rebuildStreakFromHistory();
    // Se falhou (rede, permissão), libera nova tentativa depois.
    if (!report.ran) _rebuiltThisSession = false;
    return report;
  }

  // ═════════════════════════════════════════════════════════════════
  // CHECK-IN DE HOJE
  // ═════════════════════════════════════════════════════════════════
  // A trava real contra check-in duplicado / manipulação de relógio
  // fica na regra do Firestore. Aqui fazemos a checagem otimista.
  //
  // Diferença importante para a versão antiga: quem já tinha
  // histórico real não "reinicia" — se o resumo diz 1 mas o dia de
  // ontem existe de verdade na subcoleção, recalculamos a partir
  // dos documentos antes de decidir a sequência.
  Future<CheckinResult> checkInToday() async {
    final doc = _userDoc;
    final col = _checkinsCol;
    if (doc == null || col == null) {
      return const CheckinResult(success: false, error: 'not_logged_in');
    }

    final today = _todayDate();
    final todayKey = dateKey(today);

    try {
      final snap = await doc.get();
      final data = snap.data() ?? {};
      final lastCheckinDate = data['lastCheckinDate'] as String?;

      if (lastCheckinDate == todayKey) {
        return const CheckinResult(success: false, error: 'already_done');
      }

      final currentStreak = (data['checkinStreak'] as num?)?.toInt() ?? 0;
      final longestStreak =
          (data['longestCheckinStreak'] as num?)?.toInt() ?? 0;

      // Sequência continua se o último dia coberto foi ONTEM.
      int newStreak = 1;
      if (lastCheckinDate != null) {
        final lastDate = _parseKey(lastCheckinDate);
        if (lastDate != null) {
          final expectedNext =
              DateTime(lastDate.year, lastDate.month, lastDate.day + 1);
          if (expectedNext == today) newStreak = currentStreak + 1;
        }
      }

      // Segurança extra: resumo desatualizado (caso típico de quem já
      // tinha histórico antes do sistema atual). Uma leitura do doc
      // de ontem evita quebrar a sequência à toa.
      if (newStreak == 1) {
        final yKey =
            dateKey(DateTime(today.year, today.month, today.day - 1));
        final ySnap = await col.doc(yKey).get();
        if (ySnap.exists) {
          final rebuilt = await rebuildStreakFromHistory();
          newStreak = (rebuilt.ran && rebuilt.newStreak > 0)
              ? rebuilt.newStreak + 1
              : 2;
        }
      }

      final bonus = bonusForStreak(newStreak);
      final totalXp = baseXp + bonus;
      final effectiveLongest =
          longestStreak > newStreak ? longestStreak : newStreak;

      final checkinDoc = col.doc(todayKey);

      await _db.runTransaction((tx) async {
        final freshSnap = await tx.get(doc);
        final freshData = freshSnap.data() ?? {};
        final freshLast = freshData['lastCheckinDate'] as String?;
        if (freshLast == todayKey) {
          throw StateError('already_done');
        }
        final freshLongest =
            (freshData['longestCheckinStreak'] as num?)?.toInt() ?? 0;
        final finalLongest =
            freshLongest > effectiveLongest ? freshLongest : effectiveLongest;

        tx.set(checkinDoc, {
          'status': 'done',
          'xpAwarded': totalXp,
          'timestamp': FieldValue.serverTimestamp(),
        });

        tx.update(doc, {
          'totalXp': FieldValue.increment(totalXp),
          'lastActivity': FieldValue.serverTimestamp(),
          'lastCheckinDate': todayKey,
          'checkinStreak': newStreak,
          'longestCheckinStreak': finalLongest,
          if (freshData['checkinFirstDate'] == null)
            'checkinFirstDate': todayKey,
          if (isSpecialMilestone(newStreak))
            'achievements': FieldValue.arrayUnion(['checkin_100']),
        });
      });

      // A recompensa é "nova" se este marco não estava desbloqueado
      // pelo recorde anterior.
      final reward = CheckinRewardsConfig.forStreak(newStreak);
      final isNewUnlock =
          reward != null && longestStreak < reward.requiredStreak;

      return CheckinResult(
        success: true,
        xpGained: baseXp,
        bonusXp: bonus,
        streak: newStreak,
        bonusLabel: bonusLabelForStreak(newStreak),
        unlockedReward: isNewUnlock ? reward : null,
      );
    } catch (e) {
      if (e is StateError && e.message == 'already_done') {
        return const CheckinResult(success: false, error: 'already_done');
      }
      return const CheckinResult(success: false, error: 'unknown');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // RECUPERAÇÃO DE DIA PERDIDO
  // ═════════════════════════════════════════════════════════════════
  // Chamar SÓ depois do anúncio concluído (onUserEarnedReward) ou
  // direto para Premium/Ultra (a vantagem Premium É pular o anúncio).
  //
  // Melhoria em relação à versão anterior: em vez de N leituras
  // sequenciais (1 get() por dia voltando), fazemos UMA query com o
  // histórico e usamos computeStreaks — a mesma função da
  // reconstrução. Assim a regra de sequência é única e o custo cai
  // de O(dias) leituras para 1 query.
  Future<CheckinResult> recoverDay(DateTime day) async {
    final doc = _userDoc;
    final col = _checkinsCol;
    if (doc == null || col == null) {
      return const CheckinResult(success: false, error: 'not_logged_in');
    }

    final today = _todayDate();
    final targetDate = DateTime(day.year, day.month, day.day);
    if (!targetDate.isBefore(today)) {
      return const CheckinResult(success: false, error: 'invalid_day');
    }

    final key = dateKey(targetDate);
    final checkinDoc = col.doc(key);

    try {
      final existing = await checkinDoc.get();
      if (existing.exists) {
        return const CheckinResult(success: false, error: 'already_done');
      }

      // Grava o dia recuperado de forma atômica (falha se surgiu uma
      // corrida entre a checagem acima e a escrita).
      await _db.runTransaction((tx) async {
        final freshExisting = await tx.get(checkinDoc);
        if (freshExisting.exists) {
          throw StateError('already_done');
        }
        tx.set(checkinDoc, {
          'status': 'recovered',
          'xpAwarded': baseXp,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Recalcula o resumo a partir do histórico REAL (já contendo o
      // dia que acabou de ser gravado). Uma query só.
      final userSnap = await doc.get();
      final user = userSnap.data() ?? {};
      final longestBefore =
          (user['longestCheckinStreak'] as num?)?.toInt() ?? 0;
      final currentLast = user['lastCheckinDate'] as String?;

      final snap = await col.get();
      final statuses = <String, String>{};
      for (final d in snap.docs) {
        if (_parseKey(d.id) == null) continue;
        statuses[d.id] = (d.data()['status'] as String?) ?? 'done';
      }
      final calc = computeStreaks(statuses, today: today);

      final newLongest =
          calc.longest > longestBefore ? calc.longest : longestBefore;

      // lastCheckinDate só avança (recuperar um dia antigo não a
      // "volta" para trás).
      final newLast =
          (currentLast == null || key.compareTo(currentLast) > 0)
              ? key
              : currentLast;

      await doc.update({
        'totalXp': FieldValue.increment(baseXp),
        'lastActivity': FieldValue.serverTimestamp(),
        'checkinStreak': calc.current,
        'longestCheckinStreak': newLongest,
        'lastCheckinDate': newLast,
        if (calc.firstDate != null) 'checkinFirstDate': calc.firstDate,
      });

      // Recuperar pode empurrar o recorde por cima de um marco.
      CheckinRewardDef? newlyUnlocked;
      for (final r in CheckinRewardsConfig.all) {
        if (longestBefore < r.requiredStreak &&
            newLongest >= r.requiredStreak) {
          newlyUnlocked = r; // fica com o mais alto atingido agora
        }
      }

      return CheckinResult(
        success: true,
        xpGained: baseXp,
        streak: calc.current,
        unlockedReward: newlyUnlocked,
      );
    } catch (e) {
      if (e is StateError && e.message == 'already_done') {
        return const CheckinResult(success: false, error: 'already_done');
      }
      return const CheckinResult(success: false, error: 'unknown');
    }
  }

  // ── Quantos dias perdidos existem entre o piso de recuperação e
  // hoje (exclusive hoje) ────────────────────────────────────────────
  Future<int> countRecoverableDays({
    required DateTime? firstPossibleDate,
  }) async {
    final col = _checkinsCol;
    if (col == null) return 0;

    final today = _todayDate();
    final start = _recoverableFloor(today, firstPossibleDate);

    final totalDaysSpan = today.difference(start).inDays; // exclui hoje
    if (totalDaysSpan <= 0) return 0;

    final snap = await col
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: dateKey(start))
        .where(FieldPath.documentId, isLessThan: dateKey(today))
        .get();

    final coveredDays = snap.docs.length;
    final missed = totalDaysSpan - coveredDays;
    return missed < 0 ? 0 : missed;
  }

  // ═════════════════════════════════════════════════════════════════
  // RECOMPENSA EQUIPADA (independente do avatar VIP)
  // ═════════════════════════════════════════════════════════════════
  /// Equipa/desequipa uma recompensa do Check-in. Só grava se o
  /// usuário REALMENTE desbloqueou (recorde >= marco) — a checagem é
  /// feita aqui a partir do dado do servidor, não de um valor vindo
  /// da UI. Passe `null` para desequipar. Retorna true se gravou.
  Future<bool> setEquippedReward(String? storageKeyOrNull) async {
    final doc = _userDoc;
    if (doc == null) return false;

    try {
      if (storageKeyOrNull == null) {
        await doc.set(
          {'equippedCheckinRewardId': FieldValue.delete()},
          SetOptions(merge: true),
        );
        return true;
      }

      final def = CheckinRewardsConfig.defForStorageKey(storageKeyOrNull);
      if (def == null) return false;

      final snap = await doc.get();
      final longest =
          (snap.data()?['longestCheckinStreak'] as num?)?.toInt() ?? 0;
      if (!CheckinRewardsConfig.isUnlocked(def, longest)) return false;

      await doc.set(
        {'equippedCheckinRewardId': storageKeyOrNull},
        SetOptions(merge: true),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}