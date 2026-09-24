import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_shared_widgets.dart';
import '../../widgets/admin_user_tile.dart';

// A aba mostra sempre todos os usuários (sem chips de filtro), com
// busca livre por nome, username, e-mail ou UID.

class UsersTab extends StatefulWidget {
  final AdminUserService userService;
  const UsersTab({required this.userService, Key? key}) : super(key: key);

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  // Criadas UMA vez (não a cada build) — chamar .snapshots() de novo
  // dentro de build() gera uma nova Stream a cada setState (ex: digitar
  // na busca), o que reinicia o StreamBuilder (volta a "waiting" por um
  // instante) e causa a piscada/perda de foco do teclado na busca.
  late final Stream<QuerySnapshot> _usersStream = widget.userService.usersStream();
  late final Stream<QuerySnapshot> _suspensionsStream =
      widget.userService.suspensionsStream();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
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
            stream: _suspensionsStream,
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
    // ── KPIs (sobre a base completa, antes de pesquisar) ────────────
    final total = allDocs.length;
    int onlineCount = 0;
    for (final doc in allDocs) {
      final d = doc.data() as Map<String, dynamic>;
      if (_isOnline(d)) onlineCount++;
    }

    var docs = allDocs;

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
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
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
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
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
              const SizedBox(height: 6),
            ],
          ),
        ),
        AdminSectionHeader(
          icon: Icons.people_rounded,
          iconColor: AppColors.primaryOrange,
          text:
              '${docs.length} resultado${docs.length != 1 ? 's' : ''}${_search.isNotEmpty ? ' (de $total)' : ''}',
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

  const _KpiRow({
    required this.total,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.people_alt_rounded, 'Total', '$total', AppColors.primaryOrange),
      (Icons.circle, 'Online', '$online', const Color(0xFF43B581)),
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
// (chips de filtro removidos — a aba mostra sempre todos os usuários)
// ═══════════════════════════════════════════════════════════════════