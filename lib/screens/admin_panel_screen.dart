import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Text('Acesso negado.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: AppColors.backgroundDark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [_buildAppBar()],
          body: TabBarView(
            controller: _tabController,
            children: [
              _CommentsTab(service: _service),
              _UsersTab(service: _service),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
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
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        tabs: const [
          Tab(
              icon: Icon(Icons.chat_bubble_rounded, size: 18),
              text: 'COMENTÁRIOS'),
          Tab(
              icon: Icon(Icons.people_rounded, size: 18),
              text: 'USUÁRIOS'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 1 — COMENTÁRIOS
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
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: Column(
        children: [
          // ── Filtros ──────────────────────────────────────────────
          Container(
            color: Colors.black,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

          // ── Lista ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.service.allCommentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorState(message: '${snapshot.error}');
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    message: 'Nenhum comentário encontrado',
                  );
                }

                var docs = snapshot.data!.docs;

                if (_filter == 'reported') {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return ((d['reportCount'] as num?)?.toInt() ?? 0) > 0;
                  }).toList();
                } else if (_filter == 'hidden') {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['hidden'] == true;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    message: 'Nenhum comentário encontrado',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final pathParts = doc.reference.path.split('/');
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 2 — USUÁRIOS
// ═══════════════════════════════════════════════════════════════════

class _UsersTab extends StatelessWidget {
  final AdminService service;
  const _UsersTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users_xp')
            .orderBy('totalXp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryOrange),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}');
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.people_outline_rounded,
              message: 'Nenhum usuário encontrado',
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              // ── Cabeçalho com contagem ──────────────────────────
              Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.people_rounded,
                        color: AppColors.primaryOrange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${docs.length} usuário${docs.length != 1 ? 's' : ''} cadastrado${docs.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Lista ───────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _AdminUserTile(
                      userId: doc.id,
                      data: data,
                      service: service,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE DE COMENTÁRIO
// ═══════════════════════════════════════════════════════════════════

class _AdminCommentTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isHidden = data['hidden'] == true;
    final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
    final author = data['authorName'] ?? 'Anônimo';
    final text = data['text'] ?? '';
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null
        ? '${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reportCount > 0
              ? const Color(0xFFEF5350).withOpacity(0.4)
              : isHidden
                  ? AppColors.textSecondary.withOpacity(0.2)
                  : AppColors.borderDark,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primaryOrange.withOpacity(0.15),
                  child: Text(
                    author.isNotEmpty
                        ? author[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                // Badges
                if (reportCount > 0)
                  _Badge(
                    label: '$reportCount denúncia${reportCount > 1 ? 's' : ''}',
                    color: const Color(0xFFEF5350),
                  ),
                if (isHidden) ...[
                  const SizedBox(width: 6),
                  _Badge(
                    label: 'Oculto',
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // ── Texto ─────────────────────────────────────────────
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Ações ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isHidden)
                  _ActionButton(
                    icon: Icons.visibility_rounded,
                    label: 'Restaurar',
                    color: const Color(0xFF4FC3F7),
                    onTap: () =>
                        service.restoreComment(postId, commentId),
                  )
                else
                  _ActionButton(
                    icon: Icons.visibility_off_rounded,
                    label: 'Ocultar',
                    color: AppColors.textSecondary,
                    onTap: () =>
                        service.hideComment(postId, commentId),
                  ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_rounded,
                  label: 'Excluir',
                  color: const Color(0xFFEF5350),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => _ConfirmDialog(
                        title: 'Excluir comentário?',
                        message:
                            'Esta ação não pode ser desfeita.',
                        confirmLabel: 'Excluir',
                        confirmColor: const Color(0xFFEF5350),
                      ),
                    );
                    if (confirm == true) {
                      service.deleteComment(postId, commentId);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE DE USUÁRIO
// ═══════════════════════════════════════════════════════════════════

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
    final name = (data['displayName'] as String?)?.isNotEmpty == true
        ? data['displayName'] as String
        : 'Sem nome';
    final email = data['email'] as String? ?? '';
    final xp = (data['totalXp'] as num?)?.toInt() ?? 0;
    final level = (data['level'] as num?)?.toInt() ?? 1;
    final comments =
        (data['stats']?['commentsPosted'] as num?)?.toInt() ?? 0;
    final articles =
        (data['stats']?['articlesRead'] as num?)?.toInt() ?? 0;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate();
    final createdStr = createdAt != null
        ? 'Desde ${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryOrange.withOpacity(0.15),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
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
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                          icon: Icons.star_rounded,
                          label: 'Nv $level · $xp XP',
                          color: AppColors.primaryOrange),
                      _InfoChip(
                          icon: Icons.chat_bubble_rounded,
                          label: '$comments comentários',
                          color: const Color(0xFF4FC3F7)),
                      _InfoChip(
                          icon: Icons.article_rounded,
                          label: '$articles lidos',
                          color: const Color(0xFF81C784)),
                      if (createdStr.isNotEmpty)
                        _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: createdStr,
                            color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),

            // Menu
            PopupMenuButton<String>(
              color: AppColors.backgroundElevated,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: 20),
              onSelected: (value) async {
                if (value == 'suspend') {
                  _showSuspendDialog(context, userId);
                } else if (value == 'unsuspend') {
                  await service.unsuspendUser(userId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Suspensão removida.'),
                        backgroundColor: Color(0xFF81C784),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded,
                          color: Color(0xFFEF5350), size: 18),
                      SizedBox(width: 10),
                      Text('Suspender',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'unsuspend',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF81C784), size: 18),
                      SizedBox(width: 10),
                      Text('Remover suspensão',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSuspendDialog(BuildContext context, String userId) {
    int days = 1;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.backgroundElevated,
          title: const Text(
            'Suspender usuário',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Dias:',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      if (days > 1) setStateDialog(() => days--);
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: AppColors.primaryOrange),
                  ),
                  Text(
                    '$days',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => setStateDialog(() => days++),
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.primaryOrange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Motivo (opcional)',
                  hintStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await service.suspendUser(
                    userId, days, reasonController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Usuário suspenso por $days dia(s).'),
                      backgroundColor: const Color(0xFFEF5350),
                    ),
                  );
                }
              },
              child: const Text('Suspender',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    this.color = AppColors.primaryOrange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : AppColors.borderDark,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: AppColors.primaryOrange.withOpacity(0.2), size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
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
              'Erro: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundElevated,
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: Text(message,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
