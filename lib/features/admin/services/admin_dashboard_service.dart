import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/xp_service.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO — SNAPSHOT COMPLETO DO DASHBOARD
// Tudo aqui é calculado a partir de dados reais já existentes no
// Firestore (users_xp, post_views, suspensions, admin_logs).
// Nenhum número é inventado ou estimado.
// ═══════════════════════════════════════════════════════════════════
class DashboardSnapshot {
  final int totalUsers;
  final int onlineNow;
  final int activeToday;
  final int totalXp;
  final int totalComments;
  final int totalArticlesRead;
  final int totalShares;
  final int totalSuspended;
  final int totalViews;
  final int totalUniqueViewers;
  final double avgLevel;
  final List<DashUser> topByXp;
  final List<DashUser> mostRecentlyActive;
  final Map<int, int> levelDistribution; // faixa de nível -> contagem
  final List<DashPost> topPosts;
  final List<DashPost> topShared;

  const DashboardSnapshot({
    required this.totalUsers,
    required this.onlineNow,
    required this.activeToday,
    required this.totalXp,
    required this.totalComments,
    required this.totalArticlesRead,
    required this.totalShares,
    required this.totalSuspended,
    required this.totalViews,
    required this.totalUniqueViewers,
    required this.avgLevel,
    required this.topByXp,
    required this.mostRecentlyActive,
    required this.levelDistribution,
    required this.topPosts,
    required this.topShared,
  });

  factory DashboardSnapshot.empty() => const DashboardSnapshot(
        totalUsers: 0,
        onlineNow: 0,
        activeToday: 0,
        totalXp: 0,
        totalComments: 0,
        totalArticlesRead: 0,
        totalShares: 0,
        totalSuspended: 0,
        totalViews: 0,
        totalUniqueViewers: 0,
        avgLevel: 0,
        topByXp: [],
        mostRecentlyActive: [],
        levelDistribution: {},
        topPosts: [],
        topShared: [],
      );
}

class DashUser {
  final String uid;
  final String name;
  final String email;
  final int totalXp;
  final int level;
  final DateTime? lastActivity;
  final DateTime? lastSeenAt;

  const DashUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.totalXp,
    required this.level,
    this.lastActivity,
    this.lastSeenAt,
  });

  bool get isOnline =>
      lastSeenAt != null &&
      DateTime.now().difference(lastSeenAt!).inMinutes < 5;
}

class DashPost {
  final String postId;
  final String title;
  final int totalViews;
  final int uniqueViewers;

  const DashPost({
    required this.postId,
    required this.title,
    required this.totalViews,
    required this.uniqueViewers,
  });
}

// ═══════════════════════════════════════════════════════════════════
// SERVIÇO
// ═══════════════════════════════════════════════════════════════════
class AdminDashboardService {
  final _db = FirebaseFirestore.instance;

  /// Carrega o snapshot do dashboard sob demanda (uma leitura .get() em
  /// cada coleção, sem manter um stream em tempo real aberto na coleção
  /// inteira de users_xp). Chame novamente para atualizar (ex.: pull-to-
  /// refresh ou um timer periódico).
  Future<DashboardSnapshot> loadDashboard() async {
    final usersSnap = await _db
        .collection('users_xp')
        .orderBy('totalXp', descending: true)
        .get();
    final viewsSnap = await _db
        .collection('post_views')
        .orderBy('totalViews', descending: true)
        .limit(10)
        .get();
    final suspSnap = await _db.collection('suspensions').get();
    final sharesSnap = await _db
        .collection('post_shares')
        .orderBy('totalShares', descending: true)
        .limit(10)
        .get();

    return _build(usersSnap.docs, viewsSnap.docs, suspSnap.docs, sharesSnap.docs);
  }

