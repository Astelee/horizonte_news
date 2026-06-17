import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import '../config/app_colors.dart';
import '../config/badge_config.dart';
import '../services/xp_service.dart';
import 'chat_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════
enum FriendStatus { online, away, playing, reading, offline }
enum FriendFilter { all, online, offline, favorites, recent }

extension FriendStatusExt on FriendStatus {
  String get label {
    switch (this) {
      case FriendStatus.online: return 'Online';
      case FriendStatus.away: return 'Ausente';
      case FriendStatus.playing: return 'Jogando';
      case FriendStatus.reading: return 'Lendo notícias';
      case FriendStatus.offline: return 'Offline';
    }
  }

  Color get color {
    switch (this) {
      case FriendStatus.online: return const Color(0xFF43B581);
      case FriendStatus.away: return const Color(0xFFFAA61A);
      case FriendStatus.playing: return const Color(0xFF7289DA);
      case FriendStatus.reading: return const Color(0xFFFF6B00);
      case FriendStatus.offline: return const Color(0xFF747F8D);
    }
  }

  IconData get icon {
    switch (this) {
      case FriendStatus.online: return Icons.circle;
      case FriendStatus.away: return Icons.access_time_rounded;
      case FriendStatus.playing: return Icons.sports_esports_rounded;
      case FriendStatus.reading: return Icons.article_rounded;
      case FriendStatus.offline: return Icons.circle_outlined;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO
// ═══════════════════════════════════════════════════════════════════
class FriendModel {
  final String uid;
  final String username;
  final String displayName;
  final int level;
  final int totalXp;
  final int xpForNextLevel;
  final FriendStatus status;
  final DateTime? lastActivity;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isFavorite;
  final bool isTyping;
  final List<String> achievements;
  final int rank;

  const FriendModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.level,
    required this.totalXp,
    required this.xpForNextLevel,
    required this.status,
    this.lastActivity,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isFavorite = false,
    this.isTyping = false,
    this.achievements = const [],
    this.rank = 0,
  });

  bool get isOnline => status != FriendStatus.offline;

  double get xpProgress {
    final base = (level - 1) * 500;
    final needed = xpForNextLevel - base;
    final current = totalXp - base;
    return (current / needed).clamp(0.0, 1.0);
  }

  factory FriendModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final last = (d['lastActivity'] as Timestamp?)?.toDate();
    final diffMin = last != null
        ? DateTime.now().difference(last).inMinutes
        : 9999;

    FriendStatus status;
    final statusStr = d['status'] as String? ?? '';
    if (statusStr == 'playing') {
      status = FriendStatus.playing;
    } else if (statusStr == 'reading') {
      status = FriendStatus.reading;
    } else if (statusStr == 'away' || (diffMin >= 5 && diffMin < 30)) {
      status = FriendStatus.away;
    } else if (diffMin < 5) {
      status = FriendStatus.online;
    } else {
      status = FriendStatus.offline;
    }

    final lvl = (d['level'] as num?)?.toInt() ?? 1;
    final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
    final nextXp = lvl * 500;

    return FriendModel(
      uid: doc.id,
      username: (d['username'] as String?) ?? '',
      displayName: (d['displayName'] as String?) ?? 'Usuário',
      level: lvl,
      totalXp: xp,
      xpForNextLevel: nextXp,
      status: status,
      lastActivity: last,
      lastMessage: d['lastMessage'] as String?,
      lastMessageTime: (d['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: (d['unreadCount'] as num?)?.toInt() ?? 0,
      isFavorite: (d['isFavorite'] as bool?) ?? false,
      isTyping: (d['isTyping'] as bool?) ?? false,
      achievements: List<String>.from(d['achievements'] ?? []),
      rank: (d['rank'] as num?)?.toInt() ?? 0,
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
  final _searchController = TextEditingController();
  FriendFilter _activeFilter = FriendFilter.all;
  String _searchQuery = '';
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _myUid => _auth.currentUser?.uid ?? '';

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          _buildTabBar(),
          if (_searchOpen) _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(
                  myUid: _myUid,
                  db: _db,
                  filter: _activeFilter,
                  searchQuery: _searchQuery,
                ),
                _RequestsTab(myUid: _myUid, db: _db),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundIconButton(
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            onTap: _toggleSearch,
          ),
          const SizedBox(width: 10),
          _AddFriendButton(myUid: _myUid, db: _db),
        ],
      ),
    );
  }

