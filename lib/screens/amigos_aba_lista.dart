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

        final docs = snap.data!.docs;
        final friendUids = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['fromUid'] as String) == myUid
              ? data['toUid'] as String
              : data['fromUid'] as String;
        }).toList();

        // ✅ CORREÇÃO PRINCIPAL: StreamBuilder nos docs dos amigos
        // Em vez de FutureBuilder (lê uma vez), usamos stream que
        // atualiza em tempo real quando o status muda no Firestore
        return _ListaAmigosStream(
          myUid: myUid,
          db: db,
          friendUids: friendUids,
          filter: filter,
          searchQuery: searchQuery,
        );
      },
    );
  }
}

// ── Lista que escuta os amigos em tempo real ──────────────────────
class _ListaAmigosStream extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;
  final List<String> friendUids;
  final FriendFilter filter;
  final String searchQuery;

  const _ListaAmigosStream({
    required this.myUid,
    required this.db,
    required this.friendUids,
    required this.filter,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (friendUids.isEmpty) return const EstadoSemAmigos();

    // Firestore só suporta 'whereIn' com até 30 itens
    final uidsChunk = friendUids.take(30).toList();

    return StreamBuilder<QuerySnapshot>(
      // ✅ Stream em tempo real dos documentos dos amigos
      // Quando o PresenceService atualiza users_xp/{uid}.status,
      // essa stream recebe a atualização automaticamente
      stream: db
          .collection('users_xp')
          .where(FieldPath.documentId, whereIn: uidsChunk)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const EstadoCarregando();

        final amigos = snap.data!.docs
            .map((doc) => FriendModel.fromDoc(doc))
            .toList();

        return _ListaFiltrada(
          myUid: myUid,
          db: db,
          amigos: amigos,
          filter: filter,
          searchQuery: searchQuery,
        );
      },
    );
  }
}

// ── Lista com filtros e ordenação ─────────────────────────────────
class _ListaFiltrada extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;
  final List<FriendModel> amigos;
  final FriendFilter filter;
  final String searchQuery;

  const _ListaFiltrada({
    required this.myUid,
    required this.db,
    required this.amigos,
    required this.filter,
    required this.searchQuery,
  });

  String _gerarChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    var lista = amigos.map((f) => f.copyWith(
      chatId: _gerarChatId(myUid, f.uid),
    )).toList();

    // Filtros
    switch (filter) {
      case FriendFilter.online:
        lista = lista.where((f) => f.isOnline).toList();
        break;
      case FriendFilter.offline:
        lista = lista.where((f) => !f.isOnline).toList();
        break;
      case FriendFilter.favorites:
        lista = lista.where((f) => f.isFavorite).toList();
        break;
      case FriendFilter.recent:
        lista.sort((a, b) =>
            (b.lastMessageTime ?? DateTime(0))
                .compareTo(a.lastMessageTime ?? DateTime(0)));
        break;
      case FriendFilter.all:
        break;
    }

    // Busca
    if (searchQuery.isNotEmpty) {
      lista = lista.where((f) =>
          f.displayName.toLowerCase().contains(searchQuery) ||
          f.username.toLowerCase().contains(searchQuery)).toList();
    }

    // Ordenação: favoritos → online → offline
    lista.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return 0;
    });

    if (lista.isEmpty) {
      return const EstadoVazio(
        icon: Icons.search_off_rounded,
        titulo: 'Nenhum resultado',
        subtitulo: 'Tente outro filtro ou busca',
      );
    }

    final favoritos = lista.where((f) => f.isFavorite).toList();
    final outros = lista.where((f) => !f.isFavorite).toList();

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
                friend: f,
                chatId: f.chatId ?? '',
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
                friend: f,
                chatId: f.chatId ?? '',
                myUid: myUid,
                db: db,
              )),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DO AMIGO
// ═══════════════════════════════════════════════════════════════════
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
                                FileiraBadges(
                                    achievementIds: friend.achievements),
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
                              color:
                                  const Color(0xFFFF6B00).withOpacity(0.2)),
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
