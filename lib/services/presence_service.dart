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

  static const Duration _mirrorDebounce = Duration(seconds: 1);

  StreamSubscription<DatabaseEvent>? _connectedSub;
  StreamSubscription<DatabaseEvent>? _ownStatusSub;
  Timer? _mirrorDebounceTimer;

  bool _initialized         = false;
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
  }

  Future<void> stop() async {
    if (!_initialized) return;
    _initialized = false;

    WidgetsBinding.instance.removeObserver(this);
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

    _rtdb.goOffline();
  }

  // ═══════════════════════════════════════════════════════════════
  // CONEXÃO — CORREÇÃO DO PROBLEMA 4
  // ✅ async + await onDisconnect() ANTES de gravar 'online'.
  //    Não existe mais janela onde o servidor fica sem saber
  //    o que fazer se a conexão cair.
  // ═══════════════════════════════════════════════════════════════

  Future<void> _onConnectionChanged(DatabaseEvent event) async {
    final connected = event.snapshot.value == true;
    if (!connected) return;

    final ref = _statusRef;
    if (ref == null) return;

    // 1️⃣ Registra o fallback no servidor PRIMEIRO
    await ref.onDisconnect().set({
      'state':       'offline',
      'lastChanged': ServerValue.timestamp,
    });

    // 2️⃣ Só agora marca online — servidor já tem o handler salvo
    await ref.set({
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
  // ATIVIDADE — CORREÇÃO DO PROBLEMA 3
  // ✅ Removido o timer "away" de 2 minutos.
  //    Status é agora puramente Online/Offline baseado no socket RTDB.
  //    registerActivity() mantido por compatibilidade de chamadas
  //    existentes no código, mas não altera mais o estado.
  // ═══════════════════════════════════════════════════════════════

  void registerActivity() {
    // Sem efeito. Status é controlado pelo ciclo de vida do app.
  }

  // ═══════════════════════════════════════════════════════════════
  // CICLO DE VIDA DO APP
  // ═══════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Reconecta — _onConnectionChanged dispara e registra
        // onDisconnect + marca online na sequência correta.
        _rtdb.goOnline();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // goOffline() força o socket a cair AGORA,
        // disparando imediatamente o onDisconnect no servidor
        // sem precisar esperar o processo morrer.
        _rtdb.goOffline();
        break;

      case AppLifecycleState.inactive:
        // Temporário (ligação, notificação) — não pisca o status.
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mirrorDebounceTimer?.cancel();
    _connectedSub?.cancel();
    _ownStatusSub?.cancel();
  }
}
