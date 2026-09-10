import 'package:cloud_firestore/cloud_firestore.dart';

/// Configurações globais do app (documento único), lidas por
/// qualquer usuário — a escrita é exclusiva de admin (ver
/// AdminConfigService e as regras do Firestore).
///
/// Guarda: modo manutenção (bloqueia o app inteiro) e liga/desliga
/// comentários (bloqueia apenas o envio de novos comentários; os já
/// existentes continuam visíveis).
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore
      .instance
      .collection('app_config')
      .doc('global');

  /// Stream em tempo real do documento de configuração. Se o
  /// documento ainda não existir (app nunca configurado por um
  /// admin), trata como "tudo normal": sem manutenção, comentários
  /// ligados.
  Stream<AppGlobalConfig> stream() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return AppGlobalConfig.defaults();
      return AppGlobalConfig.fromMap(snap.data()!);
    });
  }

  /// Leitura única (sem stream), útil para checagens pontuais.
  Future<AppGlobalConfig> fetch() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data() == null) return AppGlobalConfig.defaults();
    return AppGlobalConfig.fromMap(snap.data()!);
  }
}

class AppGlobalConfig {
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool commentsEnabled;

  /// 'admob' | 'partner' | 'off'
  final String adsBarMode;
  final String adsPartnerName;
  final String adsPartnerImageUrl;
  final String adsPartnerLinkUrl;

  const AppGlobalConfig({
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.commentsEnabled,
    required this.adsBarMode,
    required this.adsPartnerName,
    required this.adsPartnerImageUrl,
    required this.adsPartnerLinkUrl,
  });

  factory AppGlobalConfig.defaults() => const AppGlobalConfig(
        maintenanceMode: false,
        maintenanceMessage: '',
        commentsEnabled: true,
        adsBarMode: 'admob',
        adsPartnerName: '',
        adsPartnerImageUrl: '',
        adsPartnerLinkUrl: '',
      );

  factory AppGlobalConfig.fromMap(Map<String, dynamic> map) {
    return AppGlobalConfig(
      maintenanceMode: map['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: (map['maintenanceMessage'] as String?) ?? '',
      commentsEnabled: map['commentsEnabled'] as bool? ?? true,
      adsBarMode: (map['adsBarMode'] as String?) ?? 'admob',
      adsPartnerName: (map['adsPartnerName'] as String?) ?? '',
      adsPartnerImageUrl: (map['adsPartnerImageUrl'] as String?) ?? '',
      adsPartnerLinkUrl: (map['adsPartnerLinkUrl'] as String?) ?? '',
    );
  }
}