import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── ESTADO LOCAL DAS CONFIGURAÇÕES ──────────────────────────────
  double _fontSize      = 15.0;
  bool _notifBreaking   = true;
  bool _notifHorizonte  = true;
  bool _notifPolicia    = false;
  bool _notifEsportes   = false;
  bool _notifGeral      = true;
  bool _economiaDados   = false;
  String _autoplayMode  = 'wifi'; // 'always' | 'wifi' | 'never'

  // ── LANÇADOR DE URL ─────────────────────────────────────────────
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── LOGOUT ──────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: AppColors.primaryOrange.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Sair da conta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Tem certeza que deseja sair?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                  color: AppColors.primaryOrange.withOpacity(0.8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sair',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
      }
    }
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
            letterSpacing: 0.4,
          ),
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
            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
          _SettingsTile(
            icon: Icons.lock_rounded,
            label: 'Alterar senha',
            onTap: () => _showChangePasswordDialog(context),
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
            onChanged: (v) => setState(() => _notifGeral = v),
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

          // ── SOBRE ─────────────────────────────────────────────────
          const _SectionHeader(label: 'SOBRE'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Versão do aplicativo',
            sublabel: '1.0.0 • Horizonte News 2026',
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
            sublabel: 'contato@horizontenews.com.br',
            onTap: () =>
                _launch('mailto:contato@horizontenews.com.br'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 10),
            const Text('Cache limpo com sucesso!',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: AppColors.primaryOrange.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Alterar senha',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe seu e-mail para receber o link de redefinição.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Seu e-mail',
                hintStyle:
                    const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.primaryOrange.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                  color: AppColors.primaryOrange.withOpacity(0.8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1A1A1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        content: Row(
                          children: [
                            Icon(Icons.mark_email_read_rounded,
                                color: AppColors.primaryOrange,
                                size: 18),
                            const SizedBox(width: 10),
                            const Text(
                              'Link enviado para seu e-mail!',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1A1A1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 10),
                            const Text(
                              'E-mail não encontrado.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Enviar',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryOrange,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
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
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.primaryOrange,
              ),
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
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7),
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
                    color:
                        AppColors.primaryOrange.withOpacity(0.10),
                  ),
                  child: Icon(widget.icon,
                      size: 18, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.sublabel,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
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
                width: 1,
              ),
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
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
