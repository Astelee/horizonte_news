import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';
import 'amigos_modelos.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO DE MENSAGEM
// ═══════════════════════════════════════════════════════════════════
class MessageModel {
  final String id;
  final String text;
  final String senderUid;
  final DateTime sentAt;
  final bool deletedForMe;
  final MessageStatus status;

  const MessageModel({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.sentAt,
    this.deletedForMe = false,
    this.status = MessageStatus.sent,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final statusStr = (d['status'] as String?) ?? 'sent';
    MessageStatus status;
    switch (statusStr) {
      case 'delivered':
        status = MessageStatus.delivered;
        break;
      case 'read':
        status = MessageStatus.read;
        break;
      default:
        status = MessageStatus.sent;
    }

    return MessageModel(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      senderUid: (d['senderUid'] as String?) ?? '',
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedForMe: (d['deletedForMe'] as bool?) ?? false,
      status: status,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TELA DE CHAT
// ═══════════════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final FriendModel friend;

  const ChatScreen({Key? key, required this.friend}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  String get _myUid => _auth.currentUser?.uid ?? '';

  String get _chatId {
    final ids = [_myUid, widget.friend.uid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  CollectionReference get _messagesRef =>
      _db.collection('chats').doc(_chatId).collection('messages');

  @override
  void initState() {
    super.initState();
    _markIncomingAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Marca como "lida" todas as mensagens recebidas ainda não lidas ──
  Future<void> _markIncomingAsRead() async {
    try {
      final snap = await _messagesRef
          .where('senderUid', isEqualTo: widget.friend.uid)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();

      // Zera contador de não lidas no chat
      await _db.collection('chats').doc(_chatId).set({
        'unreadCount_$_myUid': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();
    HapticFeedback.lightImpact();

    try {
      await _db.collection('chats').doc(_chatId).set({
        'participants': [_myUid, widget.friend.uid],
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': _myUid,
        'lastMessageStatus': 'sent',
        'unreadCount_${widget.friend.uid}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      final docRef = await _messagesRef.add({
        'text': text,
        'senderUid': _myUid,
        'sentAt': FieldValue.serverTimestamp(),
        'deletedFor': [],
        'status': 'sent',
      });

      // Simula "entregue" pouco depois do envio (se o destinatário estiver
      // com o app aberto, isso seria atualizado por uma Cloud Function;
      // aqui fazemos client-side como fallback simples)
      Future.delayed(const Duration(seconds: 1), () {
        docRef.update({'status': 'delivered'}).catchError((_) {});
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao enviar mensagem.'),
            backgroundColor: AppColors.emergencyRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    await _messagesRef.doc(msg.id).update({
      'deletedFor': FieldValue.arrayUnion([_myUid]),
    });
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Limpar conversa?',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Todas as mensagens serão apagadas apenas para você. O contato permanece na sua lista de amigos.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Limpar',
              style: TextStyle(
                  color: AppColors.emergencyRed,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final snap = await _messagesRef.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([_myUid]),
      });
    }
    await batch.commit();
    HapticFeedback.mediumImpact();
  }

  void _showMessageOptions(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Color(0xFF1A1A1A)),
            left: BorderSide(color: Color(0xFF1A1A1A)),
            right: BorderSide(color: Color(0xFF1A1A1A)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionTile(
              icon: Icons.copy_rounded,
              label: 'Copiar mensagem',
              color: Colors.white,
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Mensagem copiada!'),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Apagar mensagem (para mim)',
              color: AppColors.emergencyRed,
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 8,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.friend.displayName.isNotEmpty
                        ? widget.friend.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.friend.isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF555555),
                    border:
                        Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.friend.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: widget.friend.isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: const Color(0xFF0A0A0A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (value) {
              if (value == 'clear') _clearConversation();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded,
                        color: AppColors.emergencyRed, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'Limpar conversa',
                      style: TextStyle(
                          color: AppColors.emergencyRed,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesRef
          .orderBy('sentAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryOrange,
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];

        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final deletedFor =
              List<String>.from(d['deletedFor'] ?? []);
          return !deletedFor.contains(_myUid);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: AppColors.primaryOrange.withOpacity(0.2),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nenhuma mensagem ainda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Diga olá para @${widget.friend.username}!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        // Marca como lida em tempo real enquanto a tela está aberta
        _markIncomingAsRead();
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final msg = MessageModel.fromDoc(docs[i]);
            final isMe = msg.senderUid == _myUid;

            final showDate = i == 0 ||
                !_isSameDay(
                  MessageModel.fromDoc(docs[i - 1]).sentAt,
                  msg.sentAt,
                );

            return Column(
              children: [
                if (showDate) _DateDivider(date: msg.sentAt),
                _MessageBubble(
                  msg: msg,
                  isMe: isMe,
                  onLongPress: () => _showMessageOptions(msg),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Mensagem...',
                  hintStyle: TextStyle(
                      color: Color(0xFF424242), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.orangeGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═══════════════════════════════════════════════════════════════════
// BUBBLE DE MENSAGEM
// ═══════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe ? AppColors.orangeGradient : null,
            color: isMe ? null : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: isMe
                ? [
                    BoxShadow(
                      color:
                          AppColors.primaryOrange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe
                      ? Colors.white
                      : const Color(0xFFE0E0E0),
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.sentAt),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.6)
                          : const Color(0xFF666666),
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _StatusIcon(status: msg.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ═══════════════════════════════════════════════════════════════════
// ÍCONE DE STATUS (ESTILO WHATSAPP)
// ═══════════════════════════════════════════════════════════════════
class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withOpacity(0.6),
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.done_rounded,
            size: 14, color: Colors.white.withOpacity(0.6));
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded,
            size: 14, color: Colors.white.withOpacity(0.6));
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Color(0xFF4FC3F7));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEPARADOR DE DATA
// ═══════════════════════════════════════════════════════════════════
class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: Color(0xFF1A1A1A), height: 1)),
          const SizedBox(width: 12),
          Text(
            _formatDate(date),
            style: const TextStyle(
              color: Color(0xFF555555),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Divider(color: Color(0xFF1A1A1A), height: 1)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoje';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Ontem';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// OPTION TILE DO BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
