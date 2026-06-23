import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _checkingUsername = false;
  bool _usernameAvailable = false;
  String? _errorMessage;
  String? _usernameError;

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

    // Verifica disponibilidade do username com debounce
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ── Debounce para verificar username ─────────────────────────────
  DateTime _lastCheck = DateTime.now();

  void _onUsernameChanged() {
    final value = _usernameController.text.trim();
    setState(() {
      _usernameAvailable = false;
      _usernameError = null;
    });

    if (value.length < 3) return;

    _lastCheck = DateTime.now();
    final checkTime = _lastCheck;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (checkTime == _lastCheck && mounted) {
        _checkUsernameAvailability(value);
      }
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.length < 3) return;

    setState(() => _checkingUsername = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users_xp')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _usernameAvailable = query.docs.isEmpty;
          _usernameError =
              query.docs.isEmpty ? null : 'Este ID já está em uso.';
          _checkingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  // ── Formata o username: só letras, números e _ ───────────────────
  String _formatUsername(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim().toLowerCase();

    if (!_usernameAvailable) {
      setState(
          () => _errorMessage = 'Escolha um ID de usuário disponível.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Cria conta no Firebase Auth
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user!;

      // 2. Define o displayName como o username
      await user.updateDisplayName(username);

      // 3. Cria documento no Firestore com o username
      await FirebaseFirestore.instance
          .collection('users_xp')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'username': username,
        'displayName': username,
        'email': user.email ?? '',
        'totalXp': 0,
        'level': 1,
        'totalSecondsOnline': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        'achievements': ['first_login'],
        'stats': {
          'articlesRead': 0,
          'articlesShared': 0,
          'commentsPosted': 0,
        },
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'Este e-mail já está cadastrado.';
            break;
          case 'weak-password':
            _errorMessage =
                'Senha muito fraca. Use pelo menos 6 caracteres.';
            break;
          case 'invalid-email':
            _errorMessage = 'Formato de e-mail inválido.';
            break;
          default:
            _errorMessage = 'Erro ao criar conta. Tente novamente.';
        }
      });
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
          padding: const EdgeInsets.symmetric(
              horizontal: 24.0, vertical: 8.0),
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
                  style: TextStyle(
                      color: Color(0xFF757575), fontSize: 13),
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
                        color:
                            AppColors.primaryOrange.withOpacity(0.06),
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
                          builder: (_, __) => Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.primaryOrange.withOpacity(
                                      0.7 * _glowAnim.value),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // ── Campo de ID / Username ──────────
                            _buildUsernameField(),
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
                                if (!v.contains('@'))
                                  return 'E-mail inválido';
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
                                    _obscurePassword =
                                        !_obscurePassword),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Informe uma senha';
                                if (v.length < 6)
                                  return 'Mínimo 6 caracteres';
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
                                onPressed: () => setState(() =>
                                    _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (v) {
                                if (v != _passwordController.text)
                                  return 'As senhas não coincidem';
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            if (_errorMessage != null)
                              _buildErrorBanner(_errorMessage!),
                            if (_errorMessage != null)
                              const SizedBox(height: 16),

                            AnimatedBuilder(
                              animation: _glowAnim,
                              builder: (_, __) => Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(14),
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
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    onTap: _isLoading
                                        ? null
                                        : _handleRegister,
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
                                                fontWeight:
                                                    FontWeight.w800,
                                                letterSpacing: 3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
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
                      style: TextStyle(
                          color: Color(0xFF757575), fontSize: 13),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
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

  // ── CAMPO DE USERNAME / ID ────────────────────────────────────────
  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SEU ID DE USUÁRIO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF757575),
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Será usado para te identificar no chat.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          inputFormatters: [
            // Permite só letras minúsculas, números e _
            FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z0-9_]')),
            TextInputFormatter.withFunction((old, newVal) {
              return newVal.copyWith(
                text: newVal.text.toLowerCase(),
                selection: newVal.selection,
              );
            }),
          ],
          decoration: InputDecoration(
            hintText: 'ex: Joãozinho123',
            hintStyle: const TextStyle(
                color: Color(0xFF424242), fontSize: 15),
            prefixText: '@',
            prefixStyle: const TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: const Icon(
              Icons.tag_rounded,
              color: AppColors.primaryOrange,
              size: 20,
            ),
            suffixIcon: _buildUsernameSuffix(),
            filled: true,
            fillColor: const Color(0xFF141414),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF212121)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _usernameError != null
                    ? AppColors.emergencyRed.withOpacity(0.5)
                    : _usernameAvailable &&
                            _usernameController.text.length >= 3
                        ? const Color(0xFF2E7D32).withOpacity(0.6)
                        : const Color(0xFF212121),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _usernameError != null
                    ? AppColors.emergencyRed
                    : _usernameAvailable
                        ? const Color(0xFF4CAF50)
                        : AppColors.primaryOrange,
                width: 1.5,
              ),
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
          validator: (v) {
            if (v == null || v.isEmpty) return 'Crie seu ID';
            if (v.length < 3) return 'Mínimo 3 caracteres';
            if (v.length > 20) return 'Máximo 20 caracteres';
            if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) {
              return 'Apenas letras, números e _';
            }
            if (_usernameError != null) return _usernameError;
            if (!_usernameAvailable) return 'Verificando disponibilidade...';
            return null;
          },
        ),

        // Feedback de disponibilidade
        if (_usernameController.text.length >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _checkingUsername
                  ? Row(
                      key: const ValueKey('checking'),
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verificando...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : _usernameAvailable
                      ? Row(
                          key: const ValueKey('available'),
                          children: const [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'ID disponível!',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : _usernameError != null
                          ? Row(
                              key: const ValueKey('unavailable'),
                              children: [
                                const Icon(
                                    Icons.cancel_rounded,
                                    color: AppColors.emergencyRed,
                                    size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  _usernameError!,
                                  style: const TextStyle(
                                    color: AppColors.emergencyRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildUsernameSuffix() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.primaryOrange,
          ),
        ),
      );
    }
    if (_usernameAvailable && _usernameController.text.length >= 3) {
      return const Icon(Icons.check_circle_rounded,
          color: Color(0xFF4CAF50), size: 20);
    }
    if (_usernameError != null) {
      return const Icon(Icons.cancel_rounded,
          color: AppColors.emergencyRed, size: 20);
    }
    return const SizedBox.shrink();
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
            hintStyle: const TextStyle(
                color: Color(0xFF424242), fontSize: 15),
            prefixIcon:
                Icon(icon, color: AppColors.primaryOrange, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF141414),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF212121)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF212121)),
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

  Widget _buildErrorBanner(String message) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.emergencyRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.emergencyRed.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.emergencyRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.emergencyRed,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
