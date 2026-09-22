import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../providers/admin_provider.dart';
import '../services/admin_avatar_approval_service.dart';
import '../services/admin_comment_service.dart';
import '../services/admin_config_service.dart';
import '../services/admin_dashboard_service.dart';
import '../services/admin_news_service.dart';
import '../services/admin_subscription_request_service.dart';
import '../services/admin_user_service.dart';
import '../services/admin_views_service.dart';
import 'tabs/overview_tab.dart';
import 'tabs/comments_tab.dart';
import 'tabs/banned_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/views_tab.dart';
import 'tabs/poderes_tab.dart';
import 'tabs/news_tab.dart';
import 'tabs/avatar_approvals_tab.dart';
import 'tabs/subscription_requests_tab.dart';
import 'tabs/config_tab.dart';
import 'tabs/ads_bar_tab.dart';

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
  final _avatarApprovalService = AdminAvatarApprovalService();
  final _subscriptionRequestService = AdminSubscriptionRequestService();
  final _configService = AdminConfigService();

  static const List<String> _tabTitles = [
    'CENTRAL DE CONTROLE',
    'COMENTÁRIOS',
    'BANIDOS',
    'USUÁRIOS',
    'VISUALIZAÇÕES',
    'NÍVEIS & XP',
    'PUBLICAÇÕES',
    'FOTOS PENDENTES',
    'ASSINATURAS PENDENTES',
    'CONFIGURAÇÕES',
    'BARRA DE ANÚNCIOS',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 11, vsync: this);
    _tabController.addListener(() {
      // Reconstrói o AppBar (título + botão voltar) ao trocar de aba,
      // mesmo durante o gesto (sem esperar a animação terminar).
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    _tabController.animateTo(index);
  }

  void _handleBack() {
    if (_tabController.index != 0) {
      _goToTab(0);
    } else {
      Navigator.pop(context);
    }
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
      child: PopScope(
        canPop: _tabController.index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _tabController.index != 0) _goToTab(0);
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundDark,
          // resizeToAvoidBottomInset: false aqui é essencial. Por padrão
          // (true), quando o teclado abre em qualquer aba, o Scaffold
          // EXTERNO encolhe o body inteiro — inclusive o NestedScrollView
          // e o SliverAppBar colapsável dentro dele. O NestedScrollView
          // então recalcula a posição/expansão do SliverAppBar em reação
          // a essa mudança de tamanho, e esse recálculo interrompe o
          // foco de qualquer TextField que tenha acabado de abrir o
          // teclado (ex.: a busca da aba PUBLICAÇÕES) — o teclado sobe e
          // desce na hora, antes de dar tempo de digitar.
          // Com false, é o Scaffold interno de cada aba (ex.: o da
          // NewsTab) que reage ao teclado; o NestedScrollView e o
          // SliverAppBar externos nunca veem esse inset mudar.
          resizeToAvoidBottomInset: false,
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [_buildAppBar()],
            body: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: Container(
                color: AppColors.backgroundDark,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  // Cada aba é envolvida no próprio _TabScaffold (ver
                  // definição abaixo da classe): um Scaffold transparente
                  // que trata o teclado individualmente por aba. Antes,
                  // resizeToAvoidBottomInset:false só no Scaffold externo
                  // teria deixado ConfigTab, AdsBarTab e UsersTab (que
                  // também têm TextField) sem nenhum tratamento de
                  // teclado — o teclado poderia cobrir o campo sendo
                  // editado nessas abas. Com isso, todas ganham o mesmo
                  // isolamento que a NewsTab já tinha.
                  children: [
                  _TabScaffold(
                    child: OverviewTab(
                      dashboardService: _dashboardService,
                      userService: _userService,
                      newsService: _newsService,
                      commentService: _commentService,
                      avatarApprovalService: _avatarApprovalService,
                      onGoToUsers: () => _goToTab(3),
                      onGoToViews: () => _goToTab(4),
                      onGoToBanned: () => _goToTab(2),
                      onGoToNews: () => _goToTab(6),
                      onGoToComments: () => _goToTab(1),
                      onGoToLevels: () => _goToTab(5),
                      onGoToAvatarApprovals: () => _goToTab(7),
                      onGoToConfig: () => _goToTab(9),
                      onGoToAdsBar: () => _goToTab(10),
                    ),
                  ),
                  _TabScaffold(
                    child: CommentsTab(
                      commentService: _commentService,
                      userService: _userService,
                    ),
                  ),
                  _TabScaffold(child: BannedTab(userService: _userService)),
                  _TabScaffold(child: UsersTab(userService: _userService)),
                  _TabScaffold(
                    child: ViewsTab(
                      viewsService: _viewsService,
                      commentService: _commentService,
                    ),
                  ),
                    const _TabScaffold(child: PoderesTab()),
                    _TabScaffold(child: NewsTab(newsService: _newsService)),
                    _TabScaffold(
                      child: AvatarApprovalsTab(
                          approvalService: _avatarApprovalService),
                    ),
                    _TabScaffold(
                      child: SubscriptionRequestsTab(
                          requestService: _subscriptionRequestService),
                    ),
                    _TabScaffold(
                        child: ConfigTab(configService: _configService)),
                    _TabScaffold(
                        child: AdsBarTab(configService: _configService)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final onOverview = _tabController.index == 0;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(
          onOverview
              ? Icons.arrow_back_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
        ),
        tooltip: onOverview ? 'Voltar' : 'Voltar à Central de Gestão',
        onPressed: _handleBack,
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
              children: [
                Text(
                  _tabTitles[_tabController.index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
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
    );
  }
}

/// Envolve cada aba do painel ADM em seu próprio Scaffold transparente.
///
/// Isola o teclado por aba: com resizeToAvoidBottomInset:false no
/// Scaffold externo (ver AdminPanelScreen.build), nenhuma aba recebe
/// tratamento de teclado automaticamente. Este wrapper devolve esse
/// tratamento individualmente para cada uma, sem prender o
/// NestedScrollView/SliverAppBar externos ao ciclo de abrir/fechar
/// teclado — que era o que causava o campo de busca da aba
/// PUBLICAÇÕES (e teria o mesmo efeito em CONFIGURAÇÕES, BARRA DE
/// ANÚNCIOS e USUÁRIOS) perder o foco assim que o teclado tentava subir.
class _TabScaffold extends StatelessWidget {
  final Widget child;
  const _TabScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: child,
    );
  }
}