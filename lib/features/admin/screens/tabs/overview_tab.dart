import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/badge_config.dart';
import '../../../../widgets/app_avatar.dart';
import '../../../../widgets/app_messenger.dart';
import '../../services/admin_avatar_approval_service.dart';
import '../../services/admin_subscription_request_service.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_news_service.dart';
import '../../services/admin_comment_service.dart';
import '../../widgets/dashboard_widgets.dart';

class OverviewTab extends StatefulWidget {
  final AdminDashboardService dashboardService;
  final AdminUserService userService;
  final AdminNewsService newsService;
  final AdminCommentService commentService;
  final AdminAvatarApprovalService avatarApprovalService;
  final AdminSubscriptionRequestService subscriptionRequestService;
  final VoidCallback onGoToUsers;
  final VoidCallback onGoToViews;
  final VoidCallback onGoToBanned;
  final VoidCallback onGoToNews;
  final VoidCallback onGoToComments;
  final VoidCallback onGoToLevels;
  final VoidCallback onGoToAvatarApprovals;
  final VoidCallback onGoToSubscriptionRequests;
  final VoidCallback onGoToConfig;
  final VoidCallback onGoToAdsBar;

  const OverviewTab({
    required this.dashboardService,
    required this.userService,
    required this.newsService,
    required this.commentService,
    required this.avatarApprovalService,
    required this.subscriptionRequestService,
    required this.onGoToUsers,
    required this.onGoToViews,
    required this.onGoToBanned,
    required this.onGoToNews,
    required this.onGoToComments,
    required this.onGoToLevels,
    required this.onGoToAvatarApprovals,
    required this.onGoToSubscriptionRequests,
    required this.onGoToConfig,
    required this.onGoToAdsBar,
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
        AppMessenger.success('Níveis de todos os usuários sincronizados.');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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
                _PublicationsManagementCard(
                  newsService: widget.newsService,
                  onTap: widget.onGoToNews,
                ),
                const SizedBox(height: 22),
                _buildManagementCenter(),
                const SizedBox(height: 26),
                _buildKpiGrid(data),
                const SizedBox(height: 22),
                _buildLevelDistribution(data),
                const SizedBox(height: 22),
                _buildTopRanking(data),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── KPIs gerais do sistema (não específicos de um usuário — dados
  // por usuário individual como total/online/suspensos agora vivem
  // só na aba Usuários e no perfil de cada um, para não duplicar) ──
  Widget _buildKpiGrid(DashboardSnapshot data) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 150,
        child: StatCardCompact(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF9575CD),
          label: 'Comentários',
          value: data.totalComments,
          onTap: widget.onGoToComments,
        ),
      ),
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

        // Grade 2 colunas — demais recursos
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 300;
            final tiles = <Widget>[
              _ManagementTile(
                icon: Icons.people_alt_rounded,
                color: AppColors.primaryOrange,
                title: 'USUÁRIOS',
                subtitle: 'Gerenciar contas, XP, Premium e moderação',
                onTap: widget.onGoToUsers,
              ),
              _AvatarApprovalsManagementTile(
                approvalService: widget.avatarApprovalService,
                onTap: widget.onGoToAvatarApprovals,
              ),
              _SubscriptionRequestsManagementTile(
                requestService: widget.subscriptionRequestService,
                onTap: widget.onGoToSubscriptionRequests,
              ),
              _ManagementTile(
                icon: Icons.block_rounded,
                color: const Color(0xFFEF5350),
                title: 'SUSPENSOS',
                subtitle: 'Ver e gerenciar usuários banidos',
                onTap: widget.onGoToBanned,
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
                icon: Icons.settings_rounded,
                color: AppColors.textSecondary,
                title: 'CONFIGURAÇÕES',
                subtitle: 'Configurar o sistema e preferências do painel',
                onTap: widget.onGoToConfig,
              ),
              _ManagementTile(
                icon: Icons.campaign_rounded,
                color: const Color(0xFF66BB6A),
                title: 'BARRA DE ANÚNCIOS',
                subtitle: 'Ativar AdMob, parceria ou desativar na Home',
                onTap: widget.onGoToAdsBar,
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
  // Ajustado para o teto de 30 níveis (era desenhado para 100).
  Widget _buildLevelDistribution(DashboardSnapshot data) {
    final labels = {
      1: 'Nv 1-5',
      6: 'Nv 6-10',
      11: 'Nv 11-15',
      16: 'Nv 16-20',
      21: 'Nv 21-25',
      26: 'Nv 26-30',
    };
    final colors = {
      1: const Color(0xFF66BB6A),
      6: const Color(0xFF4FC3F7),
      11: const Color(0xFF9575CD),
      16: const Color(0xFFFFD54F),
      21: AppColors.primaryOrange,
      26: const Color(0xFFEF5350),
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

/// Tile com contador de fotos de perfil aguardando aprovação manual.
class _AvatarApprovalsManagementTile extends StatelessWidget {
  final AdminAvatarApprovalService approvalService;
  final VoidCallback onTap;

  const _AvatarApprovalsManagementTile({
    required this.approvalService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: approvalService.pendingStream(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : null;
        return _ManagementTile(
          icon: Icons.photo_camera_back_rounded,
          color: AppColors.primaryOrange,
          title: 'FOTOS PENDENTES',
          subtitle: 'Aprovar fotos de perfil enviadas pelos usuários',
          onTap: onTap,
          badge: (count != null && count > 0)
              ? Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
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

/// Card de atalho da Central de Gestão para a fila de solicitações de
/// assinatura (PRO/ULTRA compradas via Google Play, aguardando
/// aprovação manual). Mesmo padrão do tile de fotos pendentes: o
/// badge mostra a contagem em tempo real via
/// AdminSubscriptionRequestService.pendingStream().
class _SubscriptionRequestsManagementTile extends StatelessWidget {
  final AdminSubscriptionRequestService requestService;
  final VoidCallback onTap;

  const _SubscriptionRequestsManagementTile({
    required this.requestService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: requestService.pendingStream(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : null;
        return _ManagementTile(
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFFFFC107),
          title: 'ASSINATURAS PENDENTES',
          subtitle: 'Aprovar ou recusar compras PRO/ULTRA',
          onTap: onTap,
          badge: (count != null && count > 0)
              ? Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
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