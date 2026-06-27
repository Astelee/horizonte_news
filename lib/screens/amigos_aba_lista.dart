// amigos_aba_lista.dart
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

// ═══════════════════════════════════════════════════════════════════
// LISTA REATIVA EM TEMPO REAL
// ═══════════════════════════════════════════════════════════════════
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

    final uidsChunk = friendUids.take(30).toList();

    return StreamBuilder<QuerySnapshot>(
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

// ═══════════════════════════════════════════════════════════════════
// LISTA COM FILTROS E ORDENAÇÃO
// ═══════════════════════════════════════════════════════════════════
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
    var lista = amigos
        .map((f) => f.copyWith(chatId: _gerarChatId(myUid, f.uid)))
        .toList();

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
      lista = lista
          .where((f) =>
              f.displayName.toLowerCase().contains(searchQuery) ||
              f.username.toLowerCase().contains(searchQuery))
          .toList();
    }

    // Ordenação: favoritos → online → offline → nome
    lista.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    if (lista.isEmpty) {
      return const EstadoVazio(
        icon: Icons.search_off_rounded,
        titulo: 'Nenhum resultado',
        subtitulo: 'Tente outro filtro ou busca',
      );
    }

    final favoritos = lista.where((f) => f.isFavorite).toList();
    final online = lista.where((f) => !f.isFavorite && f.isOnline).toList();
    final offline = lista.where((f) => !f.isFavorite && !f.isOnline).toList();

    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF111111),
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (favoritos.isNotEmpty) ...[
            CabecalhoSecao(
              icon: Icons.star_rounded,
              label: 'FAVORITOS',
              color: const Color(0xFFFAA61A),
              count: favoritos.length,
            ),
            ...favoritos.asMap().entries.map((e) => _CardAmigoAnimado(
                  friend: e.value,
                  myUid: myUid,
                  db: db,
                  index: e.key,
                )),
            const SizedBox(height: 8),
          ],
          if (online.isNotEmpty) ...[
            CabecalhoSecao(
              icon: Icons.circle,
              label: 'ONLINE',
              color: const Color(0xFF43B581),
              count: online.length,
            ),
            ...online.asMap().entries.map((e) => _CardAmigoAnimado(
                  friend: e.value,
                  myUid: myUid,
                  db: db,
                  index: favoritos.length + e.key,
                )),
            const SizedBox(height: 8),
          ],
          if (offline.isNotEmpty) ...[
            CabecalhoSecao(
              icon: Icons.circle_outlined,
              label: 'OFFLINE',
              color: const Color(0xFF555555),
              count: offline.length,
            ),
            ...offline.asMap().entries.map((e) => _CardAmigoAnimado(
                  friend: e.value,
                  myUid: myUid,
                  db: db,
                  index: favoritos.length + online.length + e.key,
                )),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD ANIMADO — wrapper com entrada fade + slide
// ═══════════════════════════════════════════════════════════════════
class _CardAmigoAnimado extends StatefulWidget {
  final FriendModel friend;
  final String myUid;
  final FirebaseFirestore db;
  final int index;

  const _CardAmigoAnimado({
    required this.friend,
    required this.myUid,
    required this.db,
    required this.index,
  });

  @override
  State<_CardAmigoAnimado> createState() => _CardAmigoAnimadoState();
}

class _CardAmigoAnimadoState extends State<_CardAmigoAnimado>
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
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Delay escalonado por índice
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
        child: CardAmigo(
          friend: widget.friend,
          chatId: widget.friend.chatId ?? '',
          myUid: widget.myUid,
          db: widget.db,
        ),
      ),
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
                  builder: (_) => TelaPerfilAmigo(friend: friend)),
            );
          },
          onLongPress: () => _abrirMenu(context),
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0xFFFF6B00).withOpacity(0.06),
          highlightColor: const Color(0xFFFF6B00).withOpacity(0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0C),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: friend.isFavorite
                    ? const Color(0xFFFAA61A).withOpacity(0.3)
                    : friend.isOnline
                        ? friend.status.color.withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
              ),
              boxShadow: [
                if (friend.isOnline)
                  BoxShadow(
                    color: friend.status.color.withOpacity(0.06),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                if (friend.isFavorite)
                  BoxShadow(
                    color: const Color(0xFFFAA61A).withOpacity(0.05),
                    blurRadius: 16,
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  AmigoAvatar(friend: friend),
                  const SizedBox(width: 12),

                  // Conteúdo
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
                            if (friend.lastMessageTime != null)
                              Text(
                                _formatarTempo(friend.lastMessageTime),
                                style: const TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 11),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Username + nível
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
                        const SizedBox(height: 6),

                        // Status / última mensagem / digitando
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: friend.isTyping
                              ? const IndicadorDigitando()
                              : friend.lastMessage != null &&
                                      friend.lastMessage!.isNotEmpty
                                  ? Text(
                                      friend.lastMessage!,
                                      key: const ValueKey('msg'),
                                      style: TextStyle(
                                        color: friend.unreadCount > 0
                                            ? Colors.white
                                                .withOpacity(0.8)
                                            : const Color(0xFF555555),
                                        fontSize: 12,
                                        fontWeight: friend.unreadCount > 0
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    )
                                  : Row(
                                      key: const ValueKey('status'),
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: friend.status.color,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          friend.status.label,
                                          style: TextStyle(
                                            color: friend.status.color
                                                .withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                        const SizedBox(height: 6),

                        // Barra XP
                        BarraXp(friend: friend),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Botão direito: badge não lidas ou chat
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: friend.unreadCount > 0
                        ? Container(
                            key: const ValueKey('badge'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${friend.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : GestureDetector(
                            key: const ValueKey('chat'),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ChatScreen(friend: friend)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00)
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFFF6B00)
                                        .withOpacity(0.2)),
                              ),
                              child: const Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Color(0xFFFF6B00),
                                  size: 15),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
