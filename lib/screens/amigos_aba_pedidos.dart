// amigos_aba_pedidos.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';

class AbaPedidos extends StatefulWidget {
  final String myUid;
  final FirebaseFirestore db;

  const AbaPedidos({
    Key? key,
    required this.myUid,
    required this.db,
  }) : super(key: key);

  @override
  State<AbaPedidos> createState() => _AbaPedidosState();
}

class _AbaPedidosState extends State<AbaPedidos>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Sub-TabBar ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1A1A1A)),
          ),
          child: TabBar(
            controller: _tab,
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
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
            tabs: [
              _buildTab('RECEBIDAS', Icons.inbox_rounded),
              _buildTab('ENVIADAS', Icons.outbox_rounded),
            ],
          ),
        ),
        // ── Conteúdo ────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AbaRecebidas(myUid: widget.myUid, db: widget.db),
              _AbaEnviadas(myUid: widget.myUid, db: widget.db),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA: SOLICITAÇÕES RECEBIDAS
// ═══════════════════════════════════════════════════════════════════
class _AbaRecebidas extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _AbaRecebidas({required this.myUid, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('friend_requests')
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SkeletonPedidos();
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const EstadoVazio(
            icon: Icons.mark_email_read_rounded,
            titulo: 'Sem pedidos pendentes',
            subtitulo: 'Quando alguém te adicionar, aparece aqui',
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final fromUid = data['fromUid'] as String;

            return StreamBuilder<DocumentSnapshot>(
              stream: db.collection('users_xp').doc(fromUid).snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return _SkeletonCardPedido();
                }
                final remetente = FriendModel.fromDoc(userSnap.data!);
                return _CardPedidoRecebido(
                  remetente: remetente,
                  requestId: docs[i].id,
                  myUid: myUid,
                  db: db,
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
// ABA: SOLICITAÇÕES ENVIADAS
// ═══════════════════════════════════════════════════════════════════
class _AbaEnviadas extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _AbaEnviadas({required this.myUid, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _SkeletonPedidos();
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const EstadoVazio(
            icon: Icons.send_rounded,
            titulo: 'Nenhuma solicitação enviada',
            subtitulo: 'Adicione amigos pelo botão + AMIGOS',
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final toUid = data['toUid'] as String;

            return StreamBuilder<DocumentSnapshot>(
              stream: db.collection('users_xp').doc(toUid).snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return _SkeletonCardPedido();
                }
                final destinatario = FriendModel.fromDoc(userSnap.data!);
                return _CardPedidoEnviado(
                  destinatario: destinatario,
                  requestId: docs[i].id,
                  db: db,
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
// CARD: PEDIDO RECEBIDO
// ═══════════════════════════════════════════════════════════════════
class _CardPedidoRecebido extends StatefulWidget {
  final FriendModel remetente;
  final String requestId;
  final String myUid;
  final FirebaseFirestore db;

  const _CardPedidoRecebido({
    required this.remetente,
    required this.requestId,
    required this.myUid,
    required this.db,
  });

  @override
  State<_CardPedidoRecebido> createState() => _CardPedidoRecebidoState();
}

class _CardPedidoRecebidoState extends State<_CardPedidoRecebido>
    with SingleTickerProviderStateMixin {
  bool _carregando = false;
  late AnimationController _entryCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.4, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _aceitar() async {
    setState(() => _carregando = true);
    HapticFeedback.heavyImpact();
    try {
      await widget.db
          .collection('friend_requests')
          .doc(widget.requestId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'participants': [widget.myUid, widget.remetente.uid],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF43B581), size: 18),
                const SizedBox(width: 10),
                Text(
                  'Agora vocês são amigos! 🎉',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF111111),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recusar() async {
    setState(() => _carregando = true);
    HapticFeedback.lightImpact();
    try {
      await widget.db
          .collection('friend_requests')
          .doc(widget.requestId)
          .delete();
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.remetente;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF6B00).withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.04),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Cabeçalho do card ───────────────────────────
                Row(
                  children: [
                    AmigoAvatar(friend: r),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (r.achievements.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                FileiraBadges(
                                    achievementIds: r.achievements),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${r.username}',
                            style: TextStyle(
                              color: const Color(0xFFFF6B00).withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              NivelBadge(level: r.level),
                              const SizedBox(width: 8),
                              Text(
                                '${r.totalXp} XP',
                                style: const TextStyle(
                                  color: Color(0xFF555555),
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B00).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFFF6B00)
                                          .withOpacity(0.25)),
                                ),
                                child: const Text(
                                  'NOVO',
                                  style: TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Ações ───────────────────────────────────────
                if (_carregando)
                  const SizedBox(
                    height: 44,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6B00),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _BotaoAcao(
                          label: 'ACEITAR',
                          icon: Icons.check_rounded,
                          gradiente: const [
                            Color(0xFFFF6B00),
                            Color(0xFFCC4400)
                          ],
                          corTexto: Colors.white,
                          onTap: _aceitar,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BotaoAcao(
                          label: 'RECUSAR',
                          icon: Icons.close_rounded,
                          corFundo: const Color(0xFFED4245).withOpacity(0.08),
                          corBorda: const Color(0xFFED4245).withOpacity(0.3),
                          corTexto: const Color(0xFFED4245),
                          onTap: _recusar,
                        ),
                      ),
                    ],
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
// CARD: PEDIDO ENVIADO
// ═══════════════════════════════════════════════════════════════════
class _CardPedidoEnviado extends StatefulWidget {
  final FriendModel destinatario;
  final String requestId;
  final FirebaseFirestore db;

  const _CardPedidoEnviado({
    required this.destinatario,
    required this.requestId,
    required this.db,
  });

  @override
  State<_CardPedidoEnviado> createState() => _CardPedidoEnviadoState();
}

class _CardPedidoEnviadoState extends State<_CardPedidoEnviado>
    with SingleTickerProviderStateMixin {
  bool _cancelando = false;
  late AnimationController _entryCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _cancelar(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancelar solicitação?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'A solicitação para @${widget.destinatario.username} será cancelada.',
          style: const TextStyle(color: Color(0xFF666666), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                  color: Color(0xFFED4245), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirma != true) return;
    setState(() => _cancelando = true);
    try {
      await widget.db
          .collection('friend_requests')
          .doc(widget.requestId)
          .delete();
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.destinatario;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFAA61A).withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AmigoAvatar(friend: d),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${d.username}',
                        style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              size: 12, color: Color(0xFFFAA61A)),
                          const SizedBox(width: 4),
                          const Text(
                            'Aguardando resposta',
                            style: TextStyle(
                              color: Color(0xFFFAA61A),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_cancelando)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFED4245)),
                  )
                else
                  GestureDetector(
                    onTap: () => _cancelar(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED4245).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFFED4245).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Color(0xFFED4245),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
// BOTÃO DE AÇÃO GENÉRICO
// ═══════════════════════════════════════════════════════════════════
class _BotaoAcao extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color>? gradiente;
  final Color? corFundo;
  final Color? corBorda;
  final Color corTexto;
  final VoidCallback onTap;

  const _BotaoAcao({
    required this.label,
    required this.icon,
    required this.corTexto,
    required this.onTap,
    this.gradiente,
    this.corFundo,
    this.corBorda,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: gradiente != null
              ? LinearGradient(colors: gradiente!)
              : null,
          color: corFundo,
          border: corBorda != null ? Border.all(color: corBorda!) : null,
          boxShadow: gradiente != null
              ? [
                  BoxShadow(
                    color: gradiente!.first.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: corTexto, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: corTexto,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SKELETON LOADING
// ═══════════════════════════════════════════════════════════════════
class _SkeletonPedidos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      itemCount: 3,
      itemBuilder: (_, __) => _SkeletonCardPedido(),
    );
  }
}

class _SkeletonCardPedido extends StatefulWidget {
  @override
  State<_SkeletonCardPedido> createState() => _SkeletonCardPedidoState();
}

class _SkeletonCardPedidoState extends State<_SkeletonCardPedido>
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1A1A1A)),
          ),
          child: Row(
            children: [
              _SkeletonBox(w: 50, h: 50, radius: 25, opacity: _anim.value),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(w: 140, h: 14, radius: 7, opacity: _anim.value),
                    const SizedBox(height: 8),
                    _SkeletonBox(w: 90, h: 11, radius: 6, opacity: _anim.value * 0.7),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SkeletonBox(w: 70, h: 36, radius: 10, opacity: _anim.value),
                        const SizedBox(width: 8),
                        _SkeletonBox(w: 70, h: 36, radius: 10, opacity: _anim.value * 0.7),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double w;
  final double h;
  final double radius;
  final double opacity;

  const _SkeletonBox({
    required this.w,
    required this.h,
    required this.radius,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity * 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
