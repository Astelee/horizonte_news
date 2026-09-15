import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/user_xp_provider.dart';
import '../services/checkin_service.dart';
import '../services/rewarded_ad_service.dart';
import '../widgets/checkin_calendar.dart';

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
  int _recoverableDays = 0;

  bool _checkingIn = false;
  String? _recoveringDayKey;

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
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  void _listenSummary() {
    _service.watchSummary().listen((data) {
      if (!mounted) return;
      final newLast = data['lastCheckinDate'] as String?;
      setState(() {
        _streak = (data['checkinStreak'] as num?)?.toInt() ?? 0;
        _longestStreak = (data['longestCheckinStreak'] as num?)?.toInt() ?? 0;
        _lastCheckinDate = newLast;
        final firstStr = data['checkinFirstDate'] as String?;
        _firstPossibleDate =
            firstStr != null ? _parseKey(firstStr) : DateTime.now();
      });
      _refreshRecoverableCount();
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
      _loadMonth();
      _refreshRecoverableCount();
      _showSnack('Dia recuperado! +${result.xpGained} XP 🟢', isError: false);
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
          _loadMonth();
          _refreshRecoverableCount();
          _showSnack('Dia recuperado! +${result.xpGained} XP 🟢',
              isError: false);
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
      builder: (_) => _CheckinSuccessSheet(result: result),
    );
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
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text(
          'Check-in Diário',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _buildSummaryCard(),
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
            _buildStreakLadder(),
            const SizedBox(height: 24),
            _buildCheckInButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0D00), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: AppColors.primaryOrange
                .withOpacity(0.25 + 0.15 * _glowAnim.value),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.08 * _glowAnim.value),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6D00), Color(0xFFCC3300)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange
                        .withOpacity(0.4 * _glowAnim.value),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: FaIcon(FontAwesomeIcons.fire,
                    color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_streak ${_streak == 1 ? 'dia' : 'dias'} seguidos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recorde: $_longestStreak dias',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_isTodayDone)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF43B581).withOpacity(0.15),
                  border: Border.all(
                      color: const Color(0xFF43B581).withOpacity(0.5)),
                ),
                child: const Text(
                  'FEITO HOJE',
                  style: TextStyle(
                    color: Color(0xFF43B581),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
          ],
        ),
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

  Widget _buildStreakLadder() {
    final milestones = [7, 14, 30, 60, 100];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              FaIcon(FontAwesomeIcons.trophy,
                  color: AppColors.primaryOrange, size: 13),
              SizedBox(width: 8),
              Text(
                'RECOMPENSAS DE SEQUÊNCIA',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...milestones.map((m) {
            final reached = _longestStreak >= m || _streak >= m;
            final bonus = CheckinService.bonusForStreak(m);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached
                          ? AppColors.primaryOrange.withOpacity(0.18)
                          : const Color(0xFF141414),
                      border: Border.all(
                        color: reached
                            ? AppColors.primaryOrange
                            : const Color(0xFF262626),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        reached ? Icons.check_rounded : Icons.lock_rounded,
                        size: 14,
                        color: reached
                            ? AppColors.primaryOrange
                            : Colors.white24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$m dias seguidos',
                      style: TextStyle(
                        color: reached ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    m == 100 ? '+$bonus XP 🏆' : '+$bonus XP',
                    style: TextStyle(
                      color: reached
                          ? AppColors.primaryOrange
                          : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCheckInButton() {
    final done = _isTodayDone;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: done || _checkingIn ? null : _handleCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              done ? const Color(0xFF1A1A1A) : AppColors.primaryOrange,
          disabledBackgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: done ? 0 : 4,
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
            : Text(
                done ? 'Check-in já realizado hoje' : 'Fazer check-in de hoje',
                style: TextStyle(
                  color: done ? Colors.white38 : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
// BOTTOM SHEET — recuperar dia perdido via anúncio
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