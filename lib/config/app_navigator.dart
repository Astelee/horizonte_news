import 'package:flutter/material.dart';
import 'app_routes.dart';

/// Chave global de navegação — permite que serviços fora da árvore de
/// widgets (ex.: NotificationService, uma classe estática) naveguem
/// programaticamente, como ao abrir uma notícia a partir de um clique
/// em notificação push.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Nome da rota atualmente visível no topo da pilha de navegação.
///
/// É atualizado automaticamente pelo [RouteTrackerObserver] a cada
/// push/pop/replace/remove, e é a fonte única de verdade para "qual
/// tela está ativa agora" — usada, por exemplo, pelo AppDrawer para
/// destacar o item correto, sem depender do `context` local de uma
/// tela específica (que pode ficar "parado" numa rota antiga quando
/// outra rota é empilhada por cima dela).
final ValueNotifier<String> currentRouteNotifier =
    ValueNotifier<String>(AppRoutes.home);

/// NavigatorObserver que mantém [currentRouteNotifier] sincronizado
/// com a rota realmente ativa no topo da pilha. Registrado uma única
/// vez no MaterialApp (navigatorObservers), reaproveitando o sistema
/// de navegação por rotas nomeadas já existente — nenhuma navegação
/// paralela é criada.
class RouteTrackerObserver extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) {
      currentRouteNotifier.value = name;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Ao voltar, quem fica visível é a rota anterior, não a que saiu.
    _update(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update(newRoute);
  }
}