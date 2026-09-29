import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════
// EVENTO DE XP EM DOBRO (2x / 3x) — FONTE ÚNICA DE VERDADE
// ═══════════════════════════════════════════════════════════════════
// O evento vive no documento global app_config/global (o mesmo que já
// guarda manutenção, comentários e barra de anúncios), nos campos:
//   xpEventEnabled    bool       — liga/desliga geral
//   xpEventMultiplier int        — 2 ou 3
//   xpEventStartsAt   Timestamp  — início (vale a partir daí)
//   xpEventEndsAt     Timestamp? — fim; ausente = sem data de fim
//
// XpEventService mantém UM único listener desse documento para o app
// inteiro e o compartilha entre quem precisa (XpService, para
// multiplicar o XP, e o aviso da Home). Assim o evento não cria
// leituras extras no Firestore. Quem escreve é só o painel admin
// (AdminConfigService.setXpEvent / clearXpEvent).
// ═══════════════════════════════════════════════════════════════════

enum XpEventStatus { off, scheduled, active, ended }

class XpEventConfig {
  final bool enabled;
  final int multiplier;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const XpEventConfig({
    required this.enabled,
    required this.multiplier,
    this.startsAt,
    this.endsAt,
  });

  factory XpEventConfig.off() =>
      const XpEventConfig(enabled: false, multiplier: 1);

  factory XpEventConfig.fromMap(Map<String, dynamic> map) {
    final rawMultiplier = (map['xpEventMultiplier'] as num?)?.toInt() ?? 2;
    final startsAt = map['xpEventStartsAt'];
    final endsAt = map['xpEventEndsAt'];
    return XpEventConfig(
      enabled: map['xpEventEnabled'] == true,
      multiplier: rawMultiplier.clamp(2, 3).toInt(),
      startsAt: startsAt is Timestamp ? startsAt.toDate() : null,
      endsAt: endsAt is Timestamp ? endsAt.toDate() : null,
    );
  }

  XpEventStatus statusAt(DateTime now) {
    if (!enabled) return XpEventStatus.off;
    if (startsAt != null && now.isBefore(startsAt!)) {
      return XpEventStatus.scheduled;
    }
    if (endsAt != null && !now.isBefore(endsAt!)) {
      return XpEventStatus.ended;
    }
    return XpEventStatus.active;
  }

  bool isActiveAt(DateTime now) => statusAt(now) == XpEventStatus.active;

  /// Multiplicador efetivo neste instante: 1 fora do evento.
  int multiplierAt(DateTime now) => isActiveAt(now) ? multiplier : 1;

  /// Próximo instante em que o estado muda sozinho (início ou fim),
  /// ou null se não há mudança futura. Usado para ligar/desligar o
  /// aviso e o painel na hora certa, sem depender de nova leitura.
  DateTime? nextChangeAfter(DateTime now) {
    if (!enabled) return null;
    if (startsAt != null && now.isBefore(startsAt!)) return startsAt;
    if (endsAt != null && now.isBefore(endsAt!)) return endsAt;
    return null;
  }
}

/// Período de um evento a ser programado pelo painel admin.
class XpEventPeriod {
  final DateTime startsAt;
  final DateTime? endsAt;
  const XpEventPeriod({required this.startsAt, this.endsAt});

  /// Fim de semana: sábado 00:00 até segunda 00:00. Se já é sábado ou
  /// domingo, começa agora e termina na segunda 00:00.
  factory XpEventPeriod.weekend(DateTime now) {
    if (now.weekday >= DateTime.saturday) {
      final monday =
          DateTime(now.year, now.month, now.day + (8 - now.weekday));
      return XpEventPeriod(startsAt: now, endsAt: monday);
    }
    final daysToSaturday = DateTime.saturday - now.weekday;
    final saturday = DateTime(now.year, now.month, now.day + daysToSaturday);
    final monday = DateTime(now.year, now.month, now.day + daysToSaturday + 2);
    return XpEventPeriod(startsAt: saturday, endsAt: monday);
  }

  /// Vale agora e termina sozinho depois de 24 horas.
  factory XpEventPeriod.next24h(DateTime now) =>
      XpEventPeriod(startsAt: now, endsAt: now.add(const Duration(hours: 24)));

  /// Vale agora e só termina quando o admin desligar.
  factory XpEventPeriod.openEnded(DateTime now) =>
      XpEventPeriod(startsAt: now, endsAt: null);
}

class XpEventService {
  static final XpEventService _instance = XpEventService._internal();
  factory XpEventService() => _instance;
  XpEventService._internal();

  final StreamController<XpEventConfig> _controller =
      StreamController<XpEventConfig>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Completer<void>? _firstLoad;
  XpEventConfig _current = XpEventConfig.off();
  bool _loaded = false;

  /// Último valor conhecido do evento (off enquanto não carregou).
  XpEventConfig get current => _current;

  void _ensureStarted() {
    if (_sub != null) return;
    final firstLoad = Completer<void>();
    _firstLoad = firstLoad;
    _sub = FirebaseFirestore.instance
        .collection('app_config')
        .doc('global')
        .snapshots()
        .listen(
      (snap) {
        final data = snap.data();
        _current = (snap.exists && data != null)
            ? XpEventConfig.fromMap(data)
            : XpEventConfig.off();
        _loaded = true;
        if (!firstLoad.isCompleted) firstLoad.complete();
        _controller.add(_current);
      },
      onError: (_) {
        // Falha de leitura: segue sem evento (1x) e permite tentar
        // de novo na próxima chamada.
        _sub?.cancel();
        _sub = null;
        if (!firstLoad.isCompleted) firstLoad.complete();
      },
    );
  }

  /// Stream do evento. Quem assina recebe já o valor atual (se houver)
  /// e depois cada mudança feita pelo admin, em tempo real.
  Stream<XpEventConfig> watch() {
    _ensureStarted();
    return Stream<XpEventConfig>.multi((controller) {
      if (_loaded) controller.add(_current);
      final sub = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  /// Multiplicador do evento neste instante (1 = sem evento). Usado
  /// pelo XpService a cada ganho de XP. Se o primeiro carregamento
  /// ainda não terminou, espera até 3s; se falhar, assume 1x.
  Future<int> currentMultiplier() async {
    _ensureStarted();
    if (!_loaded) {
      final pending = _firstLoad;
      if (pending != null) {
        await pending.future.timeout(const Duration(seconds: 3),
            onTimeout: () {});
      }
    }
    return _current.multiplierAt(DateTime.now());
  }
}