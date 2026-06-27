// amigos_perfil.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/badge_config.dart';
import '../services/xp_service.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';
import 'chat_screen.dart';

class TelaPerfilAmigo extends StatefulWidget {
  final FriendModel friend;

  const TelaPerfilAmigo({Key? key, required this.friend}) : super(key: key);

  @override
  State<TelaPerfilAmigo> createState() => _TelaPerfilAmigoState();
}

class _TelaPerfilAmigoState extends State<TelaPerfilAmigo>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _removendo = false;

  String get _myUid => _auth.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  String _tempoAtras(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<String?> _buscarRequestId() async {
    final snap = await _db
        .collection('friend_requests')
        .where('participants', arrayContains: _myUid)
        .get();
    for (final doc in snap.docs) {
      final d = doc.data();
      final parts = List<String>.from(d['participants'] ?? []);
      if (parts.contains(widget.friend.uid)) return doc.id;
    }
    return null;
  }

  Future<void> _removerAmigo(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remover amigo?',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tem certeza que quer remover @${widget.friend.username}?',
          style: const TextStyle(
              color: Color(0xFF666666), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover',
                style: TextStyle(
                    color: Color(0xFFED4245),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirma != true) return;
    setState(() => _removendo = true);

    try {
      final id = await _buscarRequestId();
      if (id != null) {
        await _db.collection('friend_requests').doc(id).delete();
      }
      HapticFeedback.heavyImpact();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _removendo = false);
    }
  }

  Future<void> _compartilharPerfil(BuildContext context) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.share_rounded,
                color: Color(0xFFFF6B00), size: 16),
            const SizedBox(width: 10),
            Text(
              'Perfil de @${widget.friend.username} copiado!',
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

  @override
  Widget build(BuildContext context) {
    final xpService = XpService();
    final achievements =
        xpService.getAllAchievements(widget.friend.achievements);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar com gradiente ──────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => _compartilharPerfil(context),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white),
                onPressed: () => _mostrarMenuOpcoes(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.friend.status.color.withOpacity(0.3),
                      const Color(0xFF150600),
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Avatar grande
                    AmigoAvatar(friend: widget.friend, size: 80),
                    const SizedBox(height: 14),
                    // Nome
                    Text(
                      widget.friend.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    // @username + status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '@${widget.friend.username}',
                          style: TextStyle(
                              color: const Color(0xFFFF6B00)
                                  .withOpacity(0.8),
                              fontSize: 13),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.friend.status.color
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: widget.friend.status.color
                                    .withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.friend.status.color,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.friend.status.label,
                                style: TextStyle(
                                    color: widget.friend.status.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Conteúdo ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                  child: Column(
                    children: [
                      // ── Botões de ação ─────────────────────────
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _BotaoAcaoPerfil(
                              label: 'MENSAGEM',
                              icon: Icons.chat_rounded,
                              gradiente: const [
                                Color(0xFFFF6B00),
                                Color(0xFFCC4400)
                              ],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                        friend: widget.friend)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _BotaoIconePerfil(
                            icon: Icons.star_rounded,
                            color: const Color(0xFFFAA61A),
                            onTap: () => _alternarFavorito(context),
                          ),
                          const SizedBox(width: 10),
                          _BotaoIconePerfil(
                            icon: Icons.share_rounded,
                            color: const Color(0xFF4FC3F7),
                            onTap: () => _compartilharPerfil(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Card de Status / Último acesso ─────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0C0C),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: widget.friend.status.color
                                  .withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.friend.status.color
                                    .withOpacity(0.1),
                                border: Border.all(
                                    color: widget.friend.status.color
                                        .withOpacity(0.3)),
                              ),
                              child: Icon(
                                widget.friend.status.icon,
                                color: widget.friend.status.color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.friend.isOnline
                                        ? widget.friend.status.label
                                        : 'Offline',
                                    style: TextStyle(
                                      color: widget.friend.status.color,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (!widget.friend.isOnline &&
                                      widget.friend.lastActivity != null)
                                    Text(
                                      'Visto ${_tempoAtras(widget.friend.lastActivity!)}',
                                      style: const TextStyle(
                                          color: Color(0xFF555555),
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Estatísticas ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0C0C),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFF6B00)
                                  .withOpacity(0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bar_chart_rounded,
                                    color: Color(0xFFFF6B00), size: 14),
                                const SizedBox(width: 6),
                                const Text(
                                  'ESTATÍSTICAS',
                                  style: TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _CartaoStat(
                                    label: 'XP Total',
                                    valor: '${widget.friend.totalXp}',
                                    icon: Icons.bolt_rounded,
                                    cor: const Color(0xFFFF6B00)),
                                const SizedBox(width: 10),
                                _CartaoStat(
                                    label: 'Nível',
                                    valor: '${widget.friend.level}',
                                    icon: Icons.military_tech_rounded,
                                    cor: const Color(0xFF7289DA)),
                                if (widget.friend.rank > 0) ...[
                                  const SizedBox(width: 10),
                                  _CartaoStat(
                                      label: 'Ranking',
                                      valor: '#${widget.friend.rank}',
                                      icon: Icons.leaderboard_rounded,
                                      cor: const Color(0xFFFFD700)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Barra XP detalhada
                            Row(
                              children: [
                                Text(
                                  'Nv.${widget.friend.level}',
                                  style: const TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: widget.friend.xpProgress,
                                      backgroundColor:
                                          const Color(0xFF1A1A1A),
                                      valueColor:
                                          const AlwaysStoppedAnimation<
                                                  Color>(
                                              Color(0xFFFF6B00)),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Nv.${widget.friend.level + 1}',
                                  style: const TextStyle(
                                      color: Color(0xFF444444),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                '${widget.friend.totalXp} / ${widget.friend.xpForNextLevel} XP',
                                style: const TextStyle(
                                    color: Color(0xFF444444),
                                    fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Emblemas ───────────────────────────────
                      _CardEmblemas(achievements: achievements),
                      const SizedBox(height: 16),

                      // ── Botão Remover Amigo ────────────────────
                      GestureDetector(
                        onTap: _removendo
                            ? null
                            : () => _removerAmigo(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFFED4245)
                                .withOpacity(0.06),
                            border: Border.all(
                                color: const Color(0xFFED4245)
                                    .withOpacity(0.25)),
                          ),
                          child: _removendo
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFED4245),
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_remove_rounded,
                                        color: Color(0xFFED4245),
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'REMOVER AMIGO',
                                      style: TextStyle(
                                        color: Color(0xFFED4245),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuOpcoes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuContextoAmigo(
        friend: widget.friend,
        myUid: _myUid,
        db: _db,
        chatId: '',
      ),
    );
  }

  Future<void> _alternarFavorito(BuildContext context) async {
    HapticFeedback.lightImpact();
    try {
      final snap =
          await _db.collection('users_xp').doc(widget.friend.uid).get();
      final atual = (snap.data()?['isFavorite'] as bool?) ?? false;
      await _db
          .collection('users_xp')
          .doc(widget.friend.uid)
          .update({'isFavorite': !atual});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              atual ? 'Removido dos favoritos' : 'Adicionado aos favoritos ⭐',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF111111),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════
// BOTÃO DE AÇÃO DO PERFIL
// ═══════════════════════════════════════════════════════════════════
class _BotaoAcaoPerfil extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradiente;
  final VoidCallback onTap;

  const _BotaoAcaoPerfil({
    required this.label,
    required this.icon,
    required this.gradiente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: gradiente),
          boxShadow: [
            BoxShadow(
              color: gradiente.first.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoIconePerfil extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BotaoIconePerfil({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARTÃO DE ESTATÍSTICA
// ═══════════════════════════════════════════════════════════════════
class _CartaoStat extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color cor;

  const _CartaoStat({
    required this.label,
    required this.valor,
    required this.icon,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: cor, size: 18),
            const SizedBox(height: 6),
            Text(valor,
                style: TextStyle(
                    color: cor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF555555), fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CARD DE EMBLEMAS
// ═══════════════════════════════════════════════════════════════════
class _CardEmblemas extends StatelessWidget {
  final List<Achievement> achievements;
  const _CardEmblemas({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final desbloqueados = achievements.where((a) => a.unlocked).toList();
    final bloqueados = achievements.where((a) => !a.unlocked).toList();

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
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFF6B00), size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'EMBLEMAS',
                    style: TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFFF6B00).withOpacity(0.12),
                ),
                child: Text(
                  '${desbloqueados.length} / ${achievements.length}',
                  style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (desbloqueados.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: desbloqueados.length,
              itemBuilder: (context, i) => _TileEmblema(
                  achievement: desbloqueados[i], unlocked: true),
            ),
          ],
          if (bloqueados.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'BLOQUEADOS',
              style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: bloqueados.length,
              itemBuilder: (context, i) => _TileEmblema(
                  achievement: bloqueados[i], unlocked: false),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TILE DE EMBLEMA
// ═══════════════════════════════════════════════════════════════════
class _TileEmblema extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  const _TileEmblema({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? BadgeConfig.achievementColor(achievement.icon)
        : const Color(0xFF2A2A2A);

    return GestureDetector(
      onTap: () => showDialog(
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
                    color: unlocked
                        ? Colors.white
                        : const Color(0xFF444444),
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    height: 1.5),
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
                      color:
                          unlocked ? color : const Color(0xFF444444),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ),
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
          ),
          boxShadow: unlocked
              ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8)]
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
                  color: unlocked
                      ? Colors.white
                      : const Color(0xFF333333),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            if (!unlocked)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: FaIcon(FontAwesomeIcons.lock,
                    size: 8, color: Color(0xFF333333)),
              ),
          ],
        ),
      ),
    );
  }
}
