import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/news_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  late AnimationController _bgAnimController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _logoFadeCtrl;
  late AnimationController _taglineFadeCtrl;
  late AnimationController _field1Ctrl;
  late AnimationController _field2Ctrl;
  late AnimationController _btnCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _taglineFade;
  late Animation<double> _field1Fade;
  late Animation<Offset> _field1Slide;
  late Animation<double> _field2Fade;
  late Animation<Offset> _field2Slide;
  late Animation<double> _btnFade;
  late Animation<Offset> _btnSlide;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSavedCredentials();
  }

  void _initAnimations() {
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _logoFadeCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _taglineFadeCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500));
    _field1Ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450));
    _field2Ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450));
    _btnCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450));

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
          parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
          parent: _glowController, curve: Curves.easeInOut),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _logoFadeCtrl, curve: Curves.easeOut));
    _logoSlide =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _logoFadeCtrl,
                curve: Curves.easeOutCubic));
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _taglineFadeCtrl, curve: Curves.easeOut));
    _field1Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _field1Ctrl, curve: Curves.easeOut));
    _field1Slide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _field1Ctrl,
                curve: Curves.easeOutCubic));
    _field2Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _field2Ctrl, curve: Curves.easeOut));
    _field2Slide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _field2Ctrl,
                curve: Curves.easeOutCubic));
    _btnFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut));
    _btnSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _btnCtrl, curve: Curves.easeOutCubic));

    _logoFadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200),
        () { if (mounted) _taglineFadeCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 400),
        () { if (mounted) _field1Ctrl.forward(); });
    Future.delayed(const Duration(milliseconds: 550),
        () { if (mounted) _field2Ctrl.forward(); });
    Future.delayed(const Duration(milliseconds: 700),
        () { if (mounted) _btnCtrl.forward(); });
  }

  Future<void> _loadSavedCredentials() async {
    final email = await _secureStorage.read(key: 'saved_email');
    final password =
        await _secureStorage.read(key: 'saved_password');
    final remember =
        await _secureStorage.read(key: 'remember_me');

    if (remember == 'true' && email != null && password != null) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleCredentialStorage() async {
    if (_rememberMe) {
      await _secureStorage.write(
          key: 'saved_email',
          value: _emailController.text.trim());
      await _secureStorage.write(
          key: 'saved_password',
          value: _passwordController.text.trim());
      await _secureStorage.write(
          key: 'remember_me', value: 'true');
    } else {
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
      await _secureStorage.write(
          key: 'remember_me', value: 'false');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgAnimController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _logoFadeCtrl.dispose();
    _taglineFadeCtrl.dispose();
    _field1Ctrl.dispose();
    _field2Ctrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  // ── Verifica permissão real do sistema ───────────────────────
  Future<bool> _systemNotifEnabled() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (Platform.isAndroid) {
        final android = plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      } else if (Platform.isIOS) {
        final ios = plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final settings = await ios?.checkPermissions();
        return settings?.isEnabled ?? false;
      }
    } catch (_) {}
    return false;
  }

  // ── Dialog de permissão personalizado ────────────────────────
  // ATUALIZADO: usa FlutterSecureStorage em vez de SharedPreferences
  // para evitar restauração pelo backup automático do Android.
  Future<void> _askNotificationPermission() async {
    final alreadyAsked =
        await _secureStorage.read(key: 'notif_permission_asked');
    if (alreadyAsked == 'true') return;

    // Verifica se o sistema já tem permissão concedida
    final jaTemPermissao = await _systemNotifEnabled();

    // Marca como já perguntado (em SecureStorage — não restaurável)
    await _secureStorage.write(
        key: 'notif_permission_asked', value: 'true');

    // Se já tem permissão no sistema, só registra o token
    if (jaTemPermissao) {
      await NotificationService.requestPermission();
      return;
    }

    if (!mounted) return;

    final userWantsNotif = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.15),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orangeGradient,
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.primaryOrange.withOpacity(0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Fique por dentro!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ative as notificações para receber as últimas notícias do Horizonte News assim que forem publicadas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppColors.orangeGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange
                              .withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'ATIVAR NOTIFICAÇÕES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF2A2A2A)),
                    ),
                    child: const Center(
                      child: Text(
                        'Agora não',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (userWantsNotif == true) {
      await NotificationService.requestPermission();
    }
  }

  // ── ATUALIZADO: pede permissão ANTES de navegar ───────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _handleCredentialStorage();

      // Pede permissão ANTES de navegar para home
      await _askNotificationPermission();

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage =
                'Nenhuma conta encontrada com este e-mail.';
            break;
          case 'wrong-password':
            _errorMessage = 'Senha incorreta. Tente novamente.';
            break;
          case 'invalid-email':
            _errorMessage = 'Formato de e-mail inválido.';
            break;
          case 'user-disabled':
            _errorMessage = 'Esta conta foi desativada.';
            break;
          case 'too-many-requests':
            _errorMessage =
                'Muitas tentativas. Aguarde e tente novamente.';
            break;
          default:
            _errorMessage =
                'Erro ao autenticar. Verifique suas credenciais.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (_, __) => CustomPaint(
              size: size,
              painter:
                  _LoginBgPainter(_bgAnimController.value),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 32),
                      _buildFormCard(),
                      const SizedBox(height: 20),
                      _buildRegisterRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoFade,
      child: SlideTransition(
        position: _logoSlide,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                  scale: _pulseAnim.value, child: child),
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, child) => Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFF6D00),
                        Color(0xFFE65100),
                        Color(0x00000000),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange
                            .withOpacity(
                                0.65 * _glowAnim.value),
                        blurRadius: 36,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: const Color(0xFFE65100)
                            .withOpacity(
                                0.25 * _glowAnim.value),
                        blurRadius: 60,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(Icons.public,
                    size: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 18),
            ShaderMask(
              shaderCallback: (bounds) =>
                  const LinearGradient(
                colors: [
                  Color(0xFFFF6D00),
                  Color(0xFFFFB74D),
                  Color(0xFFE65100),
                ],
              ).createShader(bounds),
              child: const Text(
                'HORIZONTE NEWS',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _taglineFade,
              child: const Text(
                'Seu portal de notícias em tempo real',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                  letterSpacing: 0.3,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF080808),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.07),
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
                          0.8 * _glowAnim.value),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Entrar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Seu portal de notícias em tempo real',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF757575),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _field1Fade,
                  child: SlideTransition(
                    position: _field1Slide,
                    child: _buildCyberField(
                      controller: _emailController,
                      label: 'SEU E-MAIL',
                      hint: 'voce@email.com',
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
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _field2Fade,
                  child: SlideTransition(
                    position: _field2Slide,
                    child: _buildCyberField(
                      controller: _passwordController,
                      label: 'SUA SENHA',
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
                          return 'Informe sua senha';
                        if (v.length < 6)
                          return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildRememberMeRow(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.forgotPassword),
                    child: const Text(
                      'Esqueceu a senha?',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF616161),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  _buildErrorBanner(_errorMessage!),
                if (_errorMessage != null)
                  const SizedBox(height: 16),
                FadeTransition(
                  opacity: _btnFade,
                  child: SlideTransition(
                    position: _btnSlide,
                    child: _buildLoginButton(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMeRow() {
    return GestureDetector(
      onTap: () =>
          setState(() => _rememberMe = !_rememberMe),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _rememberMe
                  ? AppColors.primaryOrange
                  : Colors.transparent,
              border: Border.all(
                color: _rememberMe
                    ? AppColors.primaryOrange
                    : const Color(0xFF424242),
                width: 1.5,
              ),
              boxShadow: _rememberMe
                  ? [
                      BoxShadow(
                        color: AppColors.primaryOrange
                            .withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: _rememberMe
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          const Text(
            'Lembrar minha conta',
            style: TextStyle(
                color: Color(0xFF9E9E9E), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberField({
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
            color: Color(0xFF616161),
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
              color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: Color(0xFF424242), fontSize: 15),
            prefixIcon: Icon(icon,
                color: AppColors.primaryOrange, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF1E1E1E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF1E1E1E)),
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

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFBF360C),
              Color(0xFFE65100),
              Color(0xFFF57C00),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange
                  .withOpacity(0.45 * _glowAnim.value),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isLoading ? null : _handleLogin,
            splashColor: Colors.white.withOpacity(0.1),
            child: Center(
              child: _isLoading
                  ? const _CyberLoader()
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Acessar notícias',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.emergencyRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.emergencyRed.withOpacity(0.4),
          width: 1,
        ),
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

  Widget _buildRegisterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Ainda não tem conta?',
          style: TextStyle(
              color: Color(0xFF757575), fontSize: 13),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => Navigator.pushNamed(
              context, AppRoutes.register),
          child: const Text(
            'Criar conta',
            style: TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FUNDO ANIMADO
// ═══════════════════════════════════════════════════════════════════
class _LoginBgPainter extends CustomPainter {
  final double t;
  _LoginBgPainter(this.t);

  static final _rng = math.Random(7);
  static final _particles = List.generate(
      28,
      (i) => _ParticleData(
            x: _rng.nextDouble(),
            y: _rng.nextDouble(),
            size: 0.8 + _rng.nextDouble() * 1.4,
            speed: 0.02 + _rng.nextDouble() * 0.05,
            opacity: 0.08 + _rng.nextDouble() * 0.25,
            phase: _rng.nextDouble(),
          ));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.025)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final orbs = [
      _OrbData(
        cx: 0.2 + 0.12 * math.sin(t * 2 * math.pi),
        cy: 0.2 + 0.08 * math.cos(t * 2 * math.pi),
        r: 0.55,
        opacity: 0.07,
      ),
      _OrbData(
        cx: 0.82 +
            0.08 * math.cos(t * 2 * math.pi + 1.5),
        cy: 0.72 +
            0.08 * math.sin(t * 2 * math.pi + 1.5),
        r: 0.45,
        opacity: 0.05,
      ),
    ];

    for (final o in orbs) {
      final center =
          Offset(o.cx * size.width, o.cy * size.height);
      final radius = o.r * size.width;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF6B00)
                  .withOpacity(o.opacity),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(
              center: center, radius: radius)),
      );
    }

    for (final p in _particles) {
      final dy =
          (p.y - t * p.speed + p.phase) % 1.0;
      final dx = p.x +
          0.02 *
              math.sin(
                  t * 2 * math.pi * 0.5 + p.phase * 6.28);
      final opacity = p.opacity *
          (0.5 +
              0.5 *
                  math.sin(t * 2 * math.pi * 0.8 +
                      p.phase * 6.28));

      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.size,
        Paint()
          ..color = const Color(0xFFFF6B00)
              .withOpacity(opacity.clamp(0.0, 1.0)),
      );
    }

    final dotPaint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.12);
    final linePaint2 = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.05)
      ..strokeWidth = 0.5;

    final dots = [
      Offset(size.width * 0.1, size.height * 0.15),
      Offset(size.width * 0.9, size.height * 0.2),
      Offset(size.width * 0.05, size.height * 0.85),
      Offset(size.width * 0.95, size.height * 0.8),
    ];

    for (int i = 0; i < dots.length; i++) {
      canvas.drawCircle(dots[i], 3, dotPaint);
      for (int j = i + 1; j < dots.length; j++) {
        canvas.drawLine(dots[i], dots[j], linePaint2);
      }
    }
  }

  @override
  bool shouldRepaint(_LoginBgPainter old) => old.t != t;
}

class _ParticleData {
  final double x, y, size, speed, opacity, phase;
  const _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _OrbData {
  final double cx, cy, r, opacity;
  const _OrbData(
      {required this.cx,
      required this.cy,
      required this.r,
      required this.opacity});
}

// ═══════════════════════════════════════════════════════════════════
// CYBER LOADER
// ═══════════════════════════════════════════════════════════════════
class _CyberLoader extends StatefulWidget {
  const _CyberLoader();

  @override
  State<_CyberLoader> createState() => _CyberLoaderState();
}

class _CyberLoaderState extends State<_CyberLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor:
            AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
