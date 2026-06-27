// amigos_adicionar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';
import 'chat_screen.dart';
import 'amigos_perfil.dart';

// ═══════════════════════════════════════════════════════════════════
// BOTÃO FLUTUANTE
// ═══════════════════════════════════════════════════════════════════
class BotaoAdicionarAmigo extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const BotaoAdicionarAmigo({Key? key, required this.myUid, required this.db})
      : super(key: key);

  void _abrir(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PainelAdicionarAmigo(myUid: myUid, db: db),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrir(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              'AMIGOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Permite abrir o painel programaticamente
void abrirPainelAmigos(BuildContext context,
    {required String myUid, required FirebaseFirestore db}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PainelAdicionarAmigo(myUid: myUid, db: db),
  );
}

// ═══════════════════════════════════════════════════════════════════
// PAINEL PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
class PainelAdicionarAmigo extends StatefulWidget {
  final String myUid;
  final FirebaseFirestore db;

  const PainelAdicionarAmigo({Key? key, required this.myUid, required this.db})
      : super(key: key);

  @override
  State<PainelAdicionarAmigo> createState() => _PainelAdicionarAmigoState();
}

class _PainelAdicionarAmigoState extends State<PainelAdicionarAmigo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _controller = TextEditingController();
  FriendModel? _usuarioEncontrado;
  bool _buscando = false;
  bool _enviando = false;
  String? _mensagem;
  bool _isErro = false;
  String? _statusSolicitacao;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Busca por username, displayName ou UID ──────────────────────
  Future<void> _buscar() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _buscando = true;
      _usuarioEncontrado = null;
      _mensagem = null;
      _statusSolicitacao = null;
    });

    HapticFeedback.lightImpact();

    try {
      QuerySnapshot? snap;

      // 1) Tenta por username (lowercase)
      snap = await widget.db
          .collection('users_xp')
          .where('username', isEqualTo: query.toLowerCase())
          .limit(1)
          .get();

      // 2) Tenta por displayName se não achou
      if (snap.docs.isEmpty) {
        snap = await widget.db
            .collection('users_xp')
            .where('displayName', isEqualTo: query)
            .limit(1)
            .get();
      }

      // 3) Tenta por UID direto
      if (snap.docs.isEmpty) {
        final byUid = await widget.db
            .collection('users_xp')
            .doc(query)
            .get();
        if (byUid.exists) {
          snap = null;
          final user = FriendModel.fromDoc(byUid);
          await _processarUsuario(user);
          return;
        }
      }

      if (snap == null || snap.docs.isEmpty) {
        setState(() {
          _mensagem = 'Nenhum usuário encontrado para "$query"';
          _isErro = true;
          _buscando = false;
        });
        return;
      }

      final user = FriendModel.fromDoc(snap.docs.first);
      await _processarUsuario(user);
    } catch (e) {
      setState(() {
        _mensagem = 'Erro ao buscar. Tente novamente.';
        _isErro = true;
        _buscando = false;
      });
    }
  }

  Future<void> _processarUsuario(FriendModel user) async {
    if (user.uid == widget.myUid) {
      setState(() {
        _mensagem = 'Você não pode se adicionar 😄';
        _isErro = true;
        _buscando = false;
      });
      return;
    }

    // Verifica se já existe vínculo
    final existing = await widget.db
        .collection('friend_requests')
        .where('participants', arrayContains: widget.myUid)
        .get();

    String? existingStatus;
    for (final doc in existing.docs) {
      final d = doc.data();
      final parts = List<String>.from(d['participants'] ?? []);
      if (parts.contains(user.uid)) {
        existingStatus = d['status'] as String?;
        break;
      }
    }

    setState(() {
      _usuarioEncontrado = user;
      _statusSolicitacao = existingStatus;
      _buscando = false;
    });
  }

  Future<void> _enviarSolicitacao() async {
    if (_usuarioEncontrado == null) return;
    setState(() => _enviando = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.db.collection('friend_requests').add({
        'fromUid': widget.myUid,
        'toUid': _usuarioEncontrado!.uid,
        'participants': [widget.myUid, _usuarioEncontrado!.uid],
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _mensagem =
            'Solicitação enviada para @${_usuarioEncontrado!.username}! 🎉';
        _isErro = false;
        _usuarioEncontrado = null;
        _controller.clear();
        _enviando = false;
      });

      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() {
        _mensagem = 'Erro ao enviar. Tente novamente.';
        _isErro = true;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
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
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_search_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADICIONAR AMIGO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Busque por nome, @username ou ID',
                          style: TextStyle(
                              color: Color(0xFF555555), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Sub-TabBar ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1A1A1A)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF555555),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded, size: 14),
                            SizedBox(width: 6),
                            Text('BUSCAR'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_rounded, size: 14),
                            SizedBox(width: 6),
                            Text('AMIGOS'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Conteúdo das abas ─────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAbaBusca(),
                    _buildAbaListaAmigos(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ABA 1: BUSCA ───────────────────────────────────────────────
  Widget _buildAbaBusca() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        children: [
          // Campo de busca
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search_rounded,
                    color: Color(0xFF555555), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    onSubmitted: (_) => _buscar(),
                    decoration: const InputDecoration(
                      hintText: 'Nome, @username ou ID do usuário',
                      hintStyle: TextStyle(
                          color: Color(0xFF444444), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      setState(() {
                        _usuarioEncontrado = null;
                        _mensagem = null;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.close_rounded,
                          color: Color(0xFF444444), size: 18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Botão buscar
          GestureDetector(
            onTap: _buscando ? null : _buscar,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _buscando
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                      ),
                color: _buscando
                    ? const Color(0xFF1A1A1A)
                    : null,
                boxShadow: _buscando
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: _buscando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF6B00),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'BUSCAR',
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
          ),
          const SizedBox(height: 20),

          // Mensagem de feedback
          if (_mensagem != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isErro
                    ? const Color(0xFFED4245).withOpacity(0.08)
                    : const Color(0xFF43B581).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isErro
                      ? const Color(0xFFED4245).withOpacity(0.3)
                      : const Color(0xFF43B581).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isErro
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _isErro
                        ? const Color(0xFFED4245)
                        : const Color(0xFF43B581),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _mensagem!,
                      style: TextStyle(
                        color: _isErro
                            ? const Color(0xFFED4245)
                            : const Color(0xFF43B581),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Card do usuário encontrado
          if (_usuarioEncontrado != null) ...[
            const SizedBox(height: 16),
            _CardUsuarioEncontrado(
              user: _usuarioEncontrado!,
              statusSolicitacao: _statusSolicitacao,
              enviando: _enviando,
              myUid: widget.myUid,
              db: widget.db,
              onEnviar: _enviarSolicitacao,
            ),
          ],

          // Dica se campo vazio
          if (_usuarioEncontrado == null && _mensagem == null && !_buscando)
            _DicaBusca(),
        ],
      ),
    );
  }

  // ── ABA 2: LISTA DE AMIGOS ─────────────────────────────────────
  Widget _buildAbaListaAmigos() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('friend_requests')
          .where('status', isEqualTo: 'accepted')
          .where('participants', arrayContains: widget.myUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SkeletonListaAmigos();
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const EstadoSemAmigos();
        }

        final friendUids = snap.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['fromUid'] as String) == widget.myUid
              ? data['toUid'] as String
              : data['fromUid'] as String;
        }).toList();

        final uidsChunk = friendUids.take(30).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: widget.db
              .collection('users_xp')
              .where(FieldPath.documentId, whereIn: uidsChunk)
              .snapshots(),
          builder: (context, friendsSnap) {
            if (!friendsSnap.hasData) return _SkeletonListaAmigos();
            final amigos = friendsSnap.data!.docs
                .map((doc) => FriendModel.fromDoc(doc))
                .toList();

            if (amigos.isEmpty) return const EstadoSemAmigos();

            amigos.sort((a, b) {
              if (a.isOnline && !b.isOnline) return -1;
              if (!a.isOnline && b.isOnline) return 1;
              return a.displayName.compareTo(b.displayName);
            });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              itemCount: amigos.length,
              itemBuilder: (context, i) {
                final friend = amigos[i];
                return _CardAmigoNaLista(
                  friend: friend,
                  myUid: widget.myUid,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DO USUÁRIO ENCONTRADO NA BUSCA
// ═══════════════════════════════════════════════════════════════════
class _CardUsuarioEncontrado extends StatelessWidget {
  final FriendModel user;
  final String? statusSolicitacao;
  final bool enviando;
  final String myUid;
  final FirebaseFirestore db;
  final VoidCallback onEnviar;

  const _CardUsuarioEncontrado({
    required this.user,
    required this.statusSolicitacao,
    required this.enviando,
    required this.myUid,
    required this.db,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B00).withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Perfil
          Row(
            children: [
              AmigoAvatar(friend: user, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: const Color(0xFFFF6B00).withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        NivelBadge(level: user.level),
                        const SizedBox(width: 8),
                        Text(
                          '${user.totalXp} XP',
                          style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: user.status.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.status.label,
                          style: TextStyle(
                            color: user.status.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ação baseada no status
          if (statusSolicitacao == 'accepted')
            _BannerResultado(
              icon: Icons.chat_bubble_rounded,
              texto: 'Vocês já são amigos! Toque para conversar',
              cor: const Color(0xFF43B581),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChatScreen(friend: user)),
                );
              },
            )
          else if (statusSolicitacao == 'pending')
            _BannerResultado(
              icon: Icons.hourglass_top_rounded,
              texto: 'Solicitação já enviada — aguardando resposta',
              cor: const Color(0xFFFAA61A),
            )
          else
            GestureDetector(
              onTap: enviando ? null : onEnviar,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: enviando
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                        ),
                  color: enviando ? const Color(0xFF1A1A1A) : null,
                  boxShadow: enviando
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'ENVIAR SOLICITAÇÃO',
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
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE AMIGO NA LISTA (aba Amigos)
// ═══════════════════════════════════════════════════════════════════
class _CardAmigoNaLista extends StatelessWidget {
  final FriendModel friend;
  final String myUid;

  const _CardAmigoNaLista({required this.friend, required this.myUid});

  String _gerarChatId() {
    final ids = [myUid, friend.uid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: friend.isOnline
                ? friend.status.color.withOpacity(0.2)
                : const Color(0xFF1A1A1A),
          ),
        ),
        child: Row(
          children: [
            AmigoAvatar(friend: friend, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName.isNotEmpty
                        ? friend.displayName
                        : friend.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '@${friend.username}',
                        style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: friend.status.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        friend.status.label,
                        style: TextStyle(
                          color: friend.status.color,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFF6B00).withOpacity(0.2)),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Color(0xFFFF6B00), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BANNER DE RESULTADO
// ═══════════════════════════════════════════════════════════════════
class _BannerResultado extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color cor;
  final VoidCallback? onTap;

  const _BannerResultado({
    required this.icon,
    required this.texto,
    required this.cor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: cor.withOpacity(0.08),
          border: Border.all(color: cor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cor, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: cor, size: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DICA DE BUSCA
// ═══════════════════════════════════════════════════════════════════
class _DicaBusca extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.08),
              border: Border.all(
                  color: const Color(0xFFFF6B00).withOpacity(0.15)),
            ),
            child: const Icon(Icons.manage_search_rounded,
                color: Color(0xFFFF6B00), size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Como encontrar alguém',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DicaItem(
            icon: Icons.alternate_email_rounded,
            texto: 'Digite o @username exato',
          ),
          const SizedBox(height: 8),
          _DicaItem(
            icon: Icons.badge_rounded,
            texto: 'Digite o nome de exibição',
          ),
          const SizedBox(height: 8),
          _DicaItem(
            icon: Icons.fingerprint_rounded,
            texto: 'Cole o ID único do usuário',
          ),
        ],
      ),
    );
  }
}

class _DicaItem extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _DicaItem({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Icon(icon, color: const Color(0xFF555555), size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          texto,
          style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SKELETON DA LISTA DE AMIGOS
// ═══════════════════════════════════════════════════════════════════
class _SkeletonListaAmigos extends StatefulWidget {
  @override
  State<_SkeletonListaAmigos> createState() => _SkeletonListaAmigosState();
}

class _SkeletonListaAmigosState extends State<_SkeletonListaAmigos>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(_anim.value * 0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(_anim.value * 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(_anim.value * 0.05),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
