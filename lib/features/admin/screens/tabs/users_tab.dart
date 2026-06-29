import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_shared_widgets.dart';
import '../../widgets/admin_user_tile.dart';

class UsersTab extends StatefulWidget {
  final AdminUserService userService;
  const UsersTab({required this.userService, Key? key})
      : super(key: key);

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder(
        stream: widget.userService.usersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange),
            );
          }
          if (snapshot.hasError) {
            return AdminErrorState(message: '${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.people_outline_rounded,
              message: 'Nenhum usuário encontrado',
            );
          }

          var docs = snapshot.data!.docs;

          // Filtro de pesquisa
          if (_search.isNotEmpty) {
            docs = docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final name = (d['displayName'] ?? d['name'] ??
                      d['userName'] ?? '')
                  .toString()
                  .toLowerCase();
              final email =
                  (d['email'] ?? '').toString().toLowerCase();
              final q = _search.toLowerCase();
              return name.contains(q) || email.contains(q);
            }).toList();
          }

          return Column(
            children: [
              // Barra de pesquisa
              Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar usuário...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary
                          .withOpacity(0.5),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textSecondary, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0A0A0A),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              AdminSectionHeader(
                icon: Icons.people_rounded,
                iconColor: AppColors.primaryOrange,
                text:
                    '${docs.length} usuário${docs.length != 1 ? 's' : ''} cadastrado${docs.length != 1 ? 's' : ''}',
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primaryOrange,
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return AdminUserTile(
                        userId: doc.id,
                        data:
                            doc.data() as Map<String, dynamic>,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
