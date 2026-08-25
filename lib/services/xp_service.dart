import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ═══════════════════════════════════════════════════════════════════
// MODELO DE DADOS DO USUÁRIO XP
// ═══════════════════════════════════════════════════════════════════
class UserXpData {
  final int totalXp;
  final int level;
  final int xpInCurrentLevel;
  final int xpForNextLevel;
  final double progressPercent;
  final int totalSecondsOnline;
  final DateTime? lastActivity;
  final List<String> achievements;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> dailyMissions;
  final String avatarId;
  final String? customTitle;

  const UserXpData({
    required this.totalXp,
    required this.level,
    required this.xpInCurrentLevel,
    required this.xpForNextLevel,
    required this.progressPercent,
    required this.totalSecondsOnline,
    this.lastActivity,
    this.achievements = const [],
    this.stats = const {},
    this.dailyMissions = const {},
    this.avatarId = 'animais_01',
    this.customTitle,
  });

  factory UserXpData.empty() => const UserXpData(
        totalXp: 0,
        level: 1,
        xpInCurrentLevel: 0,
        xpForNextLevel: 100,
        progressPercent: 0.0,
        totalSecondsOnline: 0,
        avatarId: 'animais_01',
        customTitle: null,
      );

  // ── copyWith para substituir o nível, avatar ou título ────────────
  UserXpData copyWith({int? level, String? avatarId, String? customTitle}) {
    return UserXpData(
      totalXp: totalXp,
      level: level ?? this.level,
      xpInCurrentLevel: xpInCurrentLevel,
      xpForNextLevel: xpForNextLevel,
      progressPercent: progressPercent,
      totalSecondsOnline: totalSecondsOnline,
      lastActivity: lastActivity,
      achievements: achievements,
      stats: stats,
      dailyMissions: dailyMissions,
      avatarId: avatarId ?? this.avatarId,
      customTitle: customTitle ?? this.customTitle,
    );
  }

