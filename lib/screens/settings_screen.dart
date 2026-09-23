import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../config/badge_config.dart';
import '../config/premium_config.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/xp_service.dart';
import '../providers/user_xp_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/badge_widgets.dart';
import '../widgets/subscriber_badge.dart';
import '../widgets/profile_edit_sheets.dart' show showEditDisplayNameSheet, showEditUsernameSheet, showAvatarOptionsSheet;

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
  String? _photoUrl;
  bool _uploadingPhoto = false;
  bool _showAge = false;

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

      final data = doc.data();
      final username = data?['username'] as String?;
      final photoUrl = data?['photoUrl'] as String?;
      final showAge = data?['showAge'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _currentUsername = username;
          _photoUrl = photoUrl;
          _showAge = showAge;
        });
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

  // O CachedNetworkImage (usado nas fotos de perfil, capas de notícia
  // etc.) guarda os arquivos baixados dentro do diretório temporário
  // do app, na subpasta padrão do flutter_cache_manager. Somamos o
  // tamanho real dos arquivos ali — nada de número fixo/fake.
  static const String _imageCacheFolderName = 'libCachedImageData';

  Future<Directory?> _imageCacheDir() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory('${tempDir.path}/$_imageCacheFolderName');
      return await dir.exists() ? dir : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _calcCache() async {
    double sizeMb = 0;
    try {
      final dir = await _imageCacheDir();
      if (dir != null) {
        int bytes = 0;
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              bytes += await entity.length();
            } catch (_) {
              // Arquivo apagado entre o list() e o length() — ignora
              // e segue somando o resto.
            }
          }
        }
        sizeMb = bytes / (1024 * 1024);
      }
    } catch (_) {
      // Mantém sizeMb em 0 — melhor mostrar "0 MB" do que travar a
      // tela de Configurações por causa do cálculo de cache.
    }

    if (mounted) {
      setState(() {
        _cacheSize = sizeMb;
        _loadingCache = false;
      });
    }
  }

  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_posts');

    // Apaga de verdade os arquivos de imagem em cache — antes este
    // botão só limpava uma chave do SharedPreferences que não tinha
    // nenhuma relação com o número mostrado (que era fixo).
    try {
      final dir = await _imageCacheDir();
      if (dir != null) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Sem permissão momentânea ou arquivo em uso — o usuário pode
      // tentar de novo; não é motivo para travar a tela.
    }

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

      // O Firebase Auth só deixa apagar a conta se o login for
      // RECENTE (cerca de 5 minutos). Se não for, user.delete() falha
      // com 'requires-recent-login' — e como ele é o ÚLTIMO passo
      // (precisa vir depois dos dados, que dependem de o usuário
      // ainda estar autenticado), a pessoa acabava com o perfil e os
      // comentários JÁ apagados e continuava logada, sem conta.
      // Por isso conferimos o horário do último login ANTES de apagar
      // qualquer coisa e, se estiver velho, pedimos para entrar de novo.
      final lastSignIn = user.metadata.lastSignInTime;
      final loginIsFresh = lastSignIn != null &&
          DateTime.now().difference(lastSignIn) < const Duration(minutes: 4);
      if (!loginIsFresh) {
        if (mounted) {
          Navigator.of(context).pop();
          _showSnack(
            'Por segurança, saia e entre novamente antes de excluir sua conta.',
            icon: Icons.warning_amber_rounded,
          );
        }
        return;
      }

      // ORDEM IMPORTANTE: primeiro tudo que depende de o usuário ainda
      // ter permissão (comentários, viewers, notificações), e só no
      // fim os documentos de perfil. Antes, o perfil era apagado no
      // começo e qualquer falha no meio deixava a conta pela metade:
      // sem perfil, mas com comentários e ainda logada.

      // 1. Remove comentários e respostas do usuário
      //
      // Os comentários ficam em comments/{postId}/postComments/{id} e
      // as respostas em .../{id}/replies/{id}. O código antigo
      // buscava collectionGroup('comments'), um nome que não existe
      // no banco (a coleção se chama 'postComments'), então NENHUM
      // comentário era apagado. Além disso, apagar um comentário
      // raiz não apaga as respostas dele, e apagar uma resposta não
      // corrige o repliesCount do comentário pai.
      await _deleteUserComments(db, uid);

      // 2. Remove visualizações
      final postViews = await db.collection('post_views').get();
      for (final postDoc in postViews.docs) {
        try {
          await postDoc.reference.collection('viewers').doc(uid).delete();
        } catch (_) {
          // Sem viewer para este usuário neste post — segue.
        }
      }

      // 3. Remove logs
      try {
        final adminLogs = await db
            .collection('admin_logs')
            .where('targetUid', isEqualTo: uid)
            .get();
        for (final log in adminLogs.docs) {
          await log.reference.delete();
        }
      } catch (_) {
        // Usuário comum não tem permissão de ler admin_logs — ignora.
      }

      // 4. Remove banimento, presença e username
      for (final ref in [
        db.collection('banned_users').doc(uid),
        db.collection('presence').doc(uid),
        db.collection('usernames').doc(uid),
      ]) {
        try {
          await ref.delete();
        } catch (_) {}
      }

      // 5. Check-ins (subcoleção de users_xp) antes do doc principal
      await _deleteSubcollection(db, 'users_xp/$uid/checkins');

      // 6. Perfil e XP — por último, depois de tudo que dependia deles
      await db.collection('users').doc(uid).delete();
      await db.collection('users_xp').doc(uid).delete();

      // 7. Admin (só existe se o usuário era admin)
      try {
        await db.collection('admins').doc(uid).delete();
      } catch (_) {}

      // 8. Exclui Firebase Auth
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
  // HELPER PARA COMENTÁRIOS DO USUÁRIO
  // ================================================================

  /// Apaga todos os comentários e respostas escritos por [uid].
  ///
  /// Percorre comments/{postId}/postComments em vez de usar
  /// collectionGroup().where('userId'): uma consulta de grupo com
  /// filtro exige um índice de escopo "grupo de coleções" criado à
  /// mão no console do Firebase, e sem ele a busca falha. Percorrer
  /// os posts é mais lento, mas funciona sem nenhuma configuração.
  ///
  /// Limites impostos pelas regras do Firestore (usuário comum só
  /// apaga o que ele mesmo escreveu):
  ///  • comentário raiz do usuário: apaga só o documento dele. As
  ///    respostas de OUTRAS pessoas a ele não podem ser apagadas
  ///    aqui (o dono é outro) e ficam órfãs — invisíveis no app,
  ///    porque a lista só mostra respostas de comentários que
  ///    existem;
  ///  • resposta do usuário em comentário de outra pessoa: apaga e
  ///    decrementa o repliesCount do pai de 1 em 1 (a regra só
  ///    aceita ±1 por escrita, então -N de uma vez seria negado).
  ///
  /// Cada apagamento é isolado num try/catch: uma permissão negada
  /// num item não pode impedir a exclusão do resto da conta.
  Future<void> _deleteUserComments(FirebaseFirestore db, String uid) async {
    final posts = await db.collection('comments').get();

    for (final post in posts.docs) {
      final roots = await post.reference.collection('postComments').get();

      for (final root in roots.docs) {
        final rootData = root.data();

        if (rootData['userId'] == uid) {
          try {
            await root.reference.delete();
          } catch (_) {}
          continue;
        }

        // Comentário de outra pessoa: procura respostas MINHAS nele.
        QuerySnapshot<Map<String, dynamic>> mine;
        try {
          mine = await root.reference
              .collection('replies')
              .where('userId', isEqualTo: uid)
              .get();
        } catch (_) {
          continue;
        }

        for (final r in mine.docs) {
          try {
            await r.reference.delete();
          } catch (_) {
            continue;
          }
          try {
            await root.reference.update({
              'repliesCount': FieldValue.increment(-1),
            });
          } catch (_) {
            // Contador não ajustado — não impede a exclusão da conta.
          }
        }
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
          // FOTO DE PERFIL
          // ==========================================================

          _buildProfileHeader(),

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

          _SettingsTile(
            icon: Icons.cake_outlined,
            label: 'Mostrar minha idade',
            subtitle: 'Exibe sua idade no seu perfil público',
            trailing: Switch(
              value: _showAge,
              onChanged: _toggleShowAge,
              activeColor: AppColors.primaryOrange,
              activeTrackColor: AppColors.primaryOrange.withOpacity(0.3),
              inactiveThumbColor: const Color(0xFF555555),
              inactiveTrackColor: const Color(0xFF222222),
            ),
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

  Future<void> _toggleShowAge(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _showAge = value);

    try {
      await FirebaseFirestore.instance
          .collection('users_xp')
          .doc(user.uid)
          .set({'showAge': value}, SetOptions(merge: true));
    } catch (_) {
      if (mounted) {
        setState(() => _showAge = !value);
        _showSnack(
          'Erro ao atualizar preferência.',
          icon: Icons.error_rounded,
          success: false,
        );
      }
    }
  }

  // ================================================================
  // FOTO DE PERFIL
  // ================================================================

  void _handleAvatarTap() {
    showAvatarOptionsSheet(
      context,
      hasPhoto: _photoUrl != null,
      onUploading: (_) {
        if (mounted) setState(() => _uploadingPhoto = true);
      },
      onSaved: (_) {
        // A foto enviada fica pendente de aprovação — não substitui
        // _photoUrl aqui. A foto exibida só muda quando um admin
        // aprova e o campo photoUrl no Firestore é atualizado de
        // fato (ver _loadSettings/stream que alimenta _photoUrl).
        if (mounted) setState(() => _uploadingPhoto = false);
      },
      onRemoving: () {
        if (mounted) setState(() => _uploadingPhoto = true);
      },
      onRemoved: () {
        if (mounted) {
          setState(() {
            _photoUrl = null;
            _uploadingPhoto = false;
          });
        }
      },
      onError: () {
        if (mounted) setState(() => _uploadingPhoto = false);
      },
    );
  }

  Widget _buildProfileHeader() {
    // UserXpProvider já fica escutando users_xp/{uid} em tempo real
    // desde o login (ver main.dart) — reaproveitado aqui em vez de
    // abrir outra leitura do Firestore só para esta tela.
    final xp = context.watch<UserXpProvider>();
    final data = xp.data;
    final user = FirebaseAuth.instance.currentUser;

    final levelColor = BadgeConfig.levelColor(data.level);
    final levelGradient = BadgeConfig.levelGradient(data.level);
    final title = data.customTitle ?? BadgeConfig.levelTitle(data.level);
    final isSubscriber = data.premiumTier != PremiumTier.none;

    final displayName = user?.displayName ??
        user?.email?.split('@').first ??
        'Usuário';

    final achievements = XpService().getAllAchievements(data.achievements);
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Center(
        child: Column(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: _uploadingPhoto ? null : _handleAvatarTap,
                  child: AvatarFrame(
                    level: data.level,
                    size: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        UserAvatarDisplay(
                          // data.photoUrl vem do stream ao vivo do
                          // UserXpProvider — reflete na hora quando um
                          // admin aprova/rejeita a foto pendente.
                          // _photoUrl (variável local) só é usado no
                          // hasPhoto: do bottom sheet mais abaixo.
                          name: displayName,
                          seed: user?.uid,
                          photoUrl: data.photoUrl,
                          equippedPremiumAvatarId:
                              data.equippedPremiumAvatarId,
                          size: 88,
                        ),
                        if (_uploadingPhoto)
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _uploadingPhoto ? null : _handleAvatarTap,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFBF360C),
                            Color(0xFFE65100),
                            Color(0xFFF57C00),
                          ],
                        ),
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSubscriber) ...[
                  const SizedBox(width: 6),
                  const SubscriberBadge(size: 16),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // Toca para abrir a tela de Perfil, que é onde nível,
            // título e emblemas realmente vivem — aqui é só um
            // resumo, para não duplicar toda aquela tela.
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: levelGradient),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      BadgeConfig.levelIcon(data.level),
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Nível ${data.level} · $title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FrameRarityTag(level: data.level),
                  const SizedBox(width: 10),
                  Icon(Icons.military_tech_rounded,
                      size: 14, color: levelColor),
                  const SizedBox(width: 4),
                  Text(
                    '$unlockedCount/${achievements.length} emblemas',
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: levelColor.withOpacity(0.7)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // NOME
  // ================================================================

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
    showEditDisplayNameSheet(
      context,
      onSaved: () {
        if (mounted) setState(() {});
      },
    );
  }

  // ================================================================
  // EDITAR ID DE USUÁRIO
  // ================================================================

  void _editUsernameId() {
    showEditUsernameSheet(
      context,
      currentUsername: _currentUsername,
      onSaved: (newUsername) {
        if (mounted) setState(() => _currentUsername = newUsername);
      },
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