import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_banned_tile.dart';
import '../../widgets/admin_shared_widgets.dart';

class BannedTab extends StatelessWidget {
  final AdminUserService userService;
  const BannedTab({required this.userService, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder(
        stream: userService.suspensionsStream(),
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
              icon: Icons.block_rounded,
              message: 'Nenhum usuário banido',
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              AdminSectionHeader(
                icon: Icons.block_rounded,
                iconColor: const Color(0xFFEF5350),
                text:
                    '${docs.length} usuário${docs.length != 1 ? 's' : ''} banido${docs.length != 1 ? 's' : ''}',
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
                      return AdminBannedTile(
                        userId: doc.id,
                        data: doc.data() as Map<String, dynamic>,
                        userService: userService,
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
