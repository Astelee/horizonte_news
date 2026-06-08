import 'dart:async';
import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class UserXpProvider with ChangeNotifier, WidgetsBindingObserver {
  final XpService _service = XpService();

  UserXpData _data = UserXpData.empty();
  bool _isLoading = true;
  bool _isActive = false;

  Timer? _activeTimer;
  int _secondsAccumulated = 0;

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

  // ── Ciclo de vida do app ─────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
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

  // ── Timer de tempo ativo ─────────────────────────────────────────
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

  Future<void> _flushToFirestore() async {
    if (_secondsAccumulated <= 0) return;

    final seconds = _secondsAccumulated;
    _secondsAccumulated = 0;

    final updated = await _service.addXpForTime(seconds);
    _data = updated;
    notifyListeners();
  }

  // ── Eventos de XP ────────────────────────────────────────────────
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

  // ── Comentário — usado pelo CommentsSection ───────────────────────
  // Chame provider.addXpForComment() no widget de comentários
  Future<void> addXpForComment() async {
    try {
      await _service.recordComment();
      _data = await _service.loadUserXpData();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao adicionar XP por comentário: $e');
    }
  }

  // Mantido para compatibilidade com código existente
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}