import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_navigator.dart';
import 'news_service.dart';

/// Resolve dois cenários de compartilhamento de notícia:
///
/// 1) App já instalado: alguém clica no link
///    (https://horizontenews-6b48f.web.app/noticia/{postId}) e o
///    Android abre o app direto nessa tela (App Link), sem passar
///    pela loja. Capturado aqui via [AppLinks].
///
/// 2) App não instalado: o link cai na página web de fallback, que
///    redireciona para a Play Store gravando o postId como
///    UTM/referrer no link de instalação. Depois que o usuário
///    instala e abre o app pela primeira vez, o Android entrega esse
///    referrer via Play Install Referrer API — lemos aqui uma única
///    vez e abrimos a matéria correspondente.
///
/// Em ambos os casos a navegação reaproveita o mesmo padrão já usado
/// pelo NotificationService (navigatorKey + rota '/post-detail').
class DeepLinkService {
  static const _referrerCheckedKey = 'deep_link_referrer_checked';
  static final _storage = const FlutterSecureStorage();
  static final _newsService = NewsService();
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSub;

  /// Chamar uma vez, no início do app (depois do primeiro frame),
  /// para tratar tanto o link que abriu o app agora quanto um
  /// possível deferred deep link vindo da instalação.
  static Future<void> init() async {
    // Caso 1: app aberto a partir de um clique em link (app já
    // estava instalado, ou já foi aberto antes).
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
        // Se já veio um link direto, não precisa checar o referrer
        // de instalação (esse fluxo é exclusivo do primeiro clique
        // sem o app instalado).
        return;
      }
    } catch (e) {
      debugPrint('DeepLinkService: erro ao ler link inicial: $e');
    }

    // Caso 2: primeira abertura após instalar vindo da Play Store.
    await _checkInstallReferrer();
  }

  static void dispose() {
    _linkSub?.cancel();
  }

  static void _handleUri(Uri uri) {
    // Espera algo como /noticia/{postId}
    final segments = uri.pathSegments;
    final idx = segments.indexOf('noticia');
    if (idx == -1 || idx + 1 >= segments.length) return;

    final postId = segments[idx + 1];
    if (postId.isEmpty) return;

    _openPost(postId);
  }

  /// Consulta o Play Install Referrer apenas uma vez por instalação
  /// (guardamos uma flag local para não repetir em toda abertura do
  /// app). Espera um referrer no formato: postId=XXXXX
  static Future<void> _checkInstallReferrer() async {
    final alreadyChecked = await _storage.read(key: _referrerCheckedKey);
    if (alreadyChecked == 'true') return;

    try {
      final referrerDetails =
          await AndroidPlayInstallReferrer.installReferrer;
      await _storage.write(key: _referrerCheckedKey, value: 'true');

      final referrerUrl = referrerDetails.installReferrer;
      if (referrerUrl == null || referrerUrl.isEmpty) return;

      final params = Uri.splitQueryString(referrerUrl);
      final postId = params['postId'];
      if (postId != null && postId.isNotEmpty) {
        _openPost(postId);
      }
    } catch (e) {
      // Instalação não veio da Play Store com referrer (ex.: instalado
      // via APK direto, emulador, ou já checado) — segue normalmente.
      await _storage.write(key: _referrerCheckedKey, value: 'true');
      debugPrint('DeepLinkService: sem install referrer disponível: $e');
    }
  }

  static Future<void> _openPost(String postId) async {
    // Splash/primeira tela pode ainda não ter montado o Navigator;
    // tenta algumas vezes com pequeno intervalo antes de desistir.
    for (var i = 0; i < 10; i++) {
      if (navigatorKey.currentState != null) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (navigatorKey.currentState == null) return;

    try {
      final post = await _newsService.fetchById(postId);
      if (post == null) return;

      navigatorKey.currentState?.pushNamed(
        '/post-detail', // mesmo valor de AppRoutes.postDetail
        arguments: post,
      );
    } catch (e) {
      debugPrint('DeepLinkService: erro ao abrir notícia compartilhada: $e');
    }
  }
}