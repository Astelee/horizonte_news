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
// ── Segurança ────────────────────────────────────────────────────
// O desbloqueio NUNCA é lido de uma lista gravada pelo cliente.
// Ele é sempre CALCULADO a partir de longestCheckinStreak (campo
// que só o CheckinService escreve, junto com um documento por dia
// na subcoleção checkins/). Assim ninguém consegue se conceder uma
// recompensa apenas editando o app.
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

  // ── Progressão equilibrada ───────────────────────────────────────
  // Espaçamento crescente: 7 → 14 → 30 → 60 → 100 → 150 → 200 → 365.
  // As primeiras chegam em semanas (motivam o hábito); as últimas
  // exigem meses/1 ano (prestígio real). Cada marco troca de
  // categoria visual para a coleção não ficar repetitiva.
  static const List<CheckinRewardDef> all = [
    CheckinRewardDef(
      id: CheckinRewardId.faisca,
      requiredStreak: 7,
      name: 'Faísca',
      description: 'Uma chama pequena com fagulhas. O começo do hábito.',
      kind: CheckinRewardKind.emblema,
      rarity: 1,
      gradient: [Color(0xFFFF8C3A), Color(0xFFFFD54F)],
      accentColor: Color(0xFFFF8C3A),
      bonusXp: 30,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.brasaViva,
      requiredStreak: 14,
      name: 'Brasa Viva',
      description: 'Núcleo incandescente que pulsa como um coração.',
      kind: CheckinRewardKind.simbolo,
      rarity: 2,
      gradient: [Color(0xFFFF6B00), Color(0xFFCC2200)],
      accentColor: Color(0xFFFF6B00),
      bonusXp: 60,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.anelDeFogo,
      requiredStreak: 30,
      name: 'Anel de Fogo',
      description: 'Moldura giratória com partículas em brasa ao redor.',
      kind: CheckinRewardKind.moldura,
      rarity: 3,
      gradient: [Color(0xFFFF6D00), Color(0xFFFFAB40)],
      accentColor: Color(0xFFFF9100),
      bonusXp: 150,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.chamaDupla,
      requiredStreak: 60,
      name: 'Chama Dupla',
      description: 'Duas chamas em órbita, uma clara e uma escura.',
      kind: CheckinRewardKind.efeito,
      rarity: 3,
      gradient: [Color(0xFFFF3D00), Color(0xFFFFFFFF)],
      accentColor: Color(0xFFFF5722),
      bonusXp: 300,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.coroaIgnea,
      requiredStreak: 100,
      name: 'Coroa Ígnea',
      description: 'A coroa dos 100 dias. Só quem não desiste a usa.',
      kind: CheckinRewardKind.icone,
      rarity: 4,
      gradient: [Color(0xFFFFD54F), Color(0xFFFF6B00)],
      accentColor: Color(0xFFFFC107),
      bonusXp: 500,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.eclipse,
      requiredStreak: 150,
      name: 'Eclipse',
      description: 'Um disco escuro coroado por uma corona laranja.',
      kind: CheckinRewardKind.moldura,
      rarity: 4,
      gradient: [Color(0xFF1A0A00), Color(0xFFFF6B00)],
      accentColor: Color(0xFFFF7A1A),
      bonusXp: 250,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.fenixDeCinzas,
      requiredStreak: 200,
      name: 'Fênix de Cinzas',
      description: 'Asas em brasa que se recompõem a cada ciclo.',
      kind: CheckinRewardKind.icone,
      rarity: 5,
      gradient: [Color(0xFFFF3D00), Color(0xFFFFC400)],
      accentColor: Color(0xFFFF5722),
      bonusXp: 400,
    ),
    CheckinRewardDef(
      id: CheckinRewardId.solDoHorizonte,
      requiredStreak: 365,
      name: 'Sol do Horizonte',
      description: 'Um ano inteiro. O item mais raro do Horizonte News.',
      kind: CheckinRewardKind.icone,
      rarity: 5,
      gradient: [Color(0xFFFFFFFF), Color(0xFFFFB300), Color(0xFFFF6B00)],
      accentColor: Color(0xFFFFD54F),
      bonusXp: 1000,
    ),
  ];

  static CheckinRewardDef defFor(CheckinRewardId id) =>
      all.firstWhere((e) => e.id == id, orElse: () => all.first);

  static CheckinRewardDef? defForStorageKey(String? key) {
    final id = CheckinRewardIdX.fromStorageKey(key);
    if (id == null) return null;
    return defFor(id);
  }

  /// Lista de marcos (7, 14, 30, ...) na ordem do catálogo.
  static List<int> get milestones =>
      all.map((e) => e.requiredStreak).toList(growable: false);

  /// Recompensa cujo marco é exatamente [streak], ou null.
  static CheckinRewardDef? forStreak(int streak) {
    for (final r in all) {
      if (r.requiredStreak == streak) return r;
    }
    return null;
  }

  /// Bônus de XP do marco [streak] (0 se não for um marco).
  static int bonusForStreak(int streak) => forStreak(streak)?.bonusXp ?? 0;

  /// Uma recompensa está desbloqueada quando o RECORDE já alcançou
  /// o marco. Usa o recorde (não a sequência atual) de propósito:
  /// quebrar a sequência não tira uma recompensa já conquistada.
  static bool isUnlocked(CheckinRewardDef def, int longestStreak) =>
      longestStreak >= def.requiredStreak;

  /// Recompensas já desbloqueadas para um dado recorde.
  static List<CheckinRewardDef> unlockedFor(int longestStreak) =>
      all.where((r) => isUnlocked(r, longestStreak)).toList(growable: false);

  /// Próxima recompensa ainda bloqueada, ou null se tudo foi
  /// conquistado.
  static CheckinRewardDef? nextLocked(int longestStreak) {
    for (final r in all) {
      if (!isUnlocked(r, longestStreak)) return r;
    }
    return null;
  }

  /// Fração 0..1 do caminho entre o marco anterior e o próximo,
  /// usada na barra de progressão.
  static double progressToNext(int currentStreak, int longestStreak) {
    final next = nextLocked(longestStreak);
    if (next == null) return 1.0;
    int prev = 0;
    for (final r in all) {
      if (r.requiredStreak < next.requiredStreak) prev = r.requiredStreak;
    }
    final span = next.requiredStreak - prev;
    if (span <= 0) return 0.0;
    final done = (currentStreak - prev).clamp(0, span);
    return done / span;
  }
}