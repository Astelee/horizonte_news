import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_comment_service.dart';
import '../services/admin_user_service.dart';
import '../services/admin_views_service.dart';
import 'tabs/comments_tab.dart';
import 'tabs/banned_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/views_tab.dart';
import 'tabs/poderes_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _commentService = AdminCommentService();
  final _userService = AdminUserService();
  final _viewsService = AdminViewsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
          body: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Container(
              color: AppColors.backgroundDark,
              child: TabBarView(
                controller: _tabController,
                children: [
                  CommentsTab(
                    commentService: _commentService,
                    userService: _userService,
                  ),
                  BannedTab(userService: _userService),
                  UsersTab(userService: _userService),
                  ViewsTab(viewsService: _viewsService),
                  PoderesTab(userService: _userService),
                ],
              ),
            ),
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
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.chat_bubble_rounded, size: 18), text: 'COMENTÁRIOS'),
          Tab(icon: Icon(Icons.block_rounded, size: 18), text: 'BANIDOS'),
          Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'USUÁRIOS'),
          Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'VISUALIZAÇÕES'),
          Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'PODERES'),
        ],
      ),
    );
  }
}
