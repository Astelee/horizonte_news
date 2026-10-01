import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// CATÁLOGO DE RECOMPENSAS EXCLUSIVAS DO CHECK-IN
// ═══════════════════════════════════════════════════════════════════
// Sistema PRÓPRIO do Check-in, totalmente separado dos avatares
// VIP/Ultra (premium_avatars_config.dart). Segue a mesma ideia —
// catálogo + CustomPainter + equipar — mas com identidade, ids e
// campo de armazenamento independentes:
//
//   users_xp/{uid}.equippedCheckinRewardId   (String, opcional)
//
// Isso permite ao usuário ter, AO MESMO TEMPO, um avatar VIP
// equipado e uma recompensa de check-in equipada.
//
// ── Desbloqueio permanente ────────────────────────────────────────
// Os marcos fixos usam longestCheckinStreak. O marco de mês completo
// usa a conquista permanente checkin_month_complete, pois 28/29/30/31
// são metas do calendário, não a identidade do emblema adquirido.
// O serviço reconstitui essa conquista pelo histórico quando preciso.
//
// Para adicionar uma recompensa nova: crie o painter em
// lib/widgets/checkin_reward_painters.dart, adicione um valor em
// CheckinRewardId, registre a entrada em CheckinRewardsConfig.all
// e adicione o case no switch de CheckinRewardArt. Nada mais muda.
// ═══════════════════════════════════════════════════════════════════

enum CheckinRewardId {
  faisca,
  brasaViva,
  anelDeFogo,
  chamaDupla,
  coroaIgnea,
  eclipse,
  fenixDeCinzas,
  solDoHorizonte,
}

extension CheckinRewardIdX on CheckinRewardId {
  String get storageKey {
    switch (this) {
      case CheckinRewardId.faisca:
        return 'checkin_faisca';
      case CheckinRewardId.brasaViva:
        return 'checkin_brasa_viva';
      case CheckinRewardId.anelDeFogo:
        return 'checkin_anel_de_fogo';
      case CheckinRewardId.chamaDupla:
        return 'checkin_chama_dupla';
      case CheckinRewardId.coroaIgnea:
        return 'checkin_coroa_ignea';
      case CheckinRewardId.eclipse:
        return 'checkin_eclipse';
      case CheckinRewardId.fenixDeCinzas:
        return 'checkin_fenix_de_cinzas';
      case CheckinRewardId.solDoHorizonte:
        return 'checkin_sol_do_horizonte';
    }
  }

  static CheckinRewardId? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final id in CheckinRewardId.values) {
      if (id.storageKey == key) return id;
    }
    return null;
  }
}

/// Como a recompensa é apresentada. Serve para agrupar/rotular na UI
/// e para decidir onde ela aparece (emblema pequeno, moldura ao
/// redor do avatar, efeito, etc.).
enum CheckinRewardKind { emblema, simbolo, moldura, efeito, icone }

extension CheckinRewardKindX on CheckinRewardKind {
  String get label {
    switch (this) {
      case CheckinRewardKind.emblema:
        return 'EMBLEMA';
      case CheckinRewardKind.simbolo:
        return 'SÍMBOLO';
      case CheckinRewardKind.moldura:
        return 'MOLDURA';
      case CheckinRewardKind.efeito:
        return 'EFEITO';
      case CheckinRewardKind.icone:
        return 'ÍCONE';
    }
  }
}

/// Raridade — controla intensidade de glow/partículas nos painters.
/// Vai de 1 (comum) a 5 (lendário).
class CheckinRewardDef {
  final CheckinRewardId id;
  final int requiredStreak;
  final String name;
  final String description;
  final CheckinRewardKind kind;
  final int rarity;
  final List<Color> gradient;
  final Color accentColor;

  /// XP de bônus concedido ao atingir este marco (0 = sem bônus).
  /// Precisa bater com CheckinService.bonusForStreak e com
  /// isValidCheckinXp em firestore.rules.
  final int bonusXp;

