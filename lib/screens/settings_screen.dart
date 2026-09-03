import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
  String? _currentUsername;

  // Link oficial da Política de Privacidade
  static const String _privacyPolicyUrl =
      'https://astelee.github.io/horizonte-news-privacy/';

  // Link oficial dos Termos de Uso
  static const String _termsOfUseUrl =
      'https://astelee.github.io/horizonte_termos/';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkNotificationStatus();
    _calcCache();
    _loadCurrentUsername();
  }

  Future<void> _loadCurrentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users_xp')
          .doc(user.uid)
          .get();

      final username = doc.data()?['username'] as String?;

      if (mounted) {
        setState(() => _currentUsername = username);
      }
    } catch (_) {
      // Silencioso: mantém o placeholder se falhar.
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _dataSaver = prefs.getBool('data_saver') ?? false;
      _autoplay = prefs.getString('autoplay') ?? 'wifi';
    });
  }

  Future<void> _checkNotificationStatus() async {
    final enabled =
        await NotificationService.areNotificationsEnabled();

    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
        _loadingNotifications = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    HapticFeedback.lightImpact();

    if (value) {
      final granted =
          await NotificationService.requestPermission();

      if (mounted) {
        setState(() => _notificationsEnabled = granted);
      }

      if (!granted && mounted) {
        _showSnack(
          'Permissão negada. Ative nas configurações do celular.',
          icon: Icons.notifications_off_rounded,
        );
      } else if (granted && mounted) {
        _showSnack(
          'Notificações ativadas!',
          icon: Icons.notifications_active_rounded,
          success: true,
        );
      }
    } else {
      if (mounted) {
        setState(() => _notificationsEnabled = false);

        _showSnack(
          'Para desativar, vá em Configurações do celular → Aplicativos → Horizonte News.',
          icon: Icons.settings_rounded,
        );
      }
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

    if (mounted) {
      setState(() => _cacheSize = 0);

      _showSnack(
        'Cache limpo com sucesso!',
        icon: Icons.check_circle_rounded,
        success: true,
      );
    }
  }

  Future<void> _setDataSaver(bool value) async {
    HapticFeedback.lightImpact();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_saver', value);

    if (mounted) {
      setState(() => _dataSaver = value);
    }
  }

  Future<void> _setAutoplay(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('autoplay', value);

    if (mounted) {
      setState(() => _autoplay = value);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.emergencyRed.withOpacity(0.3),
          ),
        ),
        title: const Text(
          'Sair da conta?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Seu progresso e XP estão salvos.',
          style: TextStyle(
            color: Color(0xFF9E9E9E),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sair',
              style: TextStyle(
                color: AppColors.emergencyRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.instance.signOut();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
      }
    }
  }

  // ================================================================
  // EXCLUSÃO COMPLETA DA CONTA
  // ================================================================

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.emergencyRed.withOpacity(0.3),
          ),
        ),
        title: const Text(
          'Excluir conta permanentemente?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Todos os seus dados serão apagados:\n\n'
          '• Perfil e nome de usuário\n'
          '• Nível e pontos de XP\n'
          '• Favoritos salvos\n'
          '• Comentários\n'
          '• Histórico de visualizações\n\n'
          'Essa ação não pode ser desfeita.',
          style: TextStyle(
            color: Color(0xFF9E9E9E),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'EXCLUIR',
              style: TextStyle(
                color: AppColors.emergencyRed,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      // 1. Subcoleções do usuário
      await _deleteSubcollection(
        db,
        'users/$uid/favorites',
      );

      await _deleteSubcollection(
        db,
        'users/$uid/notifications',
      );

      await _deleteSubcollection(
        db,
        'users/$uid/friends',
      );

      await _deleteSubcollection(
        db,
        'users/$uid/friend_requests',
      );

      await _deleteSubcollection(
        db,
        'users/$uid/conversations',
      );

      // 2. Documento principal
      await db.collection('users').doc(uid).delete();

      // 3. XP
      await db.collection('users_xp').doc(uid).delete();

      // 4. Admin
      await db.collection('admins').doc(uid).delete();

      // 5. Username
      await db.collection('usernames').doc(uid).delete();

      // 6. Remove visualizações
      final postViews =
          await db.collection('post_views').get();

      for (final postDoc in postViews.docs) {
        await postDoc.reference
            .collection('viewers')
            .doc(uid)
            .delete();
      }

      // 7. Remove comentários
      final comments = await db
          .collectionGroup('comments')
          .where('userId', isEqualTo: uid)
          .get();

      for (final commentDoc in comments.docs) {
        await commentDoc.reference.delete();
      }

      // 8. Remove logs
      final adminLogs = await db
          .collection('admin_logs')
          .where('targetUid', isEqualTo: uid)
          .get();

      for (final log in adminLogs.docs) {
        await log.reference.delete();
      }

      // 9. Remove banimento
      await db
          .collection('banned_users')
          .doc(uid)
          .delete();

      // 10. Remove presença
      await db
          .collection('presence')
          .doc(uid)
          .delete();

      // 11. Exclui Firebase Auth
      await user.delete();

      if (mounted) {
        Navigator.of(context).pop();

        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (e.code == 'requires-recent-login') {
        if (mounted) {
          _showSnack(
            'Por segurança, saia e entre novamente antes de excluir sua conta.',
            icon: Icons.warning_amber_rounded,
          );
        }
      } else {
        if (mounted) {
          _showSnack(
            'Erro: ${e.message}',
            icon: Icons.error_outline_rounded,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();

        _showSnack(
          'Erro inesperado. Tente novamente.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  // ================================================================
  // HELPER PARA SUBCOLEÇÕES
  // ================================================================

  Future<void> _deleteSubcollection(
    FirebaseFirestore db,
    String path,
  ) async {
    try {
      final parts = path.split('/');

      final snap = await db
          .doc(
            parts.take(2).join('/'),
          )
          .collection(parts.last)
          .get();

      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // Ignora se a subcoleção não existir.
    }
  }

  // ================================================================
  // ABRIR URL
  // ================================================================

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showSnack(
          'Não foi possível abrir o link.',
          icon: Icons.error_outline_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Não foi possível abrir o link.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  // ================================================================
  // SNACKBAR
  // ================================================================

  void _showSnack(
    String msg, {
    IconData? icon,
    bool success = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: success
                    ? const Color(0xFF4CAF50)
                    : AppColors.primaryOrange,
                size: 16,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF111111),
          ),
        ),
      ),
      body: ListView(
        children: [
          // ==========================================================
          // CONTA
          // ==========================================================

          const _SectionHeader(
            label: 'CONTA',
          ),

          _SettingsTile(
            icon: Icons.badge_outlined,
            label: 'Nome',
            subtitle: _getDisplayNameSubtitle(),
            onTap: _editDisplayName,
          ),

          const _Divider(),

          _SettingsTile(
            icon: Icons.alternate_email_rounded,
            label: 'ID de usuário',
            subtitle: _getUsernameSubtitle(),
            onTap: _editUsernameId,
          ),

          const _Divider(),

          // ==========================================================
          // NOTIFICAÇÕES
          // ==========================================================

          const _SectionHeader(
            label: 'NOTIFICAÇÕES',
          ),

          _loadingNotifications
              ? const _LoadingTile(
                  label: 'Notificações de notícias',
                )
              : _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notificações de notícias',
                  subtitle:
                      'Receba alertas quando houver novidades',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    activeColor:
                        AppColors.primaryOrange,
                    activeTrackColor: AppColors
                        .primaryOrange
                        .withOpacity(0.3),
                    inactiveThumbColor:
                        const Color(0xFF555555),
                    inactiveTrackColor:
                        const Color(0xFF222222),
                  ),
                ),

          const _Divider(),

          // ==========================================================
          // DADOS E ARMAZENAMENTO
          // ==========================================================

          const _SectionHeader(
            label: 'DADOS E ARMAZENAMENTO',
          ),

          _SettingsTile(
            icon: Icons.data_saver_on_outlined,
            label: 'Economia de dados',
            subtitle: 'Reduz qualidade de imagens',
            trailing: Switch(
              value: _dataSaver,
              onChanged: _setDataSaver,
              activeColor:
                  AppColors.primaryOrange,
              activeTrackColor: AppColors
                  .primaryOrange
                  .withOpacity(0.3),
              inactiveThumbColor:
                  const Color(0xFF555555),
              inactiveTrackColor:
                  const Color(0xFF222222),
            ),
          ),

          _SettingsTile(
            icon: Icons.play_circle_outline_rounded,
            label: 'Reprodução automática',
            subtitle: _autoplayLabel(_autoplay),
            onTap: _showAutoplaySheet,
            trailing: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF555555),
              size: 20,
            ),
          ),

          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            label: 'Limpar cache',
            subtitle: _loadingCache
                ? 'Calculando...'
                : '${_cacheSize.toStringAsFixed(1)} MB',
            onTap: _cacheSize > 0
                ? _clearCache
                : null,
            trailing: _loadingCache
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          AppColors.primaryOrange,
                    ),
                  )
                : _cacheSize > 0
                    ? Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(20),
                          color: AppColors
                              .primaryOrange
                              .withOpacity(0.15),
                          border: Border.all(
                            color: AppColors
                                .primaryOrange
                                .withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '${_cacheSize.toStringAsFixed(1)} MB',
                          style: const TextStyle(
                            color:
                                AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF4CAF50),
                        size: 18,
                      ),
          ),

          const _Divider(),

          // ==========================================================
          // SOBRE
          // ==========================================================

          const _SectionHeader(
            label: 'SOBRE',
          ),

          _SettingsTile(
            icon: Icons.shield_outlined,
            label: 'Política de privacidade',
            subtitle:
                'Leia nossa política de privacidade',
            onTap: () => _openUrl(
              _privacyPolicyUrl,
            ),
          ),

          // BOTÃO DE TERMOS DE USO ATUALIZADO
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Termos de uso',
            subtitle: 'Leia nossos termos de uso',
            onTap: () => _openUrl(
              _termsOfUseUrl,
            ),
          ),

          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Versão do app',
            subtitle: '1.0.0',
            showArrow: false,
          ),

          const _Divider(),

          // ==========================================================
          // SESSÃO
          // ==========================================================

          const _SectionHeader(
            label: 'SESSÃO',
          ),

          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Sair da conta',
            labelColor:
                AppColors.emergencyRed,
            iconColor:
                AppColors.emergencyRed,
            onTap: _handleLogout,
          ),

          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            label: 'Excluir minha conta',
            subtitle:
                'Apaga todos os dados permanentemente',
            labelColor:
                AppColors.emergencyRed,
            iconColor:
                AppColors.emergencyRed,
            onTap: _handleDeleteAccount,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ================================================================
  // NOME
  // ================================================================

  String _getDisplayNameSubtitle() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'Definir nome';
  }

  // ================================================================
  // ID DE USUÁRIO
  // ================================================================

  String _getUsernameSubtitle() {
    if (_currentUsername != null) {
      return '@$_currentUsername';
    }
    return 'Definir ID';
  }

  // ================================================================
  // EDITAR NOME
  // ================================================================

  void _editDisplayName() {
    final controller = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: Color(0xFF1A1A1A),
              ),
            ),
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
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Seu nome',
                  hintStyle: const TextStyle(
                    color: Color(0xFF424242),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF141414),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF212121),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryOrange,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final newName = controller.text.trim();

                  if (newName.isEmpty) {
                    return;
                  }

                  await FirebaseAuth.instance.currentUser
                      ?.updateDisplayName(newName);

                  if (mounted) {
                    Navigator.pop(context);

                    setState(() {});

                    _showSnack(
                      'Nome atualizado!',
                      icon: Icons.check_circle_rounded,
                      success: true,
                    );
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
                        Color(0xFFF57C00),
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

  // ================================================================
  // EDITAR ID DE USUÁRIO
  // ================================================================

  // ── Formata o username: só letras, números e _ ───────────────────
  String _formatUsername(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  void _editUsernameId() {
    final user = FirebaseAuth.instance.currentUser;

    final usernameController = TextEditingController(
      text: '',
    );

    // Pré-preenche com o ID atual (já carregado no initState).
    final originalUsername = _currentUsername;
    if (originalUsername != null) {
      usernameController.text = originalUsername;
    }

    bool usernameAvailable = originalUsername != null;
    bool checkingUsername = false;
    String? usernameError;
    DateTime lastCheck = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> checkUsernameAvailability(String username) async {
            if (username.length < 3) return;

            // Se for o mesmo ID que o usuário já tem, está disponível.
            if (originalUsername != null &&
                username == originalUsername) {
              setModalState(() {
                usernameAvailable = true;
                usernameError = null;
                checkingUsername = false;
              });
              return;
            }

            setModalState(() => checkingUsername = true);

            try {
              final query = await FirebaseFirestore.instance
                  .collection('users_xp')
                  .where('username', isEqualTo: username.toLowerCase())
                  .limit(1)
                  .get();

              usernameAvailable = query.docs.isEmpty;
              usernameError =
                  query.docs.isEmpty ? null : 'Este ID já está em uso.';
              checkingUsername = false;
              setModalState(() {});
            } catch (_) {
              checkingUsername = false;
              setModalState(() {});
            }
          }

          void onUsernameChanged(String rawValue) {
            final formatted = _formatUsername(rawValue);
            if (formatted != rawValue) {
              usernameController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(
                  offset: formatted.length,
                ),
              );
            }

            setModalState(() {
              usernameAvailable = false;
              usernameError = null;
            });

            if (formatted.length < 3) return;

            lastCheck = DateTime.now();
            final checkTime = lastCheck;

            Future.delayed(const Duration(milliseconds: 600), () {
              if (checkTime == lastCheck) {
                checkUsernameAvailability(formatted);
              }
            });
          }

          Widget? usernameSuffix() {
            if (usernameController.text.trim().length < 3) return null;
            if (checkingUsername) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryOrange,
                  ),
                ),
              );
            }
            if (usernameAvailable) {
              return const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
              );
            }
            if (usernameError != null) {
              return const Icon(
                Icons.cancel_rounded,
                color: Colors.redAccent,
              );
            }
            return null;
          }

          String? usernameHelperText() {
            final value = usernameController.text.trim();
            if (value.isEmpty) return null;
            if (value.length < 3) {
              return 'Mínimo de 3 caracteres.';
            }
            if (checkingUsername) return 'Verificando disponibilidade...';
            if (usernameError != null) return usernameError;
            if (usernameAvailable) return 'ID disponível!';
            return null;
          }

          Color helperColor() {
            final value = usernameController.text.trim();
            if (usernameError != null) return Colors.redAccent;
            if (usernameAvailable && value.length >= 3) {
              return Colors.green;
            }
            return const Color(0xFF757575);
          }

          final usernameOk = usernameController.text.trim().length >= 3 &&
              usernameAvailable;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EDITAR ID',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: usernameController,
                      autofocus: true,
                      onChanged: onUsernameChanged,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: const TextStyle(
                          color: Color(0xFF757575),
                        ),
                        hintText: 'seu_id',
                        hintStyle: const TextStyle(
                          color: Color(0xFF424242),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF141414),
                        suffixIcon: usernameSuffix(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF212121),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryOrange,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF212121),
                          ),
                        ),
                      ),
                    ),

                    if (usernameHelperText() != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        usernameHelperText()!,
                        style: TextStyle(
                          color: helperColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: (!usernameOk)
                          ? null
                          : () async {
                              final newUsername =
                                  usernameController.text.trim().toLowerCase();

                              if (user == null) return;

                              try {
                                await FirebaseFirestore.instance
                                    .collection('users_xp')
                                    .doc(user.uid)
                                    .set({
                                  'username': newUsername,
                                }, SetOptions(merge: true));

                                if (mounted) {
                                  Navigator.pop(context);
                                  setState(() {
                                    _currentUsername = newUsername;
                                  });
                                  _showSnack(
                                    'ID atualizado!',
                                    icon: Icons.check_circle_rounded,
                                    success: true,
                                  );
                                }
                              } catch (_) {
                                if (mounted) {
                                  _showSnack(
                                    'Erro ao atualizar ID.',
                                    icon: Icons.error_rounded,
                                    success: false,
                                  );
                                }
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: usernameOk
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFBF360C),
                                    Color(0xFFE65100),
                                    Color(0xFFF57C00),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF2A2A2A),
                                    Color(0xFF2A2A2A),
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
        },
      ),
    );
  }

  // ================================================================
  // REPRODUÇÃO AUTOMÁTICA
  // ================================================================

  void _showAutoplaySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding:
            const EdgeInsets.fromLTRB(
          24,
          20,
          24,
          36,
        ),
        decoration:
            const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius:
              BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'REPRODUÇÃO AUTOMÁTICA',
              style: TextStyle(
                color:
                    AppColors.primaryOrange,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 16),

            _AutoplayOption(
              label: 'Sempre',
              subtitle:
                  'Usa dados móveis e Wi-Fi',
              value: 'always',
              current: _autoplay,
              onTap: () {
                _setAutoplay('always');
                Navigator.pop(context);
              },
            ),

            _AutoplayOption(
              label: 'Somente Wi-Fi',
              subtitle:
                  'Não usa dados móveis',
              value: 'wifi',
              current: _autoplay,
              onTap: () {
                _setAutoplay('wifi');
                Navigator.pop(context);
              },
            ),

            _AutoplayOption(
              label: 'Nunca',
              subtitle:
                  'Vídeos não reproduzem automaticamente',
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
}