  // ── HEADER FIXO (sem flexible space — corrige o aperto no topo) ──
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 8,
        right: 16,
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.people_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AMIGOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Horizonte News',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── BARRA DE BUSCA EXPANSÍVEL (abre sob o header, sem trocar tela) ──
  Widget _buildSearchBar() {
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
              color: const Color(0xFF1A1A1A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar amigos...',
                hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF555555), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFF555555), size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      (FriendFilter.all, 'Todos', Icons.apps_rounded),
      (FriendFilter.online, 'Online', Icons.circle),
      (FriendFilter.favorites, 'Favoritos', Icons.star_rounded),
      (FriendFilter.recent, 'Recentes', Icons.history_rounded),
      (FriendFilter.offline, 'Offline', Icons.circle_outlined),
    ];

    return Container(
      color: Colors.black,
      child: SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          children: filters.map((f) {
            final isActive = _activeFilter == f.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeFilter = f.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isActive
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF111111),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF222222),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.$3,
                        size: 12,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF666666)),
                    const SizedBox(width: 5),
                    Text(
                      f.$2,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : const Color(0xFF666666),
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
          letterSpacing: 0.8,
        ),
        tabs: [
          const Tab(
            icon: Icon(Icons.people_rounded, size: 16),
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
                    const Icon(Icons.person_add_rounded, size: 16),
                    const SizedBox(width: 5),
                    const Text('PEDIDOS'),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFED4245),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
// BOTÃO REDONDO (usado para o ícone de busca ao lado de ADICIONAR)
// ═══════════════════════════════════════════════════════════════════
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111111),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA AMIGOS
// ═══════════════════════════════════════════════════════════════════
class _FriendsTab extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;
  final FriendFilter filter;
  final String searchQuery;

  const _FriendsTab({
    required this.myUid,
    required this.db,
    required this.filter,
    required this.searchQuery,
  });

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
          return const _EmptyFriendsState();
        }

        final docs = snap.data!.docs;

        return FutureBuilder<List<FriendModel>>(
          future: _loadFriends(docs),
          builder: (context, friendsSnap) {
            if (!friendsSnap.hasData) return const _LoadingState();

            var friends = friendsSnap.data!;

            // Filtros
            switch (filter) {
              case FriendFilter.online:
                friends = friends.where((f) => f.isOnline).toList();
                break;
              case FriendFilter.offline:
                friends = friends.where((f) => !f.isOnline).toList();
                break;
              case FriendFilter.favorites:
                friends = friends.where((f) => f.isFavorite).toList();
                break;
              case FriendFilter.recent:
                friends.sort((a, b) =>
                    (b.lastMessageTime ?? DateTime(0))
                        .compareTo(a.lastMessageTime ?? DateTime(0)));
                break;
              case FriendFilter.all:
                break;
            }

            // Pesquisa
            if (searchQuery.isNotEmpty) {
              friends = friends
                  .where((f) =>
                      f.displayName
                          .toLowerCase()
                          .contains(searchQuery) ||
                      f.username.toLowerCase().contains(searchQuery))
                  .toList();
            }

            // Ordenar: favoritos no topo, depois online
            friends.sort((a, b) {
              if (a.isFavorite && !b.isFavorite) return -1;
              if (!a.isFavorite && b.isFavorite) return 1;
              if (a.isOnline && !b.isOnline) return -1;
              if (!a.isOnline && b.isOnline) return 1;
              return 0;
            });

            if (friends.isEmpty) {
              return const _EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Nenhum resultado',
                subtitle: 'Tente outro filtro ou busca',
              );
            }

            // Separar favoritos
            final favorites = friends.where((f) => f.isFavorite).toList();
            final others = friends.where((f) => !f.isFavorite).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                if (favorites.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.star_rounded,
                    label: 'FAVORITOS',
                    color: const Color(0xFFFAA61A),
                    count: favorites.length,
                  ),
                  ...favorites.map((f) => _FriendCard(
                        friend: f,
                        myUid: myUid,
                        db: db,
                        requestId: '',
                      )),
                  const SizedBox(height: 8),
                ],
                if (others.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.people_rounded,
                    label: 'TODOS OS AMIGOS',
                    color: const Color(0xFF666666),
                    count: others.length,
                  ),
                  ...others.map((f) => _FriendCard(
                        friend: f,
                        myUid: myUid,
                        db: db,
                        requestId: '',
                      )),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<List<FriendModel>> _loadFriends(
      List<QueryDocumentSnapshot> docs) async {
    final futures = docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final friendUid = (data['fromUid'] as String) == myUid
          ? data['toUid'] as String
          : data['fromUid'] as String;

      final userDoc = await db.collection('users_xp').doc(friendUid).get();
      if (!userDoc.exists) return null;
      return FriendModel.fromDoc(userDoc);
    });

    final results = await Future.wait(futures);
    return results.whereType<FriendModel>().toList();
  }
}

