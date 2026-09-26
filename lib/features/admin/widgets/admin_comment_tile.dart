import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/app_avatar.dart';
import '../../../widgets/app_messenger.dart';
import '../../../widgets/avatar_frame.dart';
import '../../../widgets/badge_widgets.dart';
import '../services/admin_comment_service.dart';
import '../services/admin_user_service.dart';
import 'admin_shared_widgets.dart';
import 'user_profile_sheet.dart';

/// Tile de moderação de UM comentário-raiz ou de UMA resposta.
///
/// Os dados do autor (nome, foto, nível, avatar premium) vêm do perfil
/// ATUAL em users_xp/{uid} — o mesmo critério do app público em
/// comments_section.dart — e só caem no snapshot congelado salvo no
/// próprio comentário quando o perfil não existe mais (conta excluída).
///
/// Campos gravados pelo app em cada comentário/resposta:
///   userId, userName, username, text, createdAt, userLevel,
///   userAchievements, userAvatarId, userPhotoUrl,
///   userEquippedPremiumAvatarId, likesCount, repliesCount (só raiz),
///   replyToUsername (só resposta), edited/editedAt, hidden/hiddenAt.
class AdminCommentTile extends StatefulWidget {
  final AdminCommentItem item;
  final AdminCommentService commentService;
  final AdminUserService userService;

  const AdminCommentTile({
    required this.item,
    required this.commentService,
    required this.userService,
    Key? key,
  }) : super(key: key);

  @override
  State<AdminCommentTile> createState() => _AdminCommentTileState();
}

class _AdminCommentTileState extends State<AdminCommentTile> {
  static const _violet = Color(0xFF9575CD);
  static const _blue = Color(0xFF4FC3F7);
  static const _red = Color(0xFFEF5350);
  static const _amber = Color(0xFFFF9800);

  bool _expanded = false;
  bool _busy = false;

  AdminCommentItem get _item => widget.item;
  Map<String, dynamic> get _data => _item.data;

  // ── Helpers de leitura ─────────────────────────────────────────────

