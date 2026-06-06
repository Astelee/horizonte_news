import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class BreakingNewsBanner extends StatelessWidget {
  final PostModel? urgentPost;

  const BreakingNewsBanner({Key? key, this.urgentPost}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Caso não exista nenhuma notícia marcante ou plantão no momento, o widget oculta-se
    if (urgentPost == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.emergencyRed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.postDetail,
            arguments: urgentPost,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.campaign,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PLANTÃO / URGENTE',
                      style: TextStyle(
                        color: Colors.white,
                        // CORREÇÃO: FontWeight.black substituído por w900
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      urgentPost!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}