import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'blogger_rss_service.dart';
import 'news_notification_service.dart';

const String kCheckNewsTask = 'checkNewBloggerPost';

// ═══════════════════════════════════════════════════════════════════
// OBRIGATÓRIO: função top-level com @pragma
// ═══════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kCheckNewsTask) {
      await _checkAndNotify();
    }
    return Future.value(true);
  });
}

Future<void> _checkAndNotify() async {
  try {
    // Inicializa notificações locais no isolate do background
    final localNotif = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif.initialize(
      const InitializationSettings(android: androidSettings),
    );

    await localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'horizonte_news_posts',
            'Novas Notícias',
            importance: Importance.high,
          ),
        );

    // Busca posts via RSS
    final posts = await BloggerRssService.fetchLatestPosts();
    if (posts == null || posts.isEmpty) return;

    final latestPost = posts.first;

    // Verifica se já notificou este post
    final prefs = await SharedPreferences.getInstance();
    final lastNotifiedId = prefs.getString('last_notified_post_id') ?? '';

    if (latestPost.id == lastNotifiedId) return;

    // Salva o ID do post notificado
    await prefs.setString('last_notified_post_id', latestPost.id);

    // Dispara a notificação
    await localNotif.show(
      latestPost.id.hashCode,
      latestPost.title,
      latestPost.summary,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'horizonte_news_posts',
          'Novas Notícias',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation:
              BigTextStyleInformation(latestPost.summary),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: latestPost.url,
    );
  } catch (_) {
    // Nunca deixa o background travar
  }
}
