import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Fecha o teclado
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await credential.user?.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este e-mail já está cadastrado.';
          break;
        case 'weak-password':
          msg = 'Senha muito fraca. Use pelo menos 6 caracteres.';
          break;
        case 'invalid-email':
          msg = 'Formato de e-mail inválido.';
          break;
        case 'network-request-failed':
          msg = 'Sem conexão com a internet.';
          break;
        default:
          msg = 'Erro Firebase: ${e.code} — ${e.message}';
      }
      if (mounted) setState(() => _errorMessage = msg);
    } catch (e) {
      // Captura qualquer outro erro e mostra na tela
      if (mounted) setState(() => _errorMessage = 'Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF6D00),
                      Color(0xFFFFB74D),
                      Color(0xFFE65100)
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'CRIAR CONTA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cadastre-se para interagir e salvar notícias',
                  style: TextStyle(color: Color(0xFF757575), fontSize: 13),
                ),
                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF0A0A0A),
                    border: Border.all(
                      color: AppColors.primaryOrange.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.06),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 40,
                        right: 40,
                        child: AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (context, child) {
                            return Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.primaryOrange
                                        .withOpacity(0.7 * _glowAnim.value),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildField(
                              controller: _nameController,
                              label: 'NOME COMPLETO',
                              hint: 'Seu nome',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Informe seu nome';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              controller: _emailController,
                              label: 'E-MAIL',
                              hint: 'seu@email.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Informe seu e-mail';
                                if (!v.contains('@')) return 'E-mail inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              controller: _passwordController,
                              label: 'SENHA',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF616161),
                                  size: 20,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Informe uma senha';
                                if (v.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              controller: _confirmPasswordController,
                              label: 'CONFIRMAR SENHA',
                              hint: '••••••••',
                              icon: Icons.lock_reset_rounded,
                              obscureText: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF616161),
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Confirme sua senha';
                                if (v != _passwordController.text)
                                  return 'As senhas não coincidem';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Banner de erro — agora sempre visível quando há erro
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.emergencyRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.emergencyRed
                                        .withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: AppColors.emergencyRed,
                                        size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: AppColors.emergencyRed,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Botão cadastrar
                            AnimatedBuilder(
                              animation: _glowAnim,
                              builder: (context, child) {
                                return Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFBF360C),
                                        Color(0xFFE65100),
                                        Color(0xFFF57C00)
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryOrange
                                            .withOpacity(
                                                0.4 * _glowAnim.value),
                                        blurRadius: 24,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap:
                                          _isLoading ? null : _handleRegister,
                                      splashColor:
                                          Colors.white.withOpacity(0.1),
                                      child: Center(
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                          Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'CRIAR CONTA',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 3,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já tem uma conta?',
                      style:
                          TextStyle(color: Color(0xFF757575), fontSize: 13),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Entrar',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF757575),
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFF424242), fontSize: 15),
            prefixIcon: Icon(icon, color: AppColors.primaryOrange, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF141414),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF212121)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF212121)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: AppColors.primaryOrange, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: AppColors.emergencyRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: AppColors.emergencyRed, width: 1.5),
            ),
            errorStyle: const TextStyle(
                color: AppColors.emergencyRed, fontSize: 11),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
