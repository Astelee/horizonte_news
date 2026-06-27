import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Sistema de presença profissional — arquitetura igual WhatsApp/Discord.
///
/// FLUXO:
/// 1. Ao conectar: RTDB marca "online" + registra onDisconnect("offline")
/// 2. Se o socket cair (app fechado, sem rede, processo morto):
///    o SERVIDOR do Firebase grava "offline" automaticamente — sem
///    depender de nenhum código no cliente rodar.
/// 3. Um Cloud Function (ou listener no RTDB) espelha para o Firestore,
///    mantendo users_xp/{uid}.status atualizado para as outras telas.
/// 4. Timer de inatividade: após 2min sem atividade em foreground → "away".
/// 5. App em background: não altera o estado — o onDisconnect cuida disso
///    quando o socket efetivamente cair.
class PresenceService with WidgetsBindingObserver {
  PresenceService._internal();
  static final PresenceService instance = PresenceService._internal();

  final _auth      = FirebaseAuth.instance;
  final _rtdb      = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  static const Duration _awayAfter    = Duration(minutes: 2);
  // Debounce: não espelha pro Firestore mais de 1x por segundo
  static const Duration _mirrorDebounce = Duration(seconds: 1);

  StreamSubscription<DatabaseEvent>? _connectedSub;
  StreamSubscription<DatabaseEvent>? _ownStatusSub;
  Timer? _awayTimer;
  Timer? _mirrorDebounceTimer;

  bool _initialized      = false;
  bool _appInForeground  = true;
  String _lastMirroredState = '';

  String? get _uid => _auth.currentUser?.uid;

  DatabaseReference? get _statusRef {
    final uid = _uid;
    if (uid == null) return null;
    return _rtdb.ref('status/$uid');
  }

  // ═══════════════════════════════════════════════════════════════
  // INICIALIZAÇÃO
  // ═══════════════════════════════════════════════════════════════

  /// Chame uma vez no _AuthGate, após confirmar usuário logado.
  Future<void> start() async {
    if (_initialized) return;
    final uid = _uid;
    if (uid == null) return;

    // CRÍTICO: setPersistenceEnabled ANTES de qualquer referência ao RTDB.
    // Mantém o socket vivo em background e acelera a reconexão.
    try {
      _rtdb.setPersistenceEnabled(true);
    } catch (_) {
      // Ignora se já foi chamado (pode acontecer em hot reload)
    }

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Escuta a conexão com o servidor Firebase
    _connectedSub = _rtdb
        .ref('.info/connected')
        .onValue
        .listen(_onConnectionChanged);

    _startAwayTimer();
  }

  /// Chame no logout — marca offline imediatamente e limpa tudo.
  Future<void> stop() async {
    if (!_initialized) return;
    _initialized = false;

    WidgetsBinding.instance.removeObserver(this);
    _awayTimer?.cancel();
    _mirrorDebounceTimer?.cancel();
    await _connectedSub?.cancel();
    await _ownStatusSub?.cancel();

    final uid = _uid;
    if (uid != null) {
      // Grava offline de forma fire-and-forget — o onDisconnect
      // já faria isso, mas fazemos explicitamente no logout intencional
      // para ser instantâneo.
      try {
        await _rtdb.ref('status/$uid').set({
          'state':       'offline',
          'lastChanged': ServerValue.timestamp,
        });
        await _mirrorToFirestore('offline');
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CONEXÃO COM O SERVIDOR
  // ═══════════════════════════════════════════════════════════════

  void _onConnectionChanged(DatabaseEvent event) {
    final connected = event.snapshot.value == true;
    if (!connected) return;

    final ref = _statusRef;
    if (ref == null) return;

    // onDisconnect: o servidor grava isso quando o socket cai.
    // DEVE ser registrado a cada reconexão — o Firebase limpa o
    // gatilho quando a conexão cai e não restaura automaticamente.
    ref.onDisconnect().set({
      'state':       'offline',
      'lastChanged': ServerValue.timestamp,
    });

    // Marca online imediatamente após conectar/reconectar
    ref.set({
      'state':       'online',
      'lastChanged': ServerValue.timestamp,
    });

    _scheduleMirror('online');
    _listenOwnStatus();
  }

  // ═══════════════════════════════════════════════════════════════
  // ESPELHAMENTO RTDB → FIRESTORE (com debounce)
  // ═══════════════════════════════════════════════════════════════

  /// Escuta o próprio nó no RTDB e espelha para o Firestore
  /// somente quando o estado MUDA — evita writes redundantes.
  void _listenOwnStatus() {
    _ownStatusSub?.cancel();
    final ref = _statusRef;
    if (ref == null) return;

    _ownStatusSub = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is! Map) return;
      final state = data['state'] as String?;
      if (state == null) return;
      if (state == _lastMirroredState) return; // sem mudança, sem write
      _scheduleMirror(state);
    });
  }

  /// Debounce para não espelhar mais de 1x por segundo
  void _scheduleMirror(String state) {
    _mirrorDebounceTimer?.cancel();
    _mirrorDebounceTimer = Timer(_mirrorDebounce, () {
      _mirrorToFirestore(state);
    });
  }

  Future<void> _mirrorToFirestore(String state) async {
    final uid = _uid;
    if (uid == null) return;
    if (state == _lastMirroredState) return;
    _lastMirroredState = state;

    try {
      await _firestore.collection('users_xp').doc(uid).set({
        'status':       state,
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PresenceService: erro ao espelhar no Firestore: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ATIVIDADE DO USUÁRIO
  // ═══════════════════════════════════════════════════════════════

  /// Chame em qualquer interação do usuário (toque, scroll, etc.)
  /// para resetar o timer de away e voltar para online.
  void registerActivity() {
    if (!_initialized) return;
    _startAwayTimer();

    // Só grava se estava away — evita write desnecessário em cada toque
    if (_lastMirroredState == 'away') {
      _setRtdbState('online');
    }
  }

  void _setRtdbState(String state) {
    final ref = _statusRef;
    if (ref == null) return;
    ref.update({
      'state':       state,
      'lastChanged': ServerValue.timestamp,
    }).catchError((_) {});
  }

  // ═══════════════════════════════════════════════════════════════
  // CICLO DE VIDA DO APP
  // ═══════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        // App voltou ao foreground — reseta inatividade
        registerActivity();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appInForeground = false;
        _awayTimer?.cancel();
        // NÃO marcamos offline aqui intencionalmente.
        // O onDisconnect() do servidor cuida disso quando o socket
        // realmente cair — mais confiável que o lifecycle do Flutter,
        // que pode disparar em situações temporárias (notificação,
        // troca de app rápida, etc).
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TIMER DE AWAY
  // ═══════════════════════════════════════════════════════════════

  void _startAwayTimer() {
    _awayTimer?.cancel();
    _awayTimer = Timer(_awayAfter, () {
      // Só marca away se o app ainda estiver em foreground
      if (_appInForeground && _initialized) {
        _setRtdbState('away');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awayTimer?.cancel();
    _mirrorDebounceTimer?.cancel();
    _connectedSub?.cancel();
    _ownStatusSub?.cancel();
  }
}