  const CheckinRewardDef({
    required this.id,
    required this.requiredStreak,
    required this.name,
    required this.description,
    required this.kind,
    required this.rarity,
    required this.gradient,
    required this.accentColor,
    required this.bonusXp,
  });

  String get rarityLabel {
    switch (rarity) {
      case 1:
        return 'Comum';
      case 2:
        return 'Raro';
      case 3:
        return 'Épico';
      case 4:
        return 'Mítico';
      default:
        return 'Lendário';
    }
  }
}

class CheckinRewardsConfig {
  CheckinRewardsConfig._();

  // ── Progressão equilibrada (BASE MENSAL — calendário real) ───────
  // Espaçamento crescente dentro de um único mês: 3 → 5 → 7 → 10 →
  // 14 → 18 → 24 → (último dia do mês). Os 7 primeiros marcos cabem
  // no pior caso (fevereiro, 28 dias). O ÚLTIMO marco ("Sol do
  // Horizonte") NÃO é mais um número fixo (31): ele é calculado
  // dinamicamente como o último dia do mês corrente, para que a
  // recompensa máxima seja SEMPRE alcançável, mesmo em meses de 28,
  // 29 ou 30 dias — nunca um marco impossível de bater.
  //
  // `all` continua existindo (com 31 como valor "de catálogo",
  // nunca lido diretamente para decidir desbloqueio) só para não
  // quebrar código legado; todo o app deve usar `allForMonth()` /
  // `currentMonthList` daqui pra frente, que devolve os defs com o
  // último `requiredStreak` já ajustado ao mês.
  static const int _lastMilestoneBaseValue = 31;

