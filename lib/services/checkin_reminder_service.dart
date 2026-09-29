import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'checkin_reminder_plan.dart';

// ═══════════════════════════════════════════════════════════════════
// LEMBRETE LOCAL PARA PROTEGER A SEQUÊNCIA DO CHECK-IN
// ═══════════════════════════════════════════════════════════════════
// Funciona 100% no aparelho (flutter_local_notifications), sem
// servidor. NÃO recalcula sequência: usa os campos-resumo que o
// CheckinService já mantém em users_xp/{uid} (checkinStreak e
// lastCheckinDate) e a regra de "quando avisar" de
// CheckinReminderPlanner.
//
// Como evita duplicatas: existe UM único aviso agendado por vez,
// sempre com o MESMO id. Agendar de novo substitui o anterior, e
// cancelar remove o pendente.
//
// Quando é sincronizado:
//  • ao abrir/voltar ao app (UserXpProvider) — 1 leitura do doc do
//    usuário, no máximo a cada 15 min;
//  • logo após check-in, recuperação de dia ou reconstrução da
//    sequência (CheckinService) — sem leitura extra, usando os
//    valores que essas rotinas acabaram de calcular;
//  • ao deslogar (cancela).
//
// Limite de um lembrete 100% local: se o usuário fizer o check-in
// em OUTRO aparelho, este só descobre na próxima vez que o app for
// aberto aqui.
class CheckinReminderService {
  CheckinReminderService._();
  static final CheckinReminderService instance = CheckinReminderService._();

  // Id fixo => nunca há duas notificações de sequência ao mesmo tempo.
  static const int _notificationId = 4207;
  static const String _channelId = 'checkin_streak_reminder';
  static const String _channelName = 'Lembrete de sequência';
  static const String _channelDescription =
      'Avisa às 20h quando sua sequência de check-in está em risco.';
  static const String _payload = 'checkin_streak';
  static const String _smallIcon = 'ic_stat_checkin';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initFuture;
  bool _ready = false;

  // Toque na notificação com o app fechado ou sem usuário logado
  // ainda: guarda o pedido e abre o Check-in assim que possível.
  bool _pendingOpenCheckin = false;
  bool Function()? _openCheckin;

  // Fila: garante que duas sincronizações seguidas (ex.: reconstrução
  // seguida de check-in) terminem na ordem em que foram pedidas.
  Future<void> _queue = Future<void>.value();

  String? _lastPlanKey;
  String? _lastSyncUid;
  DateTime? _lastFirestoreSync;

  static const Duration _minSyncInterval = Duration(minutes: 15);

  /// Liga a navegação: [opener] deve abrir a tela de Check-in e
  /// devolver true se conseguiu (false se o Navigator ainda não
  /// existe). Chamado uma vez no main.dart.
  void attachNavigator(bool Function() opener) {
    _openCheckin = opener;
  }

