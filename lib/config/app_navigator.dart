import 'package:flutter/material.dart';

/// Chave global de navegação — permite que serviços fora da árvore de
/// widgets (ex.: NotificationService, uma classe estática) naveguem
/// programaticamente, como ao abrir uma notícia a partir de um clique
/// em notificação push.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();