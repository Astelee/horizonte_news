import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/badge_config.dart';
import 'amigos_modelos.dart';
import 'chat_screen.dart';

class AmigoAvatar extends StatefulWidget {
  final FriendModel friend;
  final double size;

  const AmigoAvatar({Key? key, required this.friend, this.size = 50})
      : super(key: key);

  @override
  State<AmigoAvatar> createState() => _AmigoAvatarState();
}

class _AmigoAvatarState extends State<AmigoAvatar>
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
    final s = widget.size;
    final borderColor = widget.friend.isFavorite
        ? const Color(0xFFFAA61A)
        : widget.friend.status.color;

    return Stack(
      children: [
        Container(
          width: s,
          height: s,
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
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.friend.displayName.isNotEmpty
                  ? widget.friend.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: s * 0.36,
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
                        color: widget.friend.status.color.withOpacity(0.3),
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

class NivelBadge extends StatelessWidget {
  final int level;
  const NivelBadge({Key? key, required this.level}) : super(key: key);

  Color get _cor {
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
        color: _cor.withOpacity(0.12),
        border: Border.all(color: _cor.withOpacity(0.4)),
      ),
      child: Text(
        'Nv.$level',
        style: TextStyle(
          color: _cor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class BarraXp extends StatelessWidget {
  final FriendModel friend;
  const BarraXp({Key? key, required this.friend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${friend.totalXp} XP',
                style: const TextStyle(color: Color(0xFF444444), fontSize: 9)),
            const Expanded(child: SizedBox()),
            Text('${friend.xpForNextLevel} XP',
                style: const TextStyle(color: Color(0xFF444444), fontSize: 9)),
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

class FileiraBadges extends StatelessWidget {
  final List<String> achievementIds;
  final int maxVisible;

  const FileiraBadges({
    Key? key,
    required this.achievementIds,
    this.maxVisible = 3,
  }) : super(key: key);

  static const _rarityOrder = [
    'first_login', '1h_online', 'first_comment', 'first_share',
    '100_articles', '10h_online', 'level_5', 'level_10',
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
              child: FaIcon(BadgeConfig.achievementIcon(id), size: 9, color: color),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class IndicadorDigitando extends StatefulWidget {
  const IndicadorDigitando({Key? key}) : super(key: key);

  @override
  State<IndicadorDigitando> createState() => _IndicadorDigitandoState();
}

class _IndicadorDigitandoState extends State<IndicadorDigitando>
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

class CabecalhoSecao extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;

  const CabecalhoSecao({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  }) : super(key: key);

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

class EstadoCarregando extends StatelessWidget {
  const EstadoCarregando({Key? key}) : super(key: key);

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

class EstadoSemAmigos extends StatelessWidget {
  const EstadoSemAmigos({Key? key}) : super(key: key);

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
                fontWeight: FontWeight.w700),
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

class EstadoVazio extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;

  const EstadoVazio({
    Key? key,
    required this.icon,
    required this.titulo,
    required this.subtitulo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFFF6B00).withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(titulo,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF444444), fontSize: 13)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MENU DE CONTEXTO REAPROVEITÁVEL (LONG PRESS)
// Usado tanto no card de amigo quanto no card de conversa.
// ═══════════════════════════════════════════════════════════════════
class MenuContextoAmigo extends StatelessWidget {
  final FriendModel friend;
  final String myUid;
  final FirebaseFirestore db;

  /// Se já souber o requestId (ex: vindo da lista de amigos), passe aqui
  /// para evitar uma leitura extra no Firestore. Se for null, o menu busca
  /// o documento de friend_requests sozinho ao clicar em "Excluir Amigo".
  final String? requestId;

  /// Se a conversa já tem chatId calculado (vindo da aba Conversas),
  /// passe aqui para "Limpar Conversa" funcionar sem recalcular.
  final String? chatId;

  /// Callback opcional chamado depois de qualquer ação que exija recarregar
  /// a tela que abriu o menu (ex: favoritar). Útil quando a tela usa um
  /// FutureBuilder que não escuta automaticamente o Firestore.
  final VoidCallback? onChanged;

  const MenuContextoAmigo({
    Key? key,
    required this.friend,
    required this.myUid,
    required this.db,
    this.requestId,
    this.chatId,
    this.onChanged,
  }) : super(key: key);

  String get _chatIdResolvido {
    if (chatId != null) return chatId!;
    final ids = [myUid, friend.uid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String?> _buscarRequestId() async {
    if (requestId != null) return requestId;
    final snap = await db
        .collection('friend_requests')
        .where('participants', arrayContains: myUid)
        .get();
    for (final doc in snap.docs) {
      final participants =
          List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(friend.uid)) return doc.id;
    }
    return null;
  }

  Future<void> _alternarFavorito(BuildContext context) async {
    Navigator.pop(context);
    await db.collection('users_xp').doc(friend.uid).update({
      'isFavorite': !friend.isFavorite,
    });
    onChanged?.call();
  }

  Future<void> _limparConversa(BuildContext context) async {
    Navigator.pop(context);

    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Limpar conversa?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Todas as mensagens serão apagadas apenas para você. O contato permanece na sua lista de amigos.',
          style: TextStyle(color: Color(0xFF999999), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Limpar',
              style: TextStyle(
                  color: Color(0xFFED4245), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    final messagesRef = db
        .collection('chats')
        .doc(_chatIdResolvido)
        .collection('messages');

    final snap = await messagesRef.get();
    final batch = db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([myUid]),
      });
    }
    await batch.commit();

    // Zera o resumo da última mensagem mostrado no card da lista
    await db.collection('chats').doc(_chatIdResolvido).set({
      'unreadCount_$myUid': 0,
    }, SetOptions(merge: true));

    HapticFeedback.mediumImpact();
    onChanged?.call();
  }

  Future<void> _excluirAmigo(BuildContext context) async {
    Navigator.pop(context);

    final idEncontrado = await _buscarRequestId();
    if (idEncontrado == null) return;

    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C0C0C),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover amigo?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Tem certeza que quer remover @${friend.username}?',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover',
                style: TextStyle(
                    color: Color(0xFFED4245), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    await db.collection('friend_requests').doc(idEncontrado).delete();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
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
              AmigoAvatar(friend: friend, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            friend.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (friend.achievements.isNotEmpty)
                          FileiraBadges(
                              achievementIds: friend.achievements),
                      ],
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
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ItemMenu(
            icon: Icons.person_rounded,
            label: 'Ver Perfil',
            color: Colors.white,
            onTap: () => Navigator.pop(context),
          ),
          _ItemMenu(
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
          _ItemMenu(
            icon: friend.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: friend.isFavorite
                ? 'Remover dos Favoritos'
                : 'Adicionar aos Favoritos',
            color: const Color(0xFFFAA61A),
            onTap: () => _alternarFavorito(context),
          ),
          _ItemMenu(
            icon: Icons.notifications_off_rounded,
            label: 'Silenciar',
            color: const Color(0xFF747F8D),
            onTap: () => Navigator.pop(context),
          ),
          _ItemMenu(
            icon: Icons.delete_sweep_rounded,
            label: 'Limpar Conversa',
            color: const Color(0xFF747F8D),
            onTap: () => _limparConversa(context),
          ),
          const Divider(color: Color(0xFF1A1A1A), height: 20),
          _ItemMenu(
            icon: Icons.person_remove_rounded,
            label: 'Excluir Amigo',
            color: const Color(0xFFED4245),
            onTap: () => _excluirAmigo(context),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ItemMenu({
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
