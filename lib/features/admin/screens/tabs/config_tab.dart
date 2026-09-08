import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_config_service.dart';
import '../../services/admin_news_service.dart';
import '../../widgets/admin_shared_widgets.dart';

class ConfigTab extends StatefulWidget {
  final AdminConfigService configService;
  const ConfigTab({required this.configService, Key? key}) : super(key: key);

  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  final _maintenanceMsgController = TextEditingController();
  final _adminNewsService = AdminNewsService();
  bool _reindexing = false;

  @override
  void dispose() {
    _maintenanceMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminSectionHeader(
            icon: Icons.settings_rounded,
            iconColor: AppColors.textSecondary,
            text: 'Configurações do sistema',
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: widget.configService.configStream(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final maintenanceOn = data?['maintenanceMode'] as bool? ?? false;
              final maintenanceMsg =
                  (data?['maintenanceMessage'] as String?) ?? '';
              final commentsOn = data?['commentsEnabled'] as bool? ?? true;

              // Mantém o campo de texto sincronizado com o valor
              // salvo, sem sobrescrever enquanto o admin está
              // digitando (só atualiza se o campo ainda está vazio
              // ou igual ao que já tinha).
              if (_maintenanceMsgController.text.isEmpty &&
                  maintenanceMsg.isNotEmpty) {
                _maintenanceMsgController.text = maintenanceMsg;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMaintenanceCard(maintenanceOn, maintenanceMsg),
                  const SizedBox(height: 14),
                  _buildCommentsCard(commentsOn),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const AdminSectionHeader(
            icon: Icons.admin_panel_settings_rounded,
            iconColor: AppColors.primaryOrange,
            text: 'Administradores',
          ),
          const SizedBox(height: 12),
          _AdminsManager(configService: widget.configService),
          const SizedBox(height: 24),
          const AdminSectionHeader(
            icon: Icons.build_rounded,
            iconColor: AppColors.textSecondary,
            text: 'Manutenção de dados',
          ),
          const SizedBox(height: 12),
          _buildReindexSearchCard(),
        ],
      ),
    );
  }

