import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/premium_config.dart';
import '../services/app_notification_service.dart';
import '../services/checkin_reminder_service.dart';
import '../services/notification_service.dart';
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

  // Dispara a re-sincronização da tag `tier` do OneSignal no momento
  // em que o Premium vence (o Firestore não emite evento quando só o
  // relógio passa da data de expiração).
  Timer? _tierExpiryTimer;

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

    // Lembrete local da sequência de check-in: alinha com o resumo
    // atual ao entrar (não altera XP nem check-in).
    CheckinReminderService.instance.syncFromFirestore(force: true);
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
      _syncPremiumTag();
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
        // Se o Premium venceu enquanto o app estava em segundo plano,
        // corrige a tag do OneSignal ao voltar.
        _syncPremiumTag();
        _updateLastSeen();
        _startTimer();
        // Ao voltar do segundo plano (no máximo a cada 15 min, ver
        // o serviço), reconfere se o lembrete de sequência segue certo.
        CheckinReminderService.instance.syncFromFirestore();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App minimizado, mas o processo continua vivo: o timer segue
        // contando XP normalmente. Só garantimos que o progresso
        // acumulado até agora seja salvo, caso o Android decida matar
        // o processo sem avisar (comum em segundo plano prolongado).
        if (_secondsAccumulated > 0) {
          _flushToFirestore();
        }
        break;
      case AppLifecycleState.detached:
        // Processo sendo destruído de verdade (app fechado/deslizado
        // para fora): aí sim paramos o timer e salvamos o resto.
        _pauseAndSave();
        break;
    }
  }

  // ── Tag `tier` do OneSignal (none / pro / ultra) ─────────────────
  // Chamada a cada snapshot de users_xp/{uid}, então cobre login,
  // assinatura nova, troca de plano e cancelamento. O plano é
  // calculado por premiumTierFromData (mesma regra do resto do app),
  // que já devolve none quando premiumExpiresAt passou. Para o caso
  // do vencimento acontecer com o app aberto, agenda um timer.
  void _syncPremiumTag() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final expiresAt = _data.premiumExpiresAt;
    final tier = premiumTierFromData({
      'premiumTier': _data.premiumTier.id,
      if (expiresAt != null) 'premiumExpiresAt': Timestamp.fromDate(expiresAt),
    });

    NotificationService.syncPremiumTier(uid, tier);

    // Aviso de "assinatura perto de vencer" (até 3 dias antes). O
    // serviço só age dentro da janela e uma vez por vencimento.
    if (tier.isPremium && expiresAt != null) {
      AppNotificationService.notifyPremiumExpiringSoon(
        uid: uid,
        tier: tier,
        expiresAt: expiresAt,
      );
    }

    _tierExpiryTimer?.cancel();
    _tierExpiryTimer = null;
    if (tier.isPremium && expiresAt != null) {
      var delay = expiresAt.difference(DateTime.now()) +
          const Duration(seconds: 1);
      if (delay.isNegative) delay = const Duration(seconds: 1);
      // Limita a espera; ao disparar, recalcula e reagenda se preciso.
      const maxDelay = Duration(hours: 6);
      if (delay > maxDelay) delay = maxDelay;
      _tierExpiryTimer = Timer(delay, _syncPremiumTag);
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

  // ── Curtidas em comentários ───────────────────────────────────────
  // Aqui não mexemos em _data porque o XP é creditado no documento
  // do AUTOR do comentário, não no de quem está curtindo.
  Future<bool> likeComment({
    required String postId,
    required String commentId,
    required String authorUid,
    String? parentCommentId,
  }) {
    return _service.likeComment(
      postId: postId,
      commentId: commentId,
      authorUid: authorUid,
      parentCommentId: parentCommentId,
    );
  }

  Future<bool> unlikeComment({
    required String postId,
    required String commentId,
    required String likerUid,
    String? parentCommentId,
  }) {
    return _service.unlikeComment(
      postId: postId,
      commentId: commentId,
      likerUid: likerUid,
      parentCommentId: parentCommentId,
    );
  }

  // ── Avatares animados premium ────────────────────────────────────
  // Atualiza otimisticamente (_data local) e grava no Firestore. O
  // stream de _startWatching também vai receber a mudança logo em
  // seguida e confirmar o mesmo valor, então não há risco de
  // divergência — só evita esperar o round-trip para a UI reagir.
  Future<void> setEquippedPremiumAvatar(String? avatarStorageKeyOrNull) async {
    _data = _data.copyWith(
      equippedPremiumAvatarId: avatarStorageKeyOrNull,
      clearEquippedPremiumAvatar: avatarStorageKeyOrNull == null,
    );
    notifyListeners();
    await _service.setEquippedPremiumAvatar(avatarStorageKeyOrNull);
  }

  Future<void> setEquippedPet(String? petId) async {
    _data = _data.copyWith(
      equippedPetId: petId,
      clearEquippedPet: petId == null,
    );
    notifyListeners();
    await _service.setEquippedPet(petId);
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
    _xpSubscription?.cancel();
    _tierExpiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}