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

  // ── Configuração de XP por tempo ────────────────────────────────
  // 10 XP a cada 60 segundos ativos = 10 XP/min
  static const int _xpPerInterval = 10;
  static const int _intervalSeconds = 60;

  // ── Tabela de níveis (XP necessário TOTAL para atingir cada nível)
  // Fórmula: xpParaNivel(n) = 100 * n * (n + 1) / 2
  // Nível 1: 0 XP | Nível 2: 200 | Nível 3: 600 | Nível 4: 1200...
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
      final totalSeconds = (data['totalSecondsOnline'] as num?)?.toInt() ?? 0;
      final achievements = List<String>.from(data['achievements'] ?? []);
      final stats = Map<String, dynamic>.from(data['stats'] ?? {});
      final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();

      return buildXpData(
        totalXp: totalXp,
        totalSecondsOnline: totalSeconds,
        lastActivity: lastActivity,
        achievements: achievements,
        stats: stats,
      );
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

  // ── Adiciona XP e atualiza Firestore com transação ───────────────
  // ANTI-FRAUDE: usa FieldValue.increment — o servidor controla o total.
  // Nunca enviamos o valor absoluto, apenas o incremento.
  Future<UserXpData> addXpForTime(int secondsActive) async {
    final doc = _userDoc;
    if (doc == null) return UserXpData.empty();

    // Calcula XP ganho proporcional ao tempo ativo
    final intervals = secondsActive ~/ _intervalSeconds;
    if (intervals <= 0) return loadUserXpData();

    final xpGained = intervals * _xpPerInterval;

    try {
      await doc.update({
        'totalXp': FieldValue.increment(xpGained),
        'totalSecondsOnline': FieldValue.increment(secondsActive),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      final updated = await loadUserXpData();
      await _checkAchievements(updated);
      return updated;
    } catch (e) {
      return loadUserXpData();
    }
  }

  // ── Registra artigo lido ─────────────────────────────────────────
  Future<void> recordArticleRead() async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.update({
      'stats.articlesRead': FieldValue.increment(1),
      'totalXp': FieldValue.increment(5),
      'lastActivity': FieldValue.serverTimestamp(),
    });
    final data = await loadUserXpData();
    await _checkAchievements(data);
  }

  // ── Registra compartilhamento ────────────────────────────────────
  Future<void> recordShare() async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.update({
      'stats.articlesShared': FieldValue.increment(1),
      'totalXp': FieldValue.increment(15),
      'lastActivity': FieldValue.serverTimestamp(),
    });
    final data = await loadUserXpData();
    await _checkAchievements(data);
  }

  // ── Registra comentário ──────────────────────────────────────────
  Future<void> recordComment() async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.update({
      'stats.commentsPosted': FieldValue.increment(1),
      'totalXp': FieldValue.increment(20),
      'lastActivity': FieldValue.serverTimestamp(),
    });
    final data = await loadUserXpData();
    await _checkAchievements(data);
  }

  // ── Verifica e desbloqueia conquistas ────────────────────────────
  Future<void> _checkAchievements(UserXpData data) async {
    final doc = _userDoc;
    if (doc == null) return;

    final current = data.achievements;
    final toUnlock = <String>[];

    // 1 hora online (3600s)
    if (data.totalSecondsOnline >= 3600 && !current.contains('1h_online')) {
      toUnlock.add('1h_online');
    }
    // 10 horas online (36000s)
    if (data.totalSecondsOnline >= 36000 && !current.contains('10h_online')) {
      toUnlock.add('10h_online');
    }
    // 100 artigos lidos
    final articlesRead =
        (data.stats['articlesRead'] as num?)?.toInt() ?? 0;
    if (articlesRead >= 100 && !current.contains('100_articles')) {
      toUnlock.add('100_articles');
    }
    // Primeiro compartilhamento
    final shares = (data.stats['articlesShared'] as num?)?.toInt() ?? 0;
    if (shares >= 1 && !current.contains('first_share')) {
      toUnlock.add('first_share');
    }
    // Primeiro comentário
    final comments = (data.stats['commentsPosted'] as num?)?.toInt() ?? 0;
    if (comments >= 1 && !current.contains('first_comment')) {
      toUnlock.add('first_comment');
    }
    // Nível 5
    if (data.level >= 5 && !current.contains('level_5')) {
      toUnlock.add('level_5');
    }
    // Nível 10
    if (data.level >= 10 && !current.contains('level_10')) {
      toUnlock.add('level_10');
    }

    if (toUnlock.isNotEmpty) {
      await doc.update({
        'achievements': FieldValue.arrayUnion(toUnlock),
      });
    }
  }

  // ── Lista todas as conquistas possíveis com status ───────────────
  List<Achievement> getAllAchievements(List<String> unlocked) {
    final all = [
      Achievement(
        id: 'first_login',
        title: 'Primeiro Acesso',
        description: 'Entrou no Horizonte News pela primeira vez',
        icon: '🚀',
        unlocked: unlocked.contains('first_login'),
      ),
      Achievement(
        id: '1h_online',
        title: '1 Hora Online',
        description: 'Ficou 1 hora ativo no aplicativo',
        icon: '⏱️',
        unlocked: unlocked.contains('1h_online'),
      ),
      Achievement(
        id: '10h_online',
        title: '10 Horas Online',
        description: 'Ficou 10 horas ativo no aplicativo',
        icon: '🏆',
        unlocked: unlocked.contains('10h_online'),
      ),
      Achievement(
        id: '100_articles',
        title: 'Leitor Dedicado',
        description: 'Leu 100 notícias no aplicativo',
        icon: '📰',
        unlocked: unlocked.contains('100_articles'),
      ),
      Achievement(
        id: 'first_share',
        title: 'Compartilhador',
        description: 'Compartilhou uma notícia pela primeira vez',
        icon: '📤',
        unlocked: unlocked.contains('first_share'),
      ),
      Achievement(
        id: 'first_comment',
        title: 'Comentarista',
        description: 'Realizou seu primeiro comentário',
        icon: '💬',
        unlocked: unlocked.contains('first_comment'),
      ),
      Achievement(
        id: 'level_5',
        title: 'Veterano',
        description: 'Alcançou o nível 5',
        icon: '⭐',
        unlocked: unlocked.contains('level_5'),
      ),
      Achievement(
        id: 'level_10',
        title: 'Lenda',
        description: 'Alcançou o nível 10',
        icon: '👑',
        unlocked: unlocked.contains('level_10'),
      ),
    ];
    return all;
  }

  // ── Nome e ícone do nível ────────────────────────────────────────
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

  static String levelIcon(int level) {
    if (level < 3) return '🌱';
    if (level < 5) return '📖';
    if (level < 8) return '✍️';
    if (level < 12) return '🎙️';
    if (level < 17) return '🗞️';
    if (level < 23) return '⭐';
    if (level < 30) return '🏅';
    return '👑';
  }
}