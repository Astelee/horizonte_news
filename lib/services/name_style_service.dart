import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/name_style_config.dart';
import '../config/premium_config.dart';

// ═══════════════════════════════════════════════════════════════════
// SALVAR A PERSONALIZAÇÃO DO NOME (base para o futuro seletor)
// ═══════════════════════════════════════════════════════════════════
// Grava/limpa users_xp/{uid}.nameStyle. O campo pertence ao dono do
// documento, então as regras atuais do Firestore já permitem a
// escrita (só photoUrl/premiumTier/premiumExpiresAt são protegidos) —
// nenhuma mudança em firestore.rules é necessária.
//
// A regra de assinatura NÃO é reescrita aqui: reaproveita
// premiumTierFromData. Sem plano vigente, salvar é recusado. E mesmo
// que o campo seja gravado por fora, quem exibe o nome
// (NameStyle.fromUserData) ignora o estilo de quem não é assinante.
// ═══════════════════════════════════════════════════════════════════

class NameStyleService {
  NameStyleService._();

  static DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users_xp').doc(uid);
  }

  /// Salva o estilo do usuário logado. Lança [StateError] se não houver
  /// usuário logado ou se a assinatura não estiver vigente.
  static Future<void> save(NameStyle style) async {
    final doc = _doc;
    if (doc == null) {
      throw StateError('Usuário não autenticado.');
    }

    final snap = await doc.get();
    final data = snap.data() ?? <String, dynamic>{};
    if (!premiumTierFromData(data).isPremium) {
      throw StateError(
        'A personalização do nome é exclusiva para assinantes.',
      );
    }

    await doc.set({'nameStyle': style.toMap()}, SetOptions(merge: true));
  }

  /// Remove a personalização (nome volta ao visual padrão).
  static Future<void> reset() async {
    final doc = _doc;
    if (doc == null) return;
    await doc.update({'nameStyle': FieldValue.delete()});
  }
}