  String? _str(Map<String, dynamic>? d, String key) {
    final v = d?[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  int _int(Map<String, dynamic>? d, String key, [int fallback = 0]) =>
      (d?[key] as num?)?.toInt() ?? fallback;

  /// Id do autor. O app grava `userId`; `authorId`/`uid` ficam só
  /// como tolerância a documentos de versões antigas.
  String? get _authorId {
    for (final f in ['userId', 'authorId', 'uid', 'user_id']) {
      final v = _str(_data, f);
      if (v != null) return v;
    }
    return null;
  }

  String _formatDate(DateTime? ts) {
    if (ts == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(ts.day)}/${two(ts.month)}/${ts.year}  '
        '${two(ts.hour)}:${two(ts.minute)}';
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authorId = _authorId;
    if (authorId == null) return _buildCard(context, null);

    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.commentService.authorProfile(authorId),
      builder: (context, snap) {
        // Enquanto carrega (ou se o perfil não existe mais), cai no
        // snapshot congelado salvo no próprio comentário.
        return _buildCard(context, snap.data);
      },
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic>? profile) {
    final authorId = _authorId;
    final isHidden = _item.isHidden;
    final isReply = _item.isReply;

    // ── Nome: perfil ao vivo → snapshot do comentário → e-mail ──────
    final emailName = _str(profile, 'email')?.split('@').first;
    final displayName = _str(profile, 'displayName') ??
        _str(profile, 'name') ??
        _str(_data, 'userName') ??
        _str(_data, 'authorName') ??
        emailName ??
        'Anônimo';
    final username = _str(profile, 'username') ?? _str(_data, 'username');

    // ── Foto e avatar premium: perfil ao vivo → snapshot ────────────
    final photoUrl = _str(profile, 'photoUrl') ??
        _str(_data, 'userPhotoUrl') ??
        _str(_data, 'authorPhotoUrl');
    final premiumAvatar = _str(profile, 'equippedPremiumAvatarId') ??
        _str(_data, 'userEquippedPremiumAvatarId');
    // Recompensa de check-in não é congelada no snapshot do
    // comentário: só existe no perfil ao vivo (users_xp/{uid}).
    final checkinReward = _str(profile, 'equippedCheckinRewardId');

    // ── Nível: perfil ao vivo → snapshot do comentário ──────────────
    final rawLevel = _int(profile, 'level', _int(_data, 'userLevel', 1));
    final int level = rawLevel < 1 ? 1 : (rawLevel > 999 ? 999 : rawLevel);

    final isPremium = _isPremium(profile);

    final text =
        (_data['text'] ?? _data['content'] ?? _data['body'] ?? '')
            .toString();
    final mention = _str(_data, 'replyToUsername');
    final likes = _int(_data, 'likesCount');
    final repliesCount = _int(_data, 'repliesCount');
    final edited = _data['edited'] == true;
    final createdAt = (_data['createdAt'] as Timestamp?)?.toDate();

    final accent = isReply ? _blue : AppColors.primaryOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHidden
              ? AppColors.textSecondary.withOpacity(0.2)
              : AppColors.borderDark,
        ),
      ),
      child: Opacity(
        opacity: isHidden ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostHeader(accent),
              if (isReply) _buildReplyContext(),
              _buildAuthorRow(
                displayName: displayName,
                username: username,
                photoUrl: photoUrl,
                premiumAvatar: premiumAvatar,
                checkinReward: checkinReward,
                level: level,
                authorId: authorId,
                isPremium: isPremium,
                createdAt: createdAt,
                isHidden: isHidden,
              ),
              const SizedBox(height: 10),
              _buildText(text, mention),
              const SizedBox(height: 10),
              _buildStatsRow(
                likes: likes,
                repliesCount: repliesCount,
                edited: edited,
              ),
              const SizedBox(height: 12),
              _buildActions(context, displayName, authorId),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPremium(Map<String, dynamic>? profile) {
    final tier = _str(profile, 'premiumTier');
    if (tier == null || tier == 'none') return false;
    final exp = (profile?['premiumExpiresAt'] as Timestamp?)?.toDate();
    return exp == null || exp.isAfter(DateTime.now());
  }

  // ── Publicação onde o comentário foi feito ─────────────────────────

  Widget _buildPostHeader(Color accent) {
    return FutureBuilder<PostRef>(
      future: widget.commentService.resolvePost(_item.postId),
      builder: (context, snap) {
        final ref = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        final found = ref != null && ref.exists;

        final String label;
        if (loading) {
          label = 'Carregando publicação…';
        } else if (found) {
          label = ref.title;
        } else {
          label = 'Publicação indisponível'
              '${_item.postId.isNotEmpty ? ' (${_shortId(_item.postId)})' : ''}';
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                _item.isReply
                    ? Icons.reply_rounded
                    : Icons.article_outlined,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        found ? Colors.white : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if (_item.isReply) ...[
                const SizedBox(width: 6),
                AdminBadge(label: 'RESPOSTA', color: accent),
              ],
            ],
          ),
        );
      },
    );
  }

  String _shortId(String id) =>
      id.length <= 10 ? id : '${id.substring(0, 10)}…';

  // ── "Em resposta a <fulano>: <trecho>" ─────────────────────────────

