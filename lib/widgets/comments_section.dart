import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/user_xp_provider.dart';
import '../features/admin/providers/admin_provider.dart';
import 'badge_widgets.dart';
import 'avatar_frame.dart';
import 'app_avatar.dart';

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;
  final int userLevel;
  final List<String> userAchievements;
  final String userAvatarId;
  final String? userPhotoUrl;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.userLevel = 1,
    this.userAchievements = const [],
    this.userAvatarId = 'animais_01',
    this.userPhotoUrl,
  });

  factory CommentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anônimo',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userLevel: (data['userLevel'] as num?)?.toInt() ?? 1,
      userAchievements: List<String>.from(data['userAchievements'] ?? []),
      userAvatarId: (data['userAvatarId'] as String?) ?? 'animais_01',
      userPhotoUrl: data['userPhotoUrl'] as String?,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — PERFIL DO COMENTARISTA
// ═══════════════════════════════════════════════════════════════════
class _CommentUserProfileSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final int userLevel;
  final List<String> userAchievements;

  const _CommentUserProfileSheet({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userLevel,
    required this.userAchievements,
  }) : super(key: key);

  @override
  State<_CommentUserProfileSheet> createState() =>
      _CommentUserProfileSheetState();
}

class _CommentUserProfileSheetState extends State<_CommentUserProfileSheet> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  Map<String, dynamic>? _userData;

  String get _myUid => _auth.currentUser?.uid ?? '';
  bool get _isMe => widget.userId == _myUid;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _db.collection('users_xp').doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() => _userData = doc.data());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    final hasHadBirthdayThisYear = (today.month > birthDate.month) ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] as String?) ?? '';
    final totalXp = (_userData?['totalXp'] as num?)?.toInt() ?? 0;
    final photoUrl = _userData?['photoUrl'] as String?;
    final showAge = _userData?['showAge'] as bool? ?? false;
    final birthDate = (_userData?['birthDate'] as Timestamp?)?.toDate();
    final age = (showAge && birthDate != null) ? _calculateAge(birthDate) : null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A)),
          left: BorderSide(color: Color(0xFF111111)),
          right: BorderSide(color: Color(0xFF111111)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar com moldura + info
          Row(
            children: [
              AvatarFrame(
                level: widget.userLevel,
                size: 60,
                child: AppAvatar(
                  name: widget.userName,
                  seed: widget.userId,
                  photoUrl: photoUrl,
                  size: 60,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: AppColors.primaryOrange.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (age != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$age anos',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        LevelBadgeInline(level: widget.userLevel),
                        const SizedBox(width: 6),
                        FrameRarityTag(level: widget.userLevel, fontSize: 8),
                        if (totalXp > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '$totalXp XP',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Conquistas
          if (widget.userAchievements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: UnlockedBadgesRow(
                unlockedAchievements: widget.userAchievements,
                maxVisible: widget.userAchievements.length,
                badgeSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (_isMe)
            _InfoBanner(
              icon: Icons.person_rounded,
              text: 'Este é o seu perfil',
              color: AppColors.primaryOrange,
            )
          else if (_loading)
            const SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEÇÃO PRINCIPAL DE COMENTÁRIOS
// ═══════════════════════════════════════════════════════════════════
class CommentsSection extends StatefulWidget {
  final String postId;
  final String postTitle;

  const CommentsSection({
    Key? key,
    required this.postId,
    required this.postTitle,
  }) : super(key: key);

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  bool _xpAwarded = false;
  bool _expanded = false;
  late AnimationController _sendAnim;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sendAnim.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  CollectionReference get _commentsRef => FirebaseFirestore.instance
      .collection('comments')
      .doc(widget.postId)
      .collection('postComments');

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _controller.text.trim();

    if (user == null) {
      _showLoginSnack();
      return;
    }

    final suspension = await FirebaseFirestore.instance
        .collection('suspensions')
        .doc(user.uid)
        .get();

    if (suspension.exists) {
      final data = suspension.data()!;
      final until = (data['until'] as Timestamp?)?.toDate();
      final isPermanent = until == null;
      final isActive = isPermanent || DateTime.now().isBefore(until!);

      if (isActive) {
        final reason = (data['reason'] as String?)?.trim() ?? '';
        final reasonText = reason.isNotEmpty ? '\nMotivo: $reason' : '';
        if (isPermanent) {
          _showSnack('Você foi banido permanentemente.$reasonText');
        } else {
          final fmt = '${until.day}/${until.month}/${until.year}';
          _showSnack('Você está suspenso até $fmt.$reasonText');
        }
        setState(() => _isSending = false);
        return;
      }
    }

    if (text.isEmpty) return;
    if (text.length < 3) {
      _showSnack('Comentário muito curto.');
      return;
    }

    setState(() => _isSending = true);
    _sendAnim.reverse().then((_) => _sendAnim.forward());

    try {
      final userName =
          user.displayName ?? user.email?.split('@').first ?? 'Leitor';
      final xpProvider = Provider.of<UserXpProvider>(context, listen: false);
      final userLevel = xpProvider.data.level;
      final userAchievements = xpProvider.data.achievements;
      final userAvatarId = xpProvider.data.avatarId;
      final userPhotoUrl = xpProvider.data.photoUrl;

      await _commentsRef.add({
        'userId': user.uid,
        'userName': userName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'userLevel': userLevel,
        'userAchievements': userAchievements,
        'userAvatarId': userAvatarId,
        'userPhotoUrl': userPhotoUrl,
      });

      _controller.clear();
      _focusNode.unfocus();

      if (!_xpAwarded && mounted) {
        await xpProvider.addXpForComment();
        _xpAwarded = true;
        _showXpSnack();
      }
    } catch (e) {
      _showSnack('Erro ao enviar comentário. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _commentsRef.doc(commentId).delete();
    } catch (e) {
      if (mounted) _showSnack('Erro ao excluir: $e');
    }
  }

  void _openUserProfile(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentUserProfileSheet(
        userId: comment.userId,
        userName: comment.userName,
        userLevel: comment.userLevel,
        userAchievements: comment.userAchievements,
      ),
    );
  }

  void _showLoginSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
          SizedBox(width: 10),
          Text('Faça login para comentar.',
              style: TextStyle(color: Colors.white)),
        ]),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showXpSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.star_rounded, color: AppColors.primaryOrange, size: 18),
          SizedBox(width: 10),
          Text('+XP por comentar!',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFF1A0800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToggleButton(),
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: _expandAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildInputArea(user),
                const SizedBox(height: 8),
                _buildCommentsList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Botão único que abre/fecha os comentários ────────────────────
  Widget _buildToggleButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: _commentsRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF0A0A0A),
                border: Border.all(
                  color: AppColors.primaryOrange
                      .withOpacity(_expanded ? 0.45 : 0.2),
                ),
                boxShadow: _expanded
                    ? [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.12),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 17, color: AppColors.primaryOrange),
                  const SizedBox(width: 10),
                  Text(
                    count > 0 ? 'Comentários ($count)' : 'Comentar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryOrange.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.05),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 500,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: user != null
                          ? '💭 O que você achou desta notícia?'
                          : 'Faça login para comentar',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 14),
                      border: InputBorder.none,
                      counterStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                      contentPadding: EdgeInsets.zero,
                    ),
                    enabled: user != null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 13,
                        color: AppColors.primaryOrange.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    const Text(
                      'Ganhe XP ao comentar',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                ScaleTransition(
                  scale: _sendAnim,
                  child: GestureDetector(
                    onTap: _isSending ? null : _sendComment,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient:
                            _isSending ? null : AppColors.orangeGradient,
                        color: _isSending
                            ? AppColors.backgroundElevated
                            : null,
                        boxShadow: _isSending
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.primaryOrange
                                      .withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryOrange),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'ENVIAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputAvatar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Consumer<UserXpProvider>(
      builder: (context, xpProvider, _) {
        return AvatarFrame(
          level: xpProvider.data.level,
          size: 36,
          child: AppAvatar(
            name: currentUser?.displayName ??
                currentUser?.email?.split('@').first ??
                'Leitor',
            seed: currentUser?.uid,
            photoUrl: xpProvider.data.photoUrl,
            size: 36,
          ),
        );
      },
    );
  }

  Widget _buildCommentsList() {
    final isAdmin =
        Provider.of<AdminProvider>(context, listen: false).isAdmin;

    return StreamBuilder<QuerySnapshot>(
      stream: _commentsRef
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryOrange),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final comments = snapshot.data!.docs
            .map((doc) => CommentModel.fromDoc(doc))
            .toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          itemCount: comments.length,
          itemBuilder: (context, index) => _CommentTile(
            comment: comments[index],
            timeAgo: _timeAgo(comments[index].createdAt),
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            isAdmin: isAdmin,
            onDelete: () => _deleteComment(comments[index].id),
            onTapUser: () => _openUserProfile(comments[index]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// COMMENT TILE
// ═══════════════════════════════════════════════════════════════════
class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final String timeAgo;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback onDelete;
  final VoidCallback onTapUser;

  const _CommentTile({
    Key? key,
    required this.comment,
    required this.timeAgo,
    required this.currentUserId,
    required this.isAdmin,
    required this.onDelete,
    required this.onTapUser,
  }) : super(key: key);

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isOwner => widget.comment.userId == widget.currentUserId;
  bool get _canDelete => _isOwner || widget.isAdmin;

  void _confirmDelete(BuildContext context) {
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primaryOrange.withOpacity(0.2)),
        ),
        title: const Text('Excluir comentário?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          widget.isAdmin && !_isOwner
              ? 'Você está excluindo o comentário de ${widget.comment.userName} como administrador.'
              : 'Esta ação não pode ser desfeita.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => rootNav.pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              rootNav.pop();
              widget.onDelete();
            },
            child: const Text('Excluir',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: widget.onTapUser,
      child: AvatarFrame(
        level: widget.comment.userLevel,
        size: 36,
        child: AppAvatar(
          name: widget.comment.userName,
          seed: widget.comment.userId,
          photoUrl: widget.comment.userPhotoUrl,
          size: 36,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF0D0D0D),
            border: Border.all(
              color: _isOwner
                  ? AppColors.primaryOrange.withOpacity(0.25)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: widget.onTapUser,
                                  child: Text(
                                    widget.comment.userName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _isOwner
                                          ? AppColors.primaryOrange
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _isOwner
                                          ? AppColors.primaryOrange
                                              .withOpacity(0.4)
                                          : Colors.white.withOpacity(0.2),
                                      decorationStyle:
                                          TextDecorationStyle.dotted,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isOwner) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: AppColors.primaryOrange
                                        .withOpacity(0.15),
                                  ),
                                  child: const Text(
                                    'EU',
                                    style: TextStyle(
                                      color: AppColors.primaryOrange,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 5),
                              LevelBadgeInline(
                                  level: widget.comment.userLevel),
                              if (widget.comment.userAchievements.isNotEmpty)
                                UnlockedBadgesRow(
                                  unlockedAchievements:
                                      widget.comment.userAchievements,
                                  maxVisible:
                                      widget.comment.userAchievements.length,
                                  badgeSize: 9,
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              widget.timeAgo,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                            if (_canDelete) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _confirmDelete(context),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 15,
                                  color: widget.isAdmin && !_isOwner
                                      ? AppColors.emergencyRed
                                          .withOpacity(0.7)
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.comment.text,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}