import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../config/app_colors.dart';
import 'amigos_modelos.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO DE MENSAGEM
// ═══════════════════════════════════════════════════════════════════
enum MessageType { text }

class MessageModel {
  final String id;
  final String text;
  final String senderUid;
  final DateTime sentAt;
  final MessageStatus status;
  final MessageType type;
  final bool deletedForAll;
  final List<String> deletedFor;
  final bool isForwarded;

  const MessageModel({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.sentAt,
    this.status = MessageStatus.sent,
    this.type = MessageType.text,
    this.deletedForAll = false,
    this.deletedFor = const [],
    this.isForwarded = false,
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
      status: status,
      type: MessageType.text,
      deletedForAll: (d['deletedForAll'] as bool?) ?? false,
      deletedFor: List<String>.from(d['deletedFor'] ?? []),
      isForwarded: (d['isForwarded'] as bool?) ?? false,
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
  bool _hasText = false;

  late double _topPadding;

  Timer? _typingDebounce;
  bool _isTypingFlagSet = false;

  String get _myUid => _auth.currentUser?.uid ?? '';

  String get _chatId {
    final ids = [_myUid, widget.friend.uid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  CollectionReference get _messagesRef =>
      _db.collection('chats').doc(_chatId).collection('messages');

  // ✅ CORREÇÃO DO PROBLEMA 2:
  // Stream reativo que lê o status do amigo diretamente do Firestore.
  // Atualiza automaticamente sempre que o PresenceService espelha
  // uma mudança de estado.
  Stream<DocumentSnapshot> get _friendPresenceStream =>
      _db.collection('users_xp').doc(widget.friend.uid).snapshots();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topPadding = MediaQuery.of(context).padding.top;
  }

  @override
  void initState() {
    super.initState();
    _markIncomingAsRead();
    _unhideForMe();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _typingDebounce?.cancel();
    _setTyping(false);
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

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (has && !_isTypingFlagSet) _setTyping(true);
    _typingDebounce?.cancel();
    _typingDebounce =
        Timer(const Duration(seconds: 2), () => _setTyping(false));
    if (!has) {
      _typingDebounce?.cancel();
      _setTyping(false);
    }
  }

  Future<void> _setTyping(bool typing) async {
    if (_isTypingFlagSet == typing) return;
    _isTypingFlagSet = typing;
    try {
      await _db.collection('chats').doc(_chatId).set(
          {'isTyping_$_myUid': typing}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _unhideForMe() async {
    try {
      await _db.collection('chats').doc(_chatId).set({
        'hiddenFor': FieldValue.arrayRemove([_myUid]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _markIncomingAsRead() async {
    try {
      final snap = await _messagesRef
          .where('senderUid', isEqualTo: widget.friend.uid)
          .where('status', whereIn: ['sent', 'delivered']).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
      await _db.collection('chats').doc(_chatId).set(
          {'unreadCount_$_myUid': 0}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessage(
      {String? text, bool isForwarded = false}) async {
    final msg = (text ?? _controller.text).trim();
    if (msg.isEmpty || _sending) return;

    setState(() => _sending = true);
    if (text == null) _controller.clear();
    _typingDebounce?.cancel();
    _setTyping(false);
    HapticFeedback.lightImpact();

    try {
      await _db.collection('chats').doc(_chatId).set({
        'participants': [_myUid, widget.friend.uid],
        'lastMessage': isForwarded ? '📨 $msg' : msg,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': _myUid,
        'lastMessageStatus': 'sent',
        'unreadCount_${widget.friend.uid}': FieldValue.increment(1),
        'hiddenFor': FieldValue.arrayRemove([widget.friend.uid, _myUid]),
      }, SetOptions(merge: true));

      final docRef = await _messagesRef.add({
        'text': msg,
        'senderUid': _myUid,
        'sentAt': FieldValue.serverTimestamp(),
        'deletedFor': [],
        'deletedForAll': false,
        'status': 'sent',
        'type': 'text',
        'isForwarded': isForwarded,
      });

      Future.delayed(const Duration(seconds: 1), () {
        docRef.update({'status': 'delivered'}).catchError((_) {});
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erro ao enviar mensagem.'),
          backgroundColor: AppColors.emergencyRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteForMe(MessageModel msg) async {
    await _messagesRef.doc(msg.id).update({
      'deletedFor': FieldValue.arrayUnion([_myUid]),
    });
  }

  Future<void> _deleteForAll(MessageModel msg) async {
    await _messagesRef.doc(msg.id).update({
      'deletedForAll': true,
      'text': 'Esta mensagem foi apagada',
    });
  }

  void _forwardMessage(MessageModel msg) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ForwardSheet(
        myUid: _myUid,
        db: _db,
        messageText: msg.text,
        onForward: (friendUid, friendModel) async {
          final ids = [_myUid, friendUid]..sort();
          final targetChatId = '${ids[0]}_${ids[1]}';

          await _db.collection('chats').doc(targetChatId).set({
            'participants': [_myUid, friendUid],
            'lastMessage': '📨 ${msg.text}',
            'lastMessageAt': FieldValue.serverTimestamp(),
            'lastMessageBy': _myUid,
            'lastMessageStatus': 'sent',
            'unreadCount_$friendUid': FieldValue.increment(1),
            'hiddenFor': FieldValue.arrayRemove([friendUid, _myUid]),
          }, SetOptions(merge: true));

          await _db
              .collection('chats')
              .doc(targetChatId)
              .collection('messages')
              .add({
            'text': msg.text,
            'senderUid': _myUid,
            'sentAt': FieldValue.serverTimestamp(),
            'deletedFor': [],
            'deletedForAll': false,
            'status': 'sent',
            'type': 'text',
            'isForwarded': true,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Mensagem encaminhada para ${friendModel.displayName}!'),
              backgroundColor: const Color(0xFF1A1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
        },
      ),
    );
  }

  Future<void> _clearConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpar conversa?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Todas as mensagens serão apagadas apenas para você.',
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
            child: const Text('Limpar',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final snap = await _messagesRef.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference,
          {'deletedFor': FieldValue.arrayUnion([_myUid])});
    }
    await batch.commit();

    await _db.collection('chats').doc(_chatId).set({
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': '',
      'lastMessageStatus': '',
      'unreadCount_$_myUid': 0,
      'hiddenFor': FieldValue.arrayUnion([_myUid]),
    }, SetOptions(merge: true));

    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
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
            if (!msg.deletedForAll)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryOrange.withOpacity(0.2)),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (!msg.deletedForAll)
              _OptionTile(
                icon: Icons.copy_rounded,
                label: 'Copiar mensagem',
                color: Colors.white,
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Mensagem copiada!'),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
              ),
            if (!msg.deletedForAll) const SizedBox(height: 8),
            if (!msg.deletedForAll)
              _OptionTile(
                icon: Icons.forward_rounded,
                label: 'Encaminhar mensagem',
                color: const Color(0xFF4FC3F7),
                onTap: () => _forwardMessage(msg),
              ),
            if (!msg.deletedForAll) const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Apagar para mim',
              color: AppColors.emergencyRed,
              onTap: () {
                Navigator.pop(context);
                _deleteForMe(msg);
              },
            ),
            if (isMe && !msg.deletedForAll) ...[
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.delete_sweep_rounded,
                label: 'Apagar para todos',
                color: AppColors.emergencyRed,
                onTap: () {
                  Navigator.pop(context);
                  _deleteForAll(msg);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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

  // ✅ CORREÇÃO DO PROBLEMA 2:
  // AppBar agora envolto em StreamBuilder que escuta users_xp/{friendUid}.
  // O ponto verde e o texto Online/Offline atualizam em tempo real
  // sempre que o PresenceService espelha uma mudança no Firestore.
  Widget _buildAppBar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _friendPresenceStream,
      builder: (context, presenceSnap) {
        final presenceData =
            presenceSnap.data?.data() as Map<String, dynamic>?;
        final isOnline = (presenceData?['status'] as String?) == 'online';

        return Container(
          color: Colors.black,
          padding: EdgeInsets.only(
            top: _topPadding + 8,
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
                            : widget.friend.username.isNotEmpty
                                ? widget.friend.username[0].toUpperCase()
                                : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900),
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
                        // ✅ Reativo — atualiza conforme o Firestore
                        color: isOnline
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF555555),
                        border: Border.all(color: Colors.black, width: 2),
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
                      widget.friend.displayName.isNotEmpty
                          ? widget.friend.displayName
                          : widget.friend.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    // StreamBuilder interno para o indicador de "digitando"
                    StreamBuilder<DocumentSnapshot>(
                      stream:
                          _db.collection('chats').doc(_chatId).snapshots(),
                      builder: (context, snap) {
                        final data =
                            snap.data?.data() as Map<String, dynamic>?;
                        final friendTyping =
                            (data?['isTyping_${widget.friend.uid}']
                                    as bool?) ??
                                false;
                        if (friendTyping) return const _TypingDots();
                        // ✅ Reativo — usa isOnline do StreamBuilder externo
                        return Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF666666),
                            fontSize: 12,
                          ),
                        );
                      },
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
                        const Text('Limpar conversa',
                            style: TextStyle(
                                color: AppColors.emergencyRed,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _messagesRef.orderBy('sentAt', descending: false).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryOrange),
          );
        }

        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final deletedFor = List<String>.from(d['deletedFor'] ?? []);
          return !deletedFor.contains(_myUid);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 56,
                    color: AppColors.primaryOrange.withOpacity(0.2)),
                const SizedBox(height: 14),
                const Text('Nenhuma mensagem ainda',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Diga olá para @${widget.friend.username}!',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 13)),
              ],
            ),
          );
        }

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
                    MessageModel.fromDoc(docs[i - 1]).sentAt, msg.sentAt);

            return Column(
              children: [
                if (showDate) _DateDivider(date: msg.sentAt),
                _MessageBubble(
                  msg: msg,
                  isMe: isMe,
                  onLongPress: () => _showMessageOptions(msg, isMe),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Mensagem...',
                    hintStyle:
                        TextStyle(color: Color(0xFF424242), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: _ActionButton(
                icon: Icons.send_rounded,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
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
    if (msg.deletedForAll) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded,
                  size: 14, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 6),
              Text(
                'Esta mensagem foi apagada',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      color: AppColors.primaryOrange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.isForwarded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_rounded,
                          size: 12,
                          color: isMe
                              ? Colors.white.withOpacity(0.6)
                              : Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        'Encaminhado',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isMe
                              ? Colors.white.withOpacity(0.6)
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFFE0E0E0),
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
// BOTÃO DE AÇÃO
// ═══════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ActionButton({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orangeGradient,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FORWARD SHEET
// ═══════════════════════════════════════════════════════════════════
class _ForwardSheet extends StatefulWidget {
  final String myUid;
  final FirebaseFirestore db;
  final String messageText;
  final Future<void> Function(String friendUid, FriendModel friend) onForward;

  const _ForwardSheet({
    required this.myUid,
    required this.db,
    required this.messageText,
    required this.onForward,
  });

  @override
  State<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<_ForwardSheet> {
  String? _sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080808),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 16, 0, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.orangeGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.forward_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENCAMINHAR',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                    Text('Selecione um contato',
                        style:
                            TextStyle(color: Color(0xFF666666), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forward_rounded,
                      color: AppColors.primaryOrange, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.messageText,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.db
                  .collection('friend_requests')
                  .where('status', isEqualTo: 'accepted')
                  .where('participants', arrayContains: widget.myUid)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryOrange),
                  );
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhum amigo ainda',
                        style: TextStyle(color: Color(0xFF666666))),
                  );
                }

                return FutureBuilder<List<FriendModel>>(
                  future: _loadFriends(docs),
                  builder: (context, friendsSnap) {
                    if (!friendsSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primaryOrange),
                      );
                    }

                    final friends = friendsSnap.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final friend = friends[i];
                        final isSending = _sending == friend.uid;

                        return GestureDetector(
                          onTap: isSending
                              ? null
                              : () async {
                                  setState(() => _sending = friend.uid);
                                  await widget.onForward(friend.uid, friend);
                                  if (mounted) Navigator.pop(context);
                                },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0F0F),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF1A1A1A)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.orangeGradient,
                                  ),
                                  child: Center(
                                    child: Text(
                                      friend.displayName.isNotEmpty
                                          ? friend.displayName[0].toUpperCase()
                                          : friend.username.isNotEmpty
                                              ? friend.username[0].toUpperCase()
                                              : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.displayName.isNotEmpty
                                            ? friend.displayName
                                            : friend.username,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      Text('@${friend.username}',
                                          style: TextStyle(
                                              color: AppColors.primaryOrange
                                                  .withOpacity(0.7),
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isSending)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryOrange),
                                  )
                                else
                                  const Icon(Icons.send_rounded,
                                      color: AppColors.primaryOrange,
                                      size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<FriendModel>> _loadFriends(
      List<QueryDocumentSnapshot> docs) async {
    final futures = docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final friendUid = (data['fromUid'] as String) == widget.myUid
          ? data['toUid'] as String
          : data['fromUid'] as String;
      final userDoc =
          await widget.db.collection('users_xp').doc(friendUid).get();
      if (!userDoc.exists) return null;
      return FriendModel.fromDoc(userDoc);
    });
    final results = await Future.wait(futures);
    return results.whereType<FriendModel>().toList();
  }
}

// ═══════════════════════════════════════════════════════════════════
// TYPING DOTS
// ═══════════════════════════════════════════════════════════════════
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('digitando',
            style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 12,
                fontStyle: FontStyle.italic)),
        const SizedBox(width: 3),
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
              final opacity =
                  (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CAF50).withOpacity(opacity),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STATUS ICON
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
              strokeWidth: 1.5, color: Colors.white.withOpacity(0.6)),
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
// DATE DIVIDER
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
          Text(_formatDate(date),
              style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
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
        date.day == now.day) return 'Hoje';
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) return 'Ontem';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// OPTION TILE
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
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
