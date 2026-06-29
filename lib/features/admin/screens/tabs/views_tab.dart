import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_views_service.dart';
import '../../widgets/admin_shared_widgets.dart';

class ViewsTab extends StatefulWidget {
  final AdminViewsService viewsService;
  const ViewsTab({required this.viewsService, Key? key})
      : super(key: key);

  @override
  State<ViewsTab> createState() => _ViewsTabState();
}

class _ViewsTabState extends State<ViewsTab> {
  String? _selectedPostId;
  String? _selectedPostTitle;

  @override
  Widget build(BuildContext context) {
    return _selectedPostId != null
        ? _buildViewersList()
        : _buildPostsList();
  }

  Widget _buildPostsList() {
    return Container(
      color: AppColors.backgroundDark,
      child: StreamBuilder<QuerySnapshot>(
        stream: widget.viewsService.mostViewedPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryOrange),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.bar_chart_rounded,
              message: 'Nenhuma visualização registrada ainda',
            );
          }

          final docs = snapshot.data!.docs;
          final totalViews = docs.fold<int>(
            0,
            (sum, d) =>
                sum +
                ((d.data() as Map<String, dynamic>)['totalViews']
                            as num? ??
                        0)
                    .toInt(),
          );

          return Column(
            children: [
              AdminSectionHeader(
                icon: Icons.bar_chart_rounded,
                iconColor: AppColors.primaryOrange,
                text:
                    '$totalViews visualizações em ${docs.length} matéria${docs.length != 1 ? 's' : ''}',
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primaryOrange,
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data =
                          docs[i].data() as Map<String, dynamic>;
                      final postId = docs[i].id;
                      final title = (data['postTitle'] as String?) ??
                          'Sem título';
                      final total =
                          (data['totalViews'] as num?)?.toInt() ?? 0;
                      final unique =
                          (data['uniqueViewers'] as num?)?.toInt() ??
                              0;
                      final lastViewed =
                          (data['lastViewedAt'] as Timestamp?)
                              ?.toDate();
                      final lastStr = lastViewed != null
                          ? '${lastViewed.day.toString().padLeft(2, '0')}/${lastViewed.month.toString().padLeft(2, '0')}/${lastViewed.year}  ${lastViewed.hour.toString().padLeft(2, '0')}:${lastViewed.minute.toString().padLeft(2, '0')}'
                          : '';

                      Color rankColor = AppColors.textSecondary;
                      if (i == 0) rankColor = const Color(0xFFFFD700);
                      if (i == 1) rankColor = const Color(0xFFC0C0C0);
                      if (i == 2) rankColor = const Color(0xFFCD7F32);

                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedPostId = postId;
                          _selectedPostTitle = title;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0A0A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: i < 3
                                  ? rankColor.withOpacity(0.35)
                                  : AppColors.borderDark,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: rankColor.withOpacity(0.12),
                                    border: Border.all(
                                        color:
                                            rankColor.withOpacity(0.4)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: rankColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          AdminViewStat(
                                            icon:
                                                Icons.visibility_rounded,
                                            label: '$total views',
                                            color:
                                                AppColors.primaryOrange,
                                          ),
                                          const SizedBox(width: 12),
                                          AdminViewStat(
                                            icon: Icons.person_rounded,
                                            label: '$unique únicos',
                                            color:
                                                const Color(0xFF4FC3F7),
                                          ),
                                        ],
                                      ),
                                      if (lastStr.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        AdminViewStat(
                                          icon: Icons.schedule_rounded,
                                          label: lastStr,
                                          color: AppColors.textMuted,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildViewersList() {
    return Container(
      color: AppColors.backgroundDark,
      child: Column(
        children: [
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedPostId = null;
                    _selectedPostTitle = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedPostTitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.viewsService
                  .postViewersStream(_selectedPostId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const AdminEmptyState(
                    icon: Icons.visibility_off_rounded,
                    message: 'Nenhum visualizador registrado',
                  );
                }

                final docs = snapshot.data!.docs;

                return Column(
                  children: [
                    AdminSectionHeader(
                      icon: Icons.people_rounded,
                      iconColor: AppColors.primaryOrange,
                      text:
                          '${docs.length} leitor${docs.length != 1 ? 'es' : ''} únicos',
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data = docs[i].data()
                              as Map<String, dynamic>;
                          final name =
                              (data['userName'] as String?) ??
                                  'Leitor';
                          final email =
                              (data['userEmail'] as String?) ?? '';
                          final viewCount =
                              (data['viewCount'] as num?)?.toInt() ??
                                  1;
                          final firstView =
                              (data['firstViewedAt'] as Timestamp?)
                                  ?.toDate();
                          final lastView =
                              (data['lastViewedAt'] as Timestamp?)
                                  ?.toDate();

                          String fmt(DateTime? d) {
                            if (d == null) return '';
                            return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0A0A),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.borderDark),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors
                                        .primaryOrange
                                        .withOpacity(0.15),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primaryOrange,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700,
                                            )),
                                        if (email.isNotEmpty)
                                          Text(email,
                                              style: const TextStyle(
                                                color:
                                                    AppColors.textMuted,
                                                fontSize: 11,
                                              )),
                                        const SizedBox(height: 4),
                                        AdminViewStat(
                                          icon:
                                              Icons.visibility_rounded,
                                          label:
                                              '$viewCount vez${viewCount != 1 ? 'es' : ''}',
                                          color: AppColors.primaryOrange,
                                        ),
                                        if (fmt(firstView).isNotEmpty)
                                          AdminViewStat(
                                            icon: Icons.login_rounded,
                                            label:
                                                '1ª vez: ${fmt(firstView)}',
                                            color: AppColors.textMuted,
                                          ),
                                        if (fmt(lastView).isNotEmpty)
                                          AdminViewStat(
                                            icon:
                                                Icons.schedule_rounded,
                                            label:
                                                'Última: ${fmt(lastView)}',
                                            color: AppColors.textMuted,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (viewCount > 1)
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryOrange
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.primaryOrange
                                              .withOpacity(0.4),
                                        ),
                                      ),
                                      child: Text(
                                        'x$viewCount',
                                        style: const TextStyle(
                                          color: AppColors.primaryOrange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
