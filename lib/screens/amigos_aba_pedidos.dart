import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';

class AbaPedidos extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const AbaPedidos({
    Key? key,
    required this.myUid,
    required this.db,
  }) : super(key: key);

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
          return const EstadoCarregando();
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final fromUid = data['fromUid'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: db.collection('users_xp').doc(fromUid).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return const SizedBox.shrink();
                }
                final remetente = FriendModel.fromDoc(userSnap.data!);
                return _CardPedido(
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
// CARD DE SOLICITAÇÃO RECEBIDA
// ═══════════════════════════════════════════════════════════════════
class _CardPedido extends StatefulWidget {
  final FriendModel remetente;
  final String requestId;
  final String myUid;
  final FirebaseFirestore db;

  const _CardPedido({
    required this.remetente,
    required this.requestId,
    required this.myUid,
    required this.db,
  });

  @override
  State<_CardPedido> createState() => _CardPedidoState();
}

class _CardPedidoState extends State<_CardPedido>
    with SingleTickerProviderStateMixin {
  bool _carregando = false;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
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
      });
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
    final remetente = widget.remetente;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
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
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                AmigoAvatar(friend: remetente),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              remetente.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (remetente.achievements.isNotEmpty)
                            FileiraBadges(
                                achievementIds: remetente.achievements),
                        ],
                      ),
                      Text(
                        '@${remetente.username}',
                        style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          NivelBadge(level: remetente.level),
                          const SizedBox(width: 6),
                          Text(
                            '${remetente.totalXp} XP',
                            style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFF6B00).withOpacity(0.2)),
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
            const SizedBox(height: 14),
            if (_carregando)
              const SizedBox(
                height: 42,
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
                    child: GestureDetector(
                      onTap: _aceitar,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFFF6B00).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'ACEITAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _recusar,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFED4245).withOpacity(0.08),
                          border: Border.all(
                            color:
                                const Color(0xFFED4245).withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close_rounded,
                                color: Color(0xFFED4245), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'RECUSAR',
                              style: TextStyle(
                                color: Color(0xFFED4245),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
