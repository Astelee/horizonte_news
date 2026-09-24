import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_colors.dart';
import '../../../config/badge_config.dart';
import '../../../config/premium_config.dart';
import '../../../services/xp_service.dart';
import '../../../widgets/app_avatar.dart';
import '../../../widgets/avatar_frame.dart';
import '../models/admin_log_model.dart';
import '../services/admin_user_service.dart';
import 'admin_shared_widgets.dart';
import 'ban_user_dialog.dart';
import 'premium_grant_dialog.dart';

/// Abre a "carta de perfil administrativo" de UM usuário em tela cheia.
///
/// Tudo aqui é carregado sob demanda (streams próprios abertos só
/// quando o perfil é aberto e fechados ao sair) — a lista de usuários
/// nunca precisa manter esses dados vivos para todo mundo.
Future<void> showUserProfileSheet(
  BuildContext context, {
  required String userId,
  required AdminUserService userService,
  Map<String, dynamic>? initialData,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: UserProfileSheet(
          userId: userId,
          userService: userService,
          initialData: initialData,
        ),
      ),
    ),
  );
}

class UserProfileSheet extends StatefulWidget {
  final String userId;
  final AdminUserService userService;
  final Map<String, dynamic>? initialData;

  const UserProfileSheet({
    required this.userId,
    required this.userService,
    this.initialData,
    Key? key,
  }) : super(key: key);

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  bool _busy = false;

  // ── Helpers de leitura (mesmo critério usado no resto do painel) ──

  String _resolveName(Map<String, dynamic> d) {
    for (final f in ['displayName', 'name', 'userName']) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final email = (d['email'] as String?) ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Sem nome';
  }

  String _lastSeenLabel(DateTime? lastSeen) {
    if (lastSeen == null) return 'Nunca visto';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 60) return 'Online agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    if (diff.inDays < 30) return 'Há ${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays < 365) return 'Há ${(diff.inDays / 30).floor()} meses';
    return 'Há mais de 1 ano';
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '—';
    return '${_fmtDate(d)} às ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _run(Future<void> Function() action, {String? okMessage}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && okMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(okMessage),
            backgroundColor: const Color(0xFF1A1A1A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível concluir: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Ações administrativas ──────────────────────────────────────

  Future<void> _handlePremium(
      String name, PremiumTier currentTier) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PremiumGrantDialog(
        userName: name,
        currentTier: currentTier,
      ),
    );
    if (result == null) return;

