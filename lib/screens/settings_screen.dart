import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _dataSaver = false;
  String _autoplay = 'wifi';
  double _cacheSize = 0;
  bool _loadingCache = true;
  bool _loadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkNotificationStatus();
    _calcCache();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dataSaver = prefs.getBool('data_saver') ?? false;
      _autoplay = prefs.getString('autoplay') ?? 'wifi';
    });
  }

  // ── Verifica o status real da permissão de notificação ────────────
  Future<void> _checkNotificationStatus() async {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (mounted) {
      setState(() {
        _notificationsEnabled = granted;
        _loadingNotifications = false;
      });
    }
  }

  // ── Solicita permissão ou abre configurações do sistema ───────────
  Future<void> _toggleNotifications(bool value) async {
    HapticFeedback.lightImpact();

    if (value) {
      // Tenta pedir permissão
      final settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (mounted) setState(() => _notificationsEnabled = granted);

      if (!granted && mounted) {
        _showSnack(
          'Permissão negada. Ative nas configurações do celular.',
          icon: Icons.notifications_off_rounded,
        );
      } else if (granted && mounted) {
        _showSnack(
          'Notificações ativadas com sucesso!',
          icon: Icons.notifications_active_rounded,
          success: true,
        );
      }
    } else {
      // Não tem como desativar programaticamente no Android —
      // direciona para as configurações do sistema
      setState(() => _notificationsEnabled = false);
      _showSnack(
        'Para desativar, vá em Configurações do celular → Aplicativos → Horizonte News.',
        icon: Icons.settings_rounded,
      );
    }
  }

  Future<void> _calcCache() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _cacheSize = 6.9;
        _loadingCache = false;
      });
    }
  }

  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_posts');
    setState(() => _cacheSize = 0);
    if (mounted) {
      _showSnack('Cache limpo com sucesso!',
          icon: Icons.check_circle_rounded, success: true);
    }
  }

  Future<void> _setDataSaver(bool value) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_saver', value);
    setState(() => _dataSaver = value);
  }

  Future<void> _setAutoplay(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('autoplay', value);
    setState(() => _autoplay = value);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: AppColors.emergencyRed.withOpacity(0.3)),
        ),
        title: const Text('Sair da conta?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Seu progresso e XP estão salvos.',
          style: TextStyle(color: Color(0xFF9E9E9E), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  void _showSnack(String msg,
      {IconData? icon, bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: success
                      ? const Color(0xFF4CAF50)
                      : AppColors.primaryOrange,
                  size: 16),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF111111)),
        ),
      ),
      body: ListView(
        children: [
          // ── CONTA ─────────────────────────────────────────────────
          _SectionHeader(label: 'CONTA'),
          _SettingsTile(
            icon: Icons.badge_outlined,
            label: 'Nome de usuário',
            subtitle: _getUsernameSubtitle(),
            onTap: _editUsername,
          ),
          _Divider(),

          // ── NOTIFICAÇÕES ──────────────────────────────────────────
          _SectionHeader(label: 'NOTIFICAÇÕES'),
          _loadingNotifications
              ? _LoadingTile(label: 'Notificações de notícias')
              : _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notificações de notícias',
                  subtitle: 'Receba alertas quando houver novidades',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeColor: AppColors.primaryOrange,
                    activeTrackColor:
                        AppColors.primaryOrange.withOpacity(0.3),
                    inactiveThumbColor: const Color(0xFF555555),
                    inactiveTrackColor: const Color(0xFF222222),
                  ),
                ),
          _Divider(),

          // ── DADOS E ARMAZENAMENTO ─────────────────────────────────
          _SectionHeader(label: 'DADOS E ARMAZENAMENTO'),
          _SettingsTile(
            icon: Icons.data_saver_on_outlined,
            label: 'Economia de dados',
            subtitle: 'Reduz qualidade de imagens',
            trailing: Switch(
              value: _dataSaver,
              onChanged: _setDataSaver,
              activeColor: AppColors.primaryOrange,
              activeTrackColor:
                  AppColors.primaryOrange.withOpacity(0.3),
              inactiveThumbColor: const Color(0xFF555555),
              inactiveTrackColor: const Color(0xFF222222),
            ),
          ),
          _SettingsTile(
            icon: Icons.play_circle_outline_rounded,
            label: 'Reprodução automática',
            subtitle: _autoplayLabel(_autoplay),
            onTap: _showAutoplaySheet,
            trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF555555), size: 20),
          ),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            label: 'Limpar cache',
            subtitle: _loadingCache
                ? 'Calculando...'
                : '${_cacheSize.toStringAsFixed(1)} MB',
            onTap: _cacheSize > 0 ? _clearCache : null,
            trailing: _loadingCache
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryOrange),
                  )
                : _cacheSize > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color:
                              AppColors.primaryOrange.withOpacity(0.15),
                          border: Border.all(
                              color: AppColors.primaryOrange
                                  .withOpacity(0.4)),
                        ),
                        child: Text(
                          '${_cacheSize.toStringAsFixed(1)} MB',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_rounded,
                        color: Color(0xFF4CAF50), size: 18),
          ),
          _Divider(),

          // ── SOBRE ─────────────────────────────────────────────────
          _SectionHeader(label: 'SOBRE'),
          _SettingsTile(
            icon: Icons.shield_outlined,
            label: 'Política de privacidade',
            onTap: () => _openUrl(
                'https://horizontenews.com.br/politica-de-privacidade'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Termos de uso',
            onTap: () => _openUrl(
                'https://horizontenews.com.br/termos-de-uso'),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Versão do app',
            subtitle: '1.0.0',
            showArrow: false,
          ),
          _Divider(),

          // ── SESSÃO ────────────────────────────────────────────────
          _SectionHeader(label: 'SESSÃO'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sair da conta',
            labelColor: AppColors.emergencyRed,
            iconColor: AppColors.emergencyRed,
            onTap: _handleLogout,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _getUsernameSubtitle() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '@usuário';
    final name = user.displayName ?? user.email?.split('@').first ?? 'usuário';
    return '@${name.toLowerCase().replaceAll(' ', '')}';
  }

  void _editUsername() {
    final controller = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EDITAR NOME',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Seu nome',
                  hintStyle:
                      const TextStyle(color: Color(0xFF424242)),
                  filled: true,
                  fillColor: const Color(0xFF141414),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF212121)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryOrange, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF212121)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;
                  await FirebaseAuth.instance.currentUser
                      ?.updateDisplayName(newName);
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    _showSnack('Nome atualizado!',
                        icon: Icons.check_circle_rounded,
                        success: true);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFBF360C),
                        Color(0xFFE65100),
                        Color(0xFFF57C00)
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'SALVAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
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
  }

  void _showAutoplaySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REPRODUÇÃO AUTOMÁTICA',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            _AutoplayOption(
              label: 'Sempre',
              subtitle: 'Usa dados móveis e Wi-Fi',
              value: 'always',
              current: _autoplay,
              onTap: () {
                _setAutoplay('always');
                Navigator.pop(context);
              },
            ),
            _AutoplayOption(
              label: 'Somente Wi-Fi',
              subtitle: 'Não usa dados móveis',
              value: 'wifi',
              current: _autoplay,
              onTap: () {
                _setAutoplay('wifi');
                Navigator.pop(context);
              },
            ),
            _AutoplayOption(
              label: 'Nunca',
              subtitle: 'Vídeos não reproduzem automaticamente',
              value: 'never',
              current: _autoplay,
              onTap: () {
                _setAutoplay('never');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _autoplayLabel(String value) {
    switch (value) {
      case 'always':
        return 'Sempre';
      case 'never':
        return 'Nunca';
      default:
        return 'Somente Wi-Fi';
    }
  }

  void _openUrl(String url) async {
    _showSnack('Abrindo navegador...',
        icon: Icons.open_in_browser_rounded);
  }
}

// ═══════════════════════════════════════════════════════════════════
// COMPONENTES INTERNOS
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
        style: const TextStyle(
          color: AppColors.primaryOrange,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? iconColor;
  final bool showArrow;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.labelColor,
    this.iconColor,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primaryOrange.withOpacity(0.05),
      highlightColor: AppColors.primaryOrange.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: (iconColor ?? AppColors.primaryOrange)
                    .withOpacity(0.12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primaryOrange,
                size: 19,
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showArrow && onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF444444), size: 20),
          ],
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  final String label;
  const _LoadingTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.primaryOrange.withOpacity(0.12),
            ),
            child: const Icon(Icons.notifications_outlined,
                color: AppColors.primaryOrange, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryOrange),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 1,
        margin: const EdgeInsets.only(left: 72),
        color: const Color(0xFF111111));
  }
}

class _AutoplayOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final String current;
  final VoidCallback onTap;

  const _AutoplayOption({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.primaryOrange.withOpacity(0.1)
              : const Color(0xFF111111),
          border: Border.all(
            color: selected
                ? AppColors.primaryOrange.withOpacity(0.5)
                : const Color(0xFF1E1E1E),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primaryOrange
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primaryOrange, size: 20),
          ],
        ),
      ),
    );
  }
}
