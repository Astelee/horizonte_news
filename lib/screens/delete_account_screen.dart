import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({Key? key}) : super(key: key);

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _loading = false;
  String _error = '';

  Future<void> _deleteAccount() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;

      // Apaga dados do Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      // Apaga subcoleções se houver (ex: favoritos)
      final favs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .get();
      for (final doc in favs.docs) {
        await doc.reference.delete();
      }

      // Apaga a conta do Firebase Auth
      await user.delete();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      // Se o login foi há muito tempo, precisa reautenticar
      if (e.code == 'requires-recent-login') {
        setState(() {
          _error =
              'Por segurança, saia e entre novamente antes de excluir sua conta.';
        });
      } else {
        setState(() => _error = 'Erro: ${e.message}');
      }
    } catch (e) {
      setState(() => _error = 'Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Excluir conta',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Todos os seus dados serão apagados permanentemente. Essa ação não pode ser desfeita.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXCLUIR',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Excluir Conta',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 20),
            const Text(
              'O que será excluído:',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const _Item('Sua conta de acesso'),
            const _Item('Seu perfil e nome de usuário'),
            const _Item('Seu nível e pontos de XP'),
            const _Item('Seus favoritos salvos'),
            const _Item('Seus comentários'),
            const SizedBox(height: 32),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Text(_error,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'EXCLUIR MINHA CONTA',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String text;
  const _Item(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline,
              color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