    if (result['revoke'] == true) {
      await _run(
        () => widget.userService.revokePremium(widget.userId),
        okMessage: 'Premium revogado.',
      );
      return;
    }
    final tier = result['tier'] as PremiumTier;
    final days = result['days'] as int;
    await _run(
      () => widget.userService.grantPremium(
        widget.userId,
        tier,
        expiresAt: DateTime.now().add(Duration(days: days)),
      ),
      okMessage: '${tier.label} concedido por $days dias.',
    );
  }

  Future<void> _handleSuspend(String name) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => BanUserDialog(authorName: name),
    );
    if (result == null) return;
    final days = result['days'] as int;
    final tempo = days == 0 ? 'tempo indeterminado' : '$days dias';
    await _run(
      () => widget.userService.suspendUser(
        widget.userId,
        days,
        result['reason'] as String,
      ),
      okMessage: '$name foi suspenso por $tempo.',
    );
  }

  Future<void> _handleUnsuspend(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Remover suspensão?',
        message: '$name poderá comentar novamente.',
        confirmLabel: 'Remover',
        confirmColor: const Color(0xFF66BB6A),
      ),
    );
    if (confirm != true) return;
    await _run(
      () => widget.userService.unsuspendUser(widget.userId),
      okMessage: 'Suspensão de $name removida.',
    );
  }

  Future<void> _handleLevelOverride(int currentLevel) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => _LevelPickerDialog(
        title: 'Definir nível manual',
        initialLevel: currentLevel,
      ),
    );
    if (selected == null) return;
    await _run(
      () => widget.userService.applyLevelOverride(widget.userId, selected),
      okMessage: 'Nível definido manualmente como $selected.',
    );
  }

  Future<void> _handleResetLevel(int realLevel) async {
    await _run(
      () => widget.userService.resetLevelOverride(widget.userId, realLevel),
      okMessage: 'Nível voltou a ser calculado pelo XP real.',
    );
  }

  Future<void> _handleTitleOverride(int currentTitleLevel) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => _LevelPickerDialog(
        title: 'Definir título customizado',
        subtitle: 'O título do nível escolhido será exibido, '
            'sem alterar o nível real do usuário.',
        initialLevel: currentTitleLevel,
      ),
    );
    if (selected == null) return;
    await _run(
      () => widget.userService.applyTitleOverride(widget.userId, selected),
      okMessage: 'Título customizado aplicado.',
    );
  }

  Future<void> _handleResetTitle() async {
    await _run(
      () => widget.userService.resetTitleOverride(widget.userId),
      okMessage: 'Título voltou ao padrão do nível.',
    );
  }

  Future<void> _handleNotify(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Enviar notificação push?',
        message: 'O envio atual do app alcança TODOS os usuários '
            'inscritos — ainda não existe envio individual por '
            'usuário. Esta notificação não será exclusiva para $name.',
        confirmLabel: 'Entendi, ver Publicações',
        confirmColor: AppColors.primaryOrange,
      ),
    );
    if (confirm == true && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificações são enviadas ao publicar uma matéria, '
            'na aba Publicações.',
          ),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    }
  }

  void _copyUid() {
    Clipboard.setData(ClipboardData(text: widget.userId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UID copiado.'),
        backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.12),
                    blurRadius: 40,
                    spreadRadius: -8,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: widget.userService.userDocStream(widget.userId),
                builder: (context, snap) {
                  final d = (snap.hasData && snap.data!.exists)
                      ? snap.data!.data()!
                      : (widget.initialData ?? const <String, dynamic>{});

                  if (!snap.hasData && widget.initialData == null) {
                    return const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryOrange),
                      ),
                    );
                  }
                  if (snap.hasData && !snap.data!.exists) {
                    return _buildNotFound(context);
                  }

                  return _buildContent(context, d);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_rounded,
              size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Este usuário não existe mais.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar',
                style: TextStyle(color: AppColors.primaryOrange)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> d) {
    final name = _resolveName(d);
    final username = d['username'] as String?;
    final email = d['email'] as String? ?? '';
    final photoUrl = d['photoUrl'] as String?;
    final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
    final realLevel = XpService.levelFromXp(xp);
    final hasLevelOverride = d['adminOverrideActive'] == true;
    final overrideLevel = (d['adminOverrideLevel'] as num?)?.toInt();
    final level = hasLevelOverride && overrideLevel != null
        ? overrideLevel
        : realLevel;
    final hasTitleOverride = d['adminOverrideTitleActive'] == true;
    final titleOverrideLevel =
        (d['adminOverrideTitleLevel'] as num?)?.toInt() ?? level;
    final displayTitleLevel =
        hasTitleOverride ? titleOverrideLevel : level;
    final title = BadgeConfig.levelTitle(displayTitleLevel);

    final xpAtLevel = XpService.xpRequiredForLevel(level);
    final xpAtNext = XpService.xpRequiredForLevel(level + 1);
    final xpInLevel = (xp - xpAtLevel).clamp(0, 1 << 30);
    final xpForNext = xpAtNext - xpAtLevel;
    final progress =
        xpForNext > 0 ? (xpInLevel / xpForNext).clamp(0.0, 1.0) : 1.0;

    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final lastSeenAt = (d['lastSeenAt'] as Timestamp?)?.toDate();
    final isOnline = lastSeenAt != null &&
        DateTime.now().difference(lastSeenAt).inMinutes < 5;

    final stats = Map<String, dynamic>.from(d['stats'] ?? {});
    final articlesRead = (stats['articlesRead'] as num?)?.toInt() ?? 0;
    final commentsPosted = (stats['commentsPosted'] as num?)?.toInt() ?? 0;
    final articlesShared = (stats['articlesShared'] as num?)?.toInt() ?? 0;

    final checkinStreak = (d['checkinStreak'] as num?)?.toInt() ?? 0;
    final longestStreak = (d['longestCheckinStreak'] as num?)?.toInt() ?? 0;
    final lastCheckinDate = d['lastCheckinDate'] as String?;

    final premiumTier = premiumTierFromData(d);
    final premiumExpiresAt =
        (d['premiumExpiresAt'] as Timestamp?)?.toDate();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, d, name, photoUrl, level, isOnline, lastSeenAt),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _identityBlock(username, email, createdAt),
                const SizedBox(height: 18),
                _sectionTitle('PROGRESSO', Icons.bolt_rounded),
                const SizedBox(height: 10),
                _progressBlock(level, title, xp, xpInLevel, xpForNext,
                    progress, hasLevelOverride, hasTitleOverride),
                const SizedBox(height: 18),
                _sectionTitle('ESTATÍSTICAS', Icons.query_stats_rounded),
                const SizedBox(height: 10),
                _statsGrid(articlesRead, commentsPosted, articlesShared,
                    checkinStreak, longestStreak, lastCheckinDate),
                const SizedBox(height: 18),
                _sectionTitle('PREMIUM', Icons.workspace_premium_rounded),
                const SizedBox(height: 10),
                _premiumBlock(name, premiumTier, premiumExpiresAt),
                const SizedBox(height: 18),
                _sectionTitle('MODERAÇÃO', Icons.shield_rounded),
                const SizedBox(height: 10),
                _moderationBlock(name),
                const SizedBox(height: 18),
                _sectionTitle('AÇÕES ADMINISTRATIVAS',
                    Icons.admin_panel_settings_rounded),
                const SizedBox(height: 10),
                _actionsGrid(name, level, realLevel, hasLevelOverride,
                    hasTitleOverride, titleOverrideLevel, premiumTier),
                const SizedBox(height: 22),
                _sectionTitle('HISTÓRICO', Icons.history_rounded),
                const SizedBox(height: 10),
                _historyBlock(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cabeçalho ───────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, Map<String, dynamic> d,
      String name, String? photoUrl, int level, bool isOnline,
      DateTime? lastSeenAt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOrange.withOpacity(0.10),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarFrame(
                level: level,
                size: 72,
                enableEntryAnimation: false,
                child: UserAvatarDisplay(
                  name: name,
                  seed: widget.userId,
                  photoUrl: photoUrl,
                  equippedPremiumAvatarId:
                      d['equippedPremiumAvatarId'] as String?,
                  equippedCheckinRewardId:
                      d['equippedCheckinRewardId'] as String?,
                  size: 72,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isOnline
                              ? Icons.circle
                              : Icons.access_time_rounded,
                          size: 10,
                          color: isOnline
                              ? const Color(0xFF43B581)
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? 'Online agora' : _lastSeenLabel(lastSeenAt),
                          style: TextStyle(
                            color: isOnline
                                ? const Color(0xFF43B581)
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Blocos de conteúdo ──────────────────────────────────────────

  Widget _sectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.borderDark,
          ),
        ),
      ],
    );
  }

  Widget _identityBlock(String? username, String email, DateTime? createdAt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (username != null && username.trim().isNotEmpty)
            _infoRow(Icons.alternate_email_rounded, '@$username'),
          if (email.isNotEmpty)
            _infoRow(Icons.email_rounded, email),
          _infoRow(Icons.event_available_rounded,
              'Cadastrado em ${_fmtDate(createdAt)}'),
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.userId,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _copyUid,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Icon(Icons.copy_rounded,
                      size: 15, color: AppColors.primaryOrange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBlock(
    int level,
    String title,
    int xp,
    int xpInLevel,
    int xpForNext,
    double progress,
    bool hasLevelOverride,
    bool hasTitleOverride,
  ) {
    final color = BadgeConfig.levelColor(level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Nível $level',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasLevelOverride)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: AdminBadge(label: 'NÍVEL MANUAL', color: Color(0xFFFFD700)),
                ),
              if (hasTitleOverride)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: AdminBadge(label: 'TÍTULO CUSTOM', color: Color(0xFFFFD700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            xpForNext > 0
                ? '$xpInLevel / $xpForNext XP para o próximo nível'
                : 'Nível máximo atingido',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            '$xp XP total',
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(
    int articlesRead,
    int commentsPosted,
    int articlesShared,
    int checkinStreak,
    int longestStreak,
    String? lastCheckinDate,
  ) {
    final items = [
      (Icons.article_rounded, 'Matérias lidas', '$articlesRead',
          const Color(0xFF66BB6A)),
      (Icons.chat_bubble_rounded, 'Comentários', '$commentsPosted',
          const Color(0xFF4FC3F7)),
      (Icons.share_rounded, 'Compartilhamentos', '$articlesShared',
          const Color(0xFF9575CD)),
      (Icons.local_fire_department_rounded, 'Sequência atual',
          '$checkinStreak dias', const Color(0xFFFF9800)),
      (Icons.emoji_events_rounded, 'Maior sequência',
          '$longestStreak dias', const Color(0xFFFFD700)),
      (Icons.calendar_today_rounded, 'Último check-in',
          lastCheckinDate ?? '—', AppColors.primaryOrange),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 300;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: twoCols
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$1, size: 16, color: item.$4),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$3,
                              style: TextStyle(
                                color: item.$4,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _premiumBlock(
      String name, PremiumTier tier, DateTime? expiresAt) {
    final isPremium = tier.isPremium;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPremium
              ? tier.accentColor.withOpacity(0.4)
              : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? tier.icon : Icons.workspace_premium_outlined,
            color: isPremium ? tier.accentColor : AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? tier.label : 'Sem plano Premium',
                  style: TextStyle(
                    color: isPremium ? tier.accentColor : Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isPremium)
                  Text(
                    expiresAt != null
                        ? 'Válido até ${_fmtDate(expiresAt)}'
                        : 'Sem data de expiração registrada',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moderationBlock(String name) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.userService.suspensionDocStream(widget.userId),
      builder: (context, snap) {
        final exists = snap.hasData && snap.data!.exists;
        if (!exists) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF66BB6A).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF66BB6A), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nenhuma suspensão ativa',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        final d = snap.data!.data()!;
        final reason = (d['reason'] as String?)?.trim() ?? '';
        final suspendedAt = (d['suspendedAt'] as Timestamp?)?.toDate();
        final until = (d['until'] as Timestamp?)?.toDate();
        final isPermanent = until == null;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFEF5350).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.block_rounded,
                      color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isPermanent
                        ? 'Suspenso permanentemente'
                        : 'Suspenso até ${_fmtDate(until)}',
                    style: const TextStyle(
                      color: Color(0xFFEF5350),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Motivo: $reason',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Desde ${_fmtDateTime(suspendedAt)}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionsGrid(
    String name,
    int level,
    int realLevel,
    bool hasLevelOverride,
    bool hasTitleOverride,
    int titleOverrideLevel,
    PremiumTier premiumTier,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.userService.suspensionDocStream(widget.userId),
      builder: (context, snap) {
        final isSuspended = snap.hasData && snap.data!.exists;

        final actions = <Widget>[
          _actionButton(
            icon: premiumTier.isPremium
                ? Icons.workspace_premium_rounded
                : Icons.workspace_premium_outlined,
            label: premiumTier.isPremium
                ? 'Gerenciar Premium'
                : 'Conceder Premium',
            color: const Color(0xFFF2B705),
            onTap: () => _handlePremium(name, premiumTier),
          ),
          isSuspended
              ? _actionButton(
                  icon: Icons.lock_open_rounded,
                  label: 'Remover suspensão',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _handleUnsuspend(name),
                )
              : _actionButton(
                  icon: Icons.block_rounded,
                  label: 'Suspender usuário',
                  color: const Color(0xFFFF9800),
                  onTap: () => _handleSuspend(name),
                ),
          _actionButton(
            icon: Icons.trending_up_rounded,
            label: 'Definir nível manual',
            color: const Color(0xFFFFD54F),
            onTap: () => _handleLevelOverride(level),
          ),
          if (hasLevelOverride)
            _actionButton(
              icon: Icons.restart_alt_rounded,
              label: 'Resetar nível',
              color: AppColors.textSecondary,
              onTap: () => _handleResetLevel(realLevel),
            ),
          _actionButton(
            icon: Icons.badge_rounded,
            label: 'Definir título',
            color: const Color(0xFF9575CD),
            onTap: () => _handleTitleOverride(titleOverrideLevel),
          ),
          if (hasTitleOverride)
            _actionButton(
              icon: Icons.restart_alt_rounded,
              label: 'Resetar título',
              color: AppColors.textSecondary,
              onTap: _handleResetTitle,
            ),
          _actionButton(
            icon: Icons.campaign_rounded,
            label: 'Enviar notificação',
            color: const Color(0xFF4FC3F7),
            onTap: () => _handleNotify(name),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 300;
            return Column(
              children: [
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                        color: AppColors.primaryOrange,
                        backgroundColor: Colors.transparent),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final a in actions)
                      SizedBox(
                        width: twoCols
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth,
                        child: a,
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyBlock() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.userService.userLogsStream(widget.userId),
      builder: (context, snap) {
        if (snap.hasError) {
          // Causa mais comum: falta o índice composto do Firestore
          // para admin_logs (targetId ASC + timestamp DESC) — a
          // consulta nunca retorna e, sem este tratamento, o
          // StreamBuilder ficava girando o loading para sempre em vez
          // de mostrar o erro.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Não foi possível carregar o histórico.\n${snap.error}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11, height: 1.4),
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryOrange),
              ),
            ),
          );
        }
        final logs = snap.data!;
        if (logs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhuma ação administrativa registrada para este usuário.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          );
        }
        return Column(
          children: logs.map((l) {
            final log = AdminLogModel(
              id: l['id'] as String? ?? '',
              adminUid: l['adminUid'] as String? ?? '',
              adminName: l['adminName'] as String? ?? 'Admin',
              action: l['action'] as String? ?? '',
              targetId: l['targetId'] as String? ?? '',
              targetType: l['targetType'] as String? ?? 'user',
              timestamp:
                  (l['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        size: 12, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.actionLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'por ${log.adminName} · ${_fmtDateTime(log.timestamp)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Seletor de nível (1..maxLevel) reutilizado tanto para override de
/// nível quanto de título — cada chamada explica seu próprio efeito.
class _LevelPickerDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int initialLevel;

  const _LevelPickerDialog({
    required this.title,
    required this.initialLevel,
    this.subtitle,
  });

  @override
  State<_LevelPickerDialog> createState() => _LevelPickerDialogState();
}

class _LevelPickerDialogState extends State<_LevelPickerDialog> {
  late int _level;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel.clamp(1, XpService.maxLevel);
  }

  @override
  Widget build(BuildContext context) {
    final color = BadgeConfig.levelColor(_level);
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nível $_level',
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                BadgeConfig.levelTitle(_level),
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: _level.toDouble(),
              min: 1,
              max: XpService.maxLevel.toDouble(),
              divisions: XpService.maxLevel - 1,
              onChanged: (v) => setState(() => _level = v.round()),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _level),
          child: Text('Aplicar',
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}