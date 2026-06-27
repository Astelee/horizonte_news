import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'amigos_modelos.dart';
import 'chat_screen.dart';
import 'amigos_widgets.dart';

class AbaConversas extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;
  final String searchQuery;
  final VoidCallback onIniciarConversa;

  const AbaConversas({
    Key? key,
    required this.myUid,
    required this.db,
    required this.searchQuery,
    required this.onIniciarConversa,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const EstadoCarregando();
        }

        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
          return !hiddenFor.contains(myUid);
        }).toList();

        if (docs.isEmpty) {
          return _EstadoSemConversas(onIniciarConversa: onIniciarConversa);
        }

        return FutureBuilder<List<_ConversaItem>>(
          future: _carregarConversas(docs),
          builder: (context, convSnap) {
            if (!convSnap.hasData) return const EstadoCarregando();

            var lista = convSnap.data!;

            if (searchQuery.isNotEmpty) {
              lista = lista
                  .where((c) =>
                      c.friend.displayName
                          .toLowerCase()
                          .contains(searchQuery) ||
                      c.friend.username.toLowerCase().contains(searchQuery))
                  .toList();
            }

            if (lista.isEmpty) {
              return const EstadoVazio(
                icon: Icons.search_off_rounded,
                titulo: 'Nenhuma conversa encontrada',
                subtitulo: 'Tente outra busca',
              );
            }

            lista.sort((a, b) {
              if (a.friend.isFavorite && !b.friend.isFavorite) return -1;
              if (!a.friend.isFavorite && b.friend.isFavorite) return 1;
              return 0;
            });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: lista.length,
              itemBuilder: (context, i) => _CardConversa(
                item: lista[i],
                myUid: myUid,
                db: db,
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_ConversaItem>> _carregarConversas(
      List<QueryDocumentSnapshot> docs) async {
    final futures = docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final friendUid =
          participants.firstWhere((p) => p != myUid, orElse: () => '');
      if (friendUid.isEmpty) return null;

      final userDoc = await db.collection('users_xp').doc(friendUid).get();
      if (!userDoc.exists) return null;

      FriendModel friend = FriendModel.fromDoc(userDoc);

      final lastMsg = data['lastMessage'] as String? ?? '';
      final lastMsgAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
      final lastMsgBy = data['lastMessageBy'] as String? ?? '';
      final unread = (data['unreadCount_$myUid'] as num?)?.toInt() ?? 0;

      MessageStatus? status;
      if (lastMsgBy == myUid) {
        final statusStr = data['lastMessageStatus'] as String? ?? 'sent';
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
      }

      friend = friend.copyWith(
        lastMessage: lastMsg,
        lastMessageTime: lastMsgAt,
        lastMessageSenderId: lastMsgBy,
        lastMessageStatus: status,
        unreadCount: unread,
        chatId: doc.id,
      );

      return _ConversaItem(
        friend: friend,
        chatId: doc.id,
        friendUid: friendUid,
      );
    });

    final results = await Future.wait(futures);
    return results.whereType<_ConversaItem>().toList();
  }
}

class _ConversaItem {
  final FriendModel friend;
  final String chatId;
  final String friendUid;

  _ConversaItem({
    required this.friend,
    required this.chatId,
    required this.friendUid,
  });
}

// ═══════════════════════════════════════════════════════════════════
// ESTADO VAZIO — NENHUMA CONVERSA AINDA
// ═══════════════════════════════════════════════════════════════════
class _EstadoSemConversas extends StatelessWidget {
  final VoidCallback onIniciarConversa;

  const _EstadoSemConversas({required this.onIniciarConversa});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.06),
              border: Border.all(
                  color: const Color(0xFFFF6B00).withOpacity(0.15)),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 36, color: Color(0xFFFF6B00)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma conversa ainda',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comece a conversar com seus amigos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF444444), fontSize: 13),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onIniciarConversa,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_comment_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'INICIAR CONVERSA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE CONVERSA — com StreamBuilder para "digitando" em tempo real
// ═══════════════════════════════════════════════════════════════════
class _CardConversa extends StatelessWidget {
  final _ConversaItem item;
  final String myUid;
  final FirebaseFirestore db;

  const _CardConversa({
    required this.item,
    required this.myUid,
    required this.db,
  });

  String _formatarTempo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
  }

  void _abrirMenuContexto(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuContextoAmigo(
        friend: item.friend,
        myUid: myUid,
        db: db,
        chatId: item.chatId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friend = item.friend;
    final souEuQueMandei = friend.lastMessageSenderId == myUid;
    final temNaoLidas = friend.unreadCount > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
      ),
      onLongPress: () => _abrirMenuContexto(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: friend.isFavorite
                ? const Color(0xFFFAA61A).withOpacity(0.3)
                : temNaoLidas
                    ? const Color(0xFFFF6B00).withOpacity(0.3)
                    : const Color(0xFF1A1A1A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AmigoAvatar(friend: friend),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + badges + hora
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    friend.displayName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: temNaoLidas
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (friend.isFavorite) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star_rounded,
                                      size: 12, color: Color(0xFFFAA61A)),
                                ],
                                if (friend.achievements.isNotEmpty)
                                  FileiraBadges(
                                      achievementIds: friend.achievements),
                              ],
                            ),
                          ),
                          Text(
                            _formatarTempo(friend.lastMessageTime),
                            style: TextStyle(
                              color: temNaoLidas
                                  ? const Color(0xFFFF6B00)
                                  : const Color(0xFF555555),
                              fontSize: 11,
                              fontWeight: temNaoLidas
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // @username + nível
                      Row(
                        children: [
                          Text(
                            '@${friend.username}',
                            style: TextStyle(
                              color: const Color(0xFFFF6B00).withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          NivelBadge(level: friend.level),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // ── LINHA DE PREVIEW — escuta isTyping em tempo real ──
                      StreamBuilder<DocumentSnapshot>(
                        stream: db
                            .collection('chats')
                            .doc(item.chatId)
                            .snapshots(),
                        builder: (context, chatSnap) {
                          final data = chatSnap.data?.data()
                              as Map<String, dynamic>?;

                          // Verifica se o AMIGO está digitando
                          final friendTyping =
                              (data?['isTyping_${item.friendUid}'] as bool?) ??
                                  false;

                          if (friendTyping) {
                            return const IndicadorDigitando();
                          }

                          // Preview normal da última mensagem
                          return Row(
                            children: [
                              if (souEuQueMandei &&
                                  friend.lastMessageStatus != null) ...[
                                _MiniStatusIcon(
                                    status: friend.lastMessageStatus!),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  souEuQueMandei
                                      ? 'Você: ${friend.lastMessage ?? ''}'
                                      : friend.lastMessage ?? '',
                                  style: TextStyle(
                                    color: temNaoLidas
                                        ? Colors.white.withOpacity(0.9)
                                        : const Color(0xFF666666),
                                    fontSize: 12.5,
                                    fontWeight: temNaoLidas
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (temNaoLidas) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${friend.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: BarraXp(friend: friend),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MINI ÍCONE DE STATUS
// ═══════════════════════════════════════════════════════════════════
class _MiniStatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _MiniStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 9,
          height: 9,
          child: CircularProgressIndicator(
            strokeWidth: 1.3,
            color: Colors.white.withOpacity(0.4),
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.done_rounded,
            size: 13, color: Colors.white.withOpacity(0.4));
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded,
            size: 13, color: Colors.white.withOpacity(0.4));
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: Color(0xFF4FC3F7));
    }
  }
}