  static const List<CheckinRewardDef> all = [
    CheckinRewardDef(
      id: CheckinRewardId.faisca,
      requiredStreak: 3,
      name: 'Faísca',
      description: 'Uma chama pequena com fagulhas. O começo do hábito.',
      kind: CheckinRewardKind.emblema,
      rarity: 1,
      gradient: [Color(0xFFFF8C3A), Color(0xFFFFD54F)],
      accentColor: Color(0xFFFF8C3A),
      bonusXp: 15,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.brasaViva,
      requiredStreak: 5,
      name: 'Brasa Viva',
      description: 'Núcleo incandescente que pulsa como um coração.',
      kind: CheckinRewardKind.simbolo,
      rarity: 2,
      gradient: [Color(0xFFFF6B00), Color(0xFFCC2200)],
      accentColor: Color(0xFFFF6B00),
      bonusXp: 25,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.anelDeFogo,
      requiredStreak: 7,
      name: 'Anel de Fogo',
      description: 'Moldura giratória com partículas em brasa ao redor.',
      kind: CheckinRewardKind.moldura,
      rarity: 3,
      gradient: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
      accentColor: Color(0xFFFF9100),
      bonusXp: 40,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.chamaDupla,
      requiredStreak: 10,
      name: 'Chama Dupla',
      description: 'Duas chamas em órbita, uma clara e uma escura.',
      kind: CheckinRewardKind.efeito,
      rarity: 3,
      gradient: [Color(0xFFFF3D00), Color(0xFFFFFFFF)],
      accentColor: Color(0xFFFF5722),
      bonusXp: 60,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.coroaIgnea,
      requiredStreak: 14,
      name: 'Coroa Ígnea',
      description: 'A coroa de duas semanas seguidas. Só quem não desiste a usa.',
      kind: CheckinRewardKind.icone,
      rarity: 4,
      gradient: [Color(0xFFFFD54F), Color(0xFFFF6B00)],
      accentColor: Color(0xFFFFC107),
      bonusXp: 90,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.eclipse,
      requiredStreak: 18,
      name: 'Eclipse',
      description: 'Um disco escuro coroado por uma corona laranja.',
      kind: CheckinRewardKind.moldura,
      rarity: 4,
      gradient: [Color(0xFF1A0A00), Color(0xFFFF6B00)],
      accentColor: Color(0xFFFF7A1A),
      bonusXp: 130,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.fenixDeCinzas,
      requiredStreak: 24,
      name: 'Fênix de Cinzas',
      description: 'Asas em brasa que se recompõem a cada ciclo.',
      kind: CheckinRewardKind.icone,
      rarity: 5,
      gradient: [Color(0xFFFF3D00), Color(0xFFFFC400)],
      accentColor: Color(0xFFFF5722),
      bonusXp: 200,
    ),
    CheckinRewardDef(
      // requiredStreak aqui é só o valor "de catálogo" (31). O valor
      // REAL usado pelo app vem de allForMonth()/currentMonthList,
      // que troca este número pelo último dia do mês corrente
      // (28/29/30/31) — então este marco é sempre alcançável.
      id: CheckinRewardId.solDoHorizonte,
      requiredStreak: _lastMilestoneBaseValue,
      name: 'Sol do Horizonte',
      description: 'O mês inteiro, sem falhar um dia. O item mais raro do Horizonte News.',
      kind: CheckinRewardKind.icone,
      rarity: 5,
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFB300), Color(0xFFFF6B00)],
      accentColor: Color(0xFFFFD54F),
      bonusXp: 350,
    ),
  ];

  // ═════════════════════════════════════════════════════════════════
  // CALENDÁRIO REAL — último marco dinâmico
  // ═════════════════════════════════════════════════════════════════
  /// Quantos dias tem [month] (calendário real: 28/29/30/31). Usa o
  /// mesmo truque de `DateTime(ano, mes + 1, dia 0)` já usado no
  /// calendário visual (checkin_calendar.dart) e no CheckinService —
  /// uma única fonte de verdade para "dias do mês" em todo o app.
  static int daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  /// A lista de recompensas ajustada para [month] (padrão: mês
  /// corrente): os marcos intermediários (3, 5, 7, 10, 14, 18, 24)
  /// nunca mudam — cabem em qualquer mês. Só o ÚLTIMO marco do
  /// catálogo é recalculado para ser exatamente o último dia real
  /// de [month] (30 em abril, 28/29 em fevereiro, 31 em janeiro...),
  /// para que a recompensa máxima seja sempre alcançável naquele
  /// mês e nunca fique "impossível" (ex.: pedir dia 31 em um mês de
  /// 30 dias).
  ///
  /// Se o último marco de catálogo (31) já for <= dias do mês (ou
  /// seja, mês de 31 dias), o valor não muda. Isso preserva 100% do
  /// comportamento anterior em meses de 31 dias.
  static List<CheckinRewardDef> allForMonth([DateTime? month]) {
    final ref = month ?? DateTime.now();
    final total = daysInMonth(ref);
    if (all.isEmpty) return all;

    return List<CheckinRewardDef>.generate(all.length, (i) {
      final def = all[i];
      final isLast = i == all.length - 1;
      if (!isLast || def.requiredStreak <= total) return def;

      // Mês mais curto que 31 dias: o marco final "encosta" no
      // último dia real do mês em vez de ficar fixo em 31.
      return CheckinRewardDef(
        id: def.id,
        requiredStreak: total,
        name: def.name,
        description: def.description,
        kind: def.kind,
        rarity: def.rarity,
        gradient: def.gradient,
        accentColor: def.accentColor,
        bonusXp: def.bonusXp,
      );
    }, growable: false);
  }

  /// Lista de recompensas do mês CORRENTE — é o que toda a UI e o
  /// CheckinService devem usar em vez de `all` diretamente, para que
  /// a última recompensa sempre reflita o calendário real de hoje.
  static List<CheckinRewardDef> get currentMonthList => allForMonth();

  static CheckinRewardDef defFor(CheckinRewardId id, {DateTime? month}) {
    final list = allForMonth(month);
    return list.firstWhere((e) => e.id == id, orElse: () => list.first);
  }

  static CheckinRewardDef? defForStorageKey(String? key, {DateTime? month}) {
    final id = CheckinRewardIdX.fromStorageKey(key);
    if (id == null) return null;
    return defFor(id, month: month);
  }

  /// Lista de marcos (3, 5, 7, ..., último dia do mês corrente) na
  /// ordem do catálogo — mantido como getter (sem parênteses) para
  /// não quebrar quem já chamava `CheckinRewardsConfig.milestones`.
  static List<int> get milestones => milestonesForMonth();

  /// Igual a [milestones], mas permite passar um mês específico —
  /// útil para testar outros meses sem depender do relógio real.
  static List<int> milestonesForMonth([DateTime? month]) =>
      allForMonth(month).map((e) => e.requiredStreak).toList(growable: false);

  /// Recompensa cujo marco é exatamente [streak] no mês informado
  /// (padrão: mês corrente), ou null.
  static CheckinRewardDef? forStreak(int streak, {DateTime? month}) {
    for (final r in allForMonth(month)) {
      if (r.requiredStreak == streak) return r;
    }
    return null;
  }

  /// Bônus de XP do marco [streak] (0 se não for um marco).
  static int bonusForStreak(int streak, {DateTime? month}) =>
      forStreak(streak, month: month)?.bonusXp ?? 0;

  static const monthCompleteAchievement = 'checkin_month_complete';

  /// Compatibilidade com perfis antigos: o emblema final equipado e
  /// um recorde de pelo menos 31 também comprovam a aquisição.
  static bool hasCompletedMonth(Map<String, dynamic> data) {
    final achievements = data['achievements'];
    return (achievements is List &&
            achievements.contains(monthCompleteAchievement)) ||
        data['equippedCheckinRewardId'] ==
            CheckinRewardId.solDoHorizonte.storageKey ||
        ((data['longestCheckinStreak'] as num?)?.toInt() ?? 0) >= 31;
  }

  /// Reconstrói a aquisição respeitando o calendário DO MÊS GANHO.
  /// Todos os dias devem existir: recorde 30 em um mês de 31 não basta.
  static bool completedMonthInHistory(
    Map<String, String> statuses, {
    required DateTime today,
  }) {
    final daysByMonth = <DateTime, Set<int>>{};
    final limit = DateTime(today.year, today.month, today.day);
    for (final entry in statuses.entries) {
      if (entry.value != 'done' && entry.value != 'recovered') continue;
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day ||
          date.isAfter(limit)) continue;
      final key = DateTime(year, month);
      daysByMonth.putIfAbsent(key, () => <int>{}).add(day);
    }
    return daysByMonth.entries.any(
      (entry) => entry.value.length == daysInMonth(entry.key),
    );
  }

  /// O mês atual só determina a meta para quem ainda não conquistou.
  /// Nunca compara um recorde de outro mês com uma meta variável.
  static bool isUnlocked(CheckinRewardDef def, int longestStreak,
      {bool completedMonth = false}) =>
      def.id == CheckinRewardId.solDoHorizonte
          ? completedMonth || longestStreak >= 31
          : longestStreak >= def.requiredStreak;

  static List<CheckinRewardDef> unlockedFor(int longestStreak,
          {DateTime? month, bool completedMonth = false}) =>
      allForMonth(month)
          .where((r) => isUnlocked(r, longestStreak,
              completedMonth: completedMonth))
          .toList(growable: false);

  static CheckinRewardDef? nextLocked(int longestStreak,
      {DateTime? month, bool completedMonth = false}) {
    for (final r in allForMonth(month)) {
      if (!isUnlocked(r, longestStreak, completedMonth: completedMonth)) {
        return r;
      }
    }
    return null;
  }

  /// Fração 0..1 do caminho entre o marco anterior e o próximo,
  /// usada na barra de progressão.
  static double progressToNext(int currentStreak, int longestStreak,
      {DateTime? month, bool completedMonth = false}) {
    final list = allForMonth(month);
    final next = nextLocked(longestStreak, month: month,
        completedMonth: completedMonth);
    if (next == null) return 1.0;
    int prev = 0;
    for (final r in list) {
      if (r.requiredStreak < next.requiredStreak) prev = r.requiredStreak;
    }
    final span = next.requiredStreak - prev;
    if (span <= 0) return 0.0;
    final done = (currentStreak - prev).clamp(0, span);
    return done / span;
  }
}