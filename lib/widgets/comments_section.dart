import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/user_xp_provider.dart';

// ─────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────
class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anônimo',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────
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
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  bool _xpAwarded = false;
  late AnimationController _sendAnim;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sendAnim.dispose();
    super.dispose();
  }

  CollectionReference get _commentsRef => FirebaseFirestore.instance
      .collection('comments')
      .doc(widget.postId)
      .collection('postComments');

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
    if (text.isEmpty) return;
    if (text.length < 3) {
      _showSnack('Comentário muito curto.');
      return;
    }

    setState(() => _isSending = true);
    _sendAnim.reverse().then((_) => _sendAnim.forward());

    try {
      final userName = user.displayName ??
          user.email?.split('@').first ??
          'Leitor';

      await _commentsRef.add({
        'userId': user.uid,
        'userName': userName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _controller.clear();
      _focusNode.unfocus();

      // XP: concede apenas uma vez por post
      if (!_xpAwarded) {
        if (mounted) {
          await Provider.of<UserXpProvider>(context, listen: false)
              .addXpForComment();
          _xpAwarded = true;
          _showXpSnack();
        }
      }
    } catch (e) {
      _showSnack('Erro ao enviar comentário. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showLoginSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                color: Colors.white, size: 16),
            SizedBox(width: 10),
            Text('Faça login para comentar.',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.backgroundElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showXpSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.star_rounded,
                color: AppColors.primaryOrange, size: 18),
            SizedBox(width: 10),
            Text('+XP por comentar!',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: const Color(0xFF1A0800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
        // ── HEADER ──────────────────────────────────────────────
        _buildHeader(),

        // ── CAMPO DE COMENTÁRIO ──────────────────────────────────
        _buildInputArea(user),

        const SizedBox(height: 8),

        // ── LISTA DE COMENTÁRIOS ─────────────────────────────────
        _buildCommentsList(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _commentsRef
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  gradient: AppColors.orangeVertical,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'COMENTÁRIOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(width: 10),
              // Contador
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.primaryOrange.withOpacity(0.15),
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INPUT
  // ─────────────────────────────────────────────────────────────
  Widget _buildInputArea(User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0A0A0A),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.2),
          ),
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
                // Avatar do usuário
                _buildAvatar(
                  user?.displayName ??
                      user?.email?.split('@').first ??
                      '?',
                  size: 36,
                ),
                const SizedBox(width: 12),

                // Campo de texto
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 500,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: user != null
                          ? 'Deixe seu comentário...'
                          : 'Faça login para comentar',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      counterStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    enabled: user != null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Linha divisória + botão enviar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dica de XP
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 13,
                        color: AppColors.primaryOrange.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Ganhe XP ao comentar',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

                // Botão enviar
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
                        gradient: _isSending
                            ? null
                            : AppColors.orangeGradient,
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
                                color: AppColors.primaryOrange,
                              ),
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

  // ─────────────────────────────────────────────────────────────
  // LISTA
  // ─────────────────────────────────────────────────────────────
  Widget _buildCommentsList() {
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
                  strokeWidth: 2,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
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
            initials: _initials(comments[index].userName),
            timeAgo: _timeAgo(comments[index].createdAt),
            currentUserId:
                FirebaseAuth.instance.currentUser?.uid ?? '',
            onDelete: () => _deleteComment(comments[index].id),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 40,
            color: AppColors.primaryOrange.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seja o primeiro a comentar!',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _commentsRef.doc(commentId).delete();
    } catch (_) {}
  }

  Widget _buildAvatar(String name, {double size = 40}) {
    final colors = [
      [const Color(0xFFFF6B00), const Color(0xFFCC4400)],
      [const Color(0xFFFF8C3A), const Color(0xFFFF6B00)],
      [const Color(0xFFE65100), const Color(0xFF8D3200)],
    ];
    final colorPair =
        colors[name.codeUnitAt(0) % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TILE DE COMENTÁRIO
// ─────────────────────────────────────────────────────────────────
class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final String initials;
  final String timeAgo;
  final String currentUserId;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.initials,
    required this.timeAgo,
    required this.currentUserId,
    required this.onDelete,
  });

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
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isOwner =>
      widget.comment.userId == widget.currentUserId;

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
