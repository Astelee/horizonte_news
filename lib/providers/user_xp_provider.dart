import 'dart:async';
import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class UserXpProvider with ChangeNotifier, WidgetsBindingObserver {
  final XpService _service = XpService();

  UserXpData _data = UserXpData.empty();
  bool _isLoading = true;
  bool _isActive = false;

  // Timer que conta o tempo ativo
  Timer? _activeTimer;
  int _secondsAccumulated = 0;

  // A cada quantos segundos salva no Firestore (evita writes excessivos)
  static const int _saveIntervalSeconds = 60;

  UserXpData get data => _data;
  bool get isLoading => _isLoading;

  // ── Inicializa provider ──────────────────────────────────────────
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _isLoading = true;
    notifyListeners();

    _data = await _service.loadUserXpData();
    _isLoading = false;
    notifyListeners();

    _startTimer();
  }

  // ── Responde às mudanças de ciclo de vida do app ─────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao primeiro plano — retoma contagem
        _startTimer();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App foi para background ou tela bloqueada — pausa e salva
        _pauseAndSave();
        break;
    }
  }

  // ── Inicia o timer de tempo ativo ────────────────────────────────
  void _startTimer() {
    if (_isActive) return;
    _isActive = true;
    _secondsAccumulated = 0;

    _activeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsAccumulated++;

      // A cada _saveIntervalSeconds, salva no Firestore e atualiza UI
      if (_secondsAccumulated >= _saveIntervalSeconds) {
        _flushToFirestore();
      }
    });
  }

  // ── Pausa o timer e salva o que acumulou ─────────────────────────
  void _pauseAndSave() {
    if (!_isActive) return;
    _isActive = false;
    _activeTimer?.cancel();
    _activeTimer = null;

    if (_secondsAccumulated > 0) {
      _flushToFirestore();
    }
  }

  // ── Envia tempo acumulado para o Firestore ───────────────────────
  Future<void> _flushToFirestore() async {
    if (_secondsAccumulated <= 0) return;

    final seconds = _secondsAccumulated;
    _secondsAccumulated = 0;

    final updated = await _service.addXpForTime(seconds);
    _data = updated;
    notifyListeners();
  }

  // ── API pública para registrar eventos ───────────────────────────
  Future<void> onArticleRead() async {
    await _service.recordArticleRead();
    _data = await _service.loadUserXpData();
    notifyListeners();
  }

  Future<void> onShare() async {
    await _service.recordShare();
    _data = await _service.loadUserXpData();
    notifyListeners();
  }

  Future<void> onComment() async {
    await _service.recordComment();
    _data = await _service.loadUserXpData();
    notifyListeners();
  }

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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
