import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO
// ═══════════════════════════════════════════════════════════════════
class FriendModel {
  final String uid;
  final String username;
  final String displayName;
  final int level;
  final int totalXp;
  final bool isOnline;
  final DateTime? lastActivity;

  const FriendModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.level,
    required this.totalXp,
    required this.isOnline,
    this.lastActivity,
  });

  factory FriendModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final last = (d['lastActivity'] as Timestamp?)?.toDate();
    final online = last != null &&
        DateTime.now().difference(last).inMinutes < 5;
    return FriendModel(
      uid: doc.id,
      username: (d['username'] as String?) ?? '',
      displayName: (d['displayName'] as String?) ?? 'Usuário',
      level: (d['level'] as num?)?.toInt() ?? 1,
      totalXp: (d['totalXp'] as num?)?.toInt() ?? 0,
      isOnline: online,
      lastActivity: last,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TELA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _myUid => _auth.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabController,
          children: [
            _FriendsTab(myUid: _myUid, db: _db),
            _RequestsTab(myUid: _myUid, db: _db),
          ],
        ),
      ),
      floatingActionButton: _AddFriendButton(myUid: _myUid, db: _db),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: AppColors.orangeGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.people_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AMIGOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Horizonte News',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF160400), Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryOrange,
        indicatorWeight: 2,
        labelColor: AppColors.primaryOrange,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        tabs: [
          const Tab(
            icon: Icon(Icons.people_rounded, size: 18),
            text: 'AMIGOS',
          ),
          Tab(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('friend_requests')
                  .where('toUid', isEqualTo: _myUid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_rounded, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'PEDIDOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
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
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA 1 — LISTA DE AMIGOS
// ═══════════════════════════════════════════════════════════════════
class _FriendsTab extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _FriendsTab({required this.myUid, required this.db});

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
          return const _LoadingState();
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Nenhum amigo ainda',
            subtitle: 'Use o botão + para buscar amigos pelo ID',
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            // Pega o UID do amigo (o que não é o meu)
            final friendUid = (data['fromUid'] as String) == myUid
                ? data['toUid'] as String
                : data['fromUid'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: db.collection('users_xp').doc(friendUid).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return const SizedBox.shrink();
                }
                final friend = FriendModel.fromDoc(userSnap.data!);
                return _FriendTile(
                  friend: friend,
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
// ABA 2 — SOLICITAÇÕES RECEBIDAS
// ═══════════════════════════════════════════════════════════════════
class _RequestsTab extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _RequestsTab({required this.myUid, required this.db});

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
          return const _LoadingState();
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.mark_email_read_rounded,
            title: 'Sem pedidos pendentes',
            subtitle: 'Quando alguém te adicionar, aparece aqui',
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
                final sender = FriendModel.fromDoc(userSnap.data!);
                return _RequestTile(
                  sender: sender,
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
// TILE DE AMIGO CONFIRMADO
// ═══════════════════════════════════════════════════════════════════
class _FriendTile extends StatelessWidget {
  final FriendModel friend;
  final String requestId;
  final String myUid;
  final FirebaseFirestore db;

  const _FriendTile({
    required this.friend,
    required this.requestId,
    required this.myUid,
    required this.db,
  });

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover amigo?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Você tem certeza que quer remover @${friend.username}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await db
                  .collection('friend_requests')
                  .doc(requestId)
                  .delete();
            },
            child: const Text('Remover',
                style: TextStyle(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FriendProfileScreen(friend: friend),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            // Avatar + status online
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                // Indicador online
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: friend.isOnline
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF555555),
                      border: Border.all(
                          color: const Color(0xFF0A0A0A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${friend.username}',
                    style: TextStyle(
                      color: AppColors.primaryOrange.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          border: Border.all(
                              color:
                                  AppColors.primaryOrange.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Nv. ${friend.level}  •  ${friend.totalXp} XP',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        friend.isOnline ? '● Online' : '● Offline',
                        style: TextStyle(
                          color: friend.isOnline
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF555555),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botão remover
            GestureDetector(
              onTap: () => _confirmRemove(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.emergencyRed.withOpacity(0.2)),
                ),
                child: const Icon(Icons.person_remove_rounded,
                    color: AppColors.emergencyRed, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE DE SOLICITAÇÃO RECEBIDA
// ═══════════════════════════════════════════════════════════════════
class _RequestTile extends StatefulWidget {
  final FriendModel sender;
  final String requestId;
  final String myUid;
  final FirebaseFirestore db;

  const _RequestTile({
    required this.sender,
    required this.requestId,
    required this.myUid,
    required this.db,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    await widget.db
        .collection('friend_requests')
        .doc(widget.requestId)
        .update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    await widget.db
        .collection('friend_requests')
        .doc(widget.requestId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.05),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.sender.displayName.isNotEmpty
                        ? widget.sender.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sender.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@${widget.sender.username}',
                      style: TextStyle(
                        color: AppColors.primaryOrange.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Nv. ${widget.sender.level}  •  ${widget.sender.totalXp} XP',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Aceitar
                    Expanded(
                      child: GestureDetector(
                        onTap: _accept,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: AppColors.orangeGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange
                                    .withOpacity(0.3),
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
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Recusar
                    Expanded(
                      child: GestureDetector(
                        onTap: _reject,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.emergencyRed.withOpacity(0.1),
                            border: Border.all(
                              color:
                                  AppColors.emergencyRed.withOpacity(0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded,
                                  color: AppColors.emergencyRed, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'RECUSAR',
                                style: TextStyle(
                                  color: AppColors.emergencyRed,
                                  fontSize: 12,
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
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTÃO FLUTUANTE — ADICIONAR AMIGO
// ═══════════════════════════════════════════════════════════════════
class _AddFriendButton extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _AddFriendButton({required this.myUid, required this.db});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddFriendSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: AppColors.orangeGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'ADICIONAR',
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

  void _showAddFriendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFriendSheet(myUid: myUid, db: db),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET — BUSCAR E ENVIAR SOLICITAÇÃO
// ═══════════════════════════════════════════════════════════════════
class _AddFriendSheet extends StatefulWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _AddFriendSheet({required this.myUid, required this.db});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _controller = TextEditingController();
  FriendModel? _foundUser;
  bool _searching = false;
  bool _sending = false;
  String? _message;
  bool _isError = false;
  String? _alreadyRequestId;
  String? _requestStatus;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _foundUser = null;
      _message = null;
      _alreadyRequestId = null;
      _requestStatus = null;
    });

    HapticFeedback.lightImpact();

    try {
      // Busca por username
      final snap = await widget.db
          .collection('users_xp')
          .where('username', isEqualTo: query)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _message = 'Nenhum usuário encontrado com @$query';
          _isError = true;
          _searching = false;
        });
        return;
      }

      final user = FriendModel.fromDoc(snap.docs.first);

      if (user.uid == widget.myUid) {
        setState(() {
          _message = 'Você não pode se adicionar.';
          _isError = true;
          _searching = false;
        });
        return;
      }

      // Verifica se já existe solicitação ou amizade
      final existing = await widget.db
          .collection('friend_requests')
          .where('participants', arrayContains: widget.myUid)
          .get();

      String? existingId;
      String? existingStatus;

      for (final doc in existing.docs) {
        final d = doc.data();
        final participants = List<String>.from(d['participants'] ?? []);
        if (participants.contains(user.uid)) {
          existingId = doc.id;
          existingStatus = d['status'] as String?;
          break;
        }
      }

      setState(() {
        _foundUser = user;
        _alreadyRequestId = existingId;
        _requestStatus = existingStatus;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Erro ao buscar. Tente novamente.';
        _isError = true;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    if (_foundUser == null) return;
    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.db.collection('friend_requests').add({
        'fromUid': widget.myUid,
        'toUid': _foundUser!.uid,
        'participants': [widget.myUid, _foundUser!.uid],
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _message = 'Solicitação enviada para @${_foundUser!.username}!';
        _isError = false;
        _foundUser = null;
        _controller.clear();
        _sending = false;
      });

      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() {
        _message = 'Erro ao enviar. Tente novamente.';
        _isError = true;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A)),
          left: BorderSide(color: Color(0xFF1A1A1A)),
          right: BorderSide(color: Color(0xFF1A1A1A)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_search_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BUSCAR AMIGO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Digite o ID do usuário para encontrá-lo',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Campo de busca
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF212121)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15),
                    onSubmitted: (_) => _search(),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_]')),
                      TextInputFormatter.withFunction((old, newVal) {
                        return newVal.copyWith(
                            text: newVal.text.toLowerCase());
                      }),
                    ],
                    decoration: InputDecoration(
                      hintText: 'ex: joao_silva123',
                      hintStyle: const TextStyle(
                          color: Color(0xFF424242), fontSize: 15),
                      prefixText: '@',
                      prefixStyle: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      prefixIcon: const Icon(Icons.tag_rounded,
                          color: AppColors.primaryOrange, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _searching ? null : _search,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppColors.orangeGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryOrange.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _searching
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.search_rounded,
                          color: Colors.white, size: 24),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Mensagem de feedback
          if (_message != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isError
                    ? AppColors.emergencyRed.withOpacity(0.1)
                    : const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isError
                      ? AppColors.emergencyRed.withOpacity(0.4)
                      : const Color(0xFF4CAF50).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: _isError
                        ? AppColors.emergencyRed
                        : const Color(0xFF4CAF50),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? AppColors.emergencyRed
                            : const Color(0xFF4CAF50),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Card do usuário encontrado
          if (_foundUser != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6B00),
                              Color(0xFFCC4400)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryOrange.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _foundUser!.displayName.isNotEmpty
                                ? _foundUser!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foundUser!.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '@${_foundUser!.username}',
                              style: TextStyle(
                                color:
                                    AppColors.primaryOrange.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: AppColors.primaryOrange
                                    .withOpacity(0.1),
                                border: Border.all(
                                    color: AppColors.primaryOrange
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                'Nível ${_foundUser!.level}  •  ${_foundUser!.totalXp} XP',
                                style: const TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botão de ação
                  if (_requestStatus == 'accepted')
                    _statusBanner(
                        Icons.people_rounded,
                        'Vocês já são amigos!',
                        AppColors.primaryOrange)
                  else if (_requestStatus == 'pending')
                    _statusBanner(
                        Icons.hourglass_top_rounded,
                        'Solicitação já enviada',
                        const Color(0xFFFFB300))
                  else
                    GestureDetector(
                      onTap: _sending ? null : _sendRequest,
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: AppColors.orangeGradient,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryOrange.withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _sending
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
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _statusBanner(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TELA DE PERFIL DO AMIGO
// ═══════════════════════════════════════════════════════════════════
class FriendProfileScreen extends StatelessWidget {
  final FriendModel friend;

  const FriendProfileScreen({Key? key, required this.friend})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.backgroundDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A0800), Color(0xFF000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF6B00),
                                Color(0xFFCC4400)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange
                                    .withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              friend.displayName.isNotEmpty
                                  ? friend.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: friend.isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF555555),
                            border: Border.all(
                                color: AppColors.backgroundDark,
                                width: 2.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${friend.username}',
                      style: TextStyle(
                        color: AppColors.primaryOrange.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: friend.isOnline
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : const Color(0xFF333333).withOpacity(0.3),
                      border: Border.all(
                        color: friend.isOnline
                            ? const Color(0xFF4CAF50).withOpacity(0.4)
                            : const Color(0xFF333333),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: friend.isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF555555),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          friend.isOnline
                              ? 'Online agora'
                              : friend.lastActivity != null
                                  ? 'Visto há ${_timeAgo(friend.lastActivity!)}'
                                  : 'Offline',
                          style: TextStyle(
                            color: friend.isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF777777),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats XP
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(
                        color: AppColors.primaryOrange.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESTATÍSTICAS',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatItem(
                                label: 'XP Total',
                                value: '${friend.totalXp}'),
                            _StatItem(
                                label: 'Nível',
                                value: '${friend.level}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primaryOrange,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 56,
              color: AppColors.primaryOrange.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
