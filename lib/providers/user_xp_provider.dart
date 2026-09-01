import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class UserXpProvider with ChangeNotifier, WidgetsBindingObserver {
  final XpService _service = XpService();

  UserXpData _data = UserXpData.empty();
  bool _isLoading = true;
  bool _isActive = false;

  Timer? _activeTimer;
  int _secondsAccumulated = 0;

  // ── Assinatura do stream em tempo real (users_xp/{uid}) ──────────
  // Qualquer mudança no Firestore — inclusive as feitas pelo admin no
  // painel (moldura/nível/título) — chega aqui automaticamente e
  // atualiza a tela de perfil sem precisar reabrir nada.
  StreamSubscription<UserXpData>? _xpSubscription;

  Function(int newLevel)? onLevelUp;

  static const int _saveIntervalSeconds = 60;

  UserXpData get data => _data;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _isLoading = true;
    notifyListeners();

    _startWatching();
    _updateLastSeen();
    _startTimer();
  }

  // ── Liga o listener em tempo real e mantém _data sempre em dia ───
  // ESTA é a única fonte de verdade para _data agora. Os métodos de
  // ação (onArticleRead, onShare, addXpForComment) só disparam a
  // gravação no Firestore; quem atualiza a tela é sempre esse
  // listener, evitando corrida entre uma leitura manual e o snapshot
  // do stream chegando com dado desatualizado.
  void _startWatching() {
    _xpSubscription?.cancel();
    bool firstEvent = true;

    _xpSubscription = _service.watchUserXpData().listen((updated) {
      // Compara sempre com o nível anterior IMEDIATO (não o nível de
      // quando a assinatura começou), já que o stream fica aberto por
      // toda a sessão e pode receber vários eventos.
      final oldLevel = _data.level;
      _data = updated;
      _isLoading = false;

      if (!firstEvent && updated.level > oldLevel) {
        onLevelUp?.call(updated.level);
      }
      firstEvent = false;

      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // O stream continua ativo em segundo plano, mas garante que a
        // assinatura esteja saudável ao voltar do background.
        if (_xpSubscription == null) {
          _startWatching();
        }
        _updateLastSeen();
        _startTimer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pauseAndSave();
        break;
    }
  }

  // ── Grava lastSeenAt no Firestore ──────────────────────────────
  void _updateLastSeen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users_xp')
        .doc(uid)
        .update({'lastSeenAt': FieldValue.serverTimestamp()})
        .catchError((_) {});
  }

  void _startTimer() {
    if (_isActive) return;
    _isActive = true;
    _secondsAccumulated = 0;

    _activeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsAccumulated++;
      if (_secondsAccumulated >= _saveIntervalSeconds) {
        _flushToFirestore();
      }
    });
  }

  void _pauseAndSave() {
    if (!_isActive) return;
    _isActive = false;
    _activeTimer?.cancel();
    _activeTimer = null;

    if (_secondsAccumulated > 0) {
      _flushToFirestore();
    }
  }

  // _flushToFirestore continua usando o retorno direto do serviço
  // (não o stream) de propósito: addXpForTime roda no timer em
  // background, então não há risco de corrida com uma leitura manual
  // concorrente — é seguro e evita esperar o round-trip do stream.
  Future<void> _flushToFirestore() async {
    if (_secondsAccumulated <= 0) return;

    final seconds = _secondsAccumulated;
    _secondsAccumulated = 0;

    final oldLevel = _data.level;
    final updated = await _service.addXpForTime(seconds);
    _data = updated;
    notifyListeners();

    if (updated.level > oldLevel) {
      onLevelUp?.call(updated.level);
    }
  }

  // ── Ações do usuário: apenas gravam. A UI atualiza via stream ────
  // (_xpSubscription em _startWatching), que também cuida de
  // detectar e disparar o level-up. Isso remove a corrida que
  // fazia a missão de "post visto" só aparecer contabilizada depois
  // de uma ação seguinte (como comentar).
  Future<void> onArticleRead(String postId) async {
    await _service.recordArticleRead(postId);
  }

  Future<void> onShare({required String postId, String? postTitle}) async {
    await _service.recordShare(postId: postId, postTitle: postTitle);
  }

  Future<void> addXpForComment() async {
    try {
      await _service.recordComment();
    } catch (e) {
      debugPrint('Erro ao adicionar XP por comentário: $e');
    }
  }

  Future<void> onComment() async => addXpForComment();

  Future<void> reload() async {
    _isLoading = true;
    notifyListeners();
    _data = await _service.loadUserXpData();
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pauseAndSave();
    _xpSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}