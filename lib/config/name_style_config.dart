import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// NOME PERSONALIZADO DE ASSINANTE — CONFIGURAÇÃO E MODELO
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para a personalização visual do NOME do
// assinante (cor + efeitos + intensidade). Quem desenha o nome é o
// widget central StyledUserName (widgets/styled_user_name.dart); as
// animações em si ficam em widgets/name_effects.dart.
//
// A escolha pertence ao USUÁRIO DONO do nome e fica salva em
// users_xp/{uid}.nameStyle — por isso todo mundo que vê aquele nome
// (comentários, ranking, perfil...) enxerga o mesmo visual. Nada aqui
// depende de quem está olhando.
//
// Formato salvo no Firestore:
//   nameStyle: {
//     color: 'blue',                    // id de NameColors
//     effects: ['glow', 'particles'],   // ids de NameEffect ([] = padrão)
//     intensity: 'normal',              // subtle | normal | intense
//   }
//
// Assinatura: NÃO existe lógica de verificação nova aqui. A leitura
// passa por premiumTierFromData (premium_config.dart), que já devolve
// none quando premiumExpiresAt venceu. Assinatura vencida → o estilo
// vira null → o nome volta ao visual padrão, mesmo que o campo
// nameStyle continue gravado (se a pessoa renovar, o estilo volta).
//
// COMO ADICIONAR UM EFEITO NOVO (sem mexer em nenhuma tela):
//   1. Adicione o valor em NameEffect (e id/label nas extensões abaixo).
//   2. Crie uma NameEffectLayer em widgets/name_effects.dart.
//   3. Registre em NameEffectRegistry.layers.
// ═══════════════════════════════════════════════════════════════════

/// Efeitos disponíveis. Podem ser combinados (Set) — ex.: brilho +
/// partículas. Novos efeitos entram aqui e no NameEffectRegistry.
enum NameEffect { glow, gradient, particles, lightning }

extension NameEffectX on NameEffect {
  /// Id estável salvo no Firestore (não mude depois de publicado).
  String get id {
    switch (this) {
      case NameEffect.glow:
        return 'glow';
      case NameEffect.gradient:
        return 'gradient';
      case NameEffect.particles:
        return 'particles';
      case NameEffect.lightning:
        return 'lightning';
    }
  }

  String get label {
    switch (this) {
      case NameEffect.glow:
        return 'Brilho pulsante';
      case NameEffect.gradient:
        return 'Gradiente animado';
      case NameEffect.particles:
        return 'Partículas';
      case NameEffect.lightning:
        return 'Raios de energia';
    }
  }

  static NameEffect? fromId(String? id) {
    for (final effect in NameEffect.values) {
      if (effect.id == id) return effect;
    }
    return null;
  }
}

/// Intensidade dos efeitos.
enum NameIntensity { subtle, normal, intense }

extension NameIntensityX on NameIntensity {
  String get id {
    switch (this) {
      case NameIntensity.subtle:
        return 'subtle';
      case NameIntensity.normal:
        return 'normal';
      case NameIntensity.intense:
        return 'intense';
    }
  }

  String get label {
    switch (this) {
      case NameIntensity.subtle:
        return 'Discreta';
      case NameIntensity.normal:
        return 'Normal';
      case NameIntensity.intense:
        return 'Intensa';
    }
  }

  /// Multiplicador usado pelos efeitos (tamanho do brilho, quantidade
  /// de partículas/raios, velocidade do gradiente).
  double get factor {
    switch (this) {
      case NameIntensity.subtle:
        return 0.6;
      case NameIntensity.normal:
        return 1.0;
      case NameIntensity.intense:
        return 1.6;
    }
  }

  static NameIntensity fromId(String? id) {
    switch (id) {
      case 'subtle':
        return NameIntensity.subtle;
      case 'intense':
        return NameIntensity.intense;
      default:
        return NameIntensity.normal;
    }
  }
}

/// Uma cor escolhível para o nome: [primary] é a cor do texto (e do
/// brilho); [secondary] é a cor de apoio (gradiente, partículas, raios).
@immutable
class NameColorPreset {
  final String id;
  final String label;
  final Color primary;
  final Color secondary;

  const NameColorPreset({
    required this.id,
    required this.label,
    required this.primary,
    required this.secondary,
  });
}

class NameColors {
  NameColors._();

  static const NameColorPreset blue = NameColorPreset(
    id: 'blue',
    label: 'Azul',
    primary: Color(0xFF4C8DFF),
    secondary: Color(0xFFA5D0FF),
  );

  static const NameColorPreset gold = NameColorPreset(
    id: 'gold',
    label: 'Dourado',
    primary: Color(0xFFFFC94D),
    secondary: Color(0xFFFF9A1F),
  );

