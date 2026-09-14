import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ═══════════════════════════════════════════════════════════════════
// STATUS DE UM DIA NO CALENDÁRIO
// ═══════════════════════════════════════════════════════════════════
enum CheckinDayStatus {
  done,       // 🟢 check-in feito no dia certo
  recovered,  // 🟢 (com indicação) — recuperado via anúncio
  missed,     // 🔴 perdido, ainda recuperável
  today,      // 🟠 hoje, ainda sem check-in
  future,     // ⚪ dia futuro, bloqueado
  beforeStart,// dias antes da criação da conta / antes de existir o recurso
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

  const CheckinResult({
    required this.success,
    this.xpGained = 0,
    this.bonusXp = 0,
    this.streak = 0,
    this.bonusLabel,
    this.error,
  });
}

// ═══════════════════════════════════════════════════════════════════
// SERVIÇO DE CHECK-IN DIÁRIO
// ═══════════════════════════════════════════════════════════════════
// Estrutura no Firestore (nova, não interfere no restante de
// users_xp/{uid}):
//
//   users_xp/{uid}
//     checkinStreak        (int)    — dias consecutivos atuais
//     longestCheckinStreak (int)    — recorde pessoal
//     lastCheckinDate      (string) — 'yyyy-MM-dd' do último dia
//                                     coberto (feito OU recuperado)
//     checkinFirstDate     (string) — 'yyyy-MM-dd' do 1º dia possível
//                                     de check-in (data de instalação
//                                     do recurso para esse usuário)
//
//   users_xp/{uid}/checkins/{yyyy-MM-dd}   (subcoleção)
//     status      'done' | 'recovered'
//     xpAwarded   int
//     timestamp   serverTimestamp()
//
// Por que uma subcoleção por dia em vez de só os campos acima?
// Porque o calendário mensal precisa saber, para CADA dia do mês,
// se ele foi feito/recuperado/perdido — e isso exige um registro
// por dia. Os campos soltos (streak/lastCheckinDate) são só um
// resumo rápido para não precisar reler a subcoleção toda hora.
class CheckinService {
  static final CheckinService _instance = CheckinService._internal();
  factory CheckinService() => _instance;
  CheckinService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── XP base por check-in e bônus de marco de sequência ────────────
  // Os mesmos valores estão espelhados na regra do Firestore
  // (checkinBaseXp / checkinBonusForStreak) para que o cliente nunca
  // possa gravar um valor diferente do esperado.
  static const int baseXp = 10;

  static int bonusForStreak(int streak) {
    switch (streak) {
      case 7:
        return 30;
      case 14:
        return 60;
      case 30:
        return 150;
      case 60:
        return 300;
      case 100:
        return 500;
      default:
        return 0;
    }
  }

  static String? bonusLabelForStreak(int streak) {
    switch (streak) {
      case 7:
        return 'Sequência de 7 dias! 🔥';
      case 14:
        return 'Sequência de 14 dias! 🔥';
      case 30:
        return 'Sequência de 30 dias! 🔥';
      case 60:
        return 'Sequência de 60 dias! 🔥';
      case 100:
        return 'Sequência de 100 dias — Lenda do Horizonte! 🏆';
      default:
        return null;
    }
  }

  // Marco especial: aos 100 dias, além do XP, desbloqueia conquista.
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

  DateTime? _parseKey(String key) {
    try {
      final parts = key.split('-');
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  // ── Stream do resumo (streak, lastCheckinDate) ────────────────────
  // Reaproveita o mesmo doc users_xp/{uid} já observado pelo
  // UserXpProvider — aqui expomos só os campos de check-in.
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

    if (day.isAfter(today)) return CheckinDayStatus.future;
    if (firstPossibleDate != null && day.isBefore(firstPossibleDate)) {
      return CheckinDayStatus.beforeStart;
    }

    final existing = monthCheckins[key];
    if (existing != null) return existing.status;

    if (day.isAtSameMomentAs(today)) return CheckinDayStatus.today;
    return CheckinDayStatus.missed;
  }

  // ── Faz o check-in do dia de hoje ──────────────────────────────────
  // A trava real contra check-in duplicado / manipulação de relógio
  // fica na regra do Firestore (compara com request.time do servidor).
  // Aqui fazemos a checagem otimista no cliente só para dar feedback
  // rápido sem gastar uma escrita rejeitada.
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

      // Sequência só continua se o último check-in foi ONTEM.
      // Qualquer lacuna maior quebra a sequência (os dias perdidos
      // ficam disponíveis para recuperação via anúncio, mas não
      // contam automaticamente para o streak).
      int newStreak = 1;
      if (lastCheckinDate != null) {
        final lastDate = _parseKey(lastCheckinDate);
        if (lastDate != null) {
          final diff = today.difference(lastDate).inDays;
          if (diff == 1) newStreak = currentStreak + 1;
        }
      }

      final bonus = bonusForStreak(newStreak);
      final totalXp = baseXp + bonus;
      final newLongest = newStreak > longestStreak ? newStreak : longestStreak;

      final checkinDoc = col.doc(todayKey);

      await _db.runTransaction((tx) async {
        final freshSnap = await tx.get(doc);
        final freshData = freshSnap.data() ?? {};
        final freshLast = freshData['lastCheckinDate'] as String?;
        if (freshLast == todayKey) {
          throw StateError('already_done');
        }

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
          'longestCheckinStreak': newLongest,
          if (freshData['checkinFirstDate'] == null)
            'checkinFirstDate': todayKey,
          if (isSpecialMilestone(newStreak))
            'achievements': FieldValue.arrayUnion(['checkin_100']),
        });
      });

      return CheckinResult(
        success: true,
        xpGained: baseXp,
        bonusXp: bonus,
        streak: newStreak,
        bonusLabel: bonusLabelForStreak(newStreak),
      );
    } catch (e) {
      if (e is StateError && e.message == 'already_done') {
        return const CheckinResult(success: false, error: 'already_done');
      }
      return const CheckinResult(success: false, error: 'unknown');
    }
  }

  // ── Recupera um dia perdido específico, APÓS o anúncio ter sido
  // concluído com sucesso (chamar só dentro de onUserEarnedReward) ───
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

        tx.update(doc, {
          'totalXp': FieldValue.increment(baseXp),
          'lastActivity': FieldValue.serverTimestamp(),
        });
      });

      return CheckinResult(success: true, xpGained: baseXp, streak: 0);
    } catch (e) {
      if (e is StateError && e.message == 'already_done') {
        return const CheckinResult(success: false, error: 'already_done');
      }
      return const CheckinResult(success: false, error: 'unknown');
    }
  }

  // ── Quantos dias perdidos existem entre a data de início do
  // recurso para esse usuário e hoje (exclusive hoje) ────────────────
  // Usado para o contador "Você tem X dias para recuperar" — varre só
  // os meses necessários, sem carregar o histórico inteiro de uma vez.
  Future<int> countRecoverableDays({
    required DateTime? firstPossibleDate,
  }) async {
    if (firstPossibleDate == null) return 0;
    final col = _checkinsCol;
    if (col == null) return 0;

    final today = _todayDate();
    final start = DateTime(
        firstPossibleDate.year, firstPossibleDate.month, firstPossibleDate.day);

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
}