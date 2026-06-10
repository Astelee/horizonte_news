import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // ── ESTADO LOCAL ─────────────────────────────────────────────────
  double _fontSize     = 15.0;
  bool _notifBreaking  = true;
  bool _notifHorizonte = true;
  bool _notifPolicia   = false;
  bool _notifEsportes  = false;
  bool _notifGeral     = false; // começa false; initState verifica
  bool _economiaDados  = false;
  String _autoplayMode = 'wifi';

  @override
  void initState() {
    super.initState();
    // Verifica no Firestore se as notificações já estão ativas
    NotificationService.isEnabled().then((enabled) {
      if (mounted) setState(() => _notifGeral = enabled);
    });
  }

  // ── TOGGLE NOTIFICAÇÕES ──────────────────────────────────────────
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

  // ── URL LAUNCHER ─────────────────────────────────────────────────
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── LOGOUT ───────────────────────────────────────────────────────
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

  // ── ALTERAR NOME DE USUÁRIO ───────────────────────────────────────
  Future<void> _showChangeUsernameDialog() async {
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
          title: const Text('Alterar nome',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Este nome aparecerá no seu perfil e no menu.',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 30,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'O nome não pode ser vazio.';
                    if (v.trim().length < 3) return 'Mínimo de 3 caracteres.';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Seu nome de usuário',
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterStyle:
                        const TextStyle(color: Colors.white38, fontSize: 11),
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
                      borderSide:
                          const BorderSide(color: AppColors.primaryOrange),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    errorStyle:
                        const TextStyle(color: Colors.redAccent, fontSize: 11),
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
                        if (mounted) {
                          await Provider.of<UserXpProvider>(context,
                                  listen: false)
                              .reload();
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                          color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  // ── ALTERAR SENHA ────────────────────────────────────────────────
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
                    borderSide:
                        const BorderSide(color: AppColors.primaryOrange),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
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
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                          color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  // ── HELPERS ──────────────────────────────────────────────────────
  void _showSnack({
    required IconData icon,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(icon,
                color: isError ? Colors.redAccent : AppColors.primaryOrange,
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

  void _showCacheClearedSnack() {
    _showSnack(
        icon: Icons.check_circle_rounded, message: 'Cache limpo com sucesso!');
  }

  String? _currentDisplayName() {
    final name = FirebaseAuth.instance.currentUser?.displayName;
    if (name == null || name.isEmpty) return null;
    return name;
  }

  // ── BUILD ────────────────────────────────────────────────────────
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

          // ── CONTA ─────────────────────────────────────────────────
          const _SectionHeader(label: 'CONTA'),
          _SettingsTile(
            icon: Icons.badge_rounded,
            label: 'Alterar nome de usuário',
            sublabel: _currentDisplayName(),
            onTap: _showChangeUsernameDialog,
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

          // ── NOTIFICAÇÕES ──────────────────────────────────────────
          const _SectionHeader(label: 'NOTIFICAÇÕES'),
          _SwitchTile(
            icon: Icons.notifications_active_rounded,
            label: 'Ativar notificações',
            value: _notifGeral,
            onChanged: _toggleNotifGeral, // ← agora funcional
          ),
          _SwitchTile(
            icon: Icons.flash_on_rounded,
            label: 'Notícias de última hora',
            value: _notifBreaking,
            onChanged: _notifGeral
                ? (v) => setState(() => _notifBreaking = v)
                : null,
          ),
          _SwitchTile(
            icon: Icons.location_city_rounded,
            label: 'Notícias de Horizonte',
            value: _notifHorizonte,
            onChanged: _notifGeral
                ? (v) => setState(() => _notifHorizonte = v)
                : null,
          ),
          _SwitchTile(
            icon: Icons.local_police_rounded,
            label: 'Notícias policiais',
            value: _notifPolicia,
            onChanged: _notifGeral
                ? (v) => setState(() => _notifPolicia = v)
                : null,
          ),
          _SwitchTile(
            icon: Icons.sports_soccer_rounded,
            label: 'Notícias esportivas',
            value: _notifEsportes,
            onChanged: _notifGeral
                ? (v) => setState(() => _notifEsportes = v)
                : null,
          ),

          const SizedBox(height: 8),

          // ── APLICATIVO ────────────────────────────────────────────
          const _SectionHeader(label: 'APLICATIVO'),
          _SliderTile(
            icon: Icons.text_fields_rounded,
            label: 'Tamanho da fonte',
            value: _fontSize,
            min: 12,
            max: 22,
            valueLabel: '${_fontSize.round()}px',
            onChanged: (v) => setState(() => _fontSize = v),
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
                  onChanged: (v) => setState(() => _autoplayMode = v!),
                ),
                _RadioOption(
                  label: 'Apenas Wi-Fi',
                  groupValue: _autoplayMode,
                  value: 'wifi',
                  onChanged: (v) => setState(() => _autoplayMode = v!),
                ),
                _RadioOption(
                  label: 'Nunca',
                  groupValue: _autoplayMode,
                  value: 'never',
                  onChanged: (v) => setState(() => _autoplayMode = v!),
                ),
              ],
            ),
          ),
          _SwitchTile(
            icon: Icons.data_saver_on_rounded,
            label: 'Economia de dados',
            sublabel: 'Reduz qualidade de imagens',
            value: _economiaDados,
            onChanged: (v) => setState(() => _economiaDados = v),
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Limpar cache',
            sublabel: 'Libera espaço de armazenamento',
            onTap: _showCacheClearedSnack,
          ),

          const SizedBox(height: 8),

          // ── PRIVACIDADE ───────────────────────────────────────────
          const _SectionHeader(label: 'PRIVACIDADE'),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            label: 'Política de Privacidade',
            trailing: const Icon(Icons.open_in_new_rounded,
                color: Colors.white38, size: 15),
            onTap: () =>
                _launch('https://horizontenews.com.br/politica-de-privacidade'),
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

          // ── SOBRE ─────────────────────────────────────────────────
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
            onTap: () => _launch('https://horizontenews.com.br/equipe'),
          ),
          _SettingsTile(
            icon: Icons.alternate_email_rounded,
            label: 'Contato oficial',
            sublabel: 'diego.magno321@gmail.com',
            onTap: () => _launch('mailto:contato@horizontenews.com.br'),
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
      content: Text(message,
          style: const TextStyle(color: Colors.white70)),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: (iconColor ?? AppColors.primaryOrange).withOpacity(0.10),
              ),
              child: Icon(icon,
                  size: 18, color: iconColor ?? AppColors.primaryOrange),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              activeTrackColor: AppColors.primaryOrange.withOpacity(0.30),
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
                child: Icon(icon, size: 18, color: AppColors.primaryOrange),
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
              inactiveTrackColor: AppColors.primaryOrange.withOpacity(0.15),
              thumbColor: AppColors.primaryOrange,
              overlayColor: AppColors.primaryOrange.withOpacity(0.12),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38, size: 20),
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
                  color: AppColors.primaryOrange.withOpacity(0.12), width: 1),
            ),
            child: widget.child,
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        selected ? AppColors.primaryOrange : Colors.white30,
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
