import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/checkin_rewards_config.dart';
import '../providers/user_xp_provider.dart';
import '../services/checkin_service.dart';
import '../services/rewarded_ad_service.dart';
import '../widgets/checkin_calendar.dart';
import '../widgets/checkin_reward_painters.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({Key? key}) : super(key: key);

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with TickerProviderStateMixin {
  final CheckinService _service = CheckinService();
  final RewardedAdService _adService = RewardedAdService();

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _burstCtrl;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, CheckinDay> _monthCheckins = {};
  bool _loadingMonth = true;

  int _streak = 0;
  int _longestStreak = 0;
  String? _lastCheckinDate;
  DateTime? _firstPossibleDate;
  String? _equippedRewardKey;
  int _recoverableDays = 0;

  bool _checkingIn = false;
  String? _recoveringDayKey;

  // Assinatura do resumo — guardada para poder cancelar no dispose
  // (antes vazava ao sair da tela).
  StreamSubscription<Map<String, dynamic>>? _summarySub;

  // Só recontamos os dias recuperáveis quando algo que influencia
  // essa conta muda (o último dia coberto). Sem isso, cada snapshot
  // do doc de XP (que muda o tempo todo por causa do XP de tempo
  // online) disparava uma query desnecessária.
  String? _lastCountedForDate;
  bool _countedOnce = false;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _adService.preload();
    _loadMonth();
    _listenSummary();
    _rebuildHistoryOnce();
  }

  @override
  void dispose() {
    _summarySub?.cancel();
    _glowCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  // ── Reconstrução da sequência a partir do histórico REAL ──────────
  // Roda no máximo uma vez por sessão do app (ver o serviço). Se algo
  // mudou, o listener de resumo abaixo recebe o novo valor sozinho —
  // não precisamos atualizar a tela manualmente.
  Future<void> _rebuildHistoryOnce() async {
    final report = await _service.ensureHistoryRebuilt();
    if (!mounted) return;
    if (report.ran && report.changed) {
      // Recarrega o calendário: dias antigos reais podem agora
      // aparecer como feitos (o serviço não cria nada, só relê).
      _loadMonth();
    }
  }

  // Único listener do resumo nesta tela (o drawer usa o mesmo stream
  // do serviço, sem criar outro listener no documento).
  void _listenSummary() {
    _summarySub = _service.watchSummary().listen((data) {
      if (!mounted) return;
      final newLast = data['lastCheckinDate'] as String?;
      setState(() {
        _streak = (data['checkinStreak'] as num?)?.toInt() ?? 0;
        _longestStreak = (data['longestCheckinStreak'] as num?)?.toInt() ?? 0;
        _lastCheckinDate = newLast;
        _equippedRewardKey = data['equippedCheckinRewardId'] as String?;
        final firstStr = data['checkinFirstDate'] as String?;
        _firstPossibleDate =
            firstStr != null ? _parseKey(firstStr) : DateTime.now();
      });

      // Só reconta quando o "último dia coberto" muda (ou na
      // primeira vez).
      if (!_countedOnce || _lastCountedForDate != newLast) {
        _countedOnce = true;
        _lastCountedForDate = newLast;
        _refreshRecoverableCount();
      }
    });
  }

  DateTime? _parseKey(String key) {
    try {
      final p = key.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMonth() async {
    setState(() => _loadingMonth = true);
    final data = await _service.loadMonth(_visibleMonth);
    if (!mounted) return;
    setState(() {
      _monthCheckins = data;
      _loadingMonth = false;
    });
  }

  Future<void> _refreshRecoverableCount() async {
    final count = await _service.countRecoverableDays(
      firstPossibleDate: _firstPossibleDate,
    );
    if (!mounted) return;
    setState(() => _recoverableDays = count);
  }

  bool get _isTodayDone {
    final now = DateTime.now();
    final key = _service.dateKey(DateTime(now.year, now.month, now.day));
    return _lastCheckinDate == key;
  }

  void _goToMonth(int offset) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    });
    _loadMonth();
  }

  bool get _canGoNextMonth {
    final now = DateTime.now();
    return _visibleMonth.year < now.year ||
        (_visibleMonth.year == now.year && _visibleMonth.month < now.month);
  }

  Future<void> _handleCheckIn() async {
    if (_checkingIn || _isTodayDone) return;
    setState(() => _checkingIn = true);

    final result = await _service.checkInToday();

    if (!mounted) return;
    setState(() => _checkingIn = false);

    if (result.success) {
      _burstCtrl.forward(from: 0);
      _showResultSheet(result);
      _loadMonth();
    } else if (result.error == 'already_done') {
      _showSnack('Você já fez o check-in de hoje!', isError: false);
    } else {
      _showSnack('Não foi possível fazer o check-in agora. Tente novamente.',
          isError: true);
    }
  }

  void _handleDayTap(DateTime day, CheckinDayStatus status) {
    if (status != CheckinDayStatus.missed) return;
    _showRecoverSheet(day);
  }

  void _showRecoverSheet(DateTime day) {
    final key = _service.dateKey(day);
    final isPremium =
        Provider.of<UserXpProvider>(context, listen: false).data.isPremium;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: !_recoveringDayKeyIs(key),
      builder: (ctx) => _RecoverSheet(
        day: day,
        isPremium: isPremium,
        onWatchAd: () => _recoverDayWithAd(day, ctx),
        onRecoverFree: () => _recoverDayFree(day, ctx),
      ),
    );
  }

  bool _recoveringDayKeyIs(String key) => _recoveringDayKey == key;

  // ── Feedback comum depois de uma recuperação bem-sucedida ─────────
  void _afterRecoverSuccess(CheckinResult result) {
    _loadMonth();
    _refreshRecoverableCount();
    _showSnack('Dia recuperado! +${result.xpGained} XP 🟢', isError: false);
    if (result.unlockedReward != null) {
      // Recuperar um dia pode emendar a sequência e cruzar um marco.
      _showRewardUnlocked(result.unlockedReward!);
    }
  }

  // ── Recuperação direta para usuários Premium (PRO/ULTRA) ──────────
  // Mesma lógica de recoverDay() do fluxo com anúncio, só que sem
  // precisar carregar/exibir o RewardedAd — a vantagem Premium É
  // pular esse passo.
  Future<void> _recoverDayFree(DateTime day, BuildContext sheetContext) async {
    final key = _service.dateKey(day);
    setState(() => _recoveringDayKey = key);

    final result = await _service.recoverDay(day);
    if (!mounted) return;
    setState(() => _recoveringDayKey = null);

    if (Navigator.of(sheetContext, rootNavigator: true).canPop()) {
      Navigator.of(sheetContext).pop();
    }

    if (result.success) {
      _afterRecoverSuccess(result);
    } else if (result.error == 'already_done') {
      _showSnack('Esse dia já foi recuperado.', isError: false);
    } else {
      _showSnack('Não foi possível recuperar o dia agora.', isError: true);
    }
  }

  Future<void> _recoverDayWithAd(DateTime day, BuildContext sheetContext) async {
    final key = _service.dateKey(day);

    if (!_adService.isReady) {
      Navigator.of(sheetContext).pop();
      _showSnack(
        'Anúncio ainda carregando, tente novamente em instantes.',
        isError: true,
      );
      _adService.preload();
      return;
    }

    setState(() => _recoveringDayKey = key);

    await _adService.show(
      onRewardEarned: () async {
        final result = await _service.recoverDay(day);
        if (!mounted) return;
        setState(() => _recoveringDayKey = null);

        if (result.success) {
          _afterRecoverSuccess(result);
        } else if (result.error == 'already_done') {
          _showSnack('Esse dia já foi recuperado.', isError: false);
        } else {
          _showSnack('Não foi possível recuperar o dia agora.',
              isError: true);
        }
      },
      onClosed: () {
        if (Navigator.of(sheetContext, rootNavigator: true).canPop()) {
          Navigator.of(sheetContext).pop();
        }
        if (mounted) setState(() => _recoveringDayKey = null);
      },
      onFailedToShow: () {
        if (Navigator.of(sheetContext, rootNavigator: true).canPop()) {
          Navigator.of(sheetContext).pop();
        }
        if (mounted) setState(() => _recoveringDayKey = null);
        _showSnack('Não foi possível carregar o anúncio agora.',
            isError: true);
      },
    );
  }

  void _showResultSheet(CheckinResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CheckinSuccessSheet(result: result),
    );
  }

  void _showRewardUnlocked(CheckinRewardDef reward) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RewardUnlockedSheet(
        reward: reward,
        onEquip: () async {
          final ok = await _service.setEquippedReward(reward.id.storageKey);
          if (!mounted) return;
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _showSnack(
            ok
                ? '${reward.name} equipado!'
                : 'Não foi possível equipar agora.',
            isError: !ok,
          );
        },
      ),
    );
  }

  Future<void> _toggleEquip(CheckinRewardDef reward) async {
    final isEquipped = _equippedRewardKey == reward.id.storageKey;
    final ok = await _service
        .setEquippedReward(isEquipped ? null : reward.id.storageKey);
    if (!mounted) return;
    if (!ok) {
      _showSnack('Não foi possível equipar agora.', isError: true);
    }
    // O listener de resumo já atualiza _equippedRewardKey sozinho.
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF43B581),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Check-in Diário',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Atmosfera de fundo: brilho laranja no topo + brasas.
          const Positioned.fill(child: _AtmosphereBackground()),
          const Positioned.fill(child: CheckinEmberField(count: 22)),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _buildStreakHero(),
                const SizedBox(height: 16),
                _buildProgressTrack(),
                const SizedBox(height: 16),
                if (_recoverableDays > 0) _buildRecoverableBanner(),
                if (_recoverableDays > 0) const SizedBox(height: 16),
                _loadingMonth
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      )
                    : CheckinCalendar(
                        month: _visibleMonth,
                        monthCheckins: _monthCheckins,
                        firstPossibleDate: _firstPossibleDate,
                        service: _service,
                        canGoNext: _canGoNextMonth,
                        onPrevMonth: () => _goToMonth(-1),
                        onNextMonth: () => _goToMonth(1),
                        onDayTap: _handleDayTap,
                      ),
                const SizedBox(height: 20),
                _buildRewardVault(),
                const SizedBox(height: 24),
                _buildCheckInButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // HERÓI DA SEQUÊNCIA — número gigante + chama + recompensa equipada
  // ═════════════════════════════════════════════════════════════════
  Widget _buildStreakHero() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        final g = _glowAnim.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2A1100).withOpacity(0.78),
                    const Color(0xFF050505).withOpacity(0.90),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.25 + 0.20 * g),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.14 * g),
                    blurRadius: 34,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Núcleo: chama grande (ou recompensa equipada).
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange
                                    .withOpacity(0.35 * g),
                                blurRadius: 44,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        if (_equippedRewardKey != null &&
                            CheckinRewardIdX.fromStorageKey(
                                    _equippedRewardKey) !=
                                null)
                          CheckinRewardBadge(
                              storageKey: _equippedRewardKey, size: 132)
                        else
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFF9100),
                                  Color(0xFFCC3300),
                                ],
                              ),
                              border: Border.all(
                                  color: const Color(0xFFFFB74D), width: 1.4),
                            ),
                            child: const Center(
                              child: FaIcon(FontAwesomeIcons.fire,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Número gigante da sequência.
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFFFB74D)],
                    ).createShader(r),
                    child: Text(
                      '$_streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _streak == 1 ? 'DIA SEGUIDO' : 'DIAS SEGUIDOS',
                    style: TextStyle(
                      color: AppColors.primaryOrange.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeroPill(
                        icon: FontAwesomeIcons.trophy,
                        text: 'Recorde $_longestStreak',
                      ),
                      if (_isTodayDone) ...[
                        const SizedBox(width: 8),
                        const _HeroPill(
                          icon: FontAwesomeIcons.check,
                          text: 'FEITO HOJE',
                          highlight: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TRILHA DE PROGRESSÃO — caminho horizontal entre os marcos
  // ═════════════════════════════════════════════════════════════════
  Widget _buildProgressTrack() {
    final next = CheckinRewardsConfig.nextLocked(_longestStreak);
    final progress =
        CheckinRewardsConfig.progressToNext(_streak, _longestStreak);
    final remaining =
        next == null ? 0 : (next.requiredStreak - _streak).clamp(0, 9999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF080808).withOpacity(0.85),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (next != null) ...[
                CheckinRewardArt(
                    id: next.id, size: 44, locked: true, animate: false),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next == null
                          ? 'COLEÇÃO COMPLETA'
                          : 'PRÓXIMA RECOMPENSA',
                      style: TextStyle(
                        color: AppColors.primaryOrange.withOpacity(0.9),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      next == null
                          ? 'Você conquistou todas as recompensas!'
                          : next.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (next != null)
                      Text(
                        remaining == 0
                            ? 'Faça o check-in de hoje para desbloquear'
                            : 'Faltam $remaining ${remaining == 1 ? 'dia' : 'dias'} · ${next.requiredStreak} dias seguidos',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progresso luminosa.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 8, color: const Color(0xFF1A1A1A)),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFCC4400), Color(0xFFFF9100)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoverableBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFE53935).withOpacity(0.08),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você tem $_recoverableDays ${_recoverableDays == 1 ? 'dia perdido' : 'dias perdidos'}. Toque em um dia vermelho no calendário para recuperar.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // COFRE DE RECOMPENSAS — coleção com desbloqueadas/bloqueadas
  // ═════════════════════════════════════════════════════════════════
  Widget _buildRewardVault() {
    final all = CheckinRewardsConfig.all;
    final unlockedCount = CheckinRewardsConfig.unlockedFor(_longestStreak).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF080808).withOpacity(0.85),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.gem,
                  color: AppColors.primaryOrange, size: 13),
              const SizedBox(width: 8),
              const Text(
                'COFRE DE RECOMPENSAS',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount/${all.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.86,
            ),
            itemCount: all.length,
            itemBuilder: (_, i) => _RewardTile(
              reward: all[i],
              unlocked:
                  CheckinRewardsConfig.isUnlocked(all[i], _longestStreak),
              equipped: _equippedRewardKey == all[i].id.storageKey,
              onTap: () => _onRewardTap(all[i]),
            ),
          ),
        ],
      ),
    );
  }

  void _onRewardTap(CheckinRewardDef reward) {
    final unlocked = CheckinRewardsConfig.isUnlocked(reward, _longestStreak);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RewardDetailSheet(
        reward: reward,
        unlocked: unlocked,
        equipped: _equippedRewardKey == reward.id.storageKey,
        currentStreak: _longestStreak,
        onToggleEquip: () async {
          Navigator.of(ctx).pop();
          await _toggleEquip(reward);
        },
      ),
    );
  }

  Widget _buildCheckInButton() {
    final done = _isTodayDone;
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: done
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryOrange
                        .withOpacity(0.22 + 0.22 * _glowAnim.value),
                    blurRadius: 18 + 10 * _glowAnim.value,
                    spreadRadius: 0.5,
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: done || _checkingIn ? null : _handleCheckIn,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                done ? const Color(0xFF1A1A1A) : AppColors.primaryOrange,
            disabledBackgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: _checkingIn
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      done ? FontAwesomeIcons.check : FontAwesomeIcons.fire,
                      size: 16,
                      color: done ? Colors.white38 : Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      done
                          ? 'Check-in já realizado hoje'
                          : 'Fazer check-in de hoje',
                      style: TextStyle(
                        color: done ? Colors.white38 : Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FUNDO ATMOSFÉRICO — brilho laranja no topo, preto embaixo
// ═══════════════════════════════════════════════════════════════════
class _AtmosphereBackground extends StatelessWidget {
  const _AtmosphereBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.05),
            radius: 1.1,
            colors: [
              AppColors.primaryOrange.withOpacity(0.22),
              const Color(0xFF120600),
              Colors.black,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _HeroPill({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFF43B581) : AppColors.primaryOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 11, color: color),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARTA DA RECOMPENSA — no cofre
// ═══════════════════════════════════════════════════════════════════
class _RewardTile extends StatelessWidget {
  final CheckinRewardDef reward;
  final bool unlocked;
  final bool equipped;
  final VoidCallback onTap;

  const _RewardTile({
    required this.reward,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = reward.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? [accent.withOpacity(0.16), const Color(0xFF0A0A0A)]
                : [const Color(0xFF111111), const Color(0xFF0A0A0A)],
          ),
          border: Border.all(
            color: equipped
                ? accent
                : unlocked
                    ? accent.withOpacity(0.45)
                    : const Color(0xFF232323),
            width: equipped ? 1.8 : 1.1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: accent.withOpacity(equipped ? 0.30 : 0.12),
                    blurRadius: equipped ? 18 : 10,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reward.kind.label,
                  style: TextStyle(
                    color: unlocked ? accent : Colors.white24,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                if (equipped)
                  Icon(Icons.check_circle_rounded, color: accent, size: 14)
                else if (!unlocked)
                  const Icon(Icons.lock_rounded,
                      color: Colors.white24, size: 13),
              ],
            ),
            Expanded(
              child: Center(
                child: CheckinRewardArt(
                  id: reward.id,
                  size: 84,
                  locked: !unlocked,
                  // Só anima o que está desbloqueado (poupa bateria).
                  animate: unlocked,
                ),
              ),
            ),
            Text(
              unlocked ? reward.name : '${reward.requiredStreak} dias',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unlocked ? Colors.white : Colors.white38,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? reward.rarityLabel : 'Bloqueado',
              style: TextStyle(
                color: unlocked ? accent.withOpacity(0.9) : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — detalhe da recompensa (equipar/desequipar)
// ═══════════════════════════════════════════════════════════════════
class _RewardDetailSheet extends StatelessWidget {
  final CheckinRewardDef reward;
  final bool unlocked;
  final bool equipped;
  final int currentStreak;
  final VoidCallback onToggleEquip;

  const _RewardDetailSheet({
    required this.reward,
    required this.unlocked,
    required this.equipped,
    required this.currentStreak,
    required this.onToggleEquip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = reward.accentColor;
    final missing =
        (reward.requiredStreak - currentStreak).clamp(0, 99999);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: accent, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(unlocked ? 0.35 : 0.08),
                        blurRadius: 46,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                CheckinRewardArt(
                    id: reward.id, size: 150, locked: !unlocked),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            unlocked ? reward.name : '???',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${reward.kind.label} · ${reward.rarityLabel.toUpperCase()}',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            unlocked
                ? reward.description
                : 'Alcance ${reward.requiredStreak} dias seguidos para desbloquear.'
                    '${missing > 0 ? ' Faltam $missing.' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white60, fontSize: 13, height: 1.45),
          ),
          if (reward.bonusXp > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Bônus do marco: +${reward.bonusXp} XP',
              style: const TextStyle(
                color: Color(0xFFFFCA28),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: unlocked ? onToggleEquip : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                disabledBackgroundColor: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                !unlocked
                    ? 'Bloqueado'
                    : equipped
                        ? 'Desequipar'
                        : 'Equipar',
                style: TextStyle(
                  color: unlocked ? Colors.black87 : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — recompensa desbloqueada (celebração)
// ═══════════════════════════════════════════════════════════════════
class _RewardUnlockedSheet extends StatelessWidget {
  final CheckinRewardDef reward;
  final Future<void> Function() onEquip;

  const _RewardUnlockedSheet({required this.reward, required this.onEquip});

  @override
  Widget build(BuildContext context) {
    final accent = reward.accentColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NOVA RECOMPENSA',
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.45),
                        blurRadius: 56,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                CheckinRewardArt(id: reward.id, size: 170),
              ],
            ),
          ),
          Text(
            reward.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${reward.kind.label} · ${reward.rarityLabel.toUpperCase()}',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            reward.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Depois',
                        style: TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => onEquip(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Equipar agora',
                        style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — resultado do check-in de hoje
// ═══════════════════════════════════════════════════════════════════
class _CheckinSuccessSheet extends StatelessWidget {
  final CheckinResult result;
  const _CheckinSuccessSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final reward = result.unlockedReward;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.primaryOrange, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF43B581), Color(0xFF2E9464)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43B581).withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 18),
          const Text(
            'Check-in realizado!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '+${result.xpGained} XP',
            style: const TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (result.bonusXp > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Bônus de sequência: +${result.bonusXp} XP',
              style: const TextStyle(
                color: Color(0xFFFFCA28),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFFF6B00).withOpacity(0.12),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(FontAwesomeIcons.fire,
                    color: AppColors.primaryOrange, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Sequência: ${result.streak} ${result.streak == 1 ? 'dia' : 'dias'}',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (result.bonusLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              result.bonusLabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (reward != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: reward.accentColor.withOpacity(0.10),
                border:
                    Border.all(color: reward.accentColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  CheckinRewardArt(id: reward.id, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECOMPENSA DESBLOQUEADA',
                          style: TextStyle(
                            color: reward.accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reward.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Veja no Cofre de Recompensas.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — recuperar dia perdido via anúncio (ou Premium)
// ═══════════════════════════════════════════════════════════════════
class _RecoverSheet extends StatefulWidget {
  final DateTime day;
  final bool isPremium;
  final VoidCallback onWatchAd;
  final VoidCallback onRecoverFree;

  const _RecoverSheet({
    required this.day,
    required this.onWatchAd,
    required this.onRecoverFree,
    this.isPremium = false,
  });

  @override
  State<_RecoverSheet> createState() => _RecoverSheetState();
}

class _RecoverSheetState extends State<_RecoverSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final dayLabel = '${widget.day.day.toString().padLeft(2, '0')}/'
        '${widget.day.month.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE53935).withOpacity(0.15),
              border:
                  Border.all(color: const Color(0xFFE53935).withOpacity(0.5)),
            ),
            child: const Icon(Icons.close_rounded,
                color: Color(0xFFE53935), size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'Você perdeu o check-in de $dayLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isPremium
                ? 'Como Premium, você recupera este dia na hora, sem anúncio.'
                : 'Assista a um anúncio para recuperar este dia e manter sua sequência.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white60, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() => _loading = true);
                      widget.isPremium
                          ? widget.onRecoverFree()
                          : widget.onWatchAd();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isPremium
                    ? const Color(0xFFF2B705)
                    : AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isPremium
                              ? Icons.bolt_rounded
                              : Icons.play_circle_fill_rounded,
                          color: widget.isPremium
                              ? Colors.black87
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isPremium
                              ? 'Recuperar agora (Premium)'
                              : 'Assistir anúncio e recuperar',
                          style: TextStyle(
                            color: widget.isPremium
                                ? Colors.black87
                                : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Agora não',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}