  static const NameColorPreset purple = NameColorPreset(
    id: 'purple',
    label: 'Roxo',
    primary: Color(0xFFB77CFF),
    secondary: Color(0xFFE3C6FF),
  );

  static const NameColorPreset red = NameColorPreset(
    id: 'red',
    label: 'Vermelho',
    primary: Color(0xFFFF5252),
    secondary: Color(0xFFFFA48A),
  );

  static const NameColorPreset green = NameColorPreset(
    id: 'green',
    label: 'Verde',
    primary: Color(0xFF3DDC84),
    secondary: Color(0xFFBBF7D0),
  );

  static const NameColorPreset pink = NameColorPreset(
    id: 'pink',
    label: 'Rosa',
    primary: Color(0xFFFF6FB5),
    secondary: Color(0xFFFFC0DF),
  );

  static const NameColorPreset cyan = NameColorPreset(
    id: 'cyan',
    label: 'Ciano',
    primary: Color(0xFF2DE2E6),
    secondary: Color(0xFFB2FBFF),
  );

  /// Lista na ordem em que aparecerá num futuro seletor de cor.
  static const List<NameColorPreset> all = [
    blue,
    gold,
    purple,
    red,
    green,
    pink,
    cyan,
  ];

  /// Cor usada quando o id salvo não existe (mais). Alinhada ao
  /// dourado do SubscriberBadge.
  static const NameColorPreset fallback = gold;

  static NameColorPreset byId(String? id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return fallback;
  }
}

/// Personalização completa do nome de UM usuário.
@immutable
class NameStyle {
  final String colorId;

  /// Vazio = "padrão": só a cor escolhida, sem animação.
  final Set<NameEffect> effects;
  final NameIntensity intensity;

  /// Validade do plano Premium do dono do nome (quando conhecida).
  /// Serve só para o widget desligar os efeitos na hora em que o plano
  /// vence com a tela aberta; a regra de assinatura em si continua
  /// sendo premiumTierFromData.
  final DateTime? premiumExpiresAt;

  const NameStyle({
    this.colorId = 'gold',
    this.effects = const {},
    this.intensity = NameIntensity.normal,
    this.premiumExpiresAt,
  });

  NameColorPreset get color => NameColors.byId(colorId);

  bool get hasEffects => effects.isNotEmpty;

  /// false quando o plano já venceu (checado a cada build do widget).
  bool get isActive =>
      premiumExpiresAt == null || DateTime.now().isBefore(premiumExpiresAt!);

  NameStyle copyWith({
    String? colorId,
    Set<NameEffect>? effects,
    NameIntensity? intensity,
    DateTime? premiumExpiresAt,
  }) {
    return NameStyle(
      colorId: colorId ?? this.colorId,
      effects: effects ?? this.effects,
      intensity: intensity ?? this.intensity,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
    );
  }

  /// Formato gravado em users_xp/{uid}.nameStyle.
  Map<String, dynamic> toMap() {
    final ids = effects.map((e) => e.id).toList()..sort();
    return {
      'color': colorId,
      'effects': ids,
      'intensity': intensity.id,
    };
  }

  /// Lê o mapa salvo. Ids desconhecidos (ex.: efeito removido numa
  /// versão futura) são ignorados em vez de quebrar a tela.
  static NameStyle? fromMap(dynamic raw, {DateTime? premiumExpiresAt}) {
    if (raw is! Map) return null;

    final effects = <NameEffect>{};
    final rawEffects = raw['effects'];
    if (rawEffects is List) {
      for (final item in rawEffects) {
        final effect = NameEffectX.fromId(item?.toString());
        if (effect != null) effects.add(effect);
      }
    }

    return NameStyle(
      colorId: NameColors.byId(raw['color']?.toString()).id,
      effects: effects,
      intensity: NameIntensityX.fromId(raw['intensity']?.toString()),
      premiumExpiresAt: premiumExpiresAt,
    );
  }

  /// Ponto ÚNICO de leitura a partir dos dados brutos de users_xp/{uid}.
  ///
  /// Devolve null (nome no visual padrão) quando o usuário não tem
  /// assinatura vigente — decidido por premiumTierFromData, a mesma
  /// regra do resto do app — ou quando nunca escolheu um estilo.
  static NameStyle? fromUserData(Map<String, dynamic>? data) {
    if (data == null) return null;
    if (!premiumTierFromData(data).isPremium) return null;

    final expires = data['premiumExpiresAt'];
    return fromMap(
      data['nameStyle'],
      premiumExpiresAt: expires is Timestamp ? expires.toDate() : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NameStyle &&
        other.colorId == colorId &&
        other.intensity == intensity &&
        other.premiumExpiresAt == premiumExpiresAt &&
        setEquals(other.effects, effects);
  }

  @override
  int get hashCode => Object.hash(
        colorId,
        intensity,
        premiumExpiresAt,
        Object.hashAllUnordered(effects),
      );
}