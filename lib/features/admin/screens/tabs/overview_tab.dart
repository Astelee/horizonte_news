import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/badge_config.dart';
import '../../../../widgets/app_avatar.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_news_service.dart';
import '../../services/admin_comment_service.dart';
import '../../models/admin_log_model.dart';
import '../../widgets/dashboard_widgets.dart';

class OverviewTab extends StatefulWidget {
  final AdminDashboardService dashboardService;
  final AdminUserService userService;
  final AdminNewsService newsService;
  final AdminCommentService commentService;
  final VoidCallback onGoToUsers;
  final VoidCallback onGoToViews;
  final VoidCallback onGoToBanned;
  final VoidCallback onGoToNews;
  final VoidCallback onGoToComments;
  final VoidCallback onGoToLevels;

  const OverviewTab({
    required this.dashboardService,
    required this.userService,
    required this.newsService,
    required this.commentService,
    required this.onGoToUsers,
    required this.onGoToViews,
    required this.onGoToBanned,
    required this.onGoToNews,
    required this.onGoToComments,
    required this.onGoToLevels,
    Key? key,
  }) : super(key: key);

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _syncing = false;
  DashboardSnapshot? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!_loading) setState(() => _loading = true);
    final data = await widget.dashboardService.loadDashboard();
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  Future<void> _syncLevels() async {
    setState(() => _syncing = true);
    try {
      await widget.userService.syncAllUserLevels();
      await _loadDashboard();
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
    final data = _data;
    return Container(
      color: AppColors.backgroundDark,
      child: Builder(
        builder: (context) {
          if (data == null && _loading) {
            return const DashboardSkeleton();
          }
          if (data == null || data.totalUsers == 0) {
            return RefreshIndicator(
              color: AppColors.primaryOrange,
              onRefresh: _loadDashboard,
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
            onRefresh: _loadDashboard,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
              children: [
                _buildKpiGrid(data),
                const SizedBox(height: 26),
                _buildManagementCenter(),
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
                label: 'Visualizações (top matérias)',
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

  // ── Central de Gestão ──────────────────────────────────────────
  Widget _buildManagementCenter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_rounded,
                size: 17, color: AppColors.primaryOrange),
            const SizedBox(width: 8),
            const Text(
              'CENTRAL DE GESTÃO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Padding(
          padding: EdgeInsets.only(left: 25),
          child: Text(
            'Gerencie todos os recursos do sistema',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Card principal — Publicações (destaque total)
        _PublicationsManagementCard(
          newsService: widget.newsService,
          onTap: widget.onGoToNews,
        ),
        const SizedBox(height: 12),

        // Grade 2 colunas — demais recursos
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 300;
            final tiles = <Widget>[
              _ManagementTile(
                icon: Icons.people_alt_rounded,
                color: AppColors.primaryOrange,
                title: 'USUÁRIOS',
                subtitle: 'Gerenciar usuários cadastrados',
                onTap: widget.onGoToUsers,
              ),
              _CommentsManagementTile(
                commentService: widget.commentService,
                onTap: widget.onGoToComments,
              ),
              _ManagementTile(
                icon: Icons.bar_chart_rounded,
                color: const Color(0xFF4FC3F7),
                title: 'VISUALIZAÇÕES',
                subtitle: 'Acompanhar desempenho das publicações',
                onTap: widget.onGoToViews,
              ),
              _ManagementTile(
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFFFD54F),
                title: 'NÍVEIS & XP',
                subtitle: 'Gerenciar níveis e experiência dos usuários',
                onTap: widget.onGoToLevels,
              ),
              _ManagementTile(
                icon: Icons.block_rounded,
                color: const Color(0xFFE53935),
                title: 'BANIDOS',
                subtitle: 'Gerenciar usuários suspensos',
                onTap: widget.onGoToBanned,
              ),
              _ManagementTile(
                icon: Icons.insights_rounded,
                color: const Color(0xFF66BB6A),
                title: 'ESTATÍSTICAS',
                subtitle: 'Dados gerais da comunidade e desempenho',
                onTap: () {
                  // Os dados de estatísticas já vivem nesta própria tela
                  // Geral (KPIs, distribuição de níveis, rankings) —
                  // não existe uma tela separada a abrir.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'As estatísticas completas estão logo acima, nesta tela.'),
                      backgroundColor: Color(0xFF1A1A1A),
                    ),
                  );
                },
              ),
              _ManagementTile(
                icon: Icons.settings_rounded,
                color: AppColors.textSecondary,
                title: 'CONFIGURAÇÕES',
                subtitle: 'Configurar o sistema e preferências do painel',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Configurações do painel em breve.'),
                      backgroundColor: Color(0xFF1A1A1A),
                    ),
                  );
                },
              ),
            ];

            if (!twoCols) {
              return Column(
                children: [
                  for (final t in tiles) ...[
                    t,
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: t,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        // Sincronizar níveis — ação de manutenção, mantida discreta
        Align(
          alignment: Alignment.centerRight,
          child: _SyncLevelsButton(
            syncing: _syncing,
            onTap: _syncing ? null : _syncLevels,
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
// AUXILIARES — CENTRAL DE GESTÃO
// ═══════════════════════════════════════════════════════════════════

/// Card principal e maior da Central de Gestão — Publicações.
/// Mostra contagem total e quantas estão em rascunho (aguardando
/// revisão) usando o stream já existente do AdminNewsService.
class _PublicationsManagementCard extends StatelessWidget {
  final AdminNewsService newsService;
  final VoidCallback onTap;

  const _PublicationsManagementCard({
    required this.newsService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: newsService.allNewsStream(),
      builder: (context, snapshot) {
        int? total;
        int? pending;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          total = docs.length;
          pending =
              docs.where((d) => d.data()['status'] == 'rascunho').length;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF0A0A0A),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.55)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.18),
                    blurRadius: 28,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: AppColors.orangeGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.dynamic_feed_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PUBLICAÇÕES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Criar, editar, revisar e gerenciar notícias',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (total != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '$total publicada${total == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppColors.primaryOrangeLight,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (pending != null && pending > 0) ...[
                                const Text('·',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                Text(
                                  '$pending aguardando revisão',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.primaryOrange.withOpacity(0.85),
                      size: 26),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tile padrão da grade 2 colunas da Central de Gestão.
class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  const _ManagementTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0A0A0A),
            border: Border.all(color: AppColors.borderDark),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 14,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  if (badge != null) badge!,
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile de Comentários — igual aos demais, mas com contador ao vivo.
class _CommentsManagementTile extends StatelessWidget {
  final AdminCommentService commentService;
  final VoidCallback onTap;

  const _CommentsManagementTile({
    required this.commentService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: commentService.allCommentsStream(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : null;
        return _ManagementTile(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF9575CD),
          title: 'COMENTÁRIOS',
          subtitle: 'Moderar e gerenciar comentários',
          onTap: onTap,
          badge: (count != null && count > 0)
              ? Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9575CD).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFF9575CD),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// Botão discreto de sincronização de níveis — antes era um dos
/// "chips" de ações rápidas; mantido como ação de manutenção.
class _SyncLevelsButton extends StatelessWidget {
  final bool syncing;
  final VoidCallback? onTap;

  const _SyncLevelsButton({required this.syncing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF66BB6A).withOpacity(0.1),
          border:
              Border.all(color: const Color(0xFF66BB6A).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (syncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF66BB6A)),
              )
            else
              const Icon(Icons.sync_rounded,
                  size: 13, color: Color(0xFF66BB6A)),
            const SizedBox(width: 6),
            Text(
              syncing ? 'Sincronizando...' : 'Sincronizar níveis',
              style: const TextStyle(
                color: Color(0xFF66BB6A),
                fontSize: 10.5,
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