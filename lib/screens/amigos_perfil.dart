import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../config/badge_config.dart';
import '../services/xp_service.dart';
import 'chat_screen.dart';
import 'amigos_modelos.dart';
import 'amigos_widgets.dart';

class TelaPerfilAmigo extends StatelessWidget {
  final FriendModel friend;

  const TelaPerfilAmigo({Key? key, required this.friend}) : super(key: key);

  String _tempoAtras(DateTime date) {
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
                                  fontWeight: FontWeight.w900),
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
                    Text(friend.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('@${friend.username}',
                            style: TextStyle(
                                color: const Color(0xFFFF6B00).withOpacity(0.8),
                                fontSize: 13)),
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
                          child: Text(friend.status.label,
                              style: TextStyle(
                                  color: friend.status.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
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
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ChatScreen(friend: friend))),
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
                          Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('ENVIAR MENSAGEM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                                  ? 'Visto ${_tempoAtras(friend.lastActivity!)}'
                                  : 'Offline',
                          style: TextStyle(
                              color: friend.status.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        const Text('ESTATÍSTICAS',
                            style: TextStyle(
                                color: Color(0xFFFF6B00),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _CartaoStat(
                                label: 'XP Total',
                                valor: '${friend.totalXp}',
                                icon: Icons.bolt_rounded,
                                cor: const Color(0xFFFF6B00)),
                            const SizedBox(width: 10),
                            _CartaoStat(
                                label: 'Nível',
                                valor: '${friend.level}',
                                icon: Icons.military_tech_rounded,
                                cor: const Color(0xFF7289DA)),
                            if (friend.rank > 0) ...[
                              const SizedBox(width: 10),
                              _CartaoStat(
                                  label: 'Ranking',
                                  valor: '#${friend.rank}',
                                  icon: Icons.leaderboard_rounded,
                                  cor: const Color(0xFFFFD700)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('PROGRESSO',
                            style: TextStyle(
                                color: Color(0xFF444444),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Nv.${friend.level}',
                                style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: friend.xpProgress,
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF6B00)),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Nv.${friend.level + 1}',
                                style: const TextStyle(
                                    color: Color(0xFF444444),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text('${friend.totalXp} / ${friend.xpForNextLevel} XP',
                              style: const TextStyle(
                                  color: Color(0xFF444444), fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardEmblemas(achievements: achievements),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoStat extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color cor;

  const _CartaoStat(
      {required this.label,
      required this.valor,
      required this.icon,
      required this.cor});

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
                    color: cor, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

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
              const Text('EMBLEMAS',
                  style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFFFF6B00).withOpacity(0.15),
                ),
                child: Text('${desbloqueados.length} / ${achievements.length}',
                    style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (desbloqueados.isNotEmpty) ...[
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
              itemCount: desbloqueados.length,
              itemBuilder: (context, i) =>
                  _TileEmblema(achievement: desbloqueados[i], unlocked: true),
            ),
          ],
          if (bloqueados.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('BLOQUEADOS',
                style: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
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
              itemCount: bloqueados.length,
              itemBuilder: (context, i) =>
                  _TileEmblema(achievement: bloqueados[i], unlocked: false),
            ),
          ],
        ],
      ),
    );
  }
}

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: FaIcon(BadgeConfig.achievementIcon(achievement.icon),
                      size: 26,
                      color: unlocked ? color : const Color(0xFF3A3A3A)),
                ),
              ),
              const SizedBox(height: 14),
              Text(achievement.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: unlocked ? Colors.white : const Color(0xFF444444),
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(achievement.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12, height: 1.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: unlocked
                      ? color.withOpacity(0.15)
                      : const Color(0xFF1A1A1A),
                ),
                child: Text(unlocked ? 'OBTIDO' : 'BLOQUEADO',
                    style: TextStyle(
                        color: unlocked ? color : const Color(0xFF444444),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: unlocked ? color.withOpacity(0.08) : const Color(0xFF0F0F0F),
          border: Border.all(
            color: unlocked ? color.withOpacity(0.3) : const Color(0xFF1A1A1A),
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
                color: unlocked ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
                border: Border.all(
                  color: unlocked ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: FaIcon(BadgeConfig.achievementIcon(achievement.icon),
                    size: 16,
                    color: unlocked ? color : const Color(0xFF3A3A3A)),
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
                child: FaIcon(FontAwesomeIcons.lock,
                    size: 8, color: Color(0xFF333333)),
              ),
          ],
        ),
      ),
    );
  }
}
