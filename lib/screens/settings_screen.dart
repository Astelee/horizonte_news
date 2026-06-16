import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../providers/user_xp_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontSize     = 15.0;
  bool   _notifGeral   = false;
  bool   _economiaDados = false;
  String _autoplayMode = 'wifi';
  String _cacheSize    = '...';
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _calcCacheSize();
    _loadCurrentUsername();
    NotificationService.isEnabled().then((enabled) {
      if (mounted) setState(() => _notifGeral = enabled);
    });
  }

  Future<void> _loadCurrentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users_xp')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _currentUsername = (doc.data()?['username'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontSize      = prefs.getDouble('fontSize') ?? 15.0;
        _economiaDados = prefs.getBool('economiaDados') ?? false;
        _autoplayMode  = prefs.getString('autoplayMode') ?? 'wifi';
      });
    }
  }

  Future<void> _calcCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      int total = 0;
      if (dir.existsSync()) {
        dir.listSync(recursive: true).forEach((f) {
          if (f is File) total += f.lengthSync();
        });
      }
      if (mounted) {
        setState(() {
          if (total < 1024 * 1024) {
            _cacheSize = '${(total / 1024).toStringAsFixed(1)} KB';
          } else {
            _cacheSize = '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '—');
    }
  }

  Future<void> _clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        dir.listSync().forEach((f) {
          try { f.deleteSync(recursive: true); } catch (_) {}
        });
      }
      await _calcCacheSize();
      if (mounted) {
        _showSnack(icon: Icons.check_circle_rounded, message: 'Cache limpo com sucesso!');
      }
    } catch (_) {
      if (mounted) {
        _showSnack(icon: Icons.error_outline_rounded, message: 'Erro ao limpar cache.', isError: true);
      }
    }
  }

  Future<void> _toggleNotifGeral(bool v) async {
    if (v) {
      final granted = await NotificationService.requestPermission();
      if (granted) {
        if (mounted) setState(() => _notifGeral = true);
      } else {
        if (mounted) {
          _showSnack(
            icon: Icons.notifications_off_rounded,
            message: 'Permissão negada. Verifique as configurações do sistema.',
            isError: true,
          );
        }
      }
    } else {
      await NotificationService.removeToken();
      if (mounted) setState(() => _notifGeral = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Sair da conta',
        message: 'Tem certeza que deseja sair?',
        confirmLabel: 'Sair',
        confirmColor: Colors.redAccent,
      ),
    );
    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ALTERAR ID (USERNAME)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _showChangeUsernameIdDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ctrl = TextEditingController(text: _currentUsername);
    bool checking = false;
    bool available = false;
    bool saving = false;
    String? usernameError;

    DateTime lastCheck = DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void onChanged(String value) {
            final v = value.trim().toLowerCase();
            setDialogState(() {
              available = false;
              usernameError = null;
            });

            if (v.length < 3) return;
            if (v == _currentUsername) {
              setDialogState(() {
                available = false;
                usernameError = 'Este já é o seu ID atual.';
              });
              return;
            }

            lastCheck = DateTime.now();
            final checkTime = lastCheck;

            setDialogState(() => checking = true);

            Future.delayed(const Duration(milliseconds: 600), () async {
              if (checkTime != lastCheck) return;
              try {
                final query = await FirebaseFirestore.instance
                    .collection('users_xp')
                    .where('username', isEqualTo: v)
                    .limit(1)
                    .get();

                if (dialogContext.mounted) {
                  setDialogState(() {
                    checking = false;
                    available = query.docs.isEmpty;
                    usernameError = query.docs.isEmpty ? null : 'Este ID já está em uso.';
                  });
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  setDialogState(() => checking = false);
                }
              }
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: AppColors.primaryOrange.withOpacity(0.3), width: 1),
            ),
            title: const Text(
              'Alterar ID de usuário',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu ID atual: @$_currentUsername',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Apenas letras minúsculas, números e _',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 16),

                // Campo de ID
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLength: 20,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_]')),
                    TextInputFormatter.withFunction((old, newVal) {
                      return newVal.copyWith(
                        text: newVal.text.toLowerCase(),
                        selection: newVal.selection,
                      );
                    }),
                  ],
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'ex: joao_silva123',
                    hintStyle:
                        const TextStyle(color: Colors.white24, fontSize: 14),
                    prefixIcon: const Icon(Icons.tag_rounded,
                        color: AppColors.primaryOrange, size: 20),
                    prefixText: '@',
                    prefixStyle: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    suffixIcon: checking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          )
                        : available
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50), size: 20)
                            : usernameError != null
                                ? const Icon(Icons.cancel_rounded,
                                    color: AppColors.emergencyRed, size: 20)
                                : null,
                    counterStyle:
                        const TextStyle(color: Colors.white24, fontSize: 10),
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: usernameError != null
                            ? AppColors.emergencyRed.withOpacity(0.5)
                            : available
                                ? const Color(0xFF4CAF50).withOpacity(0.5)
                                : const Color(0xFF2A2A2A),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: usernameError != null
                            ? AppColors.emergencyRed
                            : available
                                ? const Color(0xFF4CAF50)
                                : AppColors.primaryOrange,
                        width: 1.5,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                  ),
                ),

                // Feedback de disponibilidade
                if (ctrl.text.length >= 3)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: checking
                        ? Row(
                            key: const ValueKey('checking'),
                            children: [
                              SizedBox(
                                width: 11,
                                height: 11,
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
                                    fontSize: 11),
                              ),
                            ],
                          )
                        : available
                            ? const Row(
                                key: ValueKey('ok'),
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF4CAF50), size: 13),
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
                            : usernameError != null
                                ? Row(
                                    key: const ValueKey('err'),
                                    children: [
                                      const Icon(Icons.cancel_rounded,
                                          color: AppColors.emergencyRed,
                                          size: 13),
                                      const SizedBox(width: 6),
                                      Text(
                                        usernameError!,
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                      color: saving
                          ? Colors.white24
                          : AppColors.primaryOrange.withOpacity(0.8)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  disabledBackgroundColor:
                      AppColors.primaryOrange.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: saving || !available
                    ? null
                    : () async {
                        final newId =
                            ctrl.text.trim().toLowerCase();
                        if (newId.length < 3) return;
                        setDialogState(() => saving = true);

                        try {
                          // Atualiza no Firestore
                          await FirebaseFirestore.instance
                              .collection('users_xp')
                              .doc(user.uid)
                              .update({'username': newId});

                          // Atualiza displayName no Auth também
                          await user.updateDisplayName(newId);
                          await user.reload();

                          if (mounted) {
                            await Provider.of<UserXpProvider>(
                                    context,
                                    listen: false)
                                .reload();
                            setState(() => _currentUsername = newId);
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            _showSnack(
                              icon: Icons.check_circle_rounded,
                              message: 'ID alterado para @$newId com sucesso!',
                            );
                          }
                        } catch (_) {
                          setDialogState(() => saving = false);
                          if (mounted) {
                            _showSnack(
                              icon: Icons.error_outline_rounded,
                              message: 'Erro ao salvar. Tente novamente.',
                              isError: true,
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salvar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // ALTERAR NOME DE EXIBIÇÃO
  // ═══════════════════════════════════════════════════════════════
  Future<void> _showChangeDisplayNameDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    final ctrl = TextEditingController(text: user?.displayName ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: AppColors.primaryOrange.withOpacity(0.3), width: 1),
          ),
          title: const Text('Alterar nome de exibição',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Este nome aparecerá no seu perfil.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 30,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'O nome não pode ser vazio.';
                    if (v.trim().length < 3)
                      return 'Mínimo de 3 caracteres.';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Seu nome de exibição',
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterStyle: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppColors.primaryOrange.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppColors.primaryOrange.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primaryOrange),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.redAccent),
                    ),
                    errorStyle: const TextStyle(
                        color: Colors.redAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancelar',
                  style: TextStyle(
                      color: saving
                          ? Colors.white24
                          : AppColors.primaryOrange.withOpacity(0.8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                disabledBackgroundColor:
                    AppColors.primaryOrange.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await FirebaseAuth.instance.currentUser
                            ?.updateDisplayName(ctrl.text.trim());
                        await FirebaseAuth.instance.currentUser?.reload();

                        // Atualiza displayName no Firestore também
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance
                              .collection('users_xp')
                              .doc(uid)
                              .update(
                                  {'displayName': ctrl.text.trim()});
                        }

                        if (mounted) {
                          await Provider.of<UserXpProvider>(context,
                                  listen: false)
                              .reload();
                        }
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext);
                        if (mounted) {
                          _showSnack(
                              icon: Icons.check_circle_rounded,
                              message: 'Nome atualizado com sucesso!');
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          _showSnack(
                              icon: Icons.error_outline_rounded,
                              message: _authErrorMessage(e.code),
                              isError: true);
                        }
                      } catch (_) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          _showSnack(
                              icon: Icons.error_outline_rounded,
                              message: 'Erro inesperado. Tente novamente.',
                              isError: true);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Salvar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final ctrl = TextEditingController();
    bool sending = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: AppColors.primaryOrange.withOpacity(0.3), width: 1),
          ),
          title: const Text('Alterar senha',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Informe seu e-mail para receber o link de redefinição.',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Seu e-mail',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.primaryOrange.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.primaryOrange.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primaryOrange),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  sending ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancelar',
                  style: TextStyle(
                      color: sending
                          ? Colors.white24
                          : AppColors.primaryOrange.withOpacity(0.8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                disabledBackgroundColor:
                    AppColors.primaryOrange.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final email = ctrl.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => sending = true);
                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: email);
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext);
                        if (mounted) {
                          _showSnack(
                              icon: Icons.mark_email_read_rounded,
                              message: 'Link enviado para seu e-mail!');
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => sending = false);
                        if (mounted) {
                          _showSnack(
                              icon: Icons.error_outline_rounded,
                              message: _authErrorMessage(e.code),
                              isError: true);
                        }
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  void _showSnack(
      {required IconData icon,
      required String message,
      bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(icon,
                color: isError
                    ? Colors.redAccent
                    : AppColors.primaryOrange,
                size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'E-mail não encontrado.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'requires-recent-login':
        return 'Faça login novamente para continuar.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente mais tarde.';
      default:
        return 'Erro inesperado. Tente novamente.';
    }
  }

  String _autoplayLabelFor(String mode) {
    switch (mode) {
      case 'always':
        return 'Sempre';
      case 'never':
        return 'Nunca';
      default:
        return 'Apenas Wi-Fi';
    }
  }

  String? _currentDisplayName() {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name == null || name.isEmpty) return null;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                AppColors.primaryOrange.withOpacity(0.4),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [

          // ── CONTA ────────────────────────────────────────────────
          const _SectionHeader(label: 'CONTA'),

          // NOVO: Alterar ID
          _SettingsTile(
            icon: Icons.tag_rounded,
            label: 'Alterar ID de usuário',
            sublabel: _currentUsername.isNotEmpty
                ? '@$_currentUsername'
                : 'Nenhum ID definido',
            iconColor: AppColors.primaryOrange,
            onTap: _showChangeUsernameIdDialog,
          ),

          _SettingsTile(
            icon: Icons.badge_rounded,
            label: 'Alterar nome de exibição',
            sublabel: _currentDisplayName(),
            onTap: _showChangeDisplayNameDialog,
          ),
          _SettingsTile(
            icon: Icons.lock_rounded,
            label: 'Alterar senha',
            onTap: _showChangePasswordDialog,
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sair da conta',
            labelColor: Colors.redAccent,
            iconColor: Colors.redAccent,
            onTap: _logout,
          ),

          const SizedBox(height: 8),

          // ── NOTIFICAÇÕES ─────────────────────────────────────────
          const _SectionHeader(label: 'NOTIFICAÇÕES'),
          _SwitchTile(
            icon: Icons.notifications_active_rounded,
            label: 'Ativar notificações',
            sublabel: _notifGeral
                ? 'Você receberá alertas de notícias'
                : 'Notificações desativadas',
            value: _notifGeral,
            onChanged: _toggleNotifGeral,
          ),

          const SizedBox(height: 8),

          // ── APLICATIVO ───────────────────────────────────────────
          const _SectionHeader(label: 'APLICATIVO'),
          _SliderTile(
            icon: Icons.text_fields_rounded,
            label: 'Tamanho da fonte',
            value: _fontSize,
            min: 12,
            max: 22,
            valueLabel: '${_fontSize.round()}px',
            onChanged: (v) async {
              setState(() => _fontSize = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('fontSize', v);
            },
          ),
          _ExpandableTile(
            icon: Icons.play_circle_rounded,
            label: 'Reprodução automática de vídeos',
            sublabel: _autoplayLabelFor(_autoplayMode),
            child: Column(
              children: [
                _RadioOption(
                  label: 'Sempre',
                  groupValue: _autoplayMode,
                  value: 'always',
                  onChanged: (v) async {
                    setState(() => _autoplayMode = v!);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('autoplayMode', v!);
                  },
                ),
                _RadioOption(
                  label: 'Apenas Wi-Fi',
                  groupValue: _autoplayMode,
                  value: 'wifi',
                  onChanged: (v) async {
                    setState(() => _autoplayMode = v!);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('autoplayMode', v!);
                  },
                ),
                _RadioOption(
                  label: 'Nunca',
                  groupValue: _autoplayMode,
                  value: 'never',
                  onChanged: (v) async {
                    setState(() => _autoplayMode = v!);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('autoplayMode', v!);
                  },
                ),
              ],
            ),
          ),
          _SwitchTile(
            icon: Icons.data_saver_on_rounded,
            label: 'Economia de dados',
            sublabel: 'Reduz qualidade de imagens',
            value: _economiaDados,
            onChanged: (v) async {
              setState(() => _economiaDados = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('economiaDados', v);
            },
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Limpar cache',
            sublabel: 'Ocupando $_cacheSize',
            onTap: _clearCache,
          ),

          const SizedBox(height: 8),

          // ── PRIVACIDADE ──────────────────────────────────────────
          const _SectionHeader(label: 'PRIVACIDADE'),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            label: 'Política de Privacidade',
            trailing: const Icon(Icons.open_in_new_rounded,
                color: Colors.white38, size: 15),
            onTap: () => _launch(
                'https://horizontenews.com.br/politica-de-privacidade'),
          ),
          _SettingsTile(
            icon: Icons.gavel_rounded,
            label: 'Termos de Uso',
            trailing: const Icon(Icons.open_in_new_rounded,
                color: Colors.white38, size: 15),
            onTap: () =>
                _launch('https://horizontenews.com.br/termos-de-uso'),
          ),

          const SizedBox(height: 8),

          // ── SOBRE ────────────────────────────────────────────────
          const _SectionHeader(label: 'SOBRE'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Versão do aplicativo',
            sublabel: '1.0.0 • Horizonte News',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.groups_rounded,
            label: 'Equipe Horizonte News',
            onTap: () =>
                _launch('https://horizontenews.com.br/equipe'),
          ),
          _SettingsTile(
            icon: Icons.alternate_email_rounded,
            label: 'Contato oficial',
            sublabel: 'diego.magno321@gmail.com',
            onTap: () =>
                _launch('mailto:diego.magno321@gmail.com'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DIALOG DE CONFIRMAÇÃO
// ═══════════════════════════════════════════════════════════════════
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color? confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: AppColors.primaryOrange.withOpacity(0.3), width: 1),
      ),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
      content:
          Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancelar',
              style: TextStyle(
                  color: AppColors.primaryOrange.withOpacity(0.8))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppColors.primaryOrange,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CABEÇALHO DE SEÇÃO
// ═══════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.primaryOrange.withOpacity(0.4),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE PADRÃO
// ═══════════════════════════════════════════════════════════════════
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.sublabel,
    this.labelColor,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primaryOrange.withOpacity(0.06),
      highlightColor: AppColors.primaryOrange.withOpacity(0.04),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: (iconColor ?? AppColors.primaryOrange)
                    .withOpacity(0.10),
              ),
              child: Icon(icon,
                  size: 18,
                  color: iconColor ?? AppColors.primaryOrange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: labelColor ?? Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE COM SWITCH
// ═══════════════════════════════════════════════════════════════════
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: AppColors.primaryOrange.withOpacity(0.10),
              ),
              child: Icon(icon,
                  size: 18, color: AppColors.primaryOrange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primaryOrange,
              activeTrackColor:
                  AppColors.primaryOrange.withOpacity(0.30),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE COM SLIDER
// ═══════════════════════════════════════════════════════════════════
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: AppColors.primaryOrange.withOpacity(0.10),
                ),
                child: Icon(icon,
                    size: 18, color: AppColors.primaryOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
              Text(valueLabel,
                  style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryOrange,
              inactiveTrackColor:
                  AppColors.primaryOrange.withOpacity(0.15),
              thumbColor: AppColors.primaryOrange,
              overlayColor:
                  AppColors.primaryOrange.withOpacity(0.12),
              trackHeight: 2.5,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE EXPANSÍVEL
// ═══════════════════════════════════════════════════════════════════
class _ExpandableTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Widget child;

  const _ExpandableTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.child,
  });

  @override
  State<_ExpandableTile> createState() => _ExpandableTileState();
}

class _ExpandableTileState extends State<_ExpandableTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          splashColor: AppColors.primaryOrange.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: AppColors.primaryOrange.withOpacity(0.10),
                  ),
                  child: Icon(widget.icon,
                      size: 18, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(widget.sublabel,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38,
                      size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withOpacity(0.03),
              border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.12),
                  width: 1),
            ),
            child: widget.child,
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// OPÇÃO DE RADIO
// ═══════════════════════════════════════════════════════════════════
class _RadioOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected
                        ? AppColors.primaryOrange
                        : Colors.white30,
                    width: 2),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryOrange),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color:
                        selected ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
