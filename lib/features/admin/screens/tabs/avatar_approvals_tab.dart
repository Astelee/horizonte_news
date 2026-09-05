import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_avatar_approval_service.dart';
import '../../widgets/admin_avatar_approval_tile.dart';
import '../../widgets/admin_shared_widgets.dart';

class AvatarApprovalsTab extends StatelessWidget {
  final AdminAvatarApprovalService approvalService;
  const AvatarApprovalsTab({required this.approvalService, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder(
        stream: approvalService.pendingStream(),
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
              icon: Icons.photo_camera_back_rounded,
              message: 'Nenhuma foto pendente de aprovação',
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              AdminSectionHeader(
                icon: Icons.photo_camera_back_rounded,
                iconColor: AppColors.primaryOrange,
                text:
                    '${docs.length} foto${docs.length != 1 ? 's' : ''} pendente${docs.length != 1 ? 's' : ''}',
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
                      return AdminAvatarApprovalTile(
                        uid: doc.id,
                        data: doc.data() as Map<String, dynamic>,
                        approvalService: approvalService,
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