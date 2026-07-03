// lib/services/avatar_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/avatar_catalog.dart';

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users_xp').doc(uid);
  }

  /// Lê apenas o avatarId salvo (usado no boot do app / provider)
  Future<String> loadAvatarId() async {
    try {
      final doc = _userDoc;
      if (doc == null) return AvatarCatalog.defaultAvatarId;

      final snap = await doc.get();
      final saved = snap.data()?['avatarId'] as String?;

      if (saved != null && AvatarCatalog.exists(saved)) {
        return saved;
      }
      return AvatarCatalog.defaultAvatarId;
    } catch (_) {
      return AvatarCatalog.defaultAvatarId;
    }
  }

  /// Salva o avatarId escolhido — apenas o identificador, nunca a imagem
  Future<bool> saveAvatarId(String avatarId) async {
    try {
      final doc = _userDoc;
      if (doc == null) return false;
      if (!AvatarCatalog.exists(avatarId)) return false;

      await doc.set({'avatarId': avatarId}, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Busca o avatarId de qualquer usuário (usado em amigos, comentários etc.)
  /// Prefira ler direto do doc já carregado quando possível — isso é fallback.
  Future<String> loadAvatarIdFor(String uid) async {
    try {
      final snap = await _db.collection('users_xp').doc(uid).get();
      final saved = snap.data()?['avatarId'] as String?;
      if (saved != null && AvatarCatalog.exists(saved)) return saved;
      return AvatarCatalog.defaultAvatarId;
    } catch (_) {
      return AvatarCatalog.defaultAvatarId;
    }
  }
}
