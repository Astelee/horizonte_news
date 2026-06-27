import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._internal();
  static final PresenceService instance = PresenceService._internal();

  final _auth      = FirebaseAuth.instance;
  final _rtdb      = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  static const Duration _awayAfter      = Duration(minutes: 2);
  static const Duration _mirrorDebounce = Duration(seconds: 1);

  StreamSubscription<DatabaseEvent>? _connectedSub;
  StreamSubscription<DatabaseEvent>? _ownStatusSub;
  Timer? _awayTimer;
  Timer? _mirrorDebounceTimer;

  bool _initialized     = false;
  bool _appInForeground = true;
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

  Future<void> start() async {
    if (_initialized) return;
    final uid = _uid;
    if (uid == null) return;

    try {
      _rtdb.setPersistenceEnabled(true);
    } catch (_) {}

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    _connectedSub = _rtdb
        .ref('.info/connected')
        .onValue
        .listen(_onConnectionChanged);

    _startAwayTimer();
  }

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
      try {
        await _rtdb.ref('status/$uid').set({
          'state':       'offline',
          'lastChanged': ServerValue.timestamp,
        });
        await _mirrorToFirestore('offline');
      } catch (_) {}
    }

    // Desconecta o socket explicitamente no logout
    _rtdb.goOffline();
  }

  // ═══════════════════════════════════════════════════════════════
  // CONEXÃO COM O SERVIDOR
  // ═══════════════════════════════════════════════════════════════

  void _onConnectionChanged(DatabaseEvent event) {
    final connected = event.snapshot.value == true;
    if (!connected) return;

    final ref = _statusRef;
    if (ref == null) return;

    // Registra o que o servidor faz quando o socket cair
    ref.onDisconnect().set({
      'state':       'offline',
      'lastChanged': ServerValue.timestamp,
    });

    // Marca online imediatamente
    ref.set({
      'state':       'online',
      'lastChanged': ServerValue.timestamp,
    });

    _scheduleMirror('online');
    _listenOwnStatus();
  }

  // ═══════════════════════════════════════════════════════════════
  // ESPELHAMENTO RTDB → FIRESTORE
  // ═══════════════════════════════════════════════════════════════

  void _listenOwnStatus() {
    _ownStatusSub?.cancel();
    final ref = _statusRef;
    if (ref == null) return;

    _ownStatusSub = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is! Map) return;
      final state = data['state'] as String?;
      if (state == null) return;
      if (state == _lastMirroredState) return;
      _scheduleMirror(state);
    });
  }

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

  void registerActivity() {
    if (!_initialized) return;
    _startAwayTimer();

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
  // CICLO DE VIDA DO APP — CORREÇÃO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        // Reconecta o socket — _onConnectionChanged vai disparar
        // e registrar o onDisconnect + marcar online novamente
        _rtdb.goOnline();
        registerActivity();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appInForeground = false;
        _awayTimer?.cancel();
        // ✅ CORREÇÃO PRINCIPAL:
        // goOffline() força o socket a cair AGORA.
        // Isso faz o servidor Firebase disparar o onDisconnect
        // imediatamente, gravando 'offline' sem esperar o processo morrer.
        _rtdb.goOffline();
        break;

      case AppLifecycleState.inactive:
        // inactive é temporário (chegada de notificação, ligação)
        // não desconecta para não piscar o status
        _appInForeground = false;
        _awayTimer?.cancel();
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TIMER DE AWAY
  // ═══════════════════════════════════════════════════════════════

  void _startAwayTimer() {
    _awayTimer?.cancel();
    _awayTimer = Timer(_awayAfter, () {
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
