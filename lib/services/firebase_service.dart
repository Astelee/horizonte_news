import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<void> initialize() async {
    try {
      // Inicializa o núcleo do Firebase
      await Firebase.initializeApp();
      
      // Configura o Analytics (Métricas de acesso das notícias)
      FirebaseAnalytics analytics = FirebaseAnalytics.instance;
      await analytics.logAppOpen();

      // Configura o Messaging (Para futuras notificações Push)
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      debugPrint('Firebase inicializado com sucesso.');
    } catch (e) {
      debugPrint('Aviso: Erro ao inicializar Firebase: $e');
    }
  }
}