// ==================================================================
// CABEÇALHO DE SEÇÃO
// ==================================================================

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        8,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color:
              AppColors.primaryOrange,
          fontSize: 10,
          fontWeight:
              FontWeight.w800,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

// ==================================================================
// ITEM DE CONFIGURAÇÃO
// ==================================================================

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
      splashColor: AppColors
          .primaryOrange
          .withOpacity(0.05),
      highlightColor: AppColors
          .primaryOrange
          .withOpacity(0.03),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                        10),
                color: (iconColor ??
                        AppColors
                            .primaryOrange)
                    .withOpacity(0.12),
              ),
              child: Icon(
                icon,
                color: iconColor ??
                    AppColors
                        .primaryOrange,
                size: 19,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor ??
                          Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),

                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          const TextStyle(
                        color:
                            Color(0xFF666666),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (trailing != null)
              trailing!
            else if (showArrow &&
                onTap != null)
              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Color(0xFF444444),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// LOADING
// ==================================================================

class _LoadingTile extends StatelessWidget {
  final String label;

  const _LoadingTile({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                      10),
              color: AppColors
                  .primaryOrange
                  .withOpacity(0.12),
            ),
            child: const Icon(
              Icons
                  .notifications_outlined,
              color:
                  AppColors.primaryOrange,
              size: 19,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  AppColors.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// DIVISOR
// ==================================================================

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin:
          const EdgeInsets.only(
        left: 72,
      ),
      color:
          const Color(0xFF111111),
    );
  }
}

// ==================================================================
// OPÇÕES DE AUTOPLAY
// ==================================================================

class _AutoplayOption
    extends StatelessWidget {
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
    final selected =
        value == current;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
                  14),
          color: selected
              ? AppColors
                  .primaryOrange
                  .withOpacity(0.1)
              : const Color(
                  0xFF111111),
          border: Border.all(
            color: selected
                ? AppColors
                    .primaryOrange
                    .withOpacity(0.5)
                : const Color(
                    0xFF1E1E1E),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppColors
                              .primaryOrange
                          : Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            if (selected)
              const Icon(
                Icons
                    .check_circle_rounded,
                color:
                    AppColors.primaryOrange,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}