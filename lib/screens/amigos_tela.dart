// amigos_tela.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'amigos_modelos.dart';
import 'amigos_aba_conversas.dart';
import 'amigos_aba_pedidos.dart';
import 'amigos_aba_lista.dart';
import 'amigos_adicionar.dart';
import 'amigos_widgets.dart';

class TelaAmigos extends StatefulWidget {
  const TelaAmigos({Key? key}) : super(key: key);

  @override
  State<TelaAmigos> createState() => _TelaAmigosState();
}

class _TelaAmigosState extends State<TelaAmigos>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();
  String _busca = '';
  bool _buscaAberta = false;
  FriendFilter _filtroAmigos = FriendFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _myUid => _auth.currentUser?.uid ?? '';

  void _toggleBusca() {
    HapticFeedback.lightImpact();
    setState(() {
      _buscaAberta = !_buscaAberta;
      if (!_buscaAberta) {
        _searchController.clear();
        _busca = '';
      }
    });
  }

  void _abrirPainelAmigos() {
    abrirPainelAmigos(context, myUid: _myUid, db: _db);
  }

  void _abrirPedidos() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PainelPedidos(myUid: _myUid, db: _db),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _buscaAberta ? _buildBarraBusca() : const SizedBox.shrink(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: (_tabController.index == 1)
                ? _buildFiltrosAmigos()
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AbaConversas(
                  myUid: _myUid,
                  db: _db,
                  searchQuery: _busca,
                  onIniciarConversa: _abrirPainelAmigos,
                ),
                AbaAmigos(
                  myUid: _myUid,
                  db: _db,
                  filter: _filtroAmigos,
                  searchQuery: _busca,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BotaoIconeRedondo(
            icon: _buscaAberta
                ? Icons.close_rounded
                : Icons.search_rounded,
            onTap: _toggleBusca,
          ),
          const SizedBox(width: 10),
          BotaoAdicionarAmigo(myUid: _myUid, db: _db),
        ],
      ),
    );
  }

  // ── Header com info do usuário logado ──────────────────────────
  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users_xp').doc(_myUid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final displayName =
            (data?['displayName'] as String?) ?? 'Você';
        final initial = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('friend_requests')
              .where('toUid', isEqualTo: _myUid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, pedidosSnap) {
            final pedidosCount =
                pedidosSnap.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('friend_requests')
                  .where('status', isEqualTo: 'accepted')
                  .where('participants', arrayContains: _myUid)
                  .snapshots(),
              builder: (context, amigosSnap) {
                final amigosCount =
                    amigosSnap.data?.docs.length ?? 0;

                return Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 14,
                    left: 8,
                    right: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D0400), Colors.black],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),

                      // Avatar do usuário logado
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6B00),
                              Color(0xFFCC4400)
                            ],
                          ),
                          border: Border.all(
                              color: const Color(0xFF43B581),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF43B581)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Título + contadores
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'CONVERSAS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '$amigosCount amigo${amigosCount != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: Color(0xFF555555),
                                      fontSize: 10),
                                ),
                                if (pedidosCount > 0) ...[
                                  const Text(' · ',
                                      style: TextStyle(
                                          color: Color(0xFF333333),
                                          fontSize: 10)),
                                  Text(
                                    '$pedidosCount pedido${pedidosCount != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: Color(0xFFFF6B00),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Menu 3 pontinhos com badge de pedidos
                      _MenuTresPontinhos(
                        pedidosCount: pedidosCount,
                        onPedidosTap: _abrirPedidos,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBarraBusca() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) =>
                  setState(() => _busca = v.toLowerCase()),
              style:
                  const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _tabController.index == 1
                    ? 'Buscar amigos...'
                    : 'Buscar conversas...',
                hintStyle: const TextStyle(
                    color: Color(0xFF555555), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF555555), size: 20),
                suffixIcon: _busca.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _busca = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFF555555), size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltrosAmigos() {
    final filtros = [
      (FriendFilter.all, 'Todos', Icons.apps_rounded),
      (FriendFilter.online, 'Online', Icons.circle),
      (FriendFilter.favorites, 'Favoritos', Icons.star_rounded),
      (FriendFilter.recent, 'Recentes', Icons.history_rounded),
      (FriendFilter.offline, 'Offline', Icons.circle_outlined),
    ];

    return Container(
      color: Colors.black,
      height: 44,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filtros.map((f) {
          final ativo = _filtroAmigos == f.$1;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filtroAmigos = f.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: ativo
                    ? const Color(0xFFFF6B00)
                    : const Color(0xFF111111),
                border: Border.all(
                  color: ativo
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF222222),
                ),
                boxShadow: ativo
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B00)
                              .withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.$3,
                    size: 12,
                    color: ativo
                        ? Colors.white
                        : const Color(0xFF666666),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    f.$2,
                    style: TextStyle(
                      color: ativo
                          ? Colors.white
                          : const Color(0xFF666666),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.black,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFFF6B00),
        indicatorWeight: 2,
        labelColor: const Color(0xFFFF6B00),
        unselectedLabelColor: const Color(0xFF555555),
        dividerColor: const Color(0xFF111111),
        labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8),
        isScrollable: false,
        tabs: const [
          Tab(
            icon: Icon(Icons.chat_bubble_rounded, size: 16),
            text: 'CONVERSAS',
          ),
          Tab(
            icon: Icon(Icons.people_alt_rounded, size: 16),
            text: 'AMIGOS',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MENU DE 3 PONTINHOS
// ═══════════════════════════════════════════════════════════════════
class _MenuTresPontinhos extends StatelessWidget {
  final int pedidosCount;
  final VoidCallback onPedidosTap;

  const _MenuTresPontinhos({
    required this.pedidosCount,
    required this.onPedidosTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.more_vert_rounded, color: Colors.white),
          if (pedidosCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFED4245),
                  border:
                      Border.all(color: Colors.black, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      color: const Color(0xFF0C0C0C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: const Color(0xFFFF6B00).withOpacity(0.15)),
      ),
      onSelected: (value) {
        if (value == 'pedidos') onPedidosTap();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pedidos',
          child: Row(
            children: [
              const Icon(Icons.person_add_rounded,
                  color: Color(0xFFFF6B00), size: 18),
              const SizedBox(width: 10),
              const Text(
                'Pedidos de amizade',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              if (pedidosCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFED4245),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pedidosCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAINEL DE PEDIDOS (bottom sheet)
// ═══════════════════════════════════════════════════════════════════
class _PainelPedidos extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _PainelPedidos({required this.myUid, required this.db});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF080808),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF1A1A1A)),
              left: BorderSide(color: Color(0xFF111111)),
              right: BorderSide(color: Color(0xFF111111)),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF6B00),
                            Color(0xFFCC4400)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00)
                                .withOpacity(0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_add_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'PEDIDOS DE AMIZADE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AbaPedidos(myUid: myUid, db: db),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTÃO ÍCONE REDONDO (busca / fechar)
// ═══════════════════════════════════════════════════════════════════
class _BotaoIconeRedondo extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BotaoIconeRedondo(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
