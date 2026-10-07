import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/support_models.dart';
import '../../../services/support_launcher.dart';
import '../../../widgets/app_avatar.dart';
import '../services/admin_support_service.dart';

/// Lista de usuários para o ADM iniciar uma conversa, mesmo com quem
/// nunca escreveu. Mostra os que abriram o app mais recentemente e
/// permite buscar por início do nome, início do username ou UID.
/// Ao tocar, abre a mesma conversa do atendimento (support_conversations/{uid}).
Future<void> showSupportUserPicker(
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
    builder: (_) => _UserPickerSheet(service: service),
  );
}

class _UserPickerSheet extends StatefulWidget {
  final AdminSupportService service;
  const _UserPickerSheet({required this.service});

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  bool _failed = false;
  String _query = '';
  List<SupportProfile> _users = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await widget.service.recentUsers();
      if (!mounted) return;
      setState(() {
        _users = list;
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

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _query = q);
    if (q.isEmpty) {
      _loadRecent();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() {
        _loading = true;
        _failed = false;
      });
      try {
        final list = await widget.service.searchUsers(q);
        if (!mounted || _query != q) return;
        setState(() {
          _users = list;
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
    });
  }

  void _pick(SupportProfile p) {
    final nav = Navigator.of(context);
    nav.pop();
    SupportLauncher.openForUser(nav.context, p);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nova mensagem',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _query.isEmpty
                        ? 'Usuários que abriram o app mais recentemente. '
                            'Busque pelo começo do nome, do username ou pelo UID.'
                        : 'Resultados da busca (começo do nome, começo do username ou UID).',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuário',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryOrange),
                        ),
                      )
                    : _failed
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Não foi possível carregar os usuários.',
                                style: TextStyle(color: Colors.white)),
                          )
                        : _users.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Nenhum usuário encontrado.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _users.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1, color: AppColors.borderSubtle),
                                itemBuilder: (_, i) {
                                  final u = _users[i];
                                  return ListTile(
                                    leading: AppAvatar(
                                      name: u.userName,
                                      seed: u.userId,
                                      photoUrl: u.photoUrl,
                                      size: 40,
                                    ),
                                    title: Text(u.userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                    subtitle: u.username.isEmpty
                                        ? null
                                        : Text('@${u.username}',
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary,
                                                fontSize: 12)),
                                    trailing: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: AppColors.primaryOrange,
                                        size: 20),
                                    onTap: () => _pick(u),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}