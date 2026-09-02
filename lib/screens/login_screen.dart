import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';

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

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  late AnimationController _bgAnimController;
  late AnimationController _formAnimController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  late AnimationController _buttonBreatheController;

  late Animation<double> _formFadeAnim;
  late Animation<Offset> _formSlideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _buttonBreatheAnim;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _emailFocused = false;
  bool _passwordFocused = false;

  // Partículas geradas uma vez, com posição/velocidade/fase próprias.
  final List<_Particle> _particles =
      List.generate(28, (i) => _Particle.random(math.Random(i * 97)));

  @override
  void initState() {
    super.initState();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _formAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _buttonBreatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _formFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formAnimController, curve: Curves.easeOut),
    );

    _formSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _formAnimController, curve: Curves.easeOutCubic),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _buttonBreatheAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
          parent: _buttonBreatheController, curve: Curves.easeInOut),
    );

    _emailFocus.addListener(() {
      setState(() => _emailFocused = _emailFocus.hasFocus);
    });
    _passwordFocus.addListener(() {
      setState(() => _passwordFocused = _passwordFocus.hasFocus);
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _formAnimController.forward();
    });

    _loadSavedEmail();
  }

  // ✅ Pré-preenche o e-mail se "Lembrar login" estava ativo. A senha
  // não é mais salva — a sessão do Firebase Auth é quem garante o
  // login automático ao abrir o app.
  Future<void> _loadSavedEmail() async {
    final remembered = await AuthService.instance.isRememberEnabled();
    final savedEmail = await AuthService.instance.getSavedEmail();
    if (mounted && remembered && savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _bgAnimController.dispose();
    _formAnimController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _buttonBreatheController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ Login agora passa pelo AuthService, que aplica a preferência
      // de "Lembrar login" automaticamente.
      await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        remember: _rememberMe,
      );
      SoundService.instance.playSystemClick();

      // Pede permissão de notificação logo após o login, uma única vez
      // (NotificationService já controla isso via _permissionKey — se o
      // usuário já foi perguntado antes, não pergunta de novo).
      final jaPediu = await NotificationService.jaFoiPedidoPermissao();
      if (!jaPediu) {
        await NotificationService.requestPermission();
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'Nenhuma conta encontrada com este e-mail.';
            break;
          case 'wrong-password':
            _errorMessage = 'Senha incorreta. Tente novamente.';
            break;
          case 'invalid-credential':
            _errorMessage =
                'E-mail ou senha incorretos. Verifique e tente novamente.';
            break;
          case 'invalid-email':
            _errorMessage = 'Formato de e-mail inválido.';
            break;
          case 'user-disabled':
            _errorMessage = 'Esta conta foi desativada.';
            break;
          case 'too-many-requests':
            _errorMessage = 'Muitas tentativas. Aguarde e tente novamente.';
            break;
          case 'network-request-failed':
            _errorMessage = 'Sem conexão com a internet.';
            break;
          default:
            _errorMessage = 'Erro ao autenticar (${e.code}). Tente novamente.';
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          _AnimatedBackground(controller: _bgAnimController, size: size),
          _ParticleField(
            controller: _particleController,
            particles: _particles,
            size: size,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: FadeTransition(
                  opacity: _formFadeAnim,
                  child: SlideTransition(
                    position: _formSlideAnim,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 36),
                          _buildFormCard(),
                          const SizedBox(height: 20),
                          _buildRegisterRow(),
                        ],
                      ),
                    ),
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
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _pulseAnim.value,
            child: child,
          ),
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
                        .withOpacity(0.6 * _glowAnim.value),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: AppColors.emergencyRed
                        .withOpacity(0.3 * _glowAnim.value),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: child,
            ),
            child: const Icon(Icons.public, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF6D00), Color(0xFFFFB74D), Color(0xFFE65100)],
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
        const SizedBox(height: 6),
        const Text(
          'ACESSO AO SISTEMA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
            letterSpacing: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0A0A0A),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 0,
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
                      AppColors.primaryOrange
                          .withOpacity(0.8 * _glowAnim.value),
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
                  'LOGIN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOrange,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Entre com suas credenciais',
                  style: TextStyle(fontSize: 15, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 28),
                _buildCyberField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  focused: _emailFocused,
                  label: 'E-MAIL',
                  hint: 'seu@email.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe seu e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildCyberField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  focused: _passwordFocused,
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
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe sua senha';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                _buildRememberMeRow(),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.forgotPassword),
                    child: const Text(
                      'Esqueceu a senha?',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF616161),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],
                _buildLoginButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Checkbox "Lembrar login"
  Widget _buildRememberMeRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        SoundService.instance.playSystemClick();
        setState(() => _rememberMe = !_rememberMe);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _rememberMe
                    ? AppColors.primaryOrange
                    : Colors.transparent,
                border: Border.all(
                  color: _rememberMe
                      ? AppColors.primaryOrange
                      : const Color(0xFF424242),
                  width: 1.5,
                ),
              ),
              child: _rememberMe
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            const Text(
              'Lembrar login',
              style: TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool focused = false,
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.28),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFF424242), fontSize: 15),
              prefixIcon: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: focused ? 1.15 : 1.0,
                child: Icon(
                  icon,
                  color: focused
                      ? AppColors.primaryOrange
                      : AppColors.primaryOrange.withOpacity(0.75),
                  size: 20,
                ),
              ),
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
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnim, _buttonBreatheAnim]),
      builder: (_, __) => Transform.scale(
        scale: _isLoading ? 1.0 : _buttonBreatheAnim.value,
        child: Container(
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
                    .withOpacity(0.45 * _glowAnim.value),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.emergencyRed
                    .withOpacity(0.2 * _glowAnim.value),
                blurRadius: 40,
                spreadRadius: 0,
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
                            'ENTRAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
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
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          'Não tem uma conta?',
          style: TextStyle(color: Color(0xFF757575), fontSize: 13),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.register),
          child: const Text(
            'Cadastre-se',
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
class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final Size size;

  const _AnimatedBackground(
      {required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _CyberGridPainter(controller.value),
      ),
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  final double t;
  _CyberGridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    final gridPaint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const spacing = 32.0;
    final offsetX = (t * spacing * 2) % spacing;
    final offsetY = (t * spacing) % spacing;

    for (double x = -spacing + offsetX;
        x < size.width + spacing;
        x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -spacing + offsetY;
        y < size.height + spacing;
        y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final orbPaint = Paint()..style = PaintingStyle.fill;

    final orbs = [
      _Orb(
        center: Offset(size.width * 0.15, size.height * 0.2),
        radius: 200,
        color: AppColors.primaryOrange.withOpacity(0.07),
        phase: 0.0,
      ),
      _Orb(
        center: Offset(size.width * 0.85, size.height * 0.75),
        radius: 180,
        color: AppColors.emergencyRed.withOpacity(0.05),
        phase: 0.5,
      ),
      _Orb(
        center: Offset(size.width * 0.5, size.height * 0.5),
        radius: 250,
        color: AppColors.accentOrange.withOpacity(0.03),
        phase: 0.3,
      ),
    ];

    for (final orb in orbs) {
      final pulse =
          math.sin((t + orb.phase) * 2 * math.pi) * 0.3 + 0.7;
      orbPaint.shader = RadialGradient(
        colors: [
          orb.color.withOpacity(orb.color.opacity * pulse),
          Colors.transparent
        ],
      ).createShader(
        Rect.fromCircle(center: orb.center, radius: orb.radius),
      );
      canvas.drawCircle(orb.center, orb.radius, orbPaint);
    }
  }

  @override
  bool shouldRepaint(_CyberGridPainter old) => old.t != t;
}

class _Orb {
  final Offset center;
  final double radius;
  final Color color;
  final double phase;
  const _Orb(
      {required this.center,
      required this.radius,
      required this.color,
      required this.phase});
}

// ═══════════════════════════════════════════════════════════════════
// PARTÍCULAS FLUTUANTES
// ═══════════════════════════════════════════════════════════════════
class _Particle {
  final double x; // 0..1, posição horizontal relativa
  final double startY; // 0..1, posição vertical inicial relativa
  final double speed; // ciclos completos por loop do controller
  final double size;
  final double phase; // deslocamento no tempo, pra não nascerem juntas
  final double drift; // quanto oscila lateralmente
  final bool isRed; // usa a cor de emergência em vez do laranja

  const _Particle({
    required this.x,
    required this.startY,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
    required this.isRed,
  });

  factory _Particle.random(math.Random r) {
    return _Particle(
      x: r.nextDouble(),
      startY: r.nextDouble(),
      speed: 0.5 + r.nextDouble() * 0.9,
      size: 1.2 + r.nextDouble() * 2.4,
      phase: r.nextDouble(),
      drift: 8 + r.nextDouble() * 18,
      isRed: r.nextDouble() < 0.15,
    );
  }
}

class _ParticleField extends StatelessWidget {
  final AnimationController controller;
  final List<_Particle> particles;
  final Size size;

  const _ParticleField({
    required this.controller,
    required this.particles,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => CustomPaint(
          size: size,
          painter: _ParticlePainter(particles, controller.value),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Sobe continuamente e "dá a volta" por baixo ao sair pelo topo.
      final progress = ((t * p.speed) + p.phase) % 1.0;
      final y = (p.startY - progress) % 1.0 < 0
          ? (p.startY - progress) % 1.0 + 1.0
          : (p.startY - progress) % 1.0;
      final wobble =
          math.sin((progress * 2 * math.pi) + p.phase * 10) * p.drift;
      final dx = p.x * size.width + wobble;
      final dy = y * size.height;

      // Fade in/out suave nas bordas do trajeto vertical.
      final edgeFade = (math.sin(progress * math.pi)).clamp(0.0, 1.0);
      final baseColor =
          p.isRed ? AppColors.emergencyRed : AppColors.primaryOrange;

      paint.color = baseColor.withOpacity(0.5 * edgeFade);
      canvas.drawCircle(Offset(dx, dy), p.size, paint);

      // Glow sutil ao redor de cada partícula.
      paint.color = baseColor.withOpacity(0.12 * edgeFade);
      canvas.drawCircle(Offset(dx, dy), p.size * 3.2, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════
// LOADING ANIMADO
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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AUTENTICANDO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
