import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Serviço de presença em tempo real (online / ausente / offline).
///
/// ARQUITETURA:
/// - Fonte da verdade: Firebase Realtime Database, em status/{uid}.
///   Usa `.info/connected` + `onDisconnect()`, que são tratados pelo
///   PRÓPRIO SERVIDOR do Firebase — ou seja, mesmo se o app for fechado
///   à força, sem internet, ou o processo for matado, o servidor marca
///   o usuário como offline automaticamente, sem depender do client
///   rodar mais nenhum código. É isso que dá a instantaneidade real
///   (igual WhatsApp/Discord/Telegram).
/// - Espelhamento para Firestore: como o restante do app (amigos,
///   conversas) já lê presença do Firestore em users_xp/{uid}, este
///   serviço também escreve lá (status + lastActivity) toda vez que o
///   RTDB muda, para não precisar reescrever as outras telas.
/// - Estado "away": não existe nativamente no RTDB; é controlado aqui
///   por um timer de inatividade no client. Qualquer interação chamada
///   via [registerActivity] (ou o app voltar ao foreground) reseta o
///   timer e volta para "online".
class PresenceService with WidgetsBindingObserver {
  PresenceService._internal();
  static final PresenceService instance = PresenceService._internal();

  final _auth = FirebaseAuth.instance;
  final _rtdb = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  static const Duration _awayAfter = Duration(minutes: 2);

  StreamSubscription<DatabaseEvent>? _connectedSub;
  StreamSubscription<DocumentSnapshot>? _ownStatusMirrorSub;
  Timer? _awayTimer;
  bool _initialized = false;
  bool _appInForeground = true;

  String? get _uid => _auth.currentUser?.uid;

  DatabaseReference get _statusRef =>
      _rtdb.ref('status/${_uid!}');

  /// Chame uma vez, normalmente a partir do _AuthGate em main.dart,
  /// assim que houver um usuário autenticado.
  Future<void> start() async {
    if (_initialized) return;
    if (_uid == null) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Mantém uma conexão de socket persistente; reduz latência de
    // reconexão e é o que torna a detecção de queda quase instantânea.
    _rtdb.setPersistenceEnabled(true);

    _connectedSub = _rtdb.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (connected) {
        _onConnected();
      }
    });

    _startAwayTimer();
  }

  /// Chame no logout, para parar de escutar e marcar offline de imediato
  /// (sem esperar o onDisconnect do servidor, já que a sessão terminou
  /// de forma intencional).
  Future<void> stop() async {
    if (!_initialized) return;
    _initialized = false;

    WidgetsBinding.instance.removeObserver(this);
    _awayTimer?.cancel();
    _awayTimer = null;
    await _connectedSub?.cancel();
    _connectedSub = null;

    final uid = _uid;
    if (uid != null) {
      try {
        await _rtdb.ref('status/$uid').set({
          'state': 'offline',
          'lastChanged': ServerValue.timestamp,
        });
      } catch (_) {}
    }
  }

  /// Registra atividade do usuário (toque na tela, scroll, envio de
  /// mensagem, etc). Reseta o timer de away e, se estava away, volta
  /// para online imediatamente.
  void registerActivity() {
    if (!_initialized) return;
    _startAwayTimer();
    _setState('online');
  }

  // ── Ciclo de vida do app ─────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        registerActivity();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appInForeground = false;
        // Não marcamos offline aqui de propósito: o app pode voltar
        // rapidamente (troca de app, notificação, etc). A detecção de
        // fechamento real é feita pelo onDisconnect() do servidor, que
        // dispara quando o socket efetivamente cai — muito mais
        // confiável do que adivinhar pelo lifecycle do Flutter.
        break;
    }
  }

  // ── Conexão estabelecida/restabelecida ────────────────────────────
  void _onConnected() {
    final uid = _uid;
    if (uid == null) return;

    final ref = _rtdb.ref('status/$uid');

    // onDisconnect: registrado a CADA reconexão, pois o Firebase exige
    // que o gatilho seja redefinido sempre que a conexão é recriada.
    // É isso que garante: se o app cair, perder rede, ou for matado,
    // o SERVIDOR (não o client) grava este valor automaticamente.
    ref.onDisconnect().set({
      'state': 'offline',
      'lastChanged': ServerValue.timestamp,
    });

    // Assim que conectar (ou reconectar), marca online.
    ref.set({
      'state': 'online',
      'lastChanged': ServerValue.timestamp,
    });

    _mirrorToFirestore('online');
    _listenOwnStatusForMirror();
  }

  // ── Espelha o próprio status do RTDB para o Firestore ────────────
  // Evita escrever Firestore em todo onValue (caro); em vez disso,
  // escuta o próprio nó no RTDB e replica só quando o estado muda de
  // fato, mantendo users_xp/{uid}.status e lastActivity atualizados
  // para as telas que já leem presença de lá (lista de amigos, chat).
  void _listenOwnStatusForMirror() {
    final uid = _uid;
    if (uid == null) return;

    _statusRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is! Map) return;
      final state = data['state'] as String?;
      if (state == null) return;
      _mirrorToFirestore(state);
    });
  }

  Future<void> _mirrorToFirestore(String state) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users_xp').doc(uid).set({
        'status': state,
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PresenceService: erro ao espelhar status no Firestore: $e');
    }
  }

  // ── Define o estado diretamente (usado por registerActivity) ────
  void _setState(String state) {
    final uid = _uid;
    if (uid == null) return;
    _rtdb.ref('status/$uid').update({
      'state': state,
      'lastChanged': ServerValue.timestamp,
    }).catchError((_) {});
  }

  // ── Timer de inatividade → away ──────────────────────────────────
  void _startAwayTimer() {
    _awayTimer?.cancel();
    _awayTimer = Timer(_awayAfter, () {
      if (_appInForeground) {
        // Só marca "away" se o app ainda estiver em foreground —
        // se foi para background, o estado correto é deixado para o
        // onDisconnect ou para a próxima vez que conectar.
        _setState('away');
      }
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awayTimer?.cancel();
    _connectedSub?.cancel();
    _ownStatusMirrorSub?.cancel();
  }
}
