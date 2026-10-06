import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/support_provider.dart';
import '../services/support_launcher.dart';

/// Sinais de visibilidade do botão "Fale conosco" que não vêm do
/// Navigator.
class SupportFabVisibility {
  SupportFabVisibility._();

  /// true enquanto o menu lateral está aberto (o AppDrawer liga/desliga).
  static final ValueNotifier<bool> drawerOpen = ValueNotifier<bool>(false);
}

/// Acompanha a pilha de rotas para o botão saber em qual tela está e se
/// há diálogo / bottom sheet / menu por cima. Registrado em
/// MaterialApp.navigatorObservers (main.dart).
class SupportRouteObserver extends NavigatorObserver {
  /// Nome da rota de PÁGINA no topo (null = rota sem nome, ex.: editor
  /// ou player em tela cheia aberto com MaterialPageRoute direto).
  static final ValueNotifier<String?> currentPage = ValueNotifier<String?>(null);

  /// Quantidade de rotas que não são página (diálogo, bottom sheet,
  /// menu) acima da página atual.
  static final ValueNotifier<int> overlaysOnTop = ValueNotifier<int>(0);

  final List<Route<dynamic>> _stack = [];

  void _publish() {
    String? page;
    var overlays = 0;
    for (var i = _stack.length - 1; i >= 0; i--) {
      final r = _stack[i];
      if (r is PageRoute) {
        page = r.settings.name;
        break;
      }
      overlays++;
    }
    // Notifica depois do frame: o Navigator chama os observers durante
    // a construção/transição e não podemos dar setState nesse momento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentPage.value = page;
      overlaysOnTop.value = overlays;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _publish();
  }
}

/// Coloca o botão flutuante "Fale conosco" sobre o app inteiro, uma
/// única vez (MaterialApp.builder em main.dart) — nenhuma tela precisa
/// conhecê-lo nem duplicá-lo.
///
/// Fica oculto: sem login; fora das telas de [visibleRoutes] (login,
/// chat, painel ADM, editores e rotas sem nome, como vídeo em tela
/// cheia); com diálogo/bottom sheet/menu aberto; com o menu lateral
/// aberto; e com o teclado aberto.
class SupportFabOverlay extends StatefulWidget {
  final Widget child;
  const SupportFabOverlay({Key? key, required this.child}) : super(key: key);

  /// Telas principais onde o botão aparece. Telas com campo de texto ou
  /// botão fixo na base (detalhe da notícia, perfil, assinatura,
  /// check-in, pet, configurações) ficam de fora para não cobrir nada.
  static const Set<String> visibleRoutes = {
    AppRoutes.home,
    AppRoutes.category,
    AppRoutes.favorites,
    AppRoutes.mostRead,
    AppRoutes.horizonNow,
    AppRoutes.events,
    AppRoutes.ranking,
    AppRoutes.notifications,
  };

  /// Altura reservada na Home para a barra de anúncios (HybridBannerAd).
  static const double _homeBannerSpace = 64;

  @override
  State<SupportFabOverlay> createState() => _SupportFabOverlayState();
}

class _SupportFabOverlayState extends State<SupportFabOverlay> {
  User? _user = FirebaseAuth.instance.currentUser;
  StreamSubscription<User?>? _authSub;
  bool _expanded = true;
  Timer? _collapseTimer;
  String? _lastPage;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
    _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _expanded = true;
    _collapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<String?>(
          valueListenable: SupportRouteObserver.currentPage,
          builder: (context, page, _) => ValueListenableBuilder<int>(
            valueListenable: SupportRouteObserver.overlaysOnTop,
            builder: (context, overlays, _) => ValueListenableBuilder<bool>(
              valueListenable: SupportFabVisibility.drawerOpen,
              builder: (context, drawerOpen, _) =>
                  _buildFab(context, page, overlays, drawerOpen),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFab(
      BuildContext context, String? page, int overlays, bool drawerOpen) {
    final media = MediaQuery.of(context);
    final visible = _user != null &&
        page != null &&
        SupportFabOverlay.visibleRoutes.contains(page) &&
        overlays == 0 &&
        !drawerOpen &&
        media.viewInsets.bottom == 0;

    if (page != _lastPage) {
      _lastPage = page;
      // Reabre o rótulo ao entrar em uma tela principal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_scheduleCollapse);
      });
    }

    if (!visible) return const SizedBox.shrink();

    final bottom = media.padding.bottom +
        16 +
        (page == AppRoutes.home ? SupportFabOverlay._homeBannerSpace : 0);

    return Positioned(
      right: 16,
      bottom: bottom,
      child: Consumer<SupportProvider>(
        builder: (context, support, _) => _FabButton(
          unread: support.unreadCount,
          expanded: _expanded,
          onTap: () {
            SupportLauncher.open(asAgent: support.isAgent);
          },
        ),
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  final int unread;
  final bool expanded;
  final VoidCallback onTap;

  const _FabButton({
    required this.unread,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread > 0
          ? 'Fale conosco, $unread não lidas'
          : 'Fale conosco',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.primaryOrange,
            elevation: 6,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onTap,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: expanded ? 16 : 14,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_rounded,
                          color: Colors.black, size: 22),
                      if (expanded) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Fale conosco',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -6,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}