// ═══════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE AMIGO — MODERNO (agora com emblemas reais do XpService)
// ═══════════════════════════════════════════════════════════════════
class _FriendCard extends StatelessWidget {
  final FriendModel friend;
  final String requestId;
  final String myUid;
  final FirebaseFirestore db;

  const _FriendCard({
    required this.friend,
    required this.requestId,
    required this.myUid,
    required this.db,
  });

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FriendContextMenu(
        friend: friend,
        myUid: myUid,
        db: db,
        requestId: requestId,
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
      onLongPress: () => _showContextMenu(context),
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
                spreadRadius: 0,
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _AvatarWithStatus(friend: friend),
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
                                    size: 12,
                                    color: Color(0xFFFAA61A)),
                              ],
                              if (friend.achievements.isNotEmpty)
                                _FriendBadgeRow(
                                    achievementIds: friend.achievements),
                            ],
                          ),
                        ),
                        if (friend.lastMessageTime != null)
                          Text(
                            _formatTime(friend.lastMessageTime),
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 11,
                            ),
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
                        _LevelBadge(level: friend.level),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (friend.isTyping)
                      _TypingIndicator()
                    else if (friend.lastMessage != null)
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
                    _XpProgressBar(friend: friend),
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
                          builder: (_) => ChatScreen(friend: friend),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFF6B00)
                                  .withOpacity(0.2)),
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

// ═══════════════════════════════════════════════════════════════════
// EMBLEMAS DO AMIGO — usa o mesmo XpService/BadgeConfig do perfil
// Mostra até 3 emblemas mais relevantes, ordenados por raridade
// ═══════════════════════════════════════════════════════════════════
class _FriendBadgeRow extends StatelessWidget {
  final List<String> achievementIds;
  final int maxVisible;

  const _FriendBadgeRow({
    required this.achievementIds,
    this.maxVisible = 3,
  });

  // Mais raro = índice mais alto
  static const _rarityOrder = [
    'first_login',
    '1h_online',
    'first_comment',
    'first_share',
    '100_articles',
    '10h_online',
    'level_5',
    'level_10',
  ];