  Widget _buildReplyContext() {
    final parentText = _item.parentText;
    final parentAuthor = _item.parentAuthorName;
    final hasParent = parentText != null && parentText.trim().isNotEmpty;
    final authorLabel =
        (parentAuthor != null && parentAuthor.isNotEmpty)
            ? parentAuthor
            : 'comentário';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(left: BorderSide(color: _blue, width: 2.5)),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasParent
                ? 'Em resposta a $authorLabel'
                : 'Em resposta a um comentário que não está mais na lista',
            style: const TextStyle(
              color: _blue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasParent) ...[
            const SizedBox(height: 3),
            Text(
              parentText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Autor: avatar + nome + @username + nível ───────────────────────

  Widget _buildAuthorRow({
    required String displayName,
    required String? username,
    required String? photoUrl,
    required String? premiumAvatar,
    required String? checkinReward,
    required int level,
    required String? authorId,
    required bool isPremium,
    required DateTime? createdAt,
    required bool isHidden,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarFrame(
          level: level,
          size: 40,
          child: UserAvatarDisplay(
            name: displayName,
            seed: authorId,
            photoUrl: photoUrl,
            equippedPremiumAvatarId: premiumAvatar,
            equippedCheckinRewardId: checkinReward,
            size: 40,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (username != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primaryOrange.withOpacity(0.8),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LevelBadgeInline(level: level),
                  FrameRarityTag(level: level, fontSize: 8),
                  if (isPremium)
                    const AdminBadge(label: 'PREMIUM', color: _amber),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isHidden)
          const AdminBadge(label: 'Oculto', color: AppColors.textSecondary),
      ],
    );
  }

  // ── Texto (com @menção destacada e "ver mais") ─────────────────────

  Widget _buildText(String text, String? mention) {
    const style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      height: 1.5,
    );

    // Heurística simples de "texto longo" para decidir se mostra o
    // botão de expandir (evita medir o layout só para isso).
    final isLong = text.length > 140 || '\n'.allMatches(text).length >= 3;

    final Widget body = mention == null
        ? Text(
            text.isEmpty ? '(sem texto)' : text,
            style: style,
            maxLines: _expanded ? null : 4,
            overflow:
                _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          )
        : RichText(
            maxLines: _expanded ? null : 4,
            overflow:
                _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            text: TextSpan(
              style: style,
              children: [
                TextSpan(
                  text: '@$mention ',
                  style: TextStyle(
                    color: AppColors.primaryOrange.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: text),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver mais',
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Curtidas / respostas / editado ─────────────────────────────────

  Widget _buildStatsRow({
    required int likes,
    required int repliesCount,
    required bool edited,
  }) {
    Widget chip(IconData icon, String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        chip(
          Icons.favorite_rounded,
          '$likes ${likes == 1 ? 'curtida' : 'curtidas'}',
          likes > 0 ? _red : AppColors.textMuted,
        ),
        if (!_item.isReply)
          chip(
            Icons.chat_bubble_outline_rounded,
            '$repliesCount ${repliesCount == 1 ? 'resposta' : 'respostas'}',
            repliesCount > 0 ? _violet : AppColors.textMuted,
          ),
        if (edited)
          chip(Icons.edit_rounded, 'editado', AppColors.textMuted),
      ],
    );
  }

  // ── Ações de moderação ─────────────────────────────────────────────

  Widget _buildActions(
    BuildContext context,
    String displayName,
    String? authorId,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_item.isHidden)
              AdminActionButton(
                icon: Icons.visibility_rounded,
                label: 'Restaurar',
                color: _blue,
                onTap: () => _run(
                  context,
                  () => widget.commentService.restoreComment(
                    _item.postId,
                    _item.id,
                    parentCommentId: _item.parentCommentId,
                  ),
                  okMessage: 'Comentário restaurado.',
                ),
              )
            else
              AdminActionButton(
                icon: Icons.visibility_off_rounded,
                label: 'Ocultar',
                color: AppColors.textSecondary,
                onTap: () => _run(
                  context,
                  () => widget.commentService.hideComment(
                    _item.postId,
                    _item.id,
                    parentCommentId: _item.parentCommentId,
                  ),
                  okMessage: 'Comentário ocultado dos leitores.',
                ),
              ),
            const SizedBox(width: 8),
            AdminActionButton(
              icon: Icons.delete_rounded,
              label: 'Excluir',
              color: _red,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
        if (authorId != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AdminActionButton(
                icon: Icons.badge_rounded,
                label: 'Ver perfil / Banir',
                color: _amber,
                onTap: () => showUserProfileSheet(
                  context,
                  userId: authorId,
                  userService: widget.userService,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Executa uma ação de moderação mostrando erro real ao admin, em
  /// vez de falhar em silêncio (antes, qualquer exceção do Firestore
  /// era engolida e o botão parecia "não fazer nada").
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    String? okMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (okMessage != null) {
        AppMessenger.success(okMessage);
      }
    } catch (e) {
      AppMessenger.error('Não foi possível concluir: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final isReply = _item.isReply;
    final replies = _int(_data, 'repliesCount');

    final String message;
    if (!isReply && replies > 0) {
      final plural = replies == 1
          ? 'resposta, que também será excluída'
          : 'respostas, que também serão excluídas';
      message = 'Este comentário tem $replies $plural. '
          'Esta ação não pode ser desfeita.';
    } else {
      message = 'Esta ação não pode ser desfeita.';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: isReply ? 'Excluir resposta?' : 'Excluir comentário?',
        message: message,
        confirmLabel: 'Excluir',
        confirmColor: _red,
      ),
    );
    if (confirm != true || !context.mounted) return;

    await _run(
      context,
      () => widget.commentService.deleteComment(
        _item.postId,
        _item.id,
        parentCommentId: _item.parentCommentId,
      ),
      okMessage: isReply ? 'Resposta excluída.' : 'Comentário excluído.',
    );
  }

}