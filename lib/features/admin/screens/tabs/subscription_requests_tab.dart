import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_subscription_request_service.dart';
import '../../widgets/admin_subscription_request_tile.dart';
import '../../widgets/admin_shared_widgets.dart';

class SubscriptionRequestsTab extends StatelessWidget {
  final AdminSubscriptionRequestService requestService;
  const SubscriptionRequestsTab({required this.requestService, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder(
        stream: requestService.pendingStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryOrange),
            );
          }
          if (snapshot.hasError) {
            return AdminErrorState(message: '${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.workspace_premium_outlined,
              message: 'Nenhuma solicitação de assinatura pendente',
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              AdminSectionHeader(
                icon: Icons.workspace_premium_outlined,
                iconColor: AppColors.primaryOrange,
                text: '${docs.length} solicitação'
                    '${docs.length != 1 ? 'ões' : ''} pendente'
                    '${docs.length != 1 ? 's' : ''}',
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
                      return AdminSubscriptionRequestTile(
                        requestId: doc.id,
                        data: doc.data() as Map<String, dynamic>,
                        requestService: requestService,
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