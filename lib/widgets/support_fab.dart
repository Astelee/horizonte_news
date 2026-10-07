import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/support_provider.dart';
import 'app_messenger.dart';
import '../services/support_launcher.dart';

/// Sinais de visibilidade do botão "Fale conosco" que não vêm do
/// Navigator.
class SupportFabVisibility {
  SupportFabVisibility._();

  /// true enquanto o menu lateral está aberto (o AppDrawer liga/desliga).
  static final ValueNotifier<bool> drawerOpen = ValueNotifier<bool>(false);

  /// true = o usuário fechou o botão arrastando-o para o "X". Fica
  /// salvo no aparelho; pode ser reexibido no menu ⋮ da conversa.
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  static const String _hiddenKey = 'support_fab_hidden';
  static const String _sideKey = 'support_fab_side';
  static const String _yKey = 'support_fab_y';

  static Future<void> setHidden(bool value) async {
    hidden.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hiddenKey, value);
    } catch (_) {}
  }
}

/// Acompanha a pilha de rotas para o botão saber em qual tela está e se
/// há diálogo / bottom sheet / menu por cima. Registrado em
/// MaterialApp.navigatorObservers (main.dart).
class SupportRouteObserver extends NavigatorObserver {
  /// Instância única usada no MaterialApp. A pilha de rotas é ESTÁTICA
  /// porque o MaterialApp pode ser reconstruído (providers, tema) e
  /// criar um observador novo com a pilha vazia: sem isso, ao voltar de
  /// uma tela o botão deixava de reconhecer a rota e sumia.
  static final SupportRouteObserver instance = SupportRouteObserver._();
  SupportRouteObserver._();
  factory SupportRouteObserver() => instance;

  /// Nome da rota de PÁGINA no topo (null = rota sem nome, ex.: editor
  /// ou player em tela cheia aberto com MaterialPageRoute direto).
  static final ValueNotifier<String?> currentPage = ValueNotifier<String?>(null);

  /// Quantidade de rotas que não são página (diálogo, bottom sheet,
  /// menu) acima da página atual.
  static final ValueNotifier<int> overlaysOnTop = ValueNotifier<int>(0);

  static final List<Route<dynamic>> _stack = [];

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
/// aberto; com o teclado aberto; e depois de fechado pelo usuário.
///
/// Toque = abre o atendimento. Arrastar (é só encostar e mover) = muda de
/// lugar e gruda na borda mais próxima. Arrastar até o "X" que aparece
/// embaixo = fecha o botão.
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

  // Posição personalizada (false = padrão: canto inferior direito).
  bool _customPos = false;
  bool _rightSide = true;
  double _yFraction = 0.7; // distância do topo / altura da tela

  // Arrastando.
  bool _dragging = false;
  Offset _dragTopLeft = Offset.zero;
  bool _overClose = false;

  final GlobalKey _fabKey = GlobalKey();

  static const double _fabSize = 56;
  static const double _margin = 16;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
    _loadPrefs();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      SupportFabVisibility.hidden.value =
          prefs.getBool(SupportFabVisibility._hiddenKey) ?? false;
      final side = prefs.getString(SupportFabVisibility._sideKey);
      final y = prefs.getDouble(SupportFabVisibility._yKey);
      if (!mounted) return;
      if (side != null && y != null) {
        setState(() {
          _customPos = true;
          _rightSide = side == 'r';
          _yFraction = y.clamp(0.0, 1.0).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _savePos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          SupportFabVisibility._sideKey, _rightSide ? 'r' : 'l');
      await prefs.setDouble(SupportFabVisibility._yKey, _yFraction);
    } catch (_) {}
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
                  ValueListenableBuilder<bool>(
                valueListenable: SupportFabVisibility.hidden,
                builder: (context, hidden, _) =>
                    _buildFab(context, page, overlays, drawerOpen, hidden),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Faixa vertical permitida (topo do botão) na tela atual.
  (double, double) _yRange(BuildContext context, String? page) {
    final media = MediaQuery.of(context);
    final top = media.padding.top + 64; // abaixo da barra superior
    final bottom = media.size.height -
        media.padding.bottom -
        _margin -
        _fabSize -
        (page == AppRoutes.home ? SupportFabOverlay._homeBannerSpace : 0);
    return (top, bottom < top ? top : bottom);
  }

  Rect _closeTargetRect(BuildContext context) {
    final media = MediaQuery.of(context);
    const size = 64.0;
    return Rect.fromLTWH(
      (media.size.width - size) / 2,
      media.size.height - media.padding.bottom - size - 24,
      size,
      size,
    );
  }

  // ── Arrastar (começa assim que o dedo se move; sem precisar segurar) ──

  void _onPanStart(DragStartDetails d) {
    // Posição atual real do botão na tela, para ele não "pular".
    Offset topLeft = d.globalPosition - const Offset(_fabSize / 2, _fabSize / 2);
    final box = _fabKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      topLeft = box.localToGlobal(Offset.zero);
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _dragging = true;
      _dragTopLeft = topLeft;
      _overClose = false;
    });
  }

