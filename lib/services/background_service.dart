import 'package:workmanager/workmanager.dart';
import 'workmanager_callback.dart';

class BackgroundService {
  /// Inicializa o WorkManager. Chamar uma vez no main().
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // true para ver logs no logcat
    );
  }

  /// Agenda a verificação periódica de novas notícias.
  /// Mínimo permitido pelo Android: 15 minutos.
  static Future<void> scheduleNewsCheck() async {
    await Workmanager().registerPeriodicTask(
      'horizonte_news_check',
      kCheckNewsTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  /// Cancela a verificação (usar nas configurações do app).
  static Future<void> cancelNewsCheck() async {
    await Workmanager().cancelByUniqueName('horizonte_news_check');
  }

  /// Força uma verificação imediata (útil para testar).
  static Future<void> runNow() async {
    await Workmanager().registerOneOffTask(
      'horizonte_news_check_now',
      kCheckNewsTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
