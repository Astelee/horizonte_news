import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http; // Import necessário
import 'dart:convert'; // Import necessário

// Handler de background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId = 'horizonte_news';
  static const _channelName = 'Horizonte News';

  // ── DISPARO AUTOMÁTICO VIA ONESIGNAL ──────────────────────────
  static Future<void> sendAutoNotification(String title, String message) async {
    final url = Uri.parse('https://onesignal.com/api/v1/notifications');
    
    // Chave REST API fornecida por você
    const String restApiKey = 'hcoi4d5ciuhzn7jdpjkunfcmk'; 

    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: json.encode({
          'app_id': '999de6a2-1965-4cb0-9558-a0cc8ed39828',
          'included_segments': ['All'],
          'headings': {'pt': title},
          'contents': {'pt': message},
        }),
      );
    } catch (e) {
      // Falha silenciosa ou log de erro
    }
  }

  // ── INIT ────────────────────────────────────────────────────────
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotif.show(
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

  // ── MÉTODOS DE PERMISSÃO E TOKEN (MANTIDOS) ──────────────────────
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
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
        .set({'fcmToken': token, 'notifGeral': true}, SetOptions(merge: true));
  }

  static Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'fcmToken': FieldValue.delete(), 'notifGeral': false});
    await _messaging.deleteToken();
  }

  static Future<bool> isEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['notifGeral'] == true;
  }
}
