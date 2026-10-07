import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/support_models.dart';
import '../../../../widgets/app_avatar.dart';
import '../../../../widgets/app_messenger.dart';
import '../../services/admin_support_service.dart';
import '../../widgets/support_settings_sheets.dart';
import '../../widgets/support_user_picker.dart';

/// Aba "Atendimento" do painel ADM: caixa de entrada das conversas
/// privadas com os usuários.
///
/// • Lista ordenada pela última atividade (fixadas no topo), com foto,
///   nome, prévia, horário e contador de não lidas.
/// • Filtros: Todas, Não lidas, Aguardando resposta, Resolvidas.
/// • Busca por início do nome, início do username ou UID completo, só
///   em conversas que já existem (o Firestore não faz busca "contém").
/// • Cada filtro usa um listener limitado (40 conversas, +40 sob
///   demanda). Nenhuma mensagem é carregada aqui.
class SupportTab extends StatefulWidget {
  final AdminSupportService? service;
  const SupportTab({Key? key, this.service}) : super(key: key);

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  late final AdminSupportService _service =
      widget.service ?? AdminSupportService();

  SupportInboxFilter _filter = SupportInboxFilter.all;
  int _limit = 40;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  bool _searching = false;
  List<SupportConversation> _results = const [];

  late Stream<List<SupportConversation>> _inbox =
      _service.watchInbox(_filter, limit: _limit);
  late final Stream<List<SupportConversation>> _pinned = _service.watchPinned();
  late final Stream<int> _unreadCount = _service.watchUnreadConversationCount();
  late final Stream<int> _awaitingCount = _service.watchAwaitingCount();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setFilter(SupportInboxFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _limit = 40;
      _inbox = _service.watchInbox(_filter, limit: _limit);
    });
  }

  void _loadMore() {
    setState(() {
      _limit += 40;
      _inbox = _service.watchInbox(_filter, limit: _limit);
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _query = q);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      try {
        final r = await _service.search(q);
        if (!mounted || _query != q) return;
        setState(() {
          _results = r;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _searching = false);
        AppMessenger.error('Não foi possível buscar agora.');
      }
    });
  }

  void _open(SupportConversation c) {
    Navigator.of(context).pushNamed(
      AppRoutes.support,
      arguments: SupportChatArgs(conversationId: c.id),
    );
  }

  Future<void> _toggleResolved(SupportConversation c) async {
    try {
      await _service.setResolved(c, !c.isResolved);
    } catch (_) {
      if (mounted) AppMessenger.error('Não foi possível atualizar a conversa.');
    }
  }

  Future<void> _togglePinned(SupportConversation c) async {
    try {
      await _service.setPinned(c.id, !c.pinned);
    } catch (_) {
      if (mounted) AppMessenger.error('Não foi possível fixar a conversa.');
    }
  }

  // ── Interface ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _summaryBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Nova mensagem para um usuário',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () => showSupportUserPicker(context, service: _service),
            ),
          ),
        ),
        _searchField(),
        _filterChips(),
        Expanded(child: _query.isNotEmpty ? _searchResults() : _list()),
      ],
    );
  }

  Widget _summaryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<int>(
              stream: _unreadCount,
              builder: (context, unread) => StreamBuilder<int>(
                stream: _awaitingCount,
                builder: (context, awaiting) {
                  final u = unread.data ?? 0;
                  final a = awaiting.data ?? 0;
                  return Text(
                    '${a >= 99 ? '99+' : a} aguardando resposta · '
                    '${u >= 99 ? '99+' : u} com mensagens não lidas',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
          ),
          IconButton(
            tooltip: 'Respostas rápidas',
            icon: const Icon(Icons.bolt_rounded, color: AppColors.primaryOrange),
            onPressed: () =>
                showSupportQuickRepliesSheet(context, service: _service),
          ),
          IconButton(
            tooltip: 'Configurar atendimento',
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () =>
                showSupportConfigSheet(context, service: _service),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar por nome, username ou UID',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
          filled: true,
          fillColor: AppColors.backgroundElevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    const labels = {
      SupportInboxFilter.all: 'Todas',
      SupportInboxFilter.unread: 'Não lidas',
      SupportInboxFilter.awaiting: 'Aguardando resposta',
      SupportInboxFilter.resolved: 'Resolvidas',
    };
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: _filter == e.key,
                selectedColor: AppColors.primaryOrange,
                backgroundColor: AppColors.backgroundElevated,
                labelStyle: TextStyle(
                  color: _filter == e.key ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => _setFilter(e.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchResults() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'A busca olha só conversas que já existem: começo do nome, começo '
            'do username ou UID completo. Para falar com quem nunca escreveu, '
            'abra o perfil na aba Usuários e toque em "Enviar mensagem".',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            ),
          )
        else if (_results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Nenhuma conversa encontrada.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          for (final c in _results) _tile(c),
      ],
    );
  }

  Widget _list() {
    return StreamBuilder<List<SupportConversation>>(
      stream: _inbox,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar as conversas. Confira as regras e '
                'os índices publicados no Firebase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryOrange),
          );
        }
        final base = snap.data!;

        return StreamBuilder<List<SupportConversation>>(
          stream: _filter == SupportInboxFilter.all ? _pinned : null,
          builder: (context, pinnedSnap) {
            // Fixadas sempre no topo, mesmo que já saíram das 40 mais
            // recentes (só no filtro "Todas").
            final merged = <String, SupportConversation>{
              for (final c in base) c.id: c,
              if (_filter == SupportInboxFilter.all)
                for (final c in pinnedSnap.data ?? const <SupportConversation>[])
                  c.id: c,
            };
            final items = merged.values.toList()
              ..sort((a, b) {
                if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                final da = a.lastActivityAt ?? DateTime(1970);
                final db = b.lastActivityAt ?? DateTime(1970);
                return db.compareTo(da);
              });

            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _filter == SupportInboxFilter.all
                        ? 'Nenhuma conversa ainda.'
                        : 'Nenhuma conversa neste filtro.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length + (base.length >= _limit ? 1 : 0),
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, i) {
                if (i >= items.length) {
                  return TextButton(
                    onPressed: _loadMore,
                    child: const Text('Carregar mais conversas',
                        style: TextStyle(color: AppColors.primaryOrange)),
                  );
                }
                return _tile(items[i]);
              },
            );
          },
        );
      },
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _timeLabel(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '${_two(d.hour)}:${_two(d.minute)}';
    if (diff == 1) return 'Ontem';
    return '${_two(d.day)}/${_two(d.month)}';
  }

  Widget _tile(SupportConversation c) {
    final name = c.userName.isEmpty ? 'Sem nome' : c.userName;
    final unread = c.unreadAgent > 0;
    final prefix = c.lastMessageSenderRole == 'agent' ? 'Você: ' : '';
    final category = SupportCategory.labelOf(c.category);

    return InkWell(
      onTap: () => _open(c),
      onLongPress: () => _showActions(c),
      child: Container(
        color: unread
            ? AppColors.primaryOrange.withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppAvatar(
              name: name,
              seed: c.userId,
              photoUrl: c.photoUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (c.pinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded,
                              size: 13, color: AppColors.primaryOrange),
                        ),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight:
                                unread ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel(c.lastActivityAt),
                        style: TextStyle(
                          color: unread
                              ? AppColors.primaryOrange
                              : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$prefix${c.lastMessageText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c.unreadAgent > 99 ? '99+' : '${c.unreadAgent}',
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                  if (c.isResolved || c.blocked || category.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        [
                          if (c.isResolved) 'Resolvida',
                          if (c.blocked) 'Envio bloqueado',
                          if (category.isNotEmpty) category,
                        ].join(' · '),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(SupportConversation c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                c.isResolved
                    ? Icons.replay_rounded
                    : Icons.check_circle_outline_rounded,
                color: AppColors.primaryOrange,
              ),
              title: Text(c.isResolved ? 'Reabrir conversa' : 'Marcar como resolvida',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _toggleResolved(c);
              },
            ),
            ListTile(
              leading: Icon(
                c.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: AppColors.primaryOrange,
              ),
              title: Text(c.pinned ? 'Desafixar' : 'Fixar no topo',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _togglePinned(c);
              },
            ),
          ],
        ),
      ),
    );
  }
}