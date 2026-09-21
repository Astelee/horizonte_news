import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../services/admin_comment_service.dart';
import '../../services/admin_user_service.dart';
import '../../widgets/admin_comment_tile.dart';
import '../../widgets/admin_shared_widgets.dart';

enum _CommentFilter { all, roots, replies, hidden }

/// Aba de moderação de comentários do painel ADM.
///
/// Junta duas fontes, porque o app grava em coleções diferentes:
///  • comentários-raiz  → comments/{postId}/postComments/{id}
///  • respostas         → comments/{postId}/postComments/{id}/replies/{id}
/// O collectionGroup('postComments') sozinho nunca enxergava as
/// respostas — por isso elas simplesmente não apareciam aqui.
class CommentsTab extends StatefulWidget {
  final AdminCommentService commentService;
  final AdminUserService userService;

  const CommentsTab({
    required this.commentService,
    required this.userService,
    Key? key,
  }) : super(key: key);

  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab> {
  // Cada stream é criada UMA vez e reaproveitada (mesmo cuidado do app
  // público): criar dentro do build() reabriria o listener a cada
  // setState (ao trocar o filtro, por exemplo) e a lista piscaria.
  late final Stream<QuerySnapshot> _rootsStream =
      widget.commentService.allCommentsStream();
  late final Stream<QuerySnapshot> _repliesStream =
      widget.commentService.allRepliesStream();

  StreamSubscription<QuerySnapshot>? _rootsSub;
  StreamSubscription<QuerySnapshot>? _repliesSub;

  List<QueryDocumentSnapshot>? _roots;
  List<QueryDocumentSnapshot>? _replies;
  Object? _rootsError;
  // Falha ao carregar respostas NÃO derruba a aba inteira: os
  // comentários-raiz continuam utilizáveis e um aviso é mostrado.
  Object? _repliesError;

  _CommentFilter _filter = _CommentFilter.all;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _rootsSub?.cancel();
    _repliesSub?.cancel();
    _rootsSub = _rootsStream.listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _roots = snap.docs;
          _rootsError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _rootsError = e);
      },
    );
    _repliesSub = _repliesStream.listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _replies = snap.docs;
          _repliesError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _repliesError = e);
      },
    );
  }

  @override
  void dispose() {
    _rootsSub?.cancel();
    _repliesSub?.cancel();
    super.dispose();
  }

  // Os streams do Firestore já são em tempo real, então "puxar para
  // atualizar" só reinicia os listeners (útil depois de uma queda de
  // conexão ou de um erro) e devolve um Future que completa quando
  // chegam dados novos — antes o onRefresh era `() async {}` e o
  // indicador girava e sumia sem fazer nada.
  Future<void> _refresh() async {
    widget.commentService.clearCaches();
    setState(() {
      _roots = null;
      _replies = null;
      _rootsError = null;
      _repliesError = null;
    });
    _listen();
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted &&
        (_roots == null && _rootsError == null) &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundDark,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_rootsError != null) {
      return AdminErrorState(message: '$_rootsError');
    }
    if (_roots == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      );
    }

    final all = AdminCommentThreads.merge(
      roots: _roots!,
      replies: _replies ?? const [],
    );

    if (all.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'Nenhum comentário encontrado',
      );
    }

    final rootCount = all.where((i) => !i.isReply).length;
    final replyCount = all.where((i) => i.isReply).length;
    final hiddenCount = all.where((i) => i.isHidden).length;

    final visible = all.where((i) {
      switch (_filter) {
        case _CommentFilter.all:
          return true;
        case _CommentFilter.roots:
          return !i.isReply;
        case _CommentFilter.replies:
          return i.isReply;
        case _CommentFilter.hidden:
          return i.isHidden;
      }
    }).toList();

    final total = all.length;
    final headerText = '$total comentário${total != 1 ? 's' : ''}'
        '${replyCount > 0 ? ' · $replyCount resposta${replyCount != 1 ? 's' : ''}' : ''}'
        '${hiddenCount > 0 ? ' · $hiddenCount oculto${hiddenCount != 1 ? 's' : ''}' : ''}';

    return Column(
      children: [
        AdminSectionHeader(
          icon: Icons.chat_bubble_rounded,
          iconColor: AppColors.primaryOrange,
          text: headerText,
        ),
        _buildFilters(
          all: total,
          roots: rootCount,
          replies: replyCount,
          hidden: hiddenCount,
        ),
        if (_repliesError != null) _buildRepliesWarning(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: _refresh,
            child: visible.isEmpty
                ? ListView(
                    // ListView (e não Center) para o pull-to-refresh
                    // continuar funcionando com a lista filtrada vazia.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      AdminEmptyState(
                        icon: Icons.filter_alt_off_rounded,
                        message: 'Nenhum item neste filtro',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final item = visible[i];
                      return AdminCommentTile(
                        // Chave estável: sem ela, ao filtrar ou ao
                        // chegar um comentário novo no topo, o estado
                        // ("ver mais" aberto) pulava para outro tile.
                        key: ValueKey(
                            '${item.postId}/${item.parentCommentId ?? ''}/${item.id}'),
                        item: item,
                        commentService: widget.commentService,
                        userService: widget.userService,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters({
    required int all,
    required int roots,
    required int replies,
    required int hidden,
  }) {
    Widget chip(_CommentFilter f, String label, int count) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryOrange.withOpacity(0.16)
                  : const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primaryOrange.withOpacity(0.6)
                    : AppColors.borderDark,
              ),
            ),
            child: Text(
              '$label · $count',
              style: TextStyle(
                color:
                    selected ? AppColors.primaryOrange : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        children: [
          chip(_CommentFilter.all, 'Todos', all),
          chip(_CommentFilter.roots, 'Comentários', roots),
          chip(_CommentFilter.replies, 'Respostas', replies),
          chip(_CommentFilter.hidden, 'Ocultos', hidden),
        ],
      ),
    );
  }

  Widget _buildRepliesWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Color(0xFFFF9800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Não foi possível carregar as respostas — só os '
              'comentários principais estão sendo exibidos. '
              'Puxe a lista para baixo para tentar de novo.\n'
              'Detalhe: $_repliesError',
              style: const TextStyle(
                color: Color(0xFFFF9800),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}