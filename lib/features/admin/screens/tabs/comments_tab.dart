import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_comment_service.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_comment_tile.dart';
import '../../widgets/admin_shared_widgets.dart';

class CommentsTab extends StatelessWidget {
  final AdminCommentService commentService;
  final AdminUserService userService;

  const CommentsTab({
    required this.commentService,
    required this.userService,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder(
        stream: commentService.allCommentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange),
            );
          }
          if (snapshot.hasError) {
            return AdminErrorState(
                message: '${snapshot.error}');
          }
          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              message: 'Nenhum comentário encontrado',
            );
          }

          final docs = snapshot.data!.docs;
          final hidden =
              docs.where((d) => (d.data() as Map)['hidden'] == true).length;

          return Column(
            children: [
              AdminSectionHeader(
                icon: Icons.chat_bubble_rounded,
                iconColor: AppColors.primaryOrange,
                text:
                    '${docs.length} comentário${docs.length != 1 ? 's' : ''}${hidden > 0 ? ' · $hidden oculto${hidden != 1 ? 's' : ''}' : ''}',
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
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final pathParts =
                          doc.reference.path.split('/');
                      final postId = pathParts.length >= 2
                          ? pathParts[1]
                          : '';
                      return AdminCommentTile(
                        commentId: doc.id,
                        postId: postId,
                        data: data,
                        commentService: commentService,
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
