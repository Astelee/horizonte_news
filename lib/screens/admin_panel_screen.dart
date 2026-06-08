import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _service = AdminService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    if (!admin.isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark, // FIX #2
        body: Center(
          child: Text('Acesso negado.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // FIX #2
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabController,
          children: [
            // FIX #2: cada aba com cor de fundo explícita
            ColoredBox(
              color: AppColors.backgroundDark,
              child: _DashboardTab(service: _service),
            ),
            ColoredBox(
              color: AppColors.backgroundDark,
              child: _CommentsTab(service: _service),
            ),
            ColoredBox(
              color: AppColors.backgroundDark,
              child: _UsersTab(service: _service),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: AppColors.orangeGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'PAINEL ADMINISTRATIVO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Horizonte News',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF160400), Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.glowOrange,
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryOrange,
        indicatorWeight: 2,
        labelColor: AppColors.primaryOrange,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'PAINEL'),
          Tab(icon: Icon(Icons.chat_bubble_rounded, size: 18), text: 'COMENTÁRIOS'),
          Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'USUÁRIOS'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 1 — DASHBOARD
// ═══════════════════════════════════════════════════════════════════

class _DashboardTab extends StatefulWidget {
  final AdminService service;
  const _DashboardTab({required this.service});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final stats = await widget.service.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
          _hasError = stats == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stats = null;
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    if (_hasError || _stats == null) {
      return RefreshIndicator(
        color: AppColors.primaryOrange,
        backgroundColor: AppColors.backgroundElevated,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.primaryOrange.withOpacity(0.3),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Erro ao carregar dados do painel.\nPuxe para baixo para atualizar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.primaryOrange),
                      label: const Text(
                        'Tentar novamente',
                        style: TextStyle(color: AppColors.primaryOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final stats = _stats!;
    final logs = stats['recentLogs'] != null
        ? stats['recentLogs'] as List<QueryDocumentSnapshot>
        : <QueryDocumentSnapshot>[];
    final topUsers = stats['topUsers'] != null
        ? stats['topUsers'] as List<QueryDocumentSnapshot>
        : <QueryDocumentSnapshot>[];

    return RefreshIndicator(
      color: AppColors.primaryOrange,
      backgroundColor: AppColors.backgroundElevated,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatCard(
                icon: Icons.people_rounded,
                label: 'Usuários',
                value: '${stats['totalUsers'] ?? 0}',
                color: const Color(0xFF4FC3F7),
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.chat_bubble_rounded,
                label: 'Comentários',
                value: '${stats['totalComments'] ?? 0}',
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.flag_rounded,
                label: 'Denunciados',
                value: '${stats['reportedComments'] ?? 0}',
                color: const Color(0xFFEF5350),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'TOP USUÁRIOS POR XP'),
          const SizedBox(height: 10),
          if (topUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nenhum usuário listado',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...topUsers.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['displayName'] ?? doc.id.substring(0, 8);
              final xp = (data['totalXp'] as num?)?.toInt() ?? 0;
              final level = (data['level'] as num?)?.toInt() ?? 1;
              return _TopUserTile(
                name: name,
                xp: xp,
                level: level,
                userId: doc.id,
              );
            }),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'AÇÕES RECENTES'),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nenhuma ação registrada ainda',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...logs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _LogTile(data: data);
            }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 2 — COMENTÁRIOS
// ═══════════════════════════════════════════════════════════════════

class _CommentsTab extends StatefulWidget {
  final AdminService service;
  const _CommentsTab({required this.service});

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todos',
                active: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Denunciados',
                active: _filter == 'reported',
                color: const Color(0xFFEF5350),
                onTap: () => setState(() => _filter = 'reported'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Ocultos',
                active: _filter == 'hidden',
                color: AppColors.textSecondary,
                onTap: () => setState(() => _filter = 'hidden'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.service.allCommentsStream(
              onlyReported: _filter == 'reported',
              onlyHidden: _filter == 'hidden',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryOrange),
                );
              }

              // FIX #1: trata erros do stream
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: AppColors.primaryOrange.withOpacity(0.4),
                            size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Erro ao carregar comentários.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const _EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  message: 'Nenhum comentário encontrado',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, i) {
                  final doc = snapshot.data!.docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final ref = doc.reference;

                  // FIX #1: path correto posts/{postId}/comments/{commentId}
                  final pathParts = ref.path.split('/');
                  final postId =
                      pathParts.length >= 4 ? pathParts[1] : '';

                  return _AdminCommentTile(
                    commentId: doc.id,
                    postId: postId,
                    data: data,
                    service: widget.service,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 3 — USUÁRIOS
// ═══════════════════════════════════════════════════════════════════

class _UsersTab extends StatelessWidget {
  final AdminService service;
  const _UsersTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users_xp')
          .orderBy('totalXp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryOrange),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline_rounded,
            message: 'Nenhum usuário encontrado',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snapshot.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _AdminUserTile(
              userId: doc.id,
              data: data,
              service: service,
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS INTERNOS
// ═══════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.06), blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.orangeVertical,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _TopUserTile extends StatelessWidget {
  final String name;
  final int xp;
  final int level;
  final String userId;

  const _TopUserTile({
    required this.name,
    required this.xp,
    required this.level,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orangeGradient,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Nível $level  •  $xp XP',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.primaryOrange.withOpacity(0.15),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.3)),
            ),
            child: Text(
              'Nv. $level',
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LogTile({required this.data});

  String _actionLabel(String action) {
    switch (action) {
      case 'delete_comment':  return '🗑 Comentário deletado';
      case 'hide_comment':    return '👁 Comentário ocultado';
      case 'restore_comment': return '✅ Comentário restaurado';
      case 'suspend_user':    return '🚫 Usuário suspenso';
      case 'unsuspend_user':  return '✅ Suspensão removida';
      default:                return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = ts != null
        ? '${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(data['action'] ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'por ${data['adminName'] ?? 'Admin'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// FIX #3: convertido de StatelessWidget para StatefulWidget
class _AdminCommentTile extends StatefulWidget {
  final String commentId;
  final String postId;
  final Map<String, dynamic> data;
  final AdminService service;

  const _AdminCommentTile({
    required this.commentId,
    required this.postId,
    required this.data,
    required this.service,
  });

  @override
  State<_AdminCommentTile> createState() => _AdminCommentTileState();
}

class _AdminCommentTileState extends State<_AdminCommentTile> {
  @override
  Widget build(BuildContext context) {
    final isHidden = widget.data['hidden'] == true;
    final reportCount = (widget.data['reportCount'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0A0A0A),
        border: Border.all(
          color: isHidden
              ? AppColors.textMuted.withOpacity(0.3)
              : reportCount > 0
                  ? const Color(0xFFEF5350).withOpacity(0.3)
                  : AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orangeGradient,
                ),
                child: Center(
                  child: Text(
                    (widget.data['userName'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data['userName'] ?? 'Anônimo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.data['userId'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (reportCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFEF5350).withOpacity(0.15),
                    border: Border.all(
                        color: const Color(0xFFEF5350).withOpacity(0.4)),
                  ),
                  child: Text(
                    '⚑ $reportCount',
                    style: const TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (isHidden)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.textMuted.withOpacity(0.15),
                    border: Border.all(
                        color: AppColors.textMuted.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'OCULTO',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.data['text'] ?? '',
            style: TextStyle(
              color: isHidden
                  ? AppColors.textMuted
                  : AppColors.textSecondaryDark,
              fontSize: 13,
              fontStyle: isHidden ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isHidden)
                _ActionButton(
                  icon: Icons.visibility_off_rounded,
                  label: 'Ocultar',
                  color: AppColors.textSecondary,
                  onTap: () async {
                    await widget.service.hideComment(widget.postId, widget.commentId);
                    if (mounted) _snack('Comentário ocultado');
                  },
                )
              else
                _ActionButton(
                  icon: Icons.visibility_rounded,
                  label: 'Restaurar',
                  color: const Color(0xFF66BB6A),
                  onTap: () async {
                    await widget.service.restoreComment(widget.postId, widget.commentId);
                    if (mounted) _snack('Comentário restaurado');
                  },
                ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.delete_rounded,
                label: 'Excluir',
                color: const Color(0xFFEF5350),
                onTap: () => _confirmDelete(context),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.person_off_rounded,
                label: 'Suspender',
                color: const Color(0xFFFFA726),
                onTap: () => _showSuspendDialog(context, widget.data['userId'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FIX #3: _snack usa mounted do State corretamente
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFEF5350).withOpacity(0.3)),
        ),
        title: const Text('Excluir comentário?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Esta ação não pode ser desfeita.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // FIX #3: deleteComment usa widget. e mounted do State
              await widget.service.deleteComment(widget.postId, widget.commentId);
              if (mounted) _snack('Comentário excluído');
            },
            child: const Text('Excluir',
                style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(BuildContext context, String userId) {
    int days = 1;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFFFA726).withOpacity(0.3)),
          ),
          title: const Text('Suspender usuário',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ID: ${userId.substring(0, userId.length > 12 ? 12 : userId.length)}...',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Dias:',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(width: 12),
                  ...[1, 3, 7, 30].map((d) => GestureDetector(
                        onTap: () => setS(() => days = d),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: days == d
                                ? AppColors.primaryOrange
                                : AppColors.backgroundElevated,
                          ),
                          child: Text(
                            '$d',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Motivo (opcional)',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.primaryOrange.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primaryOrange),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
              onPressed: () async {
                Navigator.pop(context);
                await AdminService()
                    .suspendUser(userId, days, reasonCtrl.text.trim());
                if (mounted) _snack('Usuário suspenso por $days dia(s)');
              },
              child: const Text('Suspender',
                  style: TextStyle(color: Color(0xFFFFA726))),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final AdminService service;

  const _AdminUserTile({
    required this.userId,
    required this.data,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['displayName'] ?? userId.substring(0, 10);
    final xp = (data['totalXp'] as num?)?.toInt() ?? 0;
    final level = (data['level'] as num?)?.toInt() ?? 1;
    final comments =
        (data['stats']?['commentsPosted'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orangeGradient,
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Nível $level  •  $xp XP  •  $comments comentários',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  userId,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showUserActions(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.backgroundElevated,
              ),
              child: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data['displayName'] ?? userId.substring(0, 10),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _BottomSheetAction(
              icon: Icons.block_rounded,
              label: 'Suspender 1 dia',
              color: const Color(0xFFFFA726),
              onTap: () async {
                Navigator.pop(context);
                await service.suspendUser(
                    userId, 1, 'Suspenso pelo administrador');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Usuário suspenso por 1 dia',
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: AppColors.backgroundElevated,
                    ),
                  );
                }
              },
            ),
            _BottomSheetAction(
              icon: Icons.check_circle_rounded,
              label: 'Remover suspensão',
              color: const Color(0xFF66BB6A),
              onTap: () async {
                Navigator.pop(context);
                await service.unsuspendUser(userId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryOrange;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? c.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: active ? c.withOpacity(0.5) : AppColors.borderDark,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: AppColors.primaryOrange.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomSheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
