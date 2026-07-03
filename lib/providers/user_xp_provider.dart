import 'dart:async';
import 'package:flutter/material.dart';
import '../services/xp_service.dart';
import '../services/avatar_service.dart';

class UserXpProvider with ChangeNotifier, WidgetsBindingObserver {
  final XpService _service = XpService();
  final AvatarService _avatarService = AvatarService();

  UserXpData _data = UserXpData.empty();
  bool _isLoading = true;
  bool _isActive = false;

  Timer? _activeTimer;
  int _secondsAccumulated = 0;

  Function(int newLevel)? onLevelUp;

  static const int _saveIntervalSeconds = 60;

  UserXpData get data => _data;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    _isLoading = true;
    notifyListeners();

    // loadUserXpData já aplica adminOverride e avatarId internamente
    _data = await _service.loadUserXpData();
    _isLoading = false;
    notifyListeners();

    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _reloadOnResume();
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

  Future<void> _reloadOnResume() async {
    _data = await _service.loadUserXpData();
    notifyListeners();
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

  Future<void> _flushToFirestore() async {
    if (_secondsAccumulated <= 0) return;

    final seconds = _secondsAccumulated;
    _secondsAccumulated = 0;

    final oldLevel = _data.level;
    // addXpForTime → _incrementXpAndSave → loadUserXpData
    // toda a cadeia já respeita o override e o avatarId
    final updated = await _service.addXpForTime(seconds);
    _data = updated;
    notifyListeners();

    if (updated.level > oldLevel) {
      onLevelUp?.call(updated.level);
    }
  }

  Future<void> onArticleRead() async {
    final oldLevel = _data.level;
    await _service.recordArticleRead();
    _data = await _service.loadUserXpData();
    notifyListeners();
    if (_data.level > oldLevel) onLevelUp?.call(_data.level);
  }

  Future<void> onShare() async {
    final oldLevel = _data.level;
    await _service.recordShare();
    _data = await _service.loadUserXpData();
    notifyListeners();
    if (_data.level > oldLevel) onLevelUp?.call(_data.level);
  }

  Future<void> addXpForComment() async {
    try {
      final oldLevel = _data.level;
      await _service.recordComment();
      _data = await _service.loadUserXpData();
      notifyListeners();
      if (_data.level > oldLevel) onLevelUp?.call(_data.level);
    } catch (e) {
      debugPrint('Erro ao adicionar XP por comentário: $e');
    }
  }

  Future<void> onComment() async => addXpForComment();

  /// Troca o avatar: salva no Firestore e atualiza o estado local
  /// imediatamente, propagando pra toda a árvore de widgets que escuta
  /// este provider (perfil, comentários, amigos, notificações, etc).
  Future<bool> updateAvatar(String avatarId) async {
    final previous = _data.avatarId;

    // Atualização otimista — a UI muda na hora, em todas as telas
    _data = _data.copyWith(avatarId: avatarId);
    notifyListeners();

    final success = await _avatarService.saveAvatarId(avatarId);

    if (!success) {
      // reverte se falhar ao salvar
      _data = _data.copyWith(avatarId: previous);
      notifyListeners();
    }

    return success;
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