  void _onPanUpdate(BuildContext context, DragUpdateDetails d) {
    if (!_dragging) return;
    final media = MediaQuery.of(context);
    final next = _dragTopLeft + d.delta;
    final clamped = Offset(
      next.dx.clamp(0.0, media.size.width - _fabSize).toDouble(),
      next.dy.clamp(media.padding.top, media.size.height - _fabSize).toDouble(),
    );
    final center = clamped + const Offset(_fabSize / 2, _fabSize / 2);
    final nearClose = _closeTargetRect(context).inflate(28).contains(center);
    if (nearClose && !_overClose) HapticFeedback.selectionClick();
    setState(() {
      _dragTopLeft = clamped;
      _overClose = nearClose;
    });
  }

  void _onPanEnd(BuildContext context, String? page) {
    if (!_dragging) return;
    final media = MediaQuery.of(context);
    if (_overClose) {
      setState(() {
        _dragging = false;
        _overClose = false;
      });
      SupportFabVisibility.setHidden(true);
      AppMessenger.info(
          'Botão fechado. Para reexibir: Atendimento → menu ⋮ → Mostrar botão.');
      return;
    }
    // Gruda na borda mais próxima e guarda a altura escolhida.
    final centerX = _dragTopLeft.dx + _fabSize / 2;
    final (minY, maxY) = _yRange(context, page);
    final y = _dragTopLeft.dy.clamp(minY, maxY).toDouble();
    setState(() {
      _dragging = false;
      _customPos = true;
      _rightSide = centerX >= media.size.width / 2;
      _yFraction = y / media.size.height;
    });
    _savePos();
  }

  Widget _buildFab(BuildContext context, String? page, int overlays,
      bool drawerOpen, bool hidden) {
    final media = MediaQuery.of(context);
    final visible = _user != null &&
        !hidden &&
        page != null &&
        SupportFabOverlay.visibleRoutes.contains(page) &&
        overlays == 0 &&
        !drawerOpen &&
        media.viewInsets.bottom == 0;

    if (!visible) return const SizedBox.shrink();

    final button = Consumer<SupportProvider>(
      builder: (context, support, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => SupportLauncher.open(asAgent: support.isAgent),
        onPanStart: _onPanStart,
        onPanUpdate: (d) => _onPanUpdate(context, d),
        onPanEnd: (_) => _onPanEnd(context, page),
        onPanCancel: () {
          // Gesto interrompido (ex.: gesto do sistema): só solta o botão
          // onde está, sem fechar nem salvar posição.
          if (_dragging) {
            setState(() {
              _dragging = false;
              _overClose = false;
            });
          }
        },
        child: _FabButton(
          key: _fabKey,
          unread: support.unreadCount,
          dragging: _dragging,
        ),
      ),
    );

    final Widget positioned;
    if (_dragging) {
      positioned = Positioned(
        key: const ValueKey('support_fab_button'),
        left: _dragTopLeft.dx,
        top: _dragTopLeft.dy,
        child: button,
      );
    } else if (_customPos) {
      final (minY, maxY) = _yRange(context, page);
      final top =
          (_yFraction * media.size.height).clamp(minY, maxY).toDouble();
      positioned = Positioned(
        key: const ValueKey('support_fab_button'),
        top: top,
        left: _rightSide ? null : _margin,
        right: _rightSide ? _margin : null,
        child: button,
      );
    } else {
      final bottom = media.padding.bottom +
          _margin +
          (page == AppRoutes.home ? SupportFabOverlay._homeBannerSpace : 0);
      positioned = Positioned(
        key: const ValueKey('support_fab_button'),
        right: _margin,
        bottom: bottom,
        child: button,
      );
    }

    // IMPORTANTE: o botão tem key fixa e a lista nunca muda de tamanho.
    // Antes, o "X" entrava na lista só durante o arrasto, o que recriava
    // o botão no meio do gesto e fazia o arrasto falhar às vezes.
    return Positioned.fill(
      child: Stack(
        children: [
          _dragging ? _closeTarget(context) : const SizedBox.shrink(),
          positioned,
        ],
      ),
    );
  }

  Widget _closeTarget(BuildContext context) {
    final r = _closeTargetRect(context);
    return Positioned(
      key: const ValueKey('support_fab_close'),
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _overClose
                ? AppColors.emergencyRed
                : Colors.black.withOpacity(0.7),
            border: Border.all(
              color: _overClose ? Colors.white : AppColors.primaryOrange,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: _overClose ? 34 : 28,
          ),
        ),
      ),
    );
  }
}

/// Botão redondo, sempre só com o ícone de conversa (sem texto que
/// aparece e some). O nome fica na acessibilidade (leitor de tela).
class _FabButton extends StatelessWidget {
  final int unread;
  final bool dragging;

  const _FabButton({
    Key? key,
    required this.unread,
    required this.dragging,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread > 0
          ? 'Fale conosco, $unread não lidas. Arraste para mover.'
          : 'Fale conosco. Arraste para mover.',
      child: SizedBox(
        width: _SupportFabOverlayState._fabSize,
        height: _SupportFabOverlayState._fabSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: AppColors.primaryOrange,
                elevation: dragging ? 14 : 6,
                shadowColor: Colors.black,
                shape: const CircleBorder(),
                child: const Center(
                  child: Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
      ),
    );
  }
}