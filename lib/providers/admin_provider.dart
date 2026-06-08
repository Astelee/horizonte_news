import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProvider with ChangeNotifier {
  bool _isAdmin = false;
  bool _isLoading = true;
  String? _adminRole;

  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  String? get adminRole => _adminRole;

  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isAdmin = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _isAdmin = true;
        _adminRole = doc.data()?['role'] ?? 'admin';
      } else {
        _isAdmin = false;
        _adminRole = null;
      }
    } catch (_) {
      _isAdmin = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  void reset() {
    _isAdmin = false;
    _isLoading = true;
    _adminRole = null;
    notifyListeners();
  }

  // Registra ação no log
  Future<void> logAction({
    required String action,
    required String targetId,
    String? targetType,
    Map<String, dynamic>? extra,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_isAdmin) return;

    try {
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'adminUid': user.uid,
        'adminName': user.displayName ?? user.email ?? 'Admin',
        'action': action,
        'targetId': targetId,
        'targetType': targetType ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        ...?extra,
      });
    } catch (_) {}
  }
}