import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_shared_widgets.dart';
import '../../widgets/admin_user_tile.dart';

enum _UserFilter { all, online, premium, active, newUsers, suspended }

class UsersTab extends StatefulWidget {
  final AdminUserService userService;
  const UsersTab({required this.userService, Key? key}) : super(key: key);

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _search = '';
  _UserFilter _filter = _UserFilter.all;

  // ── Helpers de leitura (mesmo critério usado no resto do painel) ──

  String _resolveName(Map<String, dynamic> d) {
    for (final f in ['displayName', 'name', 'userName']) {
      final v = d[f];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final email = (d['email'] as String?) ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return '';
  }

  bool _isOnline(Map<String, dynamic> d) {
    final lastSeenAt = (d['lastSeenAt'] as Timestamp?)?.toDate();
    return lastSeenAt != null &&
        DateTime.now().difference(lastSeenAt).inMinutes < 5;
  }

  bool _isPremium(Map<String, dynamic> d) {
    final tier = d['premiumTier'] as String?;
    if (tier == null || tier == 'none') return false;
    final expiresAt = d['premiumExpiresAt'];
    if (expiresAt is Timestamp && DateTime.now().isAfter(expiresAt.toDate())) {
      return false;
    }
    return true;
  }

  bool _isNew(Map<String, dynamic> d) {
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inDays <= 7;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder<QuerySnapshot>(
        stream: widget.userService.usersStream(),
        builder: (context, usersSnap) {
          if (usersSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            );
          }
          if (usersSnap.hasError) {
            return AdminErrorState(message: '${usersSnap.error}');
          }
          if (!usersSnap.hasData || usersSnap.data!.docs.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.people_outline_rounded,
              message: 'Nenhum usuário encontrado',
            );
          }

          final allDocs = usersSnap.data!.docs;

          // Segundo stream, só para saber QUAIS uids estão suspensos —
          // documentos pequenos (id + poucos campos), coleção separada
          // de users_xp, então não pesa na lista principal.
          return StreamBuilder<QuerySnapshot>(
            stream: widget.userService.suspensionsStream(),
            builder: (context, suspSnap) {
              final suspendedIds = <String>{
                if (suspSnap.hasData)
                  for (final doc in suspSnap.data!.docs) doc.id,
              };

              return _buildBody(context, allDocs, suspendedIds);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<QueryDocumentSnapshot> allDocs,
    Set<String> suspendedIds,
  ) {
    // ── KPIs (sobre a base completa, antes de filtrar/pesquisar) ────
    final total = allDocs.length;
    int onlineCount = 0;
    int premiumCount = 0;
    int newCount = 0;
    for (final doc in allDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (_isOnline(d)) onlineCount++;
      if (_isPremium(d)) premiumCount++;
      if (_isNew(d)) newCount++;
    }
    final suspendedCount = suspendedIds.length;

    // ── Filtro por chip ──────────────────────────────────────────
    var docs = allDocs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      switch (_filter) {
        case _UserFilter.all:
          return true;
        case _UserFilter.online:
          return _isOnline(d);
        case _UserFilter.premium:
          return _isPremium(d);
        case _UserFilter.active:
          return true; // ordenação cuida disso, ver sort abaixo
        case _UserFilter.newUsers:
          return _isNew(d);
        case _UserFilter.suspended:
          return suspendedIds.contains(doc.id);
      }
    }).toList();

    if (_filter == _UserFilter.active) {
      docs.sort((a, b) {
        final da = a.data() as Map<String, dynamic>;
        final db = b.data() as Map<String, dynamic>;
        final xpA = (da['totalXp'] as num?)?.toInt() ?? 0;
        final xpB = (db['totalXp'] as num?)?.toInt() ?? 0;
        return xpB.compareTo(xpA);
      });
    }

    // ── Pesquisa: nome, username, e-mail, UID ───────────────────────
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      docs = docs.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        final name = _resolveName(d).toLowerCase();
        final username = (d['username'] as String? ?? '').toLowerCase();
        final email = (d['email'] as String? ?? '').toLowerCase();
        final uid = doc.id.toLowerCase();
        return name.contains(q) ||
            username.contains(q) ||
            email.contains(q) ||
            uid.contains(q);
      }).toList();
    }

    return Column(
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              _KpiRow(
                total: total,
                online: onlineCount,
                premium: premiumCount,
                newUsers: newCount,
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nome, username, e-mail ou UID...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.5),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary, size: 18),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary, size: 18),
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0A0A0A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _FilterChips(
                selected: _filter,
                counts: {
                  _UserFilter.all: total,
                  _UserFilter.online: onlineCount,
                  _UserFilter.premium: premiumCount,
                  _UserFilter.active: total,
                  _UserFilter.newUsers: newCount,
                  _UserFilter.suspended: suspendedCount,
                },
                onSelect: (f) => setState(() => _filter = f),
              ),
            ],
          ),
        ),
        AdminSectionHeader(
          icon: Icons.people_rounded,
          iconColor: AppColors.primaryOrange,
          text:
              '${docs.length} resultado${docs.length != 1 ? 's' : ''}${_search.isNotEmpty || _filter != _UserFilter.all ? ' (de $total)' : ''}',
        ),
        Expanded(
          child: docs.isEmpty
              ? const AdminEmptyState(
                  icon: Icons.search_off_rounded,
                  message: 'Nenhum usuário corresponde à busca/filtro',
                )
              : RefreshIndicator(
                  color: AppColors.primaryOrange,
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminUserTile(
                          userId: doc.id,
                          data: doc.data() as Map<String, dynamic>,
                          userService: widget.userService,
                          isSuspended: suspendedIds.contains(doc.id),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// KPIs
// ═══════════════════════════════════════════════════════════════════
class _KpiRow extends StatelessWidget {
  final int total;
  final int online;
  final int premium;
  final int newUsers;

  const _KpiRow({
    required this.total,
    required this.online,
    required this.premium,
    required this.newUsers,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.people_alt_rounded, 'Total', '$total', AppColors.primaryOrange),
      (Icons.circle, 'Online', '$online', const Color(0xFF43B581)),
      (Icons.workspace_premium_rounded, 'Premium', '$premium',
          const Color(0xFFF2B705)),
      (Icons.fiber_new_rounded, 'Novos (7d)', '$newUsers',
          const Color(0xFF4FC3F7)),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _KpiCard(item: items[i])),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final (IconData, String, String, Color) item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.$4.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(item.$1, size: 14, color: item.$4),
          const SizedBox(height: 4),
          Text(
            item.$3,
            style: TextStyle(
              color: item.$4,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            item.$2,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FILTROS
// ═══════════════════════════════════════════════════════════════════
class _FilterChips extends StatelessWidget {
  final _UserFilter selected;
  final Map<_UserFilter, int> counts;
  final ValueChanged<_UserFilter> onSelect;

  const _FilterChips({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  static const _labels = {
    _UserFilter.all: 'Todos',
    _UserFilter.online: 'Online',
    _UserFilter.premium: 'Premium/Ultra',
    _UserFilter.active: 'Mais ativos',
    _UserFilter.newUsers: 'Novos',
    _UserFilter.suspended: 'Suspensos',
  };

  static const _icons = {
    _UserFilter.all: Icons.apps_rounded,
    _UserFilter.online: Icons.circle,
    _UserFilter.premium: Icons.workspace_premium_rounded,
    _UserFilter.active: Icons.trending_up_rounded,
    _UserFilter.newUsers: Icons.fiber_new_rounded,
    _UserFilter.suspended: Icons.block_rounded,
  };

  static const _colors = {
    _UserFilter.all: AppColors.primaryOrange,
    _UserFilter.online: Color(0xFF43B581),
    _UserFilter.premium: Color(0xFFF2B705),
    _UserFilter.active: Color(0xFFFFD54F),
    _UserFilter.newUsers: Color(0xFF4FC3F7),
    _UserFilter.suspended: Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _UserFilter.values) ...[
            _chip(f),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(_UserFilter f) {
    final isSelected = selected == f;
    final color = _colors[f]!;
    final count = counts[f] ?? 0;
    return GestureDetector(
      onTap: () => onSelect(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.borderDark,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[f], size: 12,
                color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              '${_labels[f]} ($count)',
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}