import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'blogger_rss_service.dart';

const String kCheckNewsTask = 'checkNewBloggerPost';

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

    final posts = await BloggerRssService.fetchLatestPosts();
    if (posts == null || posts.isEmpty) return;

    final latestPost = posts.first;

    final prefs = await SharedPreferences.getInstance();
    final lastNotifiedId =
        prefs.getString('last_notified_post_id') ?? '';

    if (latestPost.id == lastNotifiedId) return;

    // Salva ID, título e URL para navegação ao tocar
    await prefs.setString('last_notified_post_id', latestPost.id);
    await prefs.setString('pending_news_title', latestPost.title);
    await prefs.setString('pending_news_url', latestPost.url);

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
  } catch (_) {}
}
