import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Serviço central de autenticação.
///
/// Centraliza login, logout e a lógica de "Lembrar login".
/// Nunca armazena senha — apenas um sinalizador (lembrar sim/não) e
/// o e-mail, para pré-preencher o campo na próxima abertura.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _storage = FlutterSecureStorage();
  static const String _rememberKey = 'remember_login';
  static const String _emailKey = 'saved_login_email';

  /// Se o usuário optou por ser lembrado na última vez que fez login.
  Future<bool> isRememberEnabled() async {
    try {
      final value = await _storage.read(key: _rememberKey);
      return value == 'true';
    } catch (e) {
      debugPrint('AuthService: erro ao ler preferência de lembrar login: $e');
      return false;
    }
  }

  /// E-mail salvo (para pré-preencher o campo), se houver.
  Future<String?> getSavedEmail() async {
    try {
      return await _storage.read(key: _emailKey);
    } catch (e) {
      debugPrint('AuthService: erro ao ler e-mail salvo: $e');
      return null;
    }
  }

  /// Realiza o login com e-mail/senha e aplica a preferência de
  /// "Lembrar login" (salva ou remove os dados persistidos).
  Future<UserCredential> signIn({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (remember) {
      await _storage.write(key: _rememberKey, value: 'true');
      await _storage.write(key: _emailKey, value: email);
    } else {
      await _clearRememberData();
    }

    return credential;
  }

  /// Deve ser chamado uma única vez, no início do app (antes de exibir
  /// qualquer tela). O Firebase mantém a sessão ativa por padrão entre
  /// aberturas do app; se o usuário NÃO marcou "Lembrar login" da última
  /// vez, forçamos o logout aqui para respeitar a escolha dele.
  Future<void> enforceRememberPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final remember = await isRememberEnabled();
    if (!remember) {
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Faz logout e remove qualquer dado persistido de "Lembrar login".
  Future<void> signOut() async {
    await _clearRememberData();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _clearRememberData() async {
    try {
      await _storage.delete(key: _rememberKey);
      await _storage.delete(key: _emailKey);
    } catch (e) {
      debugPrint('AuthService: erro ao limpar dados de login: $e');
    }
  }
}
