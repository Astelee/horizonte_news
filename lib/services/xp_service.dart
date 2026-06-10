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
  });

  factory UserXpData.empty() => const UserXpData(
        totalXp: 0,
        level: 1,
        xpInCurrentLevel: 0,
        xpForNextLevel: 100,
        progressPercent: 0.0,
        totalSecondsOnline: 0,
      );

  String get formattedTimeOnline {
    final h = totalSecondsOnline ~/ 3600;
    final m = (totalSecondsOnline % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}

// ═══════════════════════════════════════════════════════════════════
// MODELO DE CONQUISTA
// ═══════════════════════════════════════════════════════════════════

class Achievement {
  final String id;
  final String title;
  final String description;
  // 'icon' agora armazena o próprio ID da conquista.
  // BadgeConfig.achievementIcon(icon) resolve o IconData correto.
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

  // ── Calcula nível a partir do XP total ──────────────────────────
  static int levelFromXp(int totalXp) {
    int level = 1;
    while (xpRequiredForLevel(level + 1) <= totalXp) {
      level++;
    }
    return level;
  }

  // ── Constrói UserXpData a partir do XP total ────────────────────
  static UserXpData buildXpData({
    required int totalXp,
    required int totalSecondsOnline,
    DateTime? lastActivity,
    List<String> achievements = const [],
    Map<String, dynamic> stats = const {},
  }) {
    final level = levelFromXp(totalXp);
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
    );
  }

  // ── Referência ao documento do usuário no Firestore ─────────────
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users_xp').doc(uid);
  }

  // ── Carrega dados do Firestore ───────────────────────────────────
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
      final totalXp = (data['totalXp'] as num?)?.toInt() ?? 0;
      final totalSeconds =
          (data['totalSecondsOnline'] as num?)?.toInt() ?? 0;
      final achievements =
          List<String>.from(data['achievements'] ?? []);
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final lastActivity =
          (data['lastActivity'] as Timestamp?)?.toDate();

      final xpData = buildXpData(
        totalXp: totalXp,
        totalSecondsOnline: totalSeconds,
        lastActivity: lastActivity,
        achievements: achievements,
        stats: stats,
      );

      final savedLevel = (data['level'] as num?)?.toInt() ?? 1;
      if (savedLevel != xpData.level) {
        doc.update({'level': xpData.level}).catchError((_) {});
      }

      return xpData;
    } catch (e) {
      return UserXpData.empty();
    }
  }

  // ── Inicializa documento do usuário novo ─────────────────────────
  Future<void> _initializeUser() async {
    final doc = _userDoc;
    if (doc == null) return;

    final user = _auth.currentUser;
    await doc.set({
      'uid': user?.uid ?? '',
      'email': user?.email ?? '',
      'displayName': user?.displayName ?? '',
      'totalXp': 0,
      'level': 1,
      'totalSecondsOnline': 0,
      'lastActivity': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'achievements': ['first_login'],
      'stats': {
        'articlesRead': 0,
        'articlesShared': 0,
        'commentsPosted': 0,
        'consecutiveDays': 0,
        'lastLoginDate': DateTime.now().toIso8601String(),
      },
    });
  }

  // ── Helper: salva XP + level calculado de uma vez ────────────────
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

    final updated = await loadUserXpData();
    await doc.update({'level': updated.level}).catchError((_) {});

    return updated;
  }

  // ── Adiciona XP por tempo ────────────────────────────────────────
  Future<UserXpData> addXpForTime(int secondsActive) async {
    final intervals = secondsActive ~/ _intervalSeconds;
    if (intervals <= 0) return loadUserXpData();

    final xpGained = intervals * _xpPerInterval;

    try {
      final updated = await _incrementXpAndSave(
        xpGained: xpGained,
        extraSeconds: secondsActive,
      );
      await _checkAchievements(updated);
      return updated;
    } catch (e) {
      return loadUserXpData();
    }
  }

  // ── Registra artigo lido ─────────────────────────────────────────
  Future<void> recordArticleRead() async {
    try {
      final updated = await _incrementXpAndSave(
        xpGained: 5,
        extraFields: {'stats.articlesRead': FieldValue.increment(1)},
      );
      await _checkAchievements(updated);
    } catch (_) {}
  }

  // ── Registra compartilhamento ────────────────────────────────────
  Future<void> recordShare() async {
    try {
      final updated = await _incrementXpAndSave(
        xpGained: 15,
        extraFields: {'stats.articlesShared': FieldValue.increment(1)},
      );
      await _checkAchievements(updated);
    } catch (_) {}
  }

  // ── Registra comentário ──────────────────────────────────────────
  Future<void> recordComment() async {
    try {
      final updated = await _incrementXpAndSave(
        xpGained: 20,
        extraFields: {'stats.commentsPosted': FieldValue.increment(1)},
      );
      await _checkAchievements(updated);
    } catch (_) {}
  }

  // ── Verifica e desbloqueia conquistas ────────────────────────────
  Future<void> _checkAchievements(UserXpData data) async {
    final doc = _userDoc;
    if (doc == null) return;

    final current = data.achievements;
    final toUnlock = <String>[];

    if (data.totalSecondsOnline >= 3600 &&
        !current.contains('1h_online')) {
      toUnlock.add('1h_online');
    }
    if (data.totalSecondsOnline >= 36000 &&
        !current.contains('10h_online')) {
      toUnlock.add('10h_online');
    }
    final articlesRead =
        (data.stats['articlesRead'] as num?)?.toInt() ?? 0;
    if (articlesRead >= 100 && !current.contains('100_articles')) {
      toUnlock.add('100_articles');
    }
    final shares =
        (data.stats['articlesShared'] as num?)?.toInt() ?? 0;
    if (shares >= 1 && !current.contains('first_share')) {
      toUnlock.add('first_share');
    }
    final comments =
        (data.stats['commentsPosted'] as num?)?.toInt() ?? 0;
    if (comments >= 1 && !current.contains('first_comment')) {
      toUnlock.add('first_comment');
    }
    if (data.level >= 5 && !current.contains('level_5')) {
      toUnlock.add('level_5');
    }
    if (data.level >= 10 && !current.contains('level_10')) {
      toUnlock.add('level_10');
    }

    if (toUnlock.isNotEmpty) {
      await doc
          .update({'achievements': FieldValue.arrayUnion(toUnlock)});
    }
  }

  // ── Lista todas as conquistas possíveis com status ───────────────
  // ATUALIZADO: icon agora é o próprio ID da conquista.
  // BadgeConfig.achievementIcon(achievement.icon) resolve o ícone FA.
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

  // ── Nome do nível ────────────────────────────────────────────────
  static String levelTitle(int level) {
    if (level < 3) return 'Novato';
    if (level < 5) return 'Leitor';
    if (level < 8) return 'Jornalista';
    if (level < 12) return 'Repórter';
    if (level < 17) return 'Editor';
    if (level < 23) return 'Veterano';
    if (level < 30) return 'Especialista';
    return 'Lenda';
  }

  // ── Mantido para compatibilidade — UI usa BadgeConfig.levelIcon() ─
  static String levelIcon(int level) => '';
}
