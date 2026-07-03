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
  double _fontSize      = 15.0;
  bool   _notifGeral    = false;
  bool   _economiaDados = false;
  String _autoplayMode  = 'wifi';
  String _cacheSize     = '...';
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _calcCacheSize();
    _loadCurrentUsername();
    _checkNotifStatus();
  }

  // ── Verifica status via OneSignal ─────────────────────────────
  Future<void> _checkNotifStatus() async {
    try {
      final ativo = await NotificationService.notificacoesAtivas();
      if (mounted) setState(() => _notifGeral = ativo);
    } catch (_) {
      if (mounted) setState(() => _notifGeral = false);
    }
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
            _cacheSize =
                '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
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
          try {
            f.deleteSync(recursive: true);
          } catch (_) {}
        });
      }
      await _calcCacheSize();
      if (mounted) {
        _showSnack(
            icon: Icons.check_circle_rounded,
            message: 'Cache limpo com sucesso!');
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
            icon: Icons.error_outline_rounded,
            message: 'Erro ao limpar cache.',
            isError: true);
      }
    }
  }

  // ── Ativa/desativa notificações via OneSignal ─────────────────
  Future<void> _toggleNotifGeral(bool v) async {
    if (v) {
      final jaFoiPedido =
          await NotificationService.jaFoiPedidoPermissao();

      if (!jaFoiPedido) {
        // Mostra dialog bonito antes de pedir ao sistema
        if (!mounted) return;
        final aceito = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.85),
          builder: (_) => _DialogPermissaoNotificacao(),
        );
        if (aceito == true) {
          await NotificationService.pedirPermissao();
        } else {
          await NotificationService.marcarPermissaoJaPedida();
          return;
        }
      } else {
        // Já foi pedido antes — ativa diretamente via OneSignal
        await NotificationService.setNotificacoesAtivas(true);
      }

      if (mounted) setState(() => _notifGeral = true);
    } else {
      // Desativa via OneSignal
      await NotificationService.setNotificacoesAtivas(false);
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
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ALTERAR USERNAME
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
                    usernameError = query.docs.isEmpty
                        ? null
                        : 'Este ID já está em uso.';
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
            backgroundColor: const Color(0xFF0A0A0A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Alterar nome de usuário',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Será exibido em comentários, perfil e conversas.',
                  style: TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: onChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9_]')),
                    TextInputFormatter.withFunction((old, newVal) {
                      return newVal.copyWith(
                          text: newVal.text.toLowerCase());
                    }),
                  ],
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    prefixText: '@  ',
                    prefixStyle: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                    hintText: 'novo_usuario',
                    hintStyle: const TextStyle(
                        color: Color(0xFF424242), fontSize: 15),
                    filled: true,
                    fillColor: const Color(0xFF111111),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF1E1E1E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: usernameError != null
                            ? AppColors.emergencyRed.withOpacity(0.5)
                            : available
                                ? const Color(0xFF2E7D32)
                                    .withOpacity(0.6)
                                : const Color(0xFF1E1E1E),
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
                    suffixIcon: checking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
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
                                    color: AppColors.emergencyRed,
                                    size: 20)
                                : null,
                  ),
                ),
                if (usernameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      usernameError!,
                      style: const TextStyle(
                          color: AppColors.emergencyRed, fontSize: 11),
                    ),
                  ),
                if (available)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 13),
                        SizedBox(width: 5),
                        Text(
                          'Nome disponível!',
                          style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFF666666))),
              ),
              TextButton(
                onPressed: (!available || saving)
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        final newUsername =
                            ctrl.text.trim().toLowerCase();
                        try {
                          await FirebaseFirestore.instance
                              .collection('users_xp')
                              .doc(user.uid)
                              .update({'username': newUsername});
                          await user.updateDisplayName(newUsername);
                          if (mounted) {
                            setState(
                                () => _currentUsername = newUsername);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            _showSnack(
                              icon: Icons.check_circle_rounded,
                              message: 'Nome alterado com sucesso!',
                            );
                          }
                        } catch (_) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
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
                          strokeWidth: 2,
                          color: AppColors.primaryOrange,
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnack({
    required IconData icon,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        content: Row(
          children: [
            Icon(icon,
                color: isError
                    ? AppColors.emergencyRed
                    : AppColors.primaryOrange,
                size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.primaryOrange.withOpacity(0.15),
          ),
        ),
      ),
      body: ListView(
        children: [
          // ── CONTA ────────────────────────────────────────────
          _SectionHeader(label: 'CONTA'),
          _SettingsTile(
            icon: Icons.badge_outlined,
            label: 'Nome de usuário',
            sublabel: _currentUsername.isNotEmpty
                ? '@$_currentUsername'
                : 'Não definido',
            onTap: _showChangeUsernameIdDialog,
          ),
          const _Divider(),

          // ── NOTIFICAÇÕES ─────────────────────────────────────
          _SectionHeader(label: 'NOTIFICAÇÕES'),
          _SwitchTile(
            icon: Icons.notifications_outlined,
            label: 'Notificações de notícias',
            sublabel: 'Receba alertas quando houver novidades',
            value: _notifGeral,
            onChanged: _toggleNotifGeral,
          ),
          const _Divider(),

          // ── LEITURA ──────────────────────────────────────────
          _SectionHeader(label: 'LEITURA'),
          _SliderTile(
            icon: Icons.text_fields_rounded,
            label: 'Tamanho da fonte',
            valueLabel: '${_fontSize.round()}px',
            value: _fontSize,
            min: 12,
            max: 22,
            onChanged: (v) async {
              setState(() => _fontSize = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('fontSize', v);
            },
          ),
          const _Divider(),

          // ── DADOS E ARMAZENAMENTO ────────────────────────────
          _SectionHeader(label: 'DADOS E ARMAZENAMENTO'),
          _SwitchTile(
            icon: Icons.data_saver_on_outlined,
            label: 'Economia de dados',
            sublabel: 'Reduz qualidade de imagens',
            value: _economiaDados,
            onChanged: (v) async {
              setState(() => _economiaDados = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('economiaDados', v);
            },
          ),
          _ExpandableTile(
            icon: Icons.play_circle_outline_rounded,
            label: 'Reprodução automática',
            sublabel: _autoplayMode == 'always'
                ? 'Sempre'
                : _autoplayMode == 'wifi'
                    ? 'Somente Wi-Fi'
                    : 'Nunca',
            child: Column(
              children: [
                _RadioOption(
                  label: 'Sempre',
                  value: 'always',
                  groupValue: _autoplayMode,
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _autoplayMode = v);
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setString('autoplayMode', v);
                  },
                ),
                _RadioOption(
                  label: 'Somente Wi-Fi',
                  value: 'wifi',
                  groupValue: _autoplayMode,
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _autoplayMode = v);
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setString('autoplayMode', v);
                  },
                ),
                _RadioOption(
                  label: 'Nunca',
                  value: 'never',
                  groupValue: _autoplayMode,
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _autoplayMode = v);
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setString('autoplayMode', v);
                  },
                ),
              ],
            ),
          ),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            label: 'Limpar cache',
            sublabel: _cacheSize,
            onTap: _clearCache,
            trailingWidget: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primaryOrange.withOpacity(0.12),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3)),
              ),
              child: Text(
                _cacheSize,
                style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const _Divider(),

          // ── SOBRE ────────────────────────────────────────────
          _SectionHeader(label: 'SOBRE'),
          _SettingsTile(
            icon: Icons.language_outlined,
            label: 'Site oficial',
            sublabel: 'horizontenews.com.br',
            onTap: () => _launch('https://horizontenews.com.br'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Política de privacidade',
            onTap: () => _launch(
                'https://horizontenews.com.br/politica-de-privacidade'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Termos de uso',
            onTap: () =>
                _launch('https://horizontenews.com.br/termos-de-uso'),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Versão do app',
            sublabel: '1.0.0',
            onTap: () {},
          ),
          const _Divider(),

          // ── SESSÃO ───────────────────────────────────────────
          _SectionHeader(label: 'SESSÃO'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sair da conta',
            labelColor: AppColors.emergencyRed,
            onTap: _logout,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DIALOG DE PERMISSÃO (igual ao login_screen)
// ═══════════════════════════════════════════════════════════════════
class _DialogPermissaoNotificacao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF080808),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFFFF6B00).withOpacity(0.4),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.15),
              blurRadius: 48,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
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
                    color: const Color(0xFFFF6B00).withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_rounded,
                  size: 38, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Fique por dentro!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ative as notificações para receber as últimas notícias de Horizonte e região assim que forem publicadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF6B00))),
                const SizedBox(width: 6),
                const Text(
                  'Sem spam. Só o que importa.',
                  style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                width: double.infinity,
                height: 52,
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
                      color: const Color(0xFFFF6B00).withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Ativar notificações',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                  color: const Color(0xFF111111),
                ),
                child: const Center(
                  child: Text(
                    'Agora não',
                    style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primaryOrange.withOpacity(0.8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFF1A1A1A),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final Color? labelColor;
  final Widget? trailingWidget;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.onTap,
    this.labelColor,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primaryOrange.withOpacity(0.06),
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
                color: (labelColor ?? AppColors.primaryOrange)
                    .withOpacity(0.10),
              ),
              child: Icon(icon,
                  size: 18,
                  color: labelColor ?? AppColors.primaryOrange),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor ?? Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            trailingWidget ??
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(icon, size: 18, color: AppColors.primaryOrange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
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
            activeTrackColor: AppColors.primaryOrange.withOpacity(0.3),
            inactiveThumbColor: const Color(0xFF555555),
            inactiveTrackColor: const Color(0xFF2A2A2A),
          ),
        ],
      ),
    );
  }
}

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
                    color: selected ? Colors.white : Colors.white60,
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

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800)),
      content: Text(message,
          style: const TextStyle(
              color: Color(0xFF9E9E9E), height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF666666))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  color: confirmColor, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