  Stream<List<Map<String, dynamic>>> recentLogsStream({int limit = 12}) {
    return _db
        .collection('admin_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  DashboardSnapshot _build(
    List<QueryDocumentSnapshot> userDocs,
    List<QueryDocumentSnapshot> viewDocs,
    List<QueryDocumentSnapshot> suspDocs,
    List<QueryDocumentSnapshot> shareDocs,
  ) {
    int totalXp = 0;
    int totalComments = 0;
    int totalArticlesRead = 0;
    int totalShares = 0;
    int onlineNow = 0;
    int activeToday = 0;
    int levelSum = 0;
    final levelDistribution = <int, int>{}; // bucket inicial (1-4,5-9,...)
    final allUsers = <DashUser>[];

    final now = DateTime.now();

    for (final doc in userDocs) {
      final d = doc.data() as Map<String, dynamic>;
      final xp = (d['totalXp'] as num?)?.toInt() ?? 0;
      final level = XpService.levelFromXp(xp);
      final stats = Map<String, dynamic>.from(d['stats'] ?? {});
      final comments = (stats['commentsPosted'] as num?)?.toInt() ?? 0;
      final articles = (stats['articlesRead'] as num?)?.toInt() ?? 0;
      final shares = (stats['articlesShared'] as num?)?.toInt() ?? 0;
      final lastSeenAt = (d['lastSeenAt'] as Timestamp?)?.toDate();
      final lastActivity = (d['lastActivity'] as Timestamp?)?.toDate();

      String name = 'Sem nome';
      for (final f in ['displayName', 'name', 'userName']) {
        final v = d[f];
        if (v is String && v.trim().isNotEmpty) {
          name = v.trim();
          break;
        }
      }
      final email = (d['email'] as String?) ?? '';
      if (name == 'Sem nome' && email.isNotEmpty) {
        name = email.split('@').first;
      }

      totalXp += xp;
      totalComments += comments;
      totalArticlesRead += articles;
      totalShares += shares;
      levelSum += level;

      if (lastSeenAt != null && now.difference(lastSeenAt).inMinutes < 5) {
        onlineNow++;
      }
      if (lastActivity != null && now.difference(lastActivity).inHours < 24) {
        activeToday++;
      }

      final bucket = _levelBucket(level);
      levelDistribution[bucket] = (levelDistribution[bucket] ?? 0) + 1;

      allUsers.add(DashUser(
        uid: doc.id,
        name: name,
        email: email,
        totalXp: xp,
        level: level,
        lastActivity: lastActivity,
        lastSeenAt: lastSeenAt,
      ));
    }

    final topByXp = allUsers.take(5).toList();

    final mostRecentlyActive = [...allUsers]
      ..sort((a, b) {
        final aT = a.lastActivity?.millisecondsSinceEpoch ?? 0;
        final bT = b.lastActivity?.millisecondsSinceEpoch ?? 0;
        return bT.compareTo(aT);
      });

    int totalViews = 0;
    int totalUniqueViewers = 0;
    final topPosts = <DashPost>[];
    for (final doc in viewDocs) {
      final d = doc.data() as Map<String, dynamic>;
      final tv = (d['totalViews'] as num?)?.toInt() ?? 0;
      final uv = (d['uniqueViewers'] as num?)?.toInt() ?? 0;
      totalViews += tv;
      totalUniqueViewers += uv;
      topPosts.add(DashPost(
        postId: doc.id,
        title: (d['postTitle'] as String?) ?? 'Sem título',
        totalViews: tv,
        uniqueViewers: uv,
      ));
    }

    final topShared = <DashPost>[];
    for (final doc in shareDocs) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = (d['totalShares'] as num?)?.toInt() ?? 0;
      topShared.add(DashPost(
        postId: doc.id,
        title: (d['postTitle'] as String?) ?? 'Sem título',
        totalViews: ts,
        uniqueViewers: 0,
      ));
    }

    return DashboardSnapshot(
      totalUsers: allUsers.length,
      onlineNow: onlineNow,
      activeToday: activeToday,
      totalXp: totalXp,
      totalComments: totalComments,
      totalArticlesRead: totalArticlesRead,
      totalShares: totalShares,
      totalSuspended: suspDocs.length,
      totalViews: totalViews,
      totalUniqueViewers: totalUniqueViewers,
      avgLevel: allUsers.isEmpty ? 0.0 : levelSum / allUsers.length,
      topByXp: topByXp,
      mostRecentlyActive: mostRecentlyActive.take(6).toList(),
      levelDistribution: levelDistribution,
      topShared: topShared.take(5).toList(),
      topPosts: topPosts.take(5).toList(),
    );
  }

  /// Agrupa níveis em faixas legíveis para o gráfico de distribuição.
  int _levelBucket(int level) {
    if (level <= 4) return 1;
    if (level <= 9) return 5;
    if (level <= 16) return 10;
    if (level <= 22) return 17;
    if (level <= 29) return 23;
    return 30;
  }
}