  /// Inicializa o plugin e o banco de fusos horários. Seguro chamar
  /// mais de uma vez.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    try {
      tzdata.initializeTimeZones();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // App aberto PELO toque na notificação (estava fechado).
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch != null &&
          launch.didNotificationLaunchApp &&
          launch.notificationResponse?.payload == _payload) {
        _pendingOpenCheckin = true;
      }

      _ready = true;
    } catch (e) {
      debugPrint('Erro ao iniciar lembrete de check-in: $e');
      _initFuture = null; // permite nova tentativa
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != _payload) return;
    if (FirebaseAuth.instance.currentUser != null &&
        (_openCheckin?.call() ?? false)) {
      return;
    }
    _pendingOpenCheckin = true;
  }

  /// Se o app foi aberto pelo toque na notificação, abre o Check-in
  /// (uma única vez). Chamado quando já existe usuário logado.
  Future<void> openPendingCheckinIfAny() async {
    await init();
    if (!_pendingOpenCheckin) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    final opened = _openCheckin?.call() ?? false;
    if (opened) _pendingOpenCheckin = false;
  }

  Future<void> _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((Object e) {
      debugPrint('Erro no lembrete de check-in: $e');
    });
    return _queue;
  }

  /// Remove o lembrete pendente (logout, sequência quebrada...).
  Future<void> cancel() => _enqueue(_cancelNow);

  Future<void> _cancelNow() async {
    await init();
    if (!_ready) return;
    _lastPlanKey = null;
    await _plugin.cancel(_notificationId);
  }

  /// Sincroniza a partir de valores que o chamador JÁ tem (sem ler o
  /// Firestore). Usado pelo CheckinService logo após check-in,
  /// recuperação ou reconstrução.
  Future<void> syncFromValues({
    required int streak,
    required String? lastCheckinDate,
  }) {
    return _enqueue(() => _syncNow(streak, lastCheckinDate));
  }

  /// Sincroniza lendo o resumo do usuário (1 leitura do doc
  /// users_xp/{uid}). Com [force] false, no máximo a cada 15 min.
  Future<void> syncFromFirestore({bool force = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final last = _lastFirestoreSync;
    if (!force &&
        _lastSyncUid == uid &&
        last != null &&
        now.difference(last) < _minSyncInterval) {
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users_xp')
          .doc(uid)
          .get();
      _lastFirestoreSync = now;
      _lastSyncUid = uid;

      final data = snap.data() ?? {};
      await syncFromValues(
        streak: (data['checkinStreak'] as num?)?.toInt() ?? 0,
        lastCheckinDate: data['lastCheckinDate'] as String?,
      );
    } catch (e) {
      debugPrint('Erro ao ler resumo para o lembrete de check-in: $e');
    }
  }

  Future<void> _syncNow(int streak, String? lastCheckinDate) async {
    await init();
    if (!_ready) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await _cancelNow();
      return;
    }

    final plan = CheckinReminderPlanner.planFor(
      now: DateTime.now(),
      streak: streak,
      lastCheckinDate: lastCheckinDate,
    );

    // Já fez o check-in de hoje sem risco amanhã, sequência quebrada,
    // horário passado...: garante que nada fique agendado.
    if (plan == null) {
      await _cancelNow();
      return;
    }

    // Sem permissão de notificação no sistema não adianta agendar.
    // (A permissão é pedida pelo fluxo que já existe no app.)
    if (!await _notificationsAllowed()) return;

    final key = '$uid|${plan.fireAt.millisecondsSinceEpoch}|${plan.streak}';
    if (_lastPlanKey == key) return; // já agendado exatamente assim

    await _schedule(plan);
    _lastPlanKey = key;
  }

  Future<bool> _notificationsAllowed() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final enabled = await android.areNotificationsEnabled();
    return enabled ?? true;
  }

  Future<void> _schedule(ReminderPlan plan) async {
    final body = CheckinReminderPlanner.bodyFor(plan.streak);

    // O aviso some sozinho à meia-noite do dia de risco: depois disso
    // o texto "acaba hoje" deixaria de ser verdade.
    final endOfDay = DateTime(
      plan.fireAt.year,
      plan.fireAt.month,
      plan.fireAt.day + 1,
    );
    final timeoutMs = endOfDay.difference(plan.fireAt).inMilliseconds;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        color: const Color(0xFFFF6D00),
        category: AndroidNotificationCategory.reminder,
        timeoutAfter: timeoutMs,
        styleInformation: BigTextStyleInformation(body),
      ),
    );

    // O instante exato vem do relógio local do aparelho; expressá-lo
    // em UTC evita depender de um pacote extra só para descobrir o
    // nome do fuso. O horário de disparo é o mesmo.
    final when = tz.TZDateTime.from(plan.fireAt, tz.getLocation('UTC'));

    await _plugin.zonedSchedule(
      _notificationId,
      'Check-in Diário',
      body,
      when,
      details,
      // Inexato: "por volta das 20h", sem exigir a permissão de
      // alarme exato (SCHEDULE_EXACT_ALARM).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _payload,
    );
  }
}