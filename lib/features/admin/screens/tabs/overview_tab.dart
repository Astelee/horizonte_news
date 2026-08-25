import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/badge_config.dart';
import '../../../../widgets/app_avatar.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/admin_user_service.dart';
import '../../models/admin_log_model.dart';
import '../../widgets/dashboard_widgets.dart';

class OverviewTab extends StatefulWidget {
  final AdminDashboardService dashboardService;
  final AdminUserService userService;
  final VoidCallback onGoToUsers;
  final VoidCallback onGoToViews;
  final VoidCallback onGoToBanned;

  const OverviewTab({
    required this.dashboardService,
    required this.userService,
    required this.onGoToUsers,
    required this.onGoToViews,
    required this.onGoToBanned,
    Key? key,
  }) : super(key: key);

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _syncing = false;

  Future<void> _syncLevels() async {
    setState(() => _syncing = true);
    try {
      await widget.userService.syncAllUserLevels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Níveis de todos os usuários sincronizados.'),
            backgroundColor: Color(0xFF1A1A1A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _timeAgo(DateTime? d) {
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays < 30) return 'há ${diff.inDays}d';
    return 'há ${(diff.inDays / 30).floor()} meses';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder<DashboardSnapshot>(
        stream: widget.dashboardService.dashboardStream(),
        builder: (context, snap) {
          final data = snap.data;
          if (data == null || (!snap.hasData)) {
            return const DashboardSkeleton();
          }
          if (data.totalUsers == 0) {
            return RefreshIndicator(
              color: AppColors.primaryOrange,
              onRefresh: () async {},
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.dashboard_customize_rounded,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Ainda não há dados suficientes',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
              children: [
                _buildKpiGrid(data),
                const SizedBox(height: 22),
                _buildQuickActions(),
                const SizedBox(height: 22),
                _buildLevelDistribution(data),
                const SizedBox(height: 22),
                _buildTopRanking(data),
                const SizedBox(height: 22),
                _buildTopPosts(data),
                const SizedBox(height: 22),
                _buildTopShared(data),
                const SizedBox(height: 22),
                _buildRecentActivity(),
                const SizedBox(height: 22),
                _buildRecentlyActiveUsers(data),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── KPIs principais ────────────────────────────────────────────
  Widget _buildKpiGrid(DashboardSnapshot data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.people_alt_rounded,
                color: AppColors.primaryOrange,
                label: 'Usuários totais',
                value: data.totalUsers,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.circle,
                color: const Color(0xFF43B581),
                label: 'Online agora',
                value: data.onlineNow,
                live: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.bolt_rounded,
                color: const Color(0xFFFFD54F),
                label: 'XP total da comunidade',
                value: data.totalXp,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.access_time_filled_rounded,
                color: const Color(0xFF4FC3F7),
                label: 'Ativos nas últimas 24h',
                value: data.activeToday,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.chat_bubble_rounded,
                color: const Color(0xFF9575CD),
                label: 'Comentários',
                value: data.totalComments,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.visibility_rounded,
                color: const Color(0xFFEF5350),
                label: 'Views (top matérias)',
                value: data.totalViews,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.article_rounded,
                color: const Color(0xFF66BB6A),
                label: 'Notícias lidas',
                value: data.totalArticlesRead,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.block_rounded,
                color: const Color(0xFFE53935),
                label: 'Usuários suspensos',
                value: data.totalSuspended,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.share_rounded,
                color: const Color(0xFF66BB6A),
                label: 'Compartilhamentos',
                value: data.totalShares,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  // ── Ações rápidas ───────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashSectionTitle(
          title: 'AÇÕES RÁPIDAS',
          icon: Icons.flash_on_rounded,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickActionChip(
                icon: Icons.people_rounded,
                label: 'Usuários',
                color: AppColors.primaryOrange,
                onTap: widget.onGoToUsers,
              ),
              const SizedBox(width: 8),
              _QuickActionChip(
                icon: Icons.bar_chart_rounded,
                label: 'Visualizações',
                color: const Color(0xFF4FC3F7),
                onTap: widget.onGoToViews,
              ),
              const SizedBox(width: 8),
              _QuickActionChip(
                icon: Icons.block_rounded,
                label: 'Banidos',
                color: const Color(0xFFE53935),
                onTap: widget.onGoToBanned,
              ),
              const SizedBox(width: 8),
              _QuickActionChip(
                icon: Icons.sync_rounded,
                label: _syncing ? 'Sincronizando...' : 'Sincronizar níveis',
                color: const Color(0xFF66BB6A),
                onTap: _syncing ? null : _syncLevels,
                loading: _syncing,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Distribuição de níveis (donut) ──────────────────────────────
  Widget _buildLevelDistribution(DashboardSnapshot data) {
    final labels = {
      1: 'Nv 1-4',
      5: 'Nv 5-9',
      10: 'Nv 10-16',
      17: 'Nv 17-22',
      23: 'Nv 23-29',
      30: 'Nv 30+',
    };
    final colors = {
      1: const Color(0xFF66BB6A),
      5: const Color(0xFF4FC3F7),
      10: const Color(0xFF9575CD),
      17: const Color(0xFFFFD54F),
      23: AppColors.primaryOrange,
      30: const Color(0xFFEF5350),
    };

    final slices = data.levelDistribution.entries
        .map((e) => DonutSlice(
              e.value.toDouble(),
              colors[e.key] ?? AppColors.textMuted,
              labels[e.key] ?? 'Nv ${e.key}',
            ))
        .toList()
      ..sort((a, b) => (labels.values.toList().indexOf(a.label))
          .compareTo(labels.values.toList().indexOf(b.label)));

    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashSectionTitle(
            title: 'DISTRIBUIÇÃO DE NÍVEIS',
            icon: Icons.pie_chart_rounded,
          ),
          Row(
            children: [
              AnimatedDonutChart(
                slices: slices,
                centerValue: data.totalUsers,
                centerLabel: 'usuários',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in slices)
                      if (s.value > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: s.color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  s.label,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${s.value.round()}',
                                style: TextStyle(
                                  color: s.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    Text(
                      'Nível médio: ${data.avgLevel.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
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

  // ── Top 5 ranking por XP ────────────────────────────────────────
  Widget _buildTopRanking(DashboardSnapshot data) {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashSectionTitle(
            title: 'TOP 5 — RANKING GERAL',
            icon: Icons.emoji_events_rounded,
            trailing: GestureDetector(
              onTap: widget.onGoToUsers,
              child: const Text(
                'ver todos',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          for (int i = 0; i < data.topByXp.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RankRow(rank: i + 1, user: data.topByXp[i]),
            ),
        ],
      ),
    );
  }

  // ── Top posts mais vistos ───────────────────────────────────────
  Widget _buildTopPosts(DashboardSnapshot data) {
    if (data.topPosts.isEmpty) return const SizedBox.shrink();
    final bars = data.topPosts
        .map((p) => BarChartData(
              p.title.length > 10 ? '${p.title.substring(0, 10)}…' : p.title,
              p.totalViews.toDouble(),
              AppColors.primaryOrange,
            ))
        .toList();

    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashSectionTitle(
            title: 'MATÉRIAS MAIS VISTAS',
            icon: Icons.trending_up_rounded,
            trailing: GestureDetector(
              onTap: widget.onGoToViews,
              child: const Text(
                'ver todas',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          AnimatedBarChart(data: bars),
        ],
      ),
    );
  }

  // ── Top posts mais compartilhados ───────────────────────────────
  Widget _buildTopShared(DashboardSnapshot data) {
    if (data.topShared.isEmpty) return const SizedBox.shrink();
    final bars = data.topShared
        .map((p) => BarChartData(
              p.title.length > 10 ? '${p.title.substring(0, 10)}…' : p.title,
              p.totalViews.toDouble(),
              const Color(0xFF66BB6A),
            ))
        .toList();

    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashSectionTitle(
            title: 'MATÉRIAS MAIS COMPARTILHADAS',
            icon: Icons.share_rounded,
          ),
          AnimatedBarChart(data: bars),
        ],
      ),
    );
  }

  // ── Atividade recente (admin_logs) ──────────────────────────────
  Widget _buildRecentActivity() {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashSectionTitle(
            title: 'ATIVIDADE RECENTE',
            icon: Icons.history_rounded,
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.dashboardService.recentLogsStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: ShimmerBox(height: 60),
                );
              }
              final logs = snap.data!;
              if (logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Nenhuma ação administrativa registrada ainda.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                );
              }
              return Column(
                children: logs.map((l) {
                  final log = _logFromMap(l);
                  return _ActivityRow(log: log, timeAgo: _timeAgo);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Usuários mais recentemente ativos ───────────────────────────
  Widget _buildRecentlyActiveUsers(DashboardSnapshot data) {
    if (data.mostRecentlyActive.isEmpty) return const SizedBox.shrink();
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashSectionTitle(
            title: 'ATIVIDADE DE USUÁRIOS RECENTE',
            icon: Icons.person_pin_circle_rounded,
          ),
          for (final u in data.mostRecentlyActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      AppAvatar(name: u.name, seed: u.uid, size: 34),
                      if (u.isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF43B581),
                              border: Border.all(
                                  color: const Color(0xFF0A0A0A), width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Nv ${u.level} · ${BadgeConfig.levelTitle(u.level)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _timeAgo(u.lastActivity),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AUXILIARES
// ═══════════════════════════════════════════════════════════════════
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final DashUser user;
  const _RankRow({required this.rank, required this.user});

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$rank°',
            style: TextStyle(
              color: _rankColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        AppAvatar(name: user.name, seed: user.uid, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Nv ${user.level} · ${BadgeConfig.levelTitle(user.level)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${user.totalXp} XP',
          style: const TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final AdminLogModel log;
  final String Function(DateTime?) timeAgo;
  const _ActivityRow({required this.log, required this.timeAgo});

  IconData get _icon {
    switch (log.action) {
      case 'hide_comment':
        return Icons.visibility_off_rounded;
      case 'restore_comment':
        return Icons.visibility_rounded;
      case 'delete_comment':
        return Icons.delete_rounded;
      case 'suspend_user':
        return Icons.block_rounded;
      case 'unsuspend_user':
        return Icons.check_circle_rounded;
      case 'level_override':
      case 'title_override':
        return Icons.auto_awesome_rounded;
      case 'level_reset':
      case 'title_reset':
        return Icons.restart_alt_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color get _color {
    switch (log.action) {
      case 'suspend_user':
      case 'delete_comment':
        return const Color(0xFFE53935);
      case 'unsuspend_user':
      case 'restore_comment':
        return const Color(0xFF43B581);
      case 'level_override':
      case 'title_override':
        return const Color(0xFFFFD700);
      default:
        return AppColors.primaryOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 13, color: _color),
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
                  'por ${log.adminName}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeAgo(log.timestamp),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Constrói um [AdminLogModel] diretamente a partir do Map retornado pelo
/// stream de logs (evita depender de um DocumentSnapshot real).
AdminLogModel _logFromMap(Map<String, dynamic> d) {
  final extra = Map<String, dynamic>.from(d)
    ..remove('id')
    ..remove('adminUid')
    ..remove('adminName')
    ..remove('action')
    ..remove('targetId')
    ..remove('targetType')
    ..remove('postId')
    ..remove('timestamp');
  return AdminLogModel(
    id: d['id'] as String? ?? '',
    adminUid: d['adminUid'] as String? ?? '',
    adminName: d['adminName'] as String? ?? 'Admin',
    action: d['action'] as String? ?? '',
    targetId: d['targetId'] as String? ?? '',
    targetType: d['targetType'] as String? ?? 'unknown',
    postId: d['postId'] as String?,
    timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    extra: extra,
  );
}
