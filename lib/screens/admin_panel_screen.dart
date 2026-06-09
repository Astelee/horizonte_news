import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';
import '../services/xp_service.dart';

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
              _BannedUsersTab(service: _service),
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
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.chat_bubble_rounded, size: 18),
            text: 'COMENTÁRIOS',
          ),
          Tab(
            icon: Icon(Icons.block_rounded, size: 18),
            text: 'BANIDOS',
          ),
          Tab(
            icon: Icon(Icons.people_rounded, size: 18),
            text: 'USUÁRIOS',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 1 — COMENTÁRIOS
// ═══════════════════════════════════════════════════════════════════

class _CommentsTab extends StatelessWidget {
  final AdminService service;
  const _CommentsTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: StreamBuilder<QuerySnapshot>(
        stream: service.allCommentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
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

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded,
                        color: AppColors.primaryOrange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${docs.length} comentário${docs.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final pathParts = doc.reference.path.split('/');
                    final postId =
                        pathParts.length >= 2 ? pathParts[1] : '';
                    return _AdminCommentTile(
                      commentId: doc.id,
                      postId: postId,
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
// ABA 2 — USUÁRIOS BANIDOS
// ═══════════════════════════════════════════════════════════════════

class _BannedUsersTab extends StatelessWidget {
  final AdminService service;
  const _BannedUsersTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundDark,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('suspensions')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.block_rounded,
              message: 'Nenhum usuário banido',
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded,
                        color: Color(0xFFEF5350), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${docs.length} usuário${docs.length != 1 ? 's' : ''} banido${docs.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _BannedUserTile(
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
// ABA 3 — USUÁRIOS
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
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
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

  String _resolveAuthorName(Map<String, dynamic> d) {
    for (final f in [
      'authorName', 'userName', 'displayName', 'name', 'author'
    ]) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return 'Anônimo';
  }

  String? _resolveAuthorPhoto(Map<String, dynamic> d) {
    for (final f in [
      'authorPhotoUrl', 'photoUrl', 'avatarUrl', 'photoURL'
    ]) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  String? _resolveAuthorId(Map<String, dynamic> d) {
    for (final f in ['authorId', 'userId', 'uid', 'user_id']) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authorId = _resolveAuthorId(data);
    final currentName = _resolveAuthorName(data);

    if (currentName == 'Anônimo' && authorId != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: _fetchProfile(authorId),
        builder: (context, snap) {
          final enriched = Map<String, dynamic>.from(data);
          if (snap.hasData && snap.data!.exists) {
            final ud = snap.data!.data() as Map<String, dynamic>;
            enriched['authorName'] = ud['displayName'] ??
                ud['name'] ??
                ud['userName'] ??
                'Anônimo';
            enriched['authorPhotoUrl'] =
                ud['photoUrl'] ?? ud['photoURL'] ?? ud['avatarUrl'];
          }
          return _buildTile(context, enriched);
        },
      );
    }

    return _buildTile(context, data);
  }

  Future<DocumentSnapshot> _fetchProfile(String uid) async {
    final xp = await FirebaseFirestore.instance
        .collection('users_xp')
        .doc(uid)
        .get();
    if (xp.exists) return xp;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  Widget _buildTile(BuildContext context, Map<String, dynamic> d) {
    final isHidden = d['hidden'] == true;
    final author = _resolveAuthorName(d);
    final photoUrl = _resolveAuthorPhoto(d);
    final authorId = _resolveAuthorId(d);
    final text = (d['text'] ?? d['content'] ?? d['body'] ?? '').toString();
    final ts = (d['createdAt'] as Timestamp?)?.toDate();
    final dateStr = ts != null
        ? '${ts.day.toString().padLeft(2, '0')}/'
          '${ts.month.toString().padLeft(2, '0')}/'
          '${ts.year}  '
          '${ts.hour.toString().padLeft(2, '0')}:'
          '${ts.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHidden
              ? AppColors.textSecondary.withOpacity(0.2)
              : AppColors.borderDark,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppColors.primaryOrange.withOpacity(0.15),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          author.isNotEmpty ? author[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      if (dateStr.isNotEmpty)
                        Text(dateStr,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (isHidden)
                  _Badge(label: 'Oculto', color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isHidden)
                  _ActionButton(
                    icon: Icons.visibility_rounded,
                    label: 'Restaurar',
                    color: const Color(0xFF4FC3F7),
                    onTap: () => service.restoreComment(postId, commentId),
                  )
                else
                  _ActionButton(
                    icon: Icons.visibility_off_rounded,
                    label: 'Ocultar',
                    color: AppColors.textSecondary,
                    onTap: () => service.hideComment(postId, commentId),
                  ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_rounded,
                  label: 'Excluir',
                  color: const Color(0xFFEF5350),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _ConfirmDialog(
                        title: 'Excluir comentário?',
                        message: 'Esta ação não pode ser desfeita.',
                        confirmLabel: 'Excluir',
                        confirmColor: Color(0xFFEF5350),
                      ),
                    );
                    if (confirm == true) {
                      service.deleteComment(postId, commentId);
                    }
                  },
                ),
              ],
            ),
            if (authorId != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.person_off_rounded,
                    label: 'Banir usuário',
                    color: const Color(0xFFFF9800),
                    onTap: () async {
                      final result = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (_) => _BanUserDialog(authorName: author),
                      );
                      if (result != null) {
                        await service.suspendUser(
                          authorId,
                          result['days'] as int,
                          result['reason'] as String,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$author foi banido por ${result['days'] == 0 ? 'tempo indeterminado' : '${result['days']} dias'}.'),
                              backgroundColor: const Color(0xFFFF9800),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DIALOG — BANIR USUÁRIO
// ═══════════════════════════════════════════════════════════════════

class _BanUserDialog extends StatefulWidget {
  final String authorName;
  const _BanUserDialog({required this.authorName});

  @override
  State<_BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends State<_BanUserDialog> {
  final _reasonController = TextEditingController();
  int _selectedDays = 7;
  bool _permanent = false;

  static const _options = [
    {'label': '1 dia', 'days': 1},
    {'label': '3 dias', 'days': 3},
    {'label': '7 dias', 'days': 7},
    {'label': '15 dias', 'days': 15},
    {'label': '30 dias', 'days': 30},
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.person_off_rounded,
              color: Color(0xFFFF9800), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Banir ${widget.authorName}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O usuário ficará impedido de comentar.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text('Motivo do banimento',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ex: Spam, linguagem ofensiva...',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.5),
                    fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFFF9800), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Duração',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _permanent = !_permanent),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _permanent
                      ? const Color(0xFFEF5350).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _permanent
                        ? const Color(0xFFEF5350)
                        : AppColors.borderDark,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _permanent
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: _permanent
                          ? const Color(0xFFEF5350)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text('Banimento permanente',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_permanent)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options.map((opt) {
                  final days = opt['days'] as int;
                  final selected = _selectedDays == days;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDays = days),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFF9800).withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF9800)
                              : AppColors.borderDark,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFFF9800)
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Informe o motivo do banimento.'),
                  backgroundColor: Color(0xFFEF5350),
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'reason': reason,
              'days': _permanent ? 0 : _selectedDays,
            });
          },
          child: const Text(
            'Banir',
            style: TextStyle(
                color: Color(0xFFFF9800), fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE DE USUÁRIO BANIDO
// ═══════════════════════════════════════════════════════════════════

class _BannedUserTile extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final AdminService service;

  const _BannedUserTile({
    required this.userId,
    required this.data,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final reason = (data['reason'] as String?)?.trim() ?? '';
    final bannedAt = (data['suspendedAt'] as Timestamp?)?.toDate();
    final expiresAt = (data['until'] as Timestamp?)?.toDate();
    final isPermanent = expiresAt == null;

    final bannedStr = bannedAt != null
        ? '${bannedAt.day.toString().padLeft(2, '0')}/'
          '${bannedAt.month.toString().padLeft(2, '0')}/'
          '${bannedAt.year}'
        : 'Data desconhecida';

    int? daysLeft;
    bool isExpired = false;
    if (!isPermanent && expiresAt != null) {
      daysLeft = expiresAt.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        isExpired = true;
      } else if (daysLeft == 0) {
        daysLeft = 1;
      }
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users_xp')
          .doc(userId)
          .get(),
      builder: (context, snap) {
        String name = 'Usuário desconhecido';
        String email = '';

        if (snap.hasData && snap.data!.exists) {
          final ud = snap.data!.data() as Map<String, dynamic>;
          name = ud['displayName'] ?? ud['name'] ?? ud['userName'] ?? name;
          email = ud['email'] ?? '';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPermanent
                  ? const Color(0xFFEF5350).withOpacity(0.4)
                  : const Color(0xFFFF9800).withOpacity(0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          const Color(0xFFEF5350).withOpacity(0.15),
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFEF5350),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          if (email.isNotEmpty)
                            Text(email,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    _Badge(
                      label: isPermanent ? 'Permanente' : 'Temporário',
                      color: isPermanent
                          ? const Color(0xFFEF5350)
                          : const Color(0xFFFF9800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _BanInfoRow(
                  icon: Icons.event_rounded,
                  label: 'Banido em',
                  value: bannedStr,
                ),
                const SizedBox(height: 6),
                if (reason.isNotEmpty) ...[
                  _BanInfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Motivo',
                    value: reason,
                  ),
                  const SizedBox(height: 6),
                ],
                if (!isPermanent) ...[
                  _BanInfoRow(
                    icon: Icons.timer_rounded,
                    label: isExpired ? 'Expirado há' : 'Dias restantes',
                    value: isExpired
                        ? '${daysLeft!.abs()} dia${daysLeft.abs() != 1 ? 's' : ''} (expirado)'
                        : '$daysLeft dia${daysLeft != 1 ? 's' : ''}',
                    valueColor: isExpired
                        ? AppColors.textSecondary
                        : (daysLeft! <= 3
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF66BB6A)),
                  ),
                  const SizedBox(height: 6),
                ],
                _BanInfoRow(
                  icon: isPermanent
                      ? Icons.block_rounded
                      : Icons.access_time_rounded,
                  label: 'Status',
                  value: isPermanent
                      ? 'Banido permanentemente'
                      : isExpired
                          ? 'Banimento expirado'
                          : 'Banido temporariamente',
                  valueColor: isPermanent
                      ? const Color(0xFFEF5350)
                      : isExpired
                          ? AppColors.textSecondary
                          : const Color(0xFFFF9800),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ActionButton(
                    icon: Icons.lock_open_rounded,
                    label: 'Remover banimento',
                    color: const Color(0xFF66BB6A),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => _ConfirmDialog(
                          title: 'Remover banimento?',
                          message: '$name poderá comentar novamente.',
                          confirmLabel: 'Remover',
                          confirmColor: const Color(0xFF66BB6A),
                        ),
                      );
                      if (confirm == true) {
                        await service.unsuspendUser(userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Banimento de $name removido.'),
                              backgroundColor: const Color(0xFF66BB6A),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users_xp')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        final d = (snap.hasData && snap.data!.exists)
            ? snap.data!.data() as Map<String, dynamic>
            : data;

        final name =
            (d['displayName'] as String?)?.isNotEmpty == true
                ? d['displayName'] as String
                : 'Sem nome';
        final email = d['email'] as String? ?? '';
        final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
        final level = XpService.levelFromXp(xp);
        final comments =
            (d['stats']?['commentsPosted'] as num?)?.toInt() ??
            (d['commentsPosted'] as num?)?.toInt() ??
            0;
        final articles =
            (d['stats']?['articlesRead'] as num?)?.toInt() ??
            (d['articlesRead'] as num?)?.toInt() ??
            0;
        final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
        final createdStr = createdAt != null
            ? 'Desde ${createdAt.day.toString().padLeft(2, '0')}/'
              '${createdAt.month.toString().padLeft(2, '0')}/'
              '${createdAt.year}'
            : '';
        final lvlTitle = XpService.levelTitle(level);
        final lvlIcon = XpService.levelIcon(level);

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
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      AppColors.primaryOrange.withOpacity(0.15),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11)),
                      if (createdStr.isNotEmpty)
                        Text(createdStr,
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.star_rounded,
                            label: '$lvlIcon Nv $level · $lvlTitle',
                            color: AppColors.primaryOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.bolt_rounded,
                            label: '$xp XP',
                            color: const Color(0xFFFFD54F),
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            icon: Icons.chat_bubble_rounded,
                            label: '$comments',
                            color: const Color(0xFF4FC3F7),
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            icon: Icons.article_rounded,
                            label: '$articles',
                            color: const Color(0xFF66BB6A),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

class _BanInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _BanInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ],
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontSize: 14)),
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF5350)),
            const SizedBox(height: 12),
            const Text('Erro ao carregar dados',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
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
      backgroundColor: const Color(0xFF111111),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800)),
      content: Text(message,
          style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  color: confirmColor, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
