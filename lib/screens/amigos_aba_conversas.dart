// amigos_aba_conversas.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      builder: (context, snapChats) {
        if (snapChats.connectionState == ConnectionState.waiting) {
          return const EstadoCarregando();
        }

        final allDocs = snapChats.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
          return !hiddenFor.contains(myUid);
        }).toList();

        if (docs.isEmpty) {
          return _EstadoSemConversas(onIniciarConversa: onIniciarConversa);
        }

        // Extrai UIDs dos amigos de todos os chats
        final friendUids = docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final participants =
                  List<String>.from(data['participants'] ?? []);
              return participants.firstWhere(
                (p) => p != myUid,
                orElse: () => '',
              );
            })
            .where((uid) => uid.isNotEmpty)
            .toSet()
            .toList();

        if (friendUids.isEmpty) {
          return _EstadoSemConversas(onIniciarConversa: onIniciarConversa);
        }

        // Stream reativo dos perfis dos amigos
        final uidsChunk = friendUids.take(30).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('users_xp')
              .where(FieldPath.documentId, whereIn: uidsChunk)
              .snapshots(),
          builder: (context, snapUsers) {
            if (!snapUsers.hasData) return const EstadoCarregando();

            // Mapa uid → FriendModel
            final usersMap = <String, FriendModel>{};
            for (final doc in snapUsers.data!.docs) {
              usersMap[doc.id] = FriendModel.fromDoc(doc);
            }

            // Monta lista de conversas enriquecida
            final conversas = <_ConversaItem>[];
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final participants =
                  List<String>.from(data['participants'] ?? []);
              final friendUid = participants.firstWhere(
                (p) => p != myUid,
                orElse: () => '',
              );
              if (friendUid.isEmpty) continue;

              final baseModel = usersMap[friendUid];
              if (baseModel == null) continue;

              final lastMsg =
                  (data['lastMessage'] as String?) ?? '';
              final lastMsgAt =
                  (data['lastMessageAt'] as Timestamp?)?.toDate();
              final lastMsgBy =
                  (data['lastMessageBy'] as String?) ?? '';
              final unread =
                  (data['unreadCount_$myUid'] as num?)?.toInt() ?? 0;

              MessageStatus? status;
              if (lastMsgBy == myUid) {
                final statusStr =
                    (data['lastMessageStatus'] as String?) ?? 'sent';
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

              final friend = baseModel.copyWith(
                lastMessage: lastMsg,
                lastMessageTime: lastMsgAt,
                lastMessageSenderId: lastMsgBy,
                lastMessageStatus: status,
                unreadCount: unread,
                chatId: doc.id,
              );

              conversas.add(_ConversaItem(
                friend: friend,
                chatId: doc.id,
                friendUid: friendUid,
              ));
            }

            // Filtra por busca
            var lista = conversas;
            if (searchQuery.isNotEmpty) {
              lista = lista
                  .where((c) =>
                      c.friend.displayName
                          .toLowerCase()
                          .contains(searchQuery) ||
                      c.friend.username
                          .toLowerCase()
                          .contains(searchQuery))
                  .toList();
            }

            if (lista.isEmpty) {
              return const EstadoVazio(
                icon: Icons.search_off_rounded,
                titulo: 'Nenhuma conversa encontrada',
                subtitulo: 'Tente outra busca',
              );
            }

            // Ordena: favoritos → não lidas → mais recentes
            lista.sort((a, b) {
              if (a.friend.isFavorite && !b.friend.isFavorite) return -1;
              if (!a.friend.isFavorite && b.friend.isFavorite) return 1;
              if (a.friend.unreadCount > 0 && b.friend.unreadCount == 0)
                return -1;
              if (a.friend.unreadCount == 0 && b.friend.unreadCount > 0)
                return 1;
              return (b.friend.lastMessageTime ?? DateTime(0))
                  .compareTo(a.friend.lastMessageTime ?? DateTime(0));
            });

            return RefreshIndicator(
              color: const Color(0xFFFF6B00),
              backgroundColor: const Color(0xFF111111),
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: lista.length,
                itemBuilder: (context, i) => _CardConversaAnimado(
                  item: lista[i],
                  myUid: myUid,
                  db: db,
                  index: i,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO INTERNO DE CONVERSA
// ═══════════════════════════════════════════════════════════════════
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
// CARD ANIMADO DE CONVERSA
// ═══════════════════════════════════════════════════════════════════
class _CardConversaAnimado extends StatefulWidget {
  final _ConversaItem item;
  final String myUid;
  final FirebaseFirestore db;
  final int index;

  const _CardConversaAnimado({
    required this.item,
    required this.myUid,
    required this.db,
    required this.index,
  });

  @override
  State<_CardConversaAnimado> createState() => _CardConversaAnimadoState();
}

class _CardConversaAnimadoState extends State<_CardConversaAnimado>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(
      Duration(milliseconds: 40 * widget.index.clamp(0, 10)),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _CardConversa(
          item: widget.item,
          myUid: widget.myUid,
          db: widget.db,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE CONVERSA
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatScreen(friend: friend)),
            );
          },
          onLongPress: () => _abrirMenuContexto(context),
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0xFFFF6B00).withOpacity(0.06),
          highlightColor: const Color(0xFFFF6B00).withOpacity(0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
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
              boxShadow: [
                if (temNaoLidas)
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withOpacity(0.05),
                    blurRadius: 16,
                  ),
              ],
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
                          // Nome + hora
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
                                          size: 12,
                                          color: Color(0xFFFAA61A)),
                                    ],
                                    if (friend.achievements.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      FileiraBadges(
                                          achievementIds:
                                              friend.achievements),
                                    ],
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
                                  color: const Color(0xFFFF6B00)
                                      .withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              NivelBadge(level: friend.level),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Preview da mensagem com isTyping reativo
                          StreamBuilder<DocumentSnapshot>(
                            stream: db
                                .collection('chats')
                                .doc(item.chatId)
                                .snapshots(),
                            builder: (context, chatSnap) {
                              final data = chatSnap.data?.data()
                                  as Map<String, dynamic>?;
                              final friendTyping = (data?[
                                          'isTyping_${item.friendUid}']
                                      as bool?) ??
                                  false;

                              return AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 250),
                                child: friendTyping
                                    ? const Align(
                                        key: ValueKey('typing'),
                                        alignment: Alignment.centerLeft,
                                        child: IndicadorDigitando(),
                                      )
                                    : Row(
                                        key: const ValueKey('preview'),
                                        children: [
                                          if (souEuQueMandei &&
                                              friend.lastMessageStatus !=
                                                  null) ...[
                                            _MiniStatusIcon(
                                                status: friend
                                                    .lastMessageStatus!),
                                            const SizedBox(width: 4),
                                          ],
                                          Expanded(
                                            child: Text(
                                              souEuQueMandei
                                                  ? 'Você: ${friend.lastMessage ?? ''}'
                                                  : friend.lastMessage ??
                                                      '',
                                              style: TextStyle(
                                                color: temNaoLidas
                                                    ? Colors.white
                                                        .withOpacity(0.9)
                                                    : const Color(
                                                        0xFF666666),
                                                fontSize: 12.5,
                                                fontWeight: temNaoLidas
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          if (temNaoLidas) ...[
                                            const SizedBox(width: 8),
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                    0xFFFF6B00),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                              ),
                                              child: Text(
                                                '${friend.unreadCount}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MINI ÍCONE DE STATUS DE MENSAGEM
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

// ═══════════════════════════════════════════════════════════════════
// ESTADO VAZIO — SEM CONVERSAS
// ═══════════════════════════════════════════════════════════════════
class _EstadoSemConversas extends StatelessWidget {
  final VoidCallback onIniciarConversa;
  const _EstadoSemConversas({required this.onIniciarConversa});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B00).withOpacity(0.06),
                border: Border.all(
                    color: const Color(0xFFFF6B00).withOpacity(0.15)),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 38, color: Color(0xFFFF6B00)),
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
              style: TextStyle(
                  color: Color(0xFF555555), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onIniciarConversa,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'ENCONTRAR AMIGOS',
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
      ),
    );
  }
}
