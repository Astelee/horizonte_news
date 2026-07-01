import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════
// HANDLER DE BACKGROUND FCM (obrigatório fora de qualquer classe)
// ═══════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin localNotif =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'horizonte_news';
  static const _channelName = 'Horizonte News';
  static const _newsChannelId = 'horizonte_news_posts';
  static const _newsChannelName = 'Novas Notícias';

  // ── INIT ──────────────────────────────────────────────────────
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await localNotif.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Canal para notificações FCM (já existia)
    await localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    // Canal para novas notícias do Blogger
    await localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _newsChannelId,
            _newsChannelName,
            description: 'Alertas de novas postagens no Horizonte News',
            importance: Importance.high,
          ),
        );

    // FCM background handler
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // FCM foreground
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      localNotif.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }

  // ── CALLBACK AO TOCAR NA NOTIFICAÇÃO ─────────────────────────
  static void _onNotificationTap(NotificationResponse response) {
    // O payload é o URL da notícia
    // A navegação é feita via navigatorKey definido no main.dart
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // Guarda o payload para o app abrir ao iniciar
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('pending_news_url', payload);
      });
    }
  }

  // ── DISPARA NOTIFICAÇÃO DE NOVA NOTÍCIA ───────────────────────
  static Future<void> showNewsNotification({
    required int id,
    required String title,
    required String summary,
    required String postUrl,
  }) async {
    await localNotif.show(
      id,
      title,
      summary,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _newsChannelId,
          _newsChannelName,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(summary),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: postUrl,
    );
  }

  // ── FCM: PEDE PERMISSÃO + SALVA TOKEN ────────────────────────
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;
    if (granted) await _saveToken();
    return granted;
  }

  static Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token, 'notifGeral': true},
            SetOptions(merge: true));
  }

  static Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(
            {'fcmToken': FieldValue.delete(), 'notifGeral': false});
    await _messaging.deleteToken();
  }

  static Future<bool> isEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['notifGeral'] == true;
  }
}
