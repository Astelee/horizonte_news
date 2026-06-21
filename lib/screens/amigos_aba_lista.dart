import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';
import 'amigos_perfil.dart';

class AbaAmigos extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;
  final FriendFilter filter;
  final String searchQuery;

  const AbaAmigos({
    Key? key,
    required this.myUid,
    required this.db,
    required this.filter,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('friend_requests')
          .where('status', isEqualTo: 'accepted')
          .where('participants', arrayContains: myUid)
          .orderBy('acceptedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const EstadoCarregando();
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const EstadoSemAmigos();
        }

        return FutureBuilder<List<_FriendComConversa>>(
          future: _carregarAmigosComConversa(snap.data!.docs),
          builder: (context, friendsSnap) {
            if (!friendsSnap.hasData) return const EstadoCarregando();

            var lista = friendsSnap.data!;

            switch (filter) {
              case FriendFilter.online:
                lista = lista.where((f) => f.friend.isOnline).toList();
                break;
              case FriendFilter.offline:
                lista = lista.where((f) => !f.friend.isOnline).toList();
                break;
              case FriendFilter.favorites:
                lista = lista.where((f) => f.friend.isFavorite).toList();
                break;
              case FriendFilter.recent:
                lista.sort((a, b) =>
                    (b.friend.lastMessageTime ?? DateTime(0))
                        .compareTo(a.friend.lastMessageTime ?? DateTime(0)));
                break;
              case FriendFilter.all:
                break;
            }

            if (searchQuery.isNotEmpty) {
              lista = lista
                  .where((f) =>
                      f.friend.displayName
                          .toLowerCase()
                          .contains(searchQuery) ||
                      f.friend.username.toLowerCase().contains(searchQuery))
                  .toList();
            }

            lista.sort((a, b) {
              if (a.friend.isFavorite && !b.friend.isFavorite) return -1;
              if (!a.friend.isFavorite && b.friend.isFavorite) return 1;
              if (a.friend.isOnline && !b.friend.isOnline) return -1;
              if (!a.friend.isOnline && b.friend.isOnline) return 1;
              return 0;
            });

            if (lista.isEmpty) {
              return const EstadoVazio(
                icon: Icons.search_off_rounded,
                titulo: 'Nenhum resultado',
                subtitulo: 'Tente outro filtro ou busca',
              );
            }

            final favoritos = lista.where((f) => f.friend.isFavorite).toList();
            final outros = lista.where((f) => !f.friend.isFavorite).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                if (favoritos.isNotEmpty) ...[
                  CabecalhoSecao(
                    icon: Icons.star_rounded,
                    label: 'FAVORITOS',
                    color: const Color(0xFFFAA61A),
                    count: favoritos.length,
                  ),
                  ...favoritos.map((f) => CardAmigo(
                        friend: f.friend,
                        chatId: f.chatId,
                        myUid: myUid,
                        db: db,
                      )),
                  const SizedBox(height: 8),
                ],
                if (outros.isNotEmpty) ...[
                  CabecalhoSecao(
                    icon: Icons.people_rounded,
                    label: 'TODOS OS AMIGOS',
                    color: const Color(0xFF666666),
                    count: outros.length,
                  ),
                  ...outros.map((f) => CardAmigo(
                        friend: f.friend,
                        chatId: f.chatId,
                        myUid: myUid,
                        db: db,
                      )),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<List<_FriendComConversa>> _carregarAmigosComConversa(
      List<QueryDocumentSnapshot> docs) async {
    final futures = docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final friendUid = (data['fromUid'] as String) == myUid
          ? data['toUid'] as String
          : data['fromUid'] as String;

      final userDoc = await db.collection('users_xp').doc(friendUid).get();
      if (!userDoc.exists) return null;

      FriendModel friend = FriendModel.fromDoc(userDoc);

      try {
        final chatId = _gerarChatId(myUid, friendUid);
        final msgSnap = await db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (msgSnap.docs.isNotEmpty) {
          final msgData = msgSnap.docs.first.data();
          final texto = msgData['text'] as String? ?? '';
          final ts = (msgData['timestamp'] as Timestamp?)?.toDate();
          final remetente = msgData['senderId'] as String? ?? '';
          final prefixo = remetente == myUid ? 'Você: ' : '';
          friend = friend.copyWith(
            lastMessage: '$prefixo$texto',
            lastMessageTime: ts,
            chatId: chatId,
          );
        } else {
          friend = friend.copyWith(chatId: _gerarChatId(myUid, friendUid));
        }
      } catch (_) {
        friend = friend.copyWith(chatId: _gerarChatId(myUid, friendUid));
      }

      return _FriendComConversa(friend: friend, chatId: friend.chatId ?? '');
    });

    final results = await Future.wait(futures);
    return results.whereType<_FriendComConversa>().toList();
  }

  String _gerarChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}

class _FriendComConversa {
  final FriendModel friend;
  final String chatId;
  _FriendComConversa({required this.friend, required this.chatId});
}

class CardAmigo extends StatelessWidget {
  final FriendModel friend;
  final String chatId;
  final String myUid;
  final FirebaseFirestore db;

  const CardAmigo({
    Key? key,
    required this.friend,
    required this.chatId,
    required this.myUid,
    required this.db,
  }) : super(key: key);

  String _formatarTempo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _abrirMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuContextoAmigo(
        friend: friend,
        myUid: myUid,
        db: db,
        chatId: chatId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TelaPerfilAmigo(friend: friend)),
      ),
      onLongPress: () => _abrirMenu(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: friend.isFavorite
                ? const Color(0xFFFAA61A).withOpacity(0.25)
                : const Color(0xFF1A1A1A),
          ),
          boxShadow: [
            if (friend.isOnline)
              BoxShadow(
                color: friend.status.color.withOpacity(0.05),
                blurRadius: 12,
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AmigoAvatar(friend: friend),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  friend.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
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
                                FileiraBadges(achievementIds: friend.achievements),
                            ],
                          ),
                        ),
                        if (friend.lastMessageTime != null)
                          Text(
                            _formatarTempo(friend.lastMessageTime),
                            style: const TextStyle(
                                color: Color(0xFF555555), fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 6),
                    if (friend.isTyping)
                      const IndicadorDigitando()
                    else if (friend.lastMessage != null &&
                        friend.lastMessage!.isNotEmpty)
                      Text(
                        friend.lastMessage!,
                        style: TextStyle(
                          color: friend.unreadCount > 0
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF555555),
                          fontSize: 12,
                          fontWeight: friend.unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      )
                    else
                      Text(
                        friend.status.label,
                        style: TextStyle(
                          color: friend.status.color.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    BarraXp(friend: friend),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (friend.unreadCount > 0)
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
                    )
                  else
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(friend: friend)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFF6B00).withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.chat_bubble_rounded,
                            color: Color(0xFFFF6B00), size: 15),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuContextoAmigo extends StatelessWidget {
  final FriendModel friend;
  final String myUid;
  final FirebaseFirestore db;
  final String chatId;

  const MenuContextoAmigo({
    Key? key,
    required this.friend,
    required this.myUid,
    required this.db,
    required this.chatId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                  ),
                ),
                child: Center(
                  child: Text(
                    friend.displayName.isNotEmpty
                        ? friend.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text('@${friend.username}',
                      style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.7),
                          fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ItemMenu(
            icon: Icons.person_rounded,
            label: 'Ver Perfil',
            color: Colors.white,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TelaPerfilAmigo(friend: friend)));
            },
          ),
          _ItemMenu(
            icon: Icons.chat_bubble_rounded,
            label: 'Conversar',
            color: const Color(0xFFFF6B00),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(friend: friend)));
            },
          ),
          _ItemMenu(
            icon: friend.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: friend.isFavorite
                ? 'Remover dos Favoritos'
                : 'Adicionar aos Favoritos',
            color: const Color(0xFFFAA61A),
            onTap: () {
              Navigator.pop(context);
              db.collection('users_xp').doc(friend.uid).update(
                  {'isFavorite': !friend.isFavorite});
            },
          ),
          _ItemMenu(
            icon: Icons.notifications_off_rounded,
            label: 'Silenciar',
            color: const Color(0xFF747F8D),
            onTap: () => Navigator.pop(context),
          ),
          _ItemMenu(
            icon: Icons.delete_sweep_rounded,
            label: 'Limpar Conversa',
            color: const Color(0xFF747F8D),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: Color(0xFF1A1A1A), height: 20),
          _ItemMenu(
            icon: Icons.person_remove_rounded,
            label: 'Excluir Amigo',
            color: const Color(0xFFED4245),
            onTap: () {
              Navigator.pop(context);
              _confirmarRemocao(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmarRemocao(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover amigo?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Tem certeza que quer remover @${friend.username}?',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final snap = await db
                  .collection('friend_requests')
                  .where('participants', arrayContains: myUid)
                  .where('status', isEqualTo: 'accepted')
                  .get();
              for (final doc in snap.docs) {
                final d = doc.data();
                final parts = List<String>.from(d['participants'] ?? []);
                if (parts.contains(friend.uid)) {
                  await doc.reference.delete();
                  break;
                }
              }
            },
            child: const Text('Remover',
                style: TextStyle(
                    color: Color(0xFFED4245), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ItemMenu({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Expanded(child: SizedBox()),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }
}
