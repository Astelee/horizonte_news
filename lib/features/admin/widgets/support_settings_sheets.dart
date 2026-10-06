import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/support_models.dart';
import '../../../services/support_chat_service.dart';
import '../../../widgets/app_messenger.dart';
import '../services/admin_support_service.dart';

/// Configurações do atendimento: quem atende / quem recebe push,
/// mensagem de boas-vindas, aviso fora do horário e horário.
Future<void> showSupportConfigSheet(
  BuildContext context, {
  required AdminSupportService service,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _SupportConfigSheet(service: service),
  );
}

/// Gerenciar respostas rápidas (criar, editar, apagar).
Future<void> showSupportQuickRepliesSheet(
  BuildContext context, {
  required AdminSupportService service,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _QuickRepliesSheet(service: service),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Configuração geral
// ═══════════════════════════════════════════════════════════════════

class _SupportConfigSheet extends StatefulWidget {
  final AdminSupportService service;
  const _SupportConfigSheet({required this.service});

  @override
  State<_SupportConfigSheet> createState() => _SupportConfigSheetState();
}

class _SupportConfigSheetState extends State<_SupportConfigSheet> {
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _loading = true;
  bool _failed = false;
  bool _saving = false;

  List<SupportAdminAccount> _admins = const [];
  bool _agentsConfigured = false;
  final Set<String> _attend = {};
  final Set<String> _notify = {};

  bool _enabled = true;
  bool _hidePreviewAgent = true;
  bool _hoursEnabled = false;
  int _start = 9 * 60;
  int _end = 18 * 60;
  final Set<int> _days = {1, 2, 3, 4, 5};
  final _welcome = TextEditingController();
  final _offHours = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _welcome.dispose();
    _offHours.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final admins = await widget.service.listAdmins();
      final agents = await widget.service.watchAgentsConfig().first;
      final pub = await SupportChatService.instance.watchPublicConfig().first;
      if (!mounted) return;
      setState(() {
        _admins = admins;
        _agentsConfigured = agents.configured;
        if (agents.configured) {
          _attend.addAll(agents.agentUids);
          _notify.addAll(agents.notifyUids);
        } else {
          // Modo inicial: todo admin atende e recebe até salvar.
          _attend.addAll(admins.map((a) => a.uid));
          _notify.addAll(admins.map((a) => a.uid));
        }
        _enabled = pub.enabled;
        _hidePreviewAgent = pub.hidePreviewAgent;
        _hoursEnabled = pub.hoursEnabled;
        _start = pub.startMinutes;
        _end = pub.endMinutes;
        _days
          ..clear()
          ..addAll(pub.days);
        _welcome.text = pub.welcomeMessage;
        _offHours.text = pub.offHoursMessage;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_myUid.isNotEmpty && !_attend.contains(_myUid)) {
      AppMessenger.error('Você precisa continuar na lista de quem atende.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.saveAgentsConfig(
        agentUids: _attend.toList(),
        notifyUids: _notify.where(_attend.contains).toList(),
      );
      await widget.service.savePublicConfig(SupportPublicConfig(
        enabled: _enabled,
        welcomeMessage: _welcome.text.trim(),
        offHoursMessage: _offHours.text.trim(),
        hoursEnabled: _hoursEnabled,
        startMinutes: _start,
        endMinutes: _end,
        days: (_days.toList()..sort()),
        hidePreviewAgent: _hidePreviewAgent,
      ));
      if (!mounted) return;
      AppMessenger.success('Configurações do atendimento salvas');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppMessenger.error('Não foi possível salvar. Confira as regras publicadas.');
      }
    }
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (t == null) return;
    setState(() {
      if (start) {
        _start = t.hour * 60 + t.minute;
      } else {
        _end = t.hour * 60 + t.minute;
      }
    });
  }

  static String _fmt(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.backgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryOrange),
                  ),
                )
              : _failed
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Não foi possível carregar as configurações.',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
                        const Text('Configurar atendimento',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        _title('QUEM ATENDE E QUEM RECEBE NOTIFICAÇÕES'),
                        if (!_agentsConfigured)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Modo inicial: enquanto você não salvar, todo admin '
                              'atende e recebe notificações. Salve para definir a lista.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                        for (final a in _admins) _adminRow(a),
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Só admins cadastrados em "admins" aparecem aqui. '
                            'A lista de notificações é aplicada no aparelho de cada '
                            'admin quando ele abre o app.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ),
                        _title('ATENDIMENTO'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primaryOrange,
                          title: const Text('Atendimento ativo',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                              'Desligado: os usuários veem o chat, mas não enviam.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primaryOrange,
                          title: const Text(
                              'Ocultar conteúdo nas notificações da equipe',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                              'Recomendado: o push avisa que há mensagem, sem mostrar o texto.',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                          value: _hidePreviewAgent,
                          onChanged: (v) =>
                              setState(() => _hidePreviewAgent = v),
                        ),
                        _title('MENSAGEM DE BOAS-VINDAS'),
                        TextField(
                          controller: _welcome,
                          maxLines: 3,
                          maxLength: 500,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec(
                              'Aparece só quando a conversa ainda não tem mensagens'),
                        ),
                        _title('FORA DO HORÁRIO'),
                        TextField(
                          controller: _offHours,
                          maxLines: 3,
                          maxLength: 500,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec(
                              'Mostrado depois de uma mensagem enviada fora do horário (no máx. a cada 6 h)'),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primaryOrange,
                          title: const Text('Definir horário de atendimento',
                              style: TextStyle(color: Colors.white)),
                          value: _hoursEnabled,
                          onChanged: (v) => setState(() => _hoursEnabled = v),
                        ),
                        if (_hoursEnabled) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickTime(true),
                                  child: Text('Início ${_fmt(_start)}'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickTime(false),
                                  child: Text('Fim ${_fmt(_end)}'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final e in const {
                                1: 'Seg',
                                2: 'Ter',
                                3: 'Qua',
                                4: 'Qui',
                                5: 'Sex',
                                6: 'Sáb',
                                7: 'Dom',
                              }.entries)
                                FilterChip(
                                  label: Text(e.value),
                                  selected: _days.contains(e.key),
                                  selectedColor: AppColors.primaryOrange,
                                  backgroundColor: AppColors.backgroundDark,
                                  labelStyle: TextStyle(
                                    color: _days.contains(e.key)
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSelected: (sel) => setState(() {
                                    sel ? _days.add(e.key) : _days.remove(e.key);
                                  }),
                                ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Usa o horário do aparelho de cada usuário. O app nunca '
                              'mostra "Online": só avisos que você configurar aqui.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.black))
                                : const Text('Salvar',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _adminRow(SupportAdminAccount a) {
    final isMe = a.uid == _myUid;
    final attends = _attend.contains(a.uid);
    final notifies = _notify.contains(a.uid);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isMe ? '${a.name} (você)' : a.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          Text('${a.role} · ${a.uid}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryOrange,
                  title: const Text('Atende',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: attends,
                  onChanged: isMe
                      ? null
                      : (v) => setState(() {
                            if (v) {
                              _attend.add(a.uid);
                            } else {
                              _attend.remove(a.uid);
                              _notify.remove(a.uid);
                            }
                          }),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryOrange,
                  title: const Text('Push',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: notifies && attends,
                  onChanged: attends
                      ? (v) => setState(() {
                            v ? _notify.add(a.uid) : _notify.remove(a.uid);
                          })
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Respostas rápidas
// ═══════════════════════════════════════════════════════════════════

class _QuickRepliesSheet extends StatelessWidget {
  final AdminSupportService service;
  const _QuickRepliesSheet({required this.service});

  Future<void> _edit(BuildContext context, SupportQuickReply? existing,
      int nextOrder) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final text = TextEditingController(text: existing?.text ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text(existing == null ? 'Nova resposta rápida' : 'Editar resposta',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 40,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Título', counterText: ''),
              ),
              TextField(
                controller: text,
                maxLines: 5,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Mensagem'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (saved != true) return;
    if (title.text.trim().isEmpty || text.text.trim().isEmpty) {
      AppMessenger.error('Preencha o título e a mensagem.');
      return;
    }
    try {
      await service.saveQuickReply(
        id: existing?.id,
        title: title.text,
        text: text.text,
        order: existing?.order ?? nextOrder,
      );
    } catch (_) {
      AppMessenger.error('Não foi possível salvar a resposta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: StreamBuilder<List<SupportQuickReply>>(
          stream: service.watchQuickReplies(),
          builder: (context, snap) {
            final items = snap.data ?? const <SupportQuickReply>[];
            final nextOrder = items.isEmpty
                ? 10
                : items.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 10;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Respostas rápidas',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded,
                            color: AppColors.primaryOrange),
                        onPressed: () => _edit(context, null, nextOrder),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Nenhuma resposta rápida. Toque em + para criar.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: AppColors.borderSubtle),
                          itemBuilder: (_, i) {
                            final r = items[i];
                            return ListTile(
                              title: Text(r.title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(r.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              onTap: () => _edit(context, r, nextOrder),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppColors.emergencyRed),
                                onPressed: () => service.deleteQuickReply(r.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}