  List<String> get _topByRarity {
    final sorted = List<String>.from(achievementIds);
    sorted.sort((a, b) {
      final ra = _rarityOrder.indexOf(a);
      final rb = _rarityOrder.indexOf(b);
      return (rb == -1 ? 0 : rb).compareTo(ra == -1 ? 0 : ra);
    });
    return sorted.take(maxVisible).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ids = _topByRarity;
    if (ids.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ids.map((id) {
        final color = BadgeConfig.achievementColor(id);
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4), width: 0.8),
            ),
            child: Center(
              child: FaIcon(
                BadgeConfig.achievementIcon(id),
                size: 9,
                color: color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AVATAR COM STATUS ANIMADO
// ═══════════════════════════════════════════════════════════════════
class _AvatarWithStatus extends StatefulWidget {
  final FriendModel friend;

  const _AvatarWithStatus({required this.friend});

  @override
  State<_AvatarWithStatus> createState() => _AvatarWithStatusState();
}

class _AvatarWithStatusState extends State<_AvatarWithStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.friend.status == FriendStatus.online) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.friend.isFavorite
        ? const Color(0xFFFAA61A)
        : widget.friend.status.color;

    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.friend.displayName.isNotEmpty
                  ? widget.friend.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.friend.status == FriendStatus.online)
                    Container(
                      width: 16 * _pulseAnim.value,
                      height: 16 * _pulseAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            widget.friend.status.color.withOpacity(0.3),
                      ),
                    ),
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.friend.status.color,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: widget.friend.status == FriendStatus.offline
                        ? null
                        : Center(
                            child: Icon(
                              widget.friend.status.icon,
                              size: 6,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BARRA DE XP
// ═══════════════════════════════════════════════════════════════════
class _XpProgressBar extends StatelessWidget {
  final FriendModel friend;

  const _XpProgressBar({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${friend.totalXp} XP',
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 9,
              ),
            ),
            const Expanded(child: SizedBox()),
            Text(
              '${friend.xpForNextLevel} XP',
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: friend.xpProgress,
            backgroundColor: const Color(0xFF1A1A1A),
            valueColor: AlwaysStoppedAnimation<Color>(
              friend.isFavorite
                  ? const Color(0xFFFAA61A)
                  : const Color(0xFFFF6B00),
            ),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BADGE DE NÍVEL
// ═══════════════════════════════════════════════════════════════════
class _LevelBadge extends StatelessWidget {
  final int level;

  const _LevelBadge({required this.level});

  Color get _badgeColor {
    if (level >= 50) return const Color(0xFFFFD700);
    if (level >= 30) return const Color(0xFF7289DA);
    if (level >= 15) return const Color(0xFF43B581);
    return const Color(0xFFFF6B00);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: _badgeColor.withOpacity(0.12),
        border: Border.all(color: _badgeColor.withOpacity(0.4)),
      ),
      child: Text(
        'Nv.$level',
        style: TextStyle(
          color: _badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INDICADOR "DIGITANDO..."
// ═══════════════════════════════════════════════════════════════════
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'digitando',
          style: TextStyle(
            color: const Color(0xFF43B581).withOpacity(0.8),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 3),
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
              final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF43B581).withOpacity(opacity),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CONTEXT MENU (LONG PRESS)
// ═══════════════════════════════════════════════════════════════════
class _FriendContextMenu extends StatelessWidget {
  final FriendModel friend;
  final String myUid;
  final FirebaseFirestore db;
  final String requestId;

  const _FriendContextMenu({
    required this.friend,
    required this.myUid,
    required this.db,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A)),
        ),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${friend.username}',
                    style: TextStyle(
                      color: const Color(0xFFFF6B00).withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ContextMenuItem(
            icon: Icons.person_rounded,
            label: 'Ver Perfil',
            color: Colors.white,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendProfileScreen(friend: friend),
                ),
              );
            },
          ),
          _ContextMenuItem(
            icon: Icons.chat_bubble_rounded,
            label: 'Conversar',
            color: const Color(0xFFFF6B00),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(friend: friend),
                ),
              );
            },
          ),
          _ContextMenuItem(
            icon: friend.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: friend.isFavorite
                ? 'Remover dos Favoritos'
                : 'Adicionar aos Favoritos',
            color: const Color(0xFFFAA61A),
            onTap: () {
              Navigator.pop(context);
              db.collection('users_xp').doc(friend.uid).update({
                'isFavorite': !friend.isFavorite,
              });
            },
          ),
          _ContextMenuItem(
            icon: Icons.notifications_off_rounded,
            label: 'Silenciar',
            color: const Color(0xFF747F8D),
            onTap: () => Navigator.pop(context),
          ),
          _ContextMenuItem(
            icon: Icons.delete_sweep_rounded,
            label: 'Limpar Conversa',
            color: const Color(0xFF747F8D),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: Color(0xFF1A1A1A), height: 20),
          _ContextMenuItem(
            icon: Icons.person_remove_rounded,
            label: 'Excluir Amigo',
            color: const Color(0xFFED4245),
            onTap: () {
              Navigator.pop(context);
              _confirmRemove(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover amigo?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
              if (requestId.isNotEmpty) {
                await db
                    .collection('friend_requests')
                    .doc(requestId)
                    .delete();
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

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContextMenuItem({
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Expanded(child: SizedBox()),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ABA PEDIDOS
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
                return _RequestCard(
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
// CARD DE SOLICITAÇÃO
// ═══════════════════════════════════════════════════════════════════
class _RequestCard extends StatefulWidget {
  final FriendModel sender;
  final String requestId;
  final String myUid;
  final FirebaseFirestore db;

  const _RequestCard({
    required this.sender,
    required this.requestId,
    required this.myUid,
    required this.db,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
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

  Future<void> _accept() async {
    setState(() => _loading = true);
    HapticFeedback.heavyImpact();
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
                _AvatarWithStatus(friend: widget.sender),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sender.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${widget.sender.username}',
                        style: TextStyle(
                          color: const Color(0xFFFF6B00).withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _LevelBadge(level: widget.sender.level),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.sender.totalXp} XP',
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
            if (_loading)
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
                      onTap: _accept,
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
                      onTap: _reject,
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

// ═══════════════════════════════════════════════════════════════════
// BOTÃO ADICIONAR
// ═══════════════════════════════════════════════════════════════════
class _AddFriendButton extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _AddFriendButton({required this.myUid, required this.db});

  void _showAddFriend(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFriendSheet(myUid: myUid, db: db),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddFriend(context),
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
}

// ═══════════════════════════════════════════════════════════════════
// BOTTOM SHEET ADICIONAR AMIGO
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
      _requestStatus = null;
    });

    HapticFeedback.lightImpact();

    try {
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

      final existing = await widget.db
          .collection('friend_requests')
          .where('participants', arrayContains: widget.myUid)
          .get();

      String? existingStatus;

      for (final doc in existing.docs) {
        final d = doc.data();
        final participants = List<String>.from(d['participants'] ?? []);
        if (participants.contains(user.uid)) {
          existingStatus = d['status'] as String?;
          break;
        }
      }

      setState(() {
        _foundUser = user;
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
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                  ),
                  borderRadius: BorderRadius.circular(12),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Digite o @ do usuário',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E1E1E)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onSubmitted: (_) => _search(),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_]')),
                      TextInputFormatter.withFunction((old, newVal) {
                        return newVal.copyWith(
                            text: newVal.text.toLowerCase());
                      }),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'ex: joao_silva123',
                      hintStyle: TextStyle(
                          color: Color(0xFF333333), fontSize: 15),
                      prefixText: '@  ',
                      prefixStyle: TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
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
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withOpacity(0.4),
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
          if (_message != null) ...[
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isError
                    ? const Color(0xFFED4245).withOpacity(0.08)
                    : const Color(0xFF43B581).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isError
                      ? const Color(0xFFED4245).withOpacity(0.3)
                      : const Color(0xFF43B581).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: _isError
                        ? const Color(0xFFED4245)
                        : const Color(0xFF43B581),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? const Color(0xFFED4245)
                            : const Color(0xFF43B581),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_foundUser != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFFFF6B00).withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _AvatarWithStatus(friend: _foundUser!),
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
                                color: const Color(0xFFFF6B00)
                                    .withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _LevelBadge(level: _foundUser!.level),
                                const SizedBox(width: 6),
                                Text(
                                  '${_foundUser!.totalXp} XP',
                                  style: const TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 11,
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
                  if (_requestStatus == 'accepted')
                    _StatusBanner(
                      icon: Icons.people_rounded,
                      text: 'Vocês já são amigos!',
                      color: const Color(0xFFFF6B00),
                    )
                  else if (_requestStatus == 'pending')
                    _StatusBanner(
                      icon: Icons.hourglass_top_rounded,
                      text: 'Solicitação já enviada',
                      color: const Color(0xFFFAA61A),
                    )
                  else
                    GestureDetector(
                      onTap: _sending ? null : _sendRequest,
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _sending
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)
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
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
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
// TELA DE PERFIL DO AMIGO — com grade de emblemas reais
// ═══════════════════════════════════════════════════════════════════
class FriendProfileScreen extends StatelessWidget {
  final FriendModel friend;

  const FriendProfileScreen({Key? key, required this.friend})
      : super(key: key);

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  @override
  Widget build(BuildContext context) {
    final xpService = XpService();
    final achievements = xpService.getAllAchievements(friend.achievements);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF150600), Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                                color: friend.status.color, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withOpacity(0.5),
                                blurRadius: 24,
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
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: friend.status.color,
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '@${friend.username}',
                          style: TextStyle(
                            color: const Color(0xFFFF6B00).withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: friend.status.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: friend.status.color.withOpacity(0.4)),
                          ),
                          child: Text(
                            friend.status.label,
                            style: TextStyle(
                              color: friend.status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                children: [
                  // Botão Chat
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(friend: friend),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFCC4400)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'ENVIAR MENSAGEM',
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
                  const SizedBox(height: 16),
                  // Status card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1A1A1A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: friend.status.color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          friend.isOnline
                              ? friend.status.label
                              : friend.lastActivity != null
                                  ? 'Visto ${_timeAgo(friend.lastActivity!)}'
                                  : 'Offline',
                          style: TextStyle(
                            color: friend.status.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Stats
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFF6B00).withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESTATÍSTICAS',
                          style: TextStyle(
                            color: Color(0xFFFF6B00),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatCard(
                                label: 'XP Total',
                                value: '${friend.totalXp}',
                                icon: Icons.bolt_rounded,
                                color: const Color(0xFFFF6B00)),
                            const SizedBox(width: 10),
                            _StatCard(
                                label: 'Nível',
                                value: '${friend.level}',
                                icon: Icons.military_tech_rounded,
                                color: const Color(0xFF7289DA)),
                            if (friend.rank > 0) ...[
                              const SizedBox(width: 10),
                              _StatCard(
                                  label: 'Ranking',
                                  value: '#${friend.rank}',
                                  icon: Icons.leaderboard_rounded,
                                  color: const Color(0xFFFFD700)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PROGRESSO',
                          style: TextStyle(
                            color: Color(0xFF444444),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Nv.${friend.level}',
                              style: const TextStyle(
                                color: Color(0xFFFF6B00),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: friend.xpProgress,
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFF6B00)),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nv.${friend.level + 1}',
                              style: const TextStyle(
                                color: Color(0xFF444444),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            '${friend.totalXp} / ${friend.xpForNextLevel} XP',
                            style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grade de emblemas reais (mesmo sistema do seu perfil)
                  _FriendAchievementsCard(achievements: achievements),
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
// CARD DE EMBLEMAS NO PERFIL DO AMIGO
// ═══════════════════════════════════════════════════════════════════
class _FriendAchievementsCard extends StatelessWidget {
  final List<Achievement> achievements;

  const _FriendAchievementsCard({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.unlocked).toList();
    final locked = achievements.where((a) => !a.unlocked).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0C0C0C),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EMBLEMAS',
                style: TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFFF6B00).withOpacity(0.15),
                ),
                child: Text(
                  '${unlocked.length} / ${achievements.length}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (unlocked.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: unlocked.length,
              itemBuilder: (context, i) =>
                  _ProfileEmblemTile(achievement: unlocked[i], unlocked: true),
            ),
          ],
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'BLOQUEADOS',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: locked.length,
              itemBuilder: (context, i) =>
                  _ProfileEmblemTile(achievement: locked[i], unlocked: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileEmblemTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;

  const _ProfileEmblemTile({
    required this.achievement,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? BadgeConfig.achievementColor(achievement.icon)
        : const Color(0xFF2A2A2A);

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0A0A0A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                    border: Border.all(
                        color: color.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: FaIcon(
                      BadgeConfig.achievementIcon(achievement.icon),
                      size: 26,
                      color: unlocked ? color : const Color(0xFF3A3A3A),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: unlocked ? Colors.white : const Color(0xFF444444),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  achievement.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: unlocked
                        ? color.withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                  ),
                  child: Text(
                    unlocked ? 'OBTIDO' : 'BLOQUEADO',
                    style: TextStyle(
                      color: unlocked ? color : const Color(0xFF444444),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: unlocked
              ? color.withOpacity(0.08)
              : const Color(0xFF0F0F0F),
          border: Border.all(
            color: unlocked
                ? color.withOpacity(0.3)
                : const Color(0xFF1A1A1A),
            width: 1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? color.withOpacity(0.15)
                    : const Color(0xFF1A1A1A),
                border: Border.all(
                  color: unlocked
                      ? color.withOpacity(0.4)
                      : const Color(0xFF2A2A2A),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: FaIcon(
                  BadgeConfig.achievementIcon(achievement.icon),
                  size: 16,
                  color: unlocked ? color : const Color(0xFF3A3A3A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? Colors.white : const Color(0xFF333333),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            if (!unlocked)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: FaIcon(
                  FontAwesomeIcons.lock,
                  size: 8,
                  color: Color(0xFF333333),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EMPTY STATES
// ═══════════════════════════════════════════════════════════════════
class _EmptyFriendsState extends StatelessWidget {
  const _EmptyFriendsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6B00).withOpacity(0.06),
              border: Border.all(
                  color: const Color(0xFFFF6B00).withOpacity(0.15)),
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 36, color: Color(0xFFFF6B00)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum amigo ainda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use o botão + para encontrar\namigos pelo username',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF444444), fontSize: 13),
          ),
        ],
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
              size: 48,
              color: const Color(0xFFFF6B00).withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Color(0xFF444444), fontSize: 13)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Color(0xFFFF6B00),
      ),
    );
  }
}
