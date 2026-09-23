import 'package:flutter/material.dart';
import 'app_routes.dart';

/// Chave global de navegação — permite que serviços fora da árvore de
/// widgets (ex.: NotificationService, uma classe estática) naveguem
/// programaticamente, como ao abrir uma notícia a partir de um clique
/// em notificação push.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Nome da rota destacada em laranja no AppDrawer no momento.
///
/// Diferente de "rota realmente ativa no topo da pilha", este valor
/// representa o ÚLTIMO ITEM ESCOLHIDO PELO USUÁRIO no próprio Drawer.
/// Ele só muda quando o usuário toca em um item do menu — nunca
/// automaticamente ao apertar voltar. Assim, se o usuário abre
/// "Ranking" e depois volta para a Home, "Ranking" continua
/// destacado até que outro item do Drawer seja escolhido.
///
/// Começa em [AppRoutes.home] porque essa é a tela inicial do app.
final ValueNotifier<String> selectedDrawerRouteNotifier =
    ValueNotifier<String>(AppRoutes.home);