  Widget _buildReindexSearchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_search_rounded,
                  color: AppColors.primaryOrange, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Reindexar busca',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Atualiza o índice de busca de todas as notícias '
            '(inclusive as mais antigas). Use uma vez agora para a '
            'pesquisa passar a encontrar notícias já publicadas — '
            'novas notícias já são indexadas automaticamente ao '
            'salvar.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reindexing ? null : _handleReindexSearch,
              icon: _reindexing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: AppColors.primaryOrange, size: 18),
              label: Text(
                _reindexing ? 'Reindexando...' : 'Reindexar agora',
                style: const TextStyle(color: AppColors.primaryOrange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReindexSearch() async {
    setState(() => _reindexing = true);
    try {
      final count = await _adminNewsService.reindexSearchFields();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count notícias reindexadas para a busca.'),
            backgroundColor: const Color(0xFF1A1A1A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reindexar: $e'),
            backgroundColor: const Color(0xFF1A1A1A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reindexing = false);
    }
  }

  Widget _buildMaintenanceCard(bool enabled, String currentMsg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled
              ? const Color(0xFFEF5350).withOpacity(0.5)
              : AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_rounded,
                  color: enabled
                      ? const Color(0xFFEF5350)
                      : AppColors.textSecondary,
                  size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Modo manutenção',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                activeColor: const Color(0xFFEF5350),
                onChanged: (value) => _handleMaintenanceToggle(value),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Bloqueia o acesso de todos os usuários (menos admins), '
            'mostrando uma tela de aviso. Use durante atualizações '
            'importantes.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            AdminBadge(
              label: 'Ativo agora',
              color: const Color(0xFFEF5350),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _maintenanceMsgController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLength: 150,
            decoration: InputDecoration(
              hintText: 'Mensagem exibida aos usuários (opcional)',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: const Color(0xFF151515),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _saveMaintenanceMessage(enabled),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _saveMaintenanceMessage(enabled),
              child: const Text('Salvar mensagem',
                  style: TextStyle(color: AppColors.primaryOrange)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCard(bool enabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_rounded,
                  color: enabled
                      ? const Color(0xFF66BB6A)
                      : AppColors.textSecondary,
                  size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Comentários no app',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                activeColor: const Color(0xFF66BB6A),
                onChanged: (value) async {
                  await widget.configService.setCommentsEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            enabled
                ? 'Usuários podem comentar e responder normalmente nas '
                    'notícias.'
                : 'Novos comentários e respostas estão bloqueados. Os '
                    'comentários já existentes continuam visíveis.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMaintenanceToggle(bool value) async {
    if (value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AdminConfirmDialog(
          title: 'Ativar modo manutenção?',
          message: 'Todos os usuários (exceto admins) ficarão sem acesso '
              'ao app até você desativar.',
          confirmLabel: 'Ativar',
          confirmColor: const Color(0xFFEF5350),
        ),
      );
      if (confirm != true) return;
    }
    await widget.configService.setMaintenanceMode(
      enabled: value,
      message: _maintenanceMsgController.text.trim(),
    );
  }

  Future<void> _saveMaintenanceMessage(bool enabled) async {
    await widget.configService.setMaintenanceMode(
      enabled: enabled,
      message: _maintenanceMsgController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensagem salva.'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    }
  }
}

/// Lista de admins atuais + busca de usuários para promover/rebaixar.
class _AdminsManager extends StatefulWidget {
  final AdminConfigService configService;
  const _AdminsManager({required this.configService});

  @override
  State<_AdminsManager> createState() => _AdminsManagerState();
}

class _AdminsManagerState extends State<_AdminsManager> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admins atuais',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.configService.adminsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryOrange),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhum admin cadastrado.',
                    style: TextStyle(color: AppColors.textMuted)),
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final role = (data['role'] as String?) ?? 'admin';
                final label = (data['label'] as String?) ?? '';
                final isSelf = doc.id == FirebaseAuth.instance.currentUser?.uid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: AppColors.primaryOrange, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label.isNotEmpty ? label : doc.id,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            Text(
                              '$role${isSelf ? ' · você' : ''}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (!isSelf)
                        IconButton(
                          icon: const Icon(Icons.person_remove_rounded,
                              color: Color(0xFFEF5350), size: 20),
                          onPressed: () => _confirmRemoveAdmin(doc.id, label),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'Promover usuário a admin',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar por nome...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF151515),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 10),
        if (_search.length >= 2)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users_xp')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange),
                  ),
                );
              }
              final matches = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name =
                    (data['displayName'] as String?)?.toLowerCase() ?? '';
                final email = (data['email'] as String?)?.toLowerCase() ?? '';
                return name.contains(_search) || email.contains(_search);
              }).take(10).toList();

              if (matches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhum usuário encontrado.',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }

              return Column(
                children: matches.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] as String?)?.trim();
                  final email = (data['email'] as String?) ?? '';
                  final displayName =
                      (name != null && name.isNotEmpty) ? name : email;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Text(email,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _confirmAddAdmin(doc.id, displayName),
                          child: const Text('Promover',
                              style:
                                  TextStyle(color: AppColors.primaryOrange)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Digite ao menos 2 letras do nome ou e-mail para buscar.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmAddAdmin(String uid, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Promover a admin?',
        message: '$label vai ter acesso total ao painel administrativo, '
            'incluindo banir usuários e gerenciar publicações.',
        confirmLabel: 'Promover',
        confirmColor: AppColors.primaryOrange,
      ),
    );
    if (confirm != true) return;

    final admin = FirebaseAuth.instance.currentUser;
    await widget.configService.addAdmin(
      uid: uid,
      addedByName: admin?.displayName ?? admin?.email ?? 'Admin',
      label: label,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label agora é admin.'),
          backgroundColor: const Color(0xFF66BB6A),
        ),
      );
    }
  }

  Future<void> _confirmRemoveAdmin(String uid, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Remover admin?',
        message:
            '${label.isNotEmpty ? label : uid} perde acesso ao painel '
            'administrativo imediatamente.',
        confirmLabel: 'Remover',
        confirmColor: const Color(0xFFEF5350),
      ),
    );
    if (confirm != true) return;

    await widget.configService.removeAdmin(uid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin removido.'),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
    }
  }
}