  String get formattedTimeOnline {
    final h = totalSecondsOnline ~/ 3600;
    final m = (totalSecondsOnline % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  int get dailyArticles =>
      (dailyMissions['articlesRead'] as num?)?.toInt() ?? 0;
  int get dailyComments =>
      (dailyMissions['commentsPosted'] as num?)?.toInt() ?? 0;
  int get dailyShares =>
      (dailyMissions['articlesShared'] as num?)?.toInt() ?? 0;
  int get dailyMinutes =>
      (dailyMissions['minutesOnline'] as num?)?.toInt() ?? 0;
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE CONQUISTA
// ═══════════════════════════════════════════════════════════════════
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}

// ═══════════════════════════════════════════════════════════════════
// SERVIÇO PRINCIPAL DE XP
// ═══════════════════════════════════════════════════════════════════
class XpService {
  static final XpService _instance = XpService._internal();
  factory XpService() => _instance;
  XpService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _xpPerInterval = 10;
  static const int _intervalSeconds = 60;

  // ── Tabela de níveis ─────────────────────────────────────────────
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    return (100 * (level - 1) * level) ~/ 2;
  }

  static int xpRequiredForNextLevel(int level) {
    return xpRequiredForLevel(level + 1) - xpRequiredForLevel(level);
  }

  static int levelFromXp(int totalXp) {
    int level = 1;
    while (xpRequiredForLevel(level + 1) <= totalXp) {
      level++;
    }
    return level;
  }

  static UserXpData buildXpData({
    required int totalXp,
    required int totalSecondsOnline,
    DateTime? lastActivity,
    List<String> achievements = const [],
    Map<String, dynamic> stats = const {},
    Map<String, dynamic> dailyMissions = const {},
    int? overrideLevel,
    String avatarId = 'animais_01',
    String? customTitle,
  }) {
    final calculatedLevel = levelFromXp(totalXp);
    final level = overrideLevel ?? calculatedLevel;

    final xpAtThisLevel = xpRequiredForLevel(level);
    final xpAtNextLevel = xpRequiredForLevel(level + 1);
    final xpInCurrentLevel = totalXp - xpAtThisLevel;
    final xpForNextLevel = xpAtNextLevel - xpAtThisLevel;
    final progress = xpForNextLevel > 0
        ? (xpInCurrentLevel / xpForNextLevel).clamp(0.0, 1.0)
        : 1.0;

    return UserXpData(
      totalXp: totalXp,
      level: level,
      xpInCurrentLevel: xpInCurrentLevel,
      xpForNextLevel: xpForNextLevel,
      progressPercent: progress,
      totalSecondsOnline: totalSecondsOnline,
      lastActivity: lastActivity,
      achievements: achievements,
      stats: stats,
      dailyMissions: dailyMissions,
      avatarId: avatarId,
      customTitle: customTitle,
    );
  }

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users_xp').doc(uid);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Carrega dados do Firestore — respeita adminOverride ──────────
  Future<UserXpData> loadUserXpData() async {
    try {
      final doc = _userDoc;
      if (doc == null) return UserXpData.empty();

      final snap = await doc.get();
      if (!snap.exists || snap.data() == null) {
        await _initializeUser();
        return UserXpData.empty();
      }

      final data = snap.data()!;

      await _checkAndResetDailyMissions(doc, data);

      final snapUpdated = await doc.get();
      final dataUpdated = snapUpdated.data()!;

      final totalXp = (dataUpdated['totalXp'] as num?)?.toInt() ?? 0;
      final totalSeconds =
          (dataUpdated['totalSecondsOnline'] as num?)?.toInt() ?? 0;
      final achievements =
          List<String>.from(dataUpdated['achievements'] ?? []);
      final stats =
          Map<String, dynamic>.from(dataUpdated['stats'] ?? {});
      final dailyMissions =
          Map<String, dynamic>.from(dataUpdated['dailyMissions'] ?? {});
      final lastActivity =
          (dataUpdated['lastActivity'] as Timestamp?)?.toDate();
      final avatarId =
          (dataUpdated['avatarId'] as String?) ?? 'animais_01';

      // ── Lê override de nível do admin ────────────────────────────
      final overrideActive = dataUpdated['adminOverrideActive'] == true;
      final overrideLevel =
          overrideActive
              ? (dataUpdated['adminOverrideLevel'] as num?)?.toInt()
              : null;

      // ── Lê título/tag customizada do admin ───────────────────────
      final titleOverrideActive =
          dataUpdated['adminOverrideTitleActive'] == true;
      final customTitle = titleOverrideActive
          ? (dataUpdated['adminOverrideTitleLevel'] as String?)
          : null;

      final xpData = buildXpData(
        totalXp: totalXp,
        totalSecondsOnline: totalSeconds,
        lastActivity: lastActivity,
        achievements: achievements,
        stats: stats,
        dailyMissions: dailyMissions,
        overrideLevel: overrideLevel,
        avatarId: avatarId,
        customTitle: customTitle,
      );

      // Só sincroniza level no Firestore se NÃO houver override ativo
      if (!overrideActive) {
        final savedLevel = (dataUpdated['level'] as num?)?.toInt() ?? 1;
        if (savedLevel != xpData.level) {
          doc.update({'level': xpData.level}).catchError((_) {});
        }
      }

      return xpData;
    } catch (e) {
      return UserXpData.empty();
    }
  }

  Future<void> _checkAndResetDailyMissions(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    final today = _todayString();
    final lastReset = data['lastMissionReset'] as String? ?? '';

    if (lastReset == today) return;

    int consecutiveDays =
        (data['stats']?['consecutiveDays'] as num?)?.toInt() ?? 0;

    if (lastReset.isNotEmpty) {
      try {
        final lastDate = DateTime.parse(lastReset);
        final todayDate = DateTime.now();
        final diff = todayDate
            .difference(
                DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;

        if (diff == 1) {
          consecutiveDays += 1;
        } else if (diff > 1) {
          consecutiveDays = 1;
        }
      } catch (_) {
        consecutiveDays = 1;
      }
    } else {
      consecutiveDays = 1;
    }

    await doc.update({
      'lastMissionReset': today,
      'dailyMissions': {
        'articlesRead': 0,
        'commentsPosted': 0,
        'articlesShared': 0,
        'minutesOnline': 0,
        'rewardsCollected': <String>[],
      },
      'stats.consecutiveDays': consecutiveDays,
      'stats.lastLoginDate': today,
    });
  }

  Future<void> _initializeUser() async {
    final doc = _userDoc;
    if (doc == null) return;

    final user = _auth.currentUser;
    final today = _todayString();

    await doc.set({
      'uid': user?.uid ?? '',
      'email': user?.email ?? '',
      'displayName': user?.displayName ?? '',
      'totalXp': 0,
      'level': 1,
      'totalSecondsOnline': 0,
      'avatarId': 'animais_01',
      'lastActivity': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'achievements': ['first_login'],
      'lastMissionReset': today,
      'dailyMissions': {
        'articlesRead': 0,
        'commentsPosted': 0,
        'articlesShared': 0,
        'minutesOnline': 0,
        'rewardsCollected': <String>[],
      },
      'stats': {
        'articlesRead': 0,
        'articlesShared': 0,
        'commentsPosted': 0,
        'consecutiveDays': 1,
        'lastLoginDate': today,
      },
    });
  }

  Future<UserXpData> _incrementXpAndSave({
    required int xpGained,
    int? extraSeconds,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final doc = _userDoc;
    if (doc == null) return UserXpData.empty();

    final update = <String, dynamic>{
      'totalXp': FieldValue.increment(xpGained),
      'lastActivity': FieldValue.serverTimestamp(),
      ...extraFields,
    };

    if (extraSeconds != null) {
      update['totalSecondsOnline'] = FieldValue.increment(extraSeconds);
    }

    await doc.update(update);

    // loadUserXpData já respeita o override internamente
    final updated = await loadUserXpData();

    // Só atualiza level no Firestore se não houver override
    final snap = await doc.get();
    final overrideActive = snap.data()?['adminOverrideActive'] == true;
    if (!overrideActive) {
      await doc.update({'level': updated.level}).catchError((_) {});
    }

    return updated;
  }

  Future<UserXpData> addXpForTime(int secondsActive) async {
    final intervals = secondsActive ~/ _intervalSeconds;
    if (intervals <= 0) return loadUserXpData();

    final xpGained = intervals * _xpPerInterval;
    final minutesActive = secondsActive ~/ 60;

    try {
      final updated = await _incrementXpAndSave(
        xpGained: xpGained,
        extraSeconds: secondsActive,
        extraFields: minutesActive > 0
            ? {
                'dailyMissions.minutesOnline':
                    FieldValue.increment(minutesActive),
              }
            : {},
      );
      await _checkMissionRewards(updated);
      await _checkAchievements(updated);
      return updated;
    } catch (e) {
      return loadUserXpData();
    }
  }

  // ── Evita dar XP de novo pro mesmo post (trava por postId) ────────
  // Guarda os IDs já recompensados em stats.<field> — arrays pequenos,
  // já que só crescem com ações reais do usuário (não por visita).
  Future<bool> _alreadyAwarded(String statsField, String postId) async {
    final doc = _userDoc;
    if (doc == null) return true; // sem usuário logado, não premia
    final snap = await doc.get();
    final ids = List<String>.from(
        (snap.data()?['stats']?[statsField] as List?) ?? []);
    return ids.contains(postId);
  }

  Future<void> recordArticleRead(String postId) async {
    if (postId.isEmpty) return;
    try {
      if (await _alreadyAwarded('articlesReadIds', postId)) return;

      final updated = await _incrementXpAndSave(
        xpGained: 5,
        extraFields: {
          'stats.articlesRead': FieldValue.increment(1),
          'stats.articlesReadIds': FieldValue.arrayUnion([postId]),
          'dailyMissions.articlesRead': FieldValue.increment(1),
        },
      );
      await _checkMissionRewards(updated);
      await _checkAchievements(updated);
    } catch (_) {}
  }

  Future<void> recordShare({required String postId, String? postTitle}) async {
    if (postId.isEmpty) return;
    try {
      if (await _alreadyAwarded('articlesSharedIds', postId)) {
        // Continua contando o compartilhamento no post (métrica pública),
        // só não dá XP de novo pro mesmo usuário.
        await _recordPostShare(postId: postId, postTitle: postTitle ?? '');
        return;
      }

      final updated = await _incrementXpAndSave(
        xpGained: 15,
        extraFields: {
          'stats.articlesShared': FieldValue.increment(1),
          'stats.articlesSharedIds': FieldValue.arrayUnion([postId]),
          'dailyMissions.articlesShared': FieldValue.increment(1),
        },
      );
      await _checkMissionRewards(updated);
      await _checkAchievements(updated);
      await _recordPostShare(postId: postId, postTitle: postTitle ?? '');
    } catch (_) {}
  }

  // ── Registra QUAL post foi compartilhado (usado no Dashboard ADM) ──
  Future<void> _recordPostShare({
    required String postId,
    required String postTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final shareRef = _db.collection('post_shares').doc(postId);
      await shareRef.set({
        'postId': postId,
        'postTitle': postTitle,
        'totalShares': FieldValue.increment(1),
        'lastSharedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> recordComment() async {
    try {
      final updated = await _incrementXpAndSave(
        xpGained: 20,
        extraFields: {
          'stats.commentsPosted': FieldValue.increment(1),
          'dailyMissions.commentsPosted': FieldValue.increment(1),
        },
      );
      await _checkMissionRewards(updated);
      await _checkAchievements(updated);
    } catch (_) {}
  }

  Future<void> _checkMissionRewards(UserXpData data) async {
    final doc = _userDoc;
    if (doc == null) return;

    final collected =
        List<String>.from(data.dailyMissions['rewardsCollected'] ?? []);

    if (data.dailyArticles >= 5 && !collected.contains('articles')) {
      await doc.update({
        'totalXp': FieldValue.increment(25),
        'dailyMissions.rewardsCollected':
            FieldValue.arrayUnion(['articles']),
      });
    }
    if (data.dailyComments >= 2 && !collected.contains('comments')) {
      await doc.update({
        'totalXp': FieldValue.increment(40),
        'dailyMissions.rewardsCollected':
            FieldValue.arrayUnion(['comments']),
      });
    }
    if (data.dailyShares >= 1 && !collected.contains('shares')) {
      await doc.update({
        'totalXp': FieldValue.increment(15),
        'dailyMissions.rewardsCollected':
            FieldValue.arrayUnion(['shares']),
      });
    }
    if (data.dailyMinutes >= 10 && !collected.contains('time')) {
      await doc.update({
        'totalXp': FieldValue.increment(20),
        'dailyMissions.rewardsCollected':
            FieldValue.arrayUnion(['time']),
      });
    }
  }

  Future<void> _checkAchievements(UserXpData data) async {
    final doc = _userDoc;
    if (doc == null) return;

    final current = data.achievements;
    final toUnlock = <String>[];

    void unlock(String id, bool condition) {
      if (condition && !current.contains(id)) toUnlock.add(id);
    }

    // ── Horas online ──────────────────────────────────────────────
    unlock('1h_online', data.totalSecondsOnline >= 3600);
    unlock('10h_online', data.totalSecondsOnline >= 36000);
    unlock('50h_online', data.totalSecondsOnline >= 180000);
    unlock('100h_online', data.totalSecondsOnline >= 360000);

    // ── Artigos lidos — IDs batendo com BadgeConfig.achievementIcon
    // (articles_10/50/100/500, não 100_articles) ────────────────────
    final articlesRead = (data.stats['articlesRead'] as num?)?.toInt() ?? 0;
    unlock('articles_10', articlesRead >= 10);
    unlock('articles_50', articlesRead >= 50);
    unlock('articles_100', articlesRead >= 100);
    unlock('articles_500', articlesRead >= 500);

    // ── Compartilhamentos ────────────────────────────────────────────
    final shares = (data.stats['articlesShared'] as num?)?.toInt() ?? 0;
    unlock('first_share', shares >= 1);
    unlock('shares_10', shares >= 10);

    // ── Comentários ──────────────────────────────────────────────────
    final comments = (data.stats['commentsPosted'] as num?)?.toInt() ?? 0;
    unlock('first_comment', comments >= 1);
    unlock('comments_10', comments >= 10);
    unlock('comments_50', comments >= 50);

    // ── Sequência de dias consecutivos (já salva em stats.consecutiveDays,
    // só faltava usá-la para liberar as conquistas de streak) ───────────
    final consecutiveDays =
        (data.stats['consecutiveDays'] as num?)?.toInt() ?? 0;
    unlock('streak_7', consecutiveDays >= 7);
    unlock('streak_30', consecutiveDays >= 30);
    unlock('streak_100', consecutiveDays >= 100);

    // ── Nível ────────────────────────────────────────────────────────
    unlock('level_5', data.level >= 5);
    unlock('level_10', data.level >= 10);

    if (toUnlock.isNotEmpty) {
      await doc
          .update({'achievements': FieldValue.arrayUnion(toUnlock)});
    }
  }

  List<Achievement> getAllAchievements(List<String> unlocked) {
    return [
      Achievement(
        id: 'first_login',
        title: 'Primeiro Acesso',
        description: 'Entrou no Horizonte News pela primeira vez',
        icon: 'first_login',
        unlocked: unlocked.contains('first_login'),
      ),
      Achievement(
        id: '1h_online',
        title: '1 Hora Online',
        description: 'Ficou 1 hora ativo no aplicativo',
        icon: '1h_online',
        unlocked: unlocked.contains('1h_online'),
      ),
      Achievement(
        id: '10h_online',
        title: '10 Horas Online',
        description: 'Ficou 10 horas ativo no aplicativo',
        icon: '10h_online',
        unlocked: unlocked.contains('10h_online'),
      ),
      Achievement(
        id: '100_articles',
        title: 'Leitor Dedicado',
        description: 'Leu 100 notícias no aplicativo',
        icon: '100_articles',
        unlocked: unlocked.contains('100_articles'),
      ),
      Achievement(
        id: 'first_share',
        title: 'Compartilhador',
        description: 'Compartilhou uma notícia pela primeira vez',
        icon: 'first_share',
        unlocked: unlocked.contains('first_share'),
      ),
      Achievement(
        id: 'first_comment',
        title: 'Comentarista',
        description: 'Realizou seu primeiro comentário',
        icon: 'first_comment',
        unlocked: unlocked.contains('first_comment'),
      ),
      Achievement(
        id: 'level_5',
        title: 'Veterano',
        description: 'Alcançou o nível 5',
        icon: 'level_5',
        unlocked: unlocked.contains('level_5'),
      ),
      Achievement(
        id: 'level_10',
        title: 'Lenda',
        description: 'Alcançou o nível 10',
        icon: 'level_10',
        unlocked: unlocked.contains('level_10'),
      ),
    ];
  }

  // Título e ícone por nível vivem em BadgeConfig (config/badge_config.dart)
  // — era o sistema realmente usado nas telas e testado; os métodos
  // levelTitle/levelIcon que existiam aqui foram removidos por serem
  // um segundo sistema divergente que ninguém mais chama.
}
