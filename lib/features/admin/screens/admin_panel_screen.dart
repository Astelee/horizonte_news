import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_comment_service.dart';
import '../services/admin_dashboard_service.dart';
import '../services/admin_news_service.dart';
import '../services/admin_user_service.dart';
import '../services/admin_views_service.dart';
import 'tabs/overview_tab.dart';
import 'tabs/comments_tab.dart';
import 'tabs/banned_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/views_tab.dart';
import 'tabs/poderes_tab.dart';
import 'tabs/news_tab.dart';

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
  final _dashboardService = AdminDashboardService();
  final _newsService = AdminNewsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    _tabController.animateTo(index);
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
                  OverviewTab(
                    dashboardService: _dashboardService,
                    userService: _userService,
                    onGoToUsers: () => _goToTab(3),
                    onGoToViews: () => _goToTab(4),
                    onGoToBanned: () => _goToTab(2),
                  ),
                  CommentsTab(
                    commentService: _commentService,
                    userService: _userService,
                  ),
                  BannedTab(userService: _userService),
                  UsersTab(userService: _userService),
                  ViewsTab(
                    viewsService: _viewsService,
                    commentService: _commentService,
                  ),
                  const PoderesTab(),
                  NewsTab(newsService: _newsService),
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
                  'CENTRAL DE CONTROLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Horizonte News · Painel Administrativo',
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryOrange.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.black,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.primaryOrange,
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'GERAL', icon: Icon(Icons.dashboard_rounded, size: 18)),
              Tab(text: 'COMENTÁRIOS', icon: Icon(Icons.chat_bubble_rounded, size: 18)),
              Tab(text: 'BANIDOS', icon: Icon(Icons.block_rounded, size: 18)),
              Tab(text: 'USUÁRIOS', icon: Icon(Icons.people_rounded, size: 18)),
              Tab(text: 'VISUALIZAÇÕES', icon: Icon(Icons.bar_chart_rounded, size: 18)),
              Tab(text: 'NÍVEIS', icon: Icon(Icons.auto_awesome_rounded, size: 18)),
              Tab(text: 'NOTÍCIAS', icon: Icon(Icons.article_rounded, size: 18)),
            ],
          ),
        ),
      ),
    );
  }
}