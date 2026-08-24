import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Serviço central de autenticação.
///
/// Centraliza login, logout e a lógica de "Lembrar login".
/// Quando "Lembrar login" está ativo, apenas o e-mail fica salvo
/// (flutter_secure_storage, com criptografia do sistema) para
/// pré-preencher o campo no próximo login. A sessão em si é mantida
/// pelo próprio Firebase Auth (persistência nativa), então o usuário
/// continua entrando automaticamente sem precisarmos guardar a senha.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _storage = FlutterSecureStorage();
  static const String _rememberKey = 'remember_login';
  static const String _emailKey = 'saved_login_email';

  Future<bool> isRememberEnabled() async {
    try {
      final value = await _storage.read(key: _rememberKey);
      return value == 'true';
    } catch (e) {
      debugPrint('AuthService: erro ao ler remember_login: $e');
      return false;
    }
  }

  Future<String?> getSavedEmail() async {
    try {
      return await _storage.read(key: _emailKey);
    } catch (e) {
      debugPrint('AuthService: erro ao ler e-mail salvo: $e');
      return null;
    }
  }

  /// Realiza o login e aplica a preferência de "Lembrar login".
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
      try {
        await _storage.write(key: _rememberKey, value: 'true');
        await _storage.write(key: _emailKey, value: email);
      } catch (e) {
        debugPrint('AuthService: erro ao salvar dados de lembrar login: $e');
      }
    } else {
      await _clearRememberData();
    }

    return credential;
  }

  /// Deve ser chamado uma única vez, no início do app. Se o usuário
  /// não marcou "Lembrar login" da última vez, força o logout para
  /// respeitar a escolha dele.
  Future<void> enforceRememberPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final remember = await isRememberEnabled();
    if (!remember) {
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Logout manual (botão "Sair da conta"). Desloga da conta, mas
  /// MANTÉM o e-mail salvo se "Lembrar login" estiver ativo — assim
  /// o próximo login já vem com o e-mail pré-preenchido.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Remove todos os dados salvos de login. Chamado quando o usuário
  /// desmarca a opção "Lembrar login".
  Future<void> _clearRememberData() async {
    try {
      await _storage.delete(key: _rememberKey);
      await _storage.delete(key: _emailKey);
    } catch (e) {
      debugPrint('AuthService: erro ao limpar dados de login: $e');
    }
  }

  /// Remove explicitamente os dados salvos (uso público, caso precise
  /// de um botão separado de "esquecer dados salvos" no futuro).
  Future<void> forgetSavedCredentials() => _clearRememberData();
}
