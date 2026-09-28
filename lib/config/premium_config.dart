import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ═══════════════════════════════════════════════════════════════════
// CONFIGURAÇÃO DO SISTEMA PREMIUM (PRO / ULTRA)
// ═══════════════════════════════════════════════════════════════════
// Fonte única de verdade para tudo relacionado a planos Premium:
// multiplicador de XP, cores/ícones do selo, e leitura do tier a
// partir dos dados brutos do Firestore (users_xp/{uid}).
//
// Os valores de multiplicador aqui espelham o que deve existir nas
// regras do Firestore (quando a validação de compra via Cloud
// Function for implementada) — igual já acontece com checkinBaseXp
// em CheckinService/firestore.rules.
// ═══════════════════════════════════════════════════════════════════

enum PremiumTier { none, pro, ultra }

extension PremiumTierX on PremiumTier {
  String get id {
    switch (this) {
      case PremiumTier.pro:
        return 'pro';
      case PremiumTier.ultra:
        return 'ultra';
      case PremiumTier.none:
        return 'none';
    }
  }

  static PremiumTier fromId(String? id) {
    switch (id) {
      case 'pro':
        return PremiumTier.pro;
      case 'ultra':
        return PremiumTier.ultra;
      default:
        return PremiumTier.none;
    }
  }

  /// Multiplicador aplicado a todo ganho de XP (tempo online, leitura,
  /// comentário, compartilhamento, check-in, curtida recebida).
  int get xpMultiplier {
    switch (this) {
      case PremiumTier.pro:
        return 2;
      case PremiumTier.ultra:
        return 8;
      case PremiumTier.none:
        return 1;
    }
  }

  bool get isPremium => this != PremiumTier.none;

  /// Quem tem Premium (qualquer tier) recupera check-in perdido sem
  /// precisar assistir anúncio, e não vê o banner de anúncios do app.
  bool get skipsAds => isPremium;

  String get label {
    switch (this) {
      case PremiumTier.pro:
        return 'PRO';
      case PremiumTier.ultra:
        return 'ULTRA';
      case PremiumTier.none:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case PremiumTier.pro:
        return FontAwesomeIcons.bolt;
      case PremiumTier.ultra:
        return FontAwesomeIcons.crown;
      case PremiumTier.none:
        return FontAwesomeIcons.bolt;
    }
  }

  Color get accentColor {
    switch (this) {
      case PremiumTier.pro:
        return const Color(0xFF4C8DFF);
      case PremiumTier.ultra:
        return const Color(0xFFF2B705);
      case PremiumTier.none:
        return Colors.transparent;
    }
  }

  List<Color> get gradient {
    switch (this) {
      case PremiumTier.pro:
        return const [Color(0xFF4C8DFF), Color(0xFF2E5FE8)];
      case PremiumTier.ultra:
        return const [Color(0xFFF2B705), Color(0xFFE08E00)];
      case PremiumTier.none:
        return const [Colors.transparent, Colors.transparent];
    }
  }
}

/// Lê o tier Premium a partir dos dados brutos de users_xp/{uid},
/// já considerando a data de expiração — passado o prazo, o tier
/// salvo é ignorado e o usuário volta a ser tratado como 'none'
/// mesmo que premiumTier ainda esteja gravado (a limpeza do campo em
/// si é responsabilidade do backend/Cloud Function, isso aqui é só
/// leitura defensiva no cliente).
PremiumTier premiumTierFromData(Map<String, dynamic> data) {
  final tier = PremiumTierX.fromId(data['premiumTier'] as String?);
  if (tier == PremiumTier.none) return PremiumTier.none;

  final expiresAt = data['premiumExpiresAt'];
  if (expiresAt is Timestamp) {
    if (DateTime.now().isAfter(expiresAt.toDate())) {
      return PremiumTier.none;
    }
  }

